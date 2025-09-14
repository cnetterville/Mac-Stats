//
//  WiFiManager.swift
//  Mac Stats
//
//  Created by Mac Stats on Current Date
//

import Foundation
import CoreWLAN
import Network
import SystemConfiguration
import CoreLocation

// MARK: - WiFi Info Structure
struct WiFiInfo {
    let isConnected: Bool
    let networkName: String
    let signalStrength: Int // RSSI in dBm
    let securityType: String
    let hasPermission: Bool
    let errorMessage: String?
    let isWiFiEnabled: Bool
    let linkQuality: Double // 0.0 to 1.0
    let hasLocationPermission: Bool
    
    static let disconnected = WiFiInfo(
        isConnected: false,
        networkName: "",
        signalStrength: -100,
        securityType: "",
        hasPermission: true,
        errorMessage: nil,
        isWiFiEnabled: false,
        linkQuality: 0.0,
        hasLocationPermission: false
    )
    
    static let noPermission = WiFiInfo(
        isConnected: false,
        networkName: "",
        signalStrength: -100,
        securityType: "",
        hasPermission: false,
        errorMessage: "WiFi information requires additional permissions",
        isWiFiEnabled: false,
        linkQuality: 0.0,
        hasLocationPermission: false
    )
}

// MARK: - WiFi Manager
class WiFiManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var wifiInfo: WiFiInfo = .disconnected
    private var wifiClient: CWWiFiClient?
    private var networkMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "WiFiMonitor")
    private var locationManager: CLLocationManager?
    private var hasRequestedLocationPermission = false
    
    override init() {
        super.init()
        setupLocationManager()
        setupWiFiClient()
        setupNetworkMonitor()
        refreshWiFiInfo()
    }
    
    deinit {
        networkMonitor?.cancel()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Check current authorization status
        let authStatus = locationManager?.authorizationStatus ?? .notDetermined
        print("Current location authorization status: \(authStatus.rawValue)")
        
        if authStatus == .notDetermined && !hasRequestedLocationPermission {
            print("Requesting location permission for WiFi access...")
            locationManager?.requestAlwaysAuthorization()
            hasRequestedLocationPermission = true
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location authorization changed to: \(status.rawValue)")
        
        DispatchQueue.main.async {
            // Wait a moment for the permission to take effect, then refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshWiFiInfo()
            }
        }
    }
    
    private func setupWiFiClient() {
        wifiClient = CWWiFiClient.shared()
        print("WiFi client initialized successfully")
    }
    
    private func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            print("Network path changed - WiFi available: \(path.usesInterfaceType(.wifi)), satisfied: \(path.status == .satisfied)")
            DispatchQueue.main.async {
                self?.refreshWiFiInfo()
            }
        }
        networkMonitor?.start(queue: monitorQueue)
    }
    
    func refreshWiFiInfo() {
        print("Refreshing WiFi info...")
        
        let hasLocationPermission = checkLocationPermission()
        print("Location permission status: \(hasLocationPermission)")
        
        guard let client = wifiClient else {
            print("No WiFi client available")
            DispatchQueue.main.async {
                self.wifiInfo = .noPermission
            }
            return
        }
        
        // Try to get all interfaces first
        let interfaces = client.interfaces()
        print("Found \(interfaces?.count ?? 0) WiFi interfaces")
        
        // Try to get the default interface
        guard let interface = client.interface() else {
            print("No default WiFi interface found, trying alternative methods...")
            
            // Try network path monitoring as fallback
            if let wifiStatus = getWiFiStatusFromNetworkPath() {
                DispatchQueue.main.async {
                    self.wifiInfo = wifiStatus
                }
                return
            }
            
            DispatchQueue.main.async {
                self.wifiInfo = WiFiInfo(
                    isConnected: false,
                    networkName: "",
                    signalStrength: -100,
                    securityType: "",
                    hasPermission: true,
                    errorMessage: "No WiFi interface found",
                    isWiFiEnabled: false,
                    linkQuality: 0.0,
                    hasLocationPermission: hasLocationPermission
                )
            }
            return
        }
        
        // Check if WiFi is powered on
        let isWiFiEnabled = interface.powerOn()
        print("WiFi enabled: \(isWiFiEnabled)")
        
        // Try to get SSID
        let ssid = interface.ssid()
        print("SSID from CoreWLAN: \(ssid ?? "nil")")
        
        // Check if we're actually connected using multiple methods
        var isConnected = false
        var networkName = ""
        var signalStrength = -100
        var securityType = ""
        
        if let ssidName = ssid, !ssidName.isEmpty {
            // We got SSID successfully
            isConnected = true
            networkName = ssidName
            signalStrength = interface.rssiValue()
            securityType = getSecurityType(from: interface)
            print("Successfully got WiFi details via CoreWLAN")
        } else if isWiFiEnabled {
            // WiFi is enabled but no SSID - might be permission issue or not connected
            print("WiFi is enabled but SSID is unavailable")
            
            // Check if network path monitoring indicates WiFi is active
            if let networkPathInfo = getWiFiStatusFromNetworkPath() {
                print("Network path method found WiFi connection")
                isConnected = networkPathInfo.isConnected
                networkName = networkPathInfo.networkName
                signalStrength = networkPathInfo.signalStrength
                securityType = networkPathInfo.securityType
            } else if isWiFiLikelyActive() {
                // Interface-based detection suggests WiFi is active
                print("Interface analysis suggests WiFi is active")
                isConnected = true
                networkName = hasLocationPermission ? "Connected Network" : "Connected (Name Hidden)"
                signalStrength = -55 // Reasonable estimate
                securityType = "Unknown"
            } else {
                // Try the alternative method as final fallback
                if let alternativeInfo = getAlternativeWiFiInfo() {
                    isConnected = alternativeInfo.isConnected
                    networkName = alternativeInfo.networkName
                    signalStrength = alternativeInfo.signalStrength
                    securityType = alternativeInfo.securityType
                }
            }
        }
        
        if isConnected && networkName.isEmpty {
            networkName = hasLocationPermission ? "Connected Network" : "Connected (Name Hidden)"
        }
        
        let quality = isConnected ? calculateLinkQuality(rssi: signalStrength) : 0.0
        
        DispatchQueue.main.async {
            self.wifiInfo = WiFiInfo(
                isConnected: isConnected,
                networkName: networkName,
                signalStrength: signalStrength,
                securityType: securityType,
                hasPermission: true,
                errorMessage: isConnected ? nil : (isWiFiEnabled ? "Not connected to any network" : "WiFi is disabled"),
                isWiFiEnabled: isWiFiEnabled,
                linkQuality: quality,
                hasLocationPermission: hasLocationPermission
            )
        }
        
        if isConnected {
            print("Successfully updated WiFi info - Connected to: \(networkName)")
        } else {
            print("WiFi is \(isWiFiEnabled ? "enabled but not connected" : "disabled")")
        }
    }
    
    private func checkLocationPermission() -> Bool {
        guard let manager = locationManager else { return false }
        let status = manager.authorizationStatus
        return status == .authorizedAlways
    }
    
    private func getWiFiStatusFromNetworkPath() -> WiFiInfo? {
        // Use NWPathMonitor to check current path with better detection
        let pathMonitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        var result: WiFiInfo?
        
        pathMonitor.pathUpdateHandler = { path in
            print("Network path status: \(path.status), available interfaces: \(path.availableInterfaces)")
            
            // Check if WiFi is being used
            let hasWiFi = path.usesInterfaceType(.wifi)
            let hasEthernet = path.usesInterfaceType(.wiredEthernet)
            let isSatisfied = path.status == .satisfied
            
            print("Network analysis - WiFi: \(hasWiFi), Ethernet: \(hasEthernet), Satisfied: \(isSatisfied)")
            
            if hasWiFi && isSatisfied {
                print("Network path confirms active WiFi connection")
                result = WiFiInfo(
                    isConnected: true,
                    networkName: self.checkLocationPermission() ? "WiFi Network (Details Limited)" : "WiFi Connected",
                    signalStrength: -50, // Estimate for active connection
                    securityType: "Unknown",
                    hasPermission: true,
                    errorMessage: nil,
                    isWiFiEnabled: true,
                    linkQuality: 0.7,
                    hasLocationPermission: self.checkLocationPermission()
                )
            } else if hasWiFi && !isSatisfied {
                // WiFi interface available but connection issues
                result = WiFiInfo(
                    isConnected: false,
                    networkName: "",
                    signalStrength: -100,
                    securityType: "",
                    hasPermission: true,
                    errorMessage: "WiFi interface detected but connection unsatisfied",
                    isWiFiEnabled: true,
                    linkQuality: 0.0,
                    hasLocationPermission: self.checkLocationPermission()
                )
            }
            
            semaphore.signal()
        }
        
        pathMonitor.start(queue: DispatchQueue.global())
        _ = semaphore.wait(timeout: .now() + 2.0) // Wait up to 2 seconds
        pathMonitor.cancel()
        
        return result
    }
    
    private func getAlternativeWiFiInfo() -> WiFiInfo? {
        // Use NWPathMonitor to detect WiFi connectivity more reliably
        let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let semaphore = DispatchSemaphore(value: 0)
        var result: WiFiInfo?
        
        pathMonitor.pathUpdateHandler = { path in
            print("Alternative WiFi check - WiFi interface active: \(path.usesInterfaceType(.wifi)), status: \(path.status)")
            
            if path.usesInterfaceType(.wifi) && path.status == .satisfied {
                // WiFi is active and connected
                result = WiFiInfo(
                    isConnected: true,
                    networkName: self.checkLocationPermission() ? "Connected Network (Limited Info)" : "Connected (Name Hidden)",
                    signalStrength: -50, // Reasonable estimate
                    securityType: "Unknown",
                    hasPermission: true,
                    errorMessage: nil,
                    isWiFiEnabled: true,
                    linkQuality: 0.7,
                    hasLocationPermission: self.checkLocationPermission()
                )
                print("Alternative method detected active WiFi connection")
            } else if path.usesInterfaceType(.wifi) && path.status == .unsatisfied {
                // WiFi interface exists but not connected
                result = WiFiInfo(
                    isConnected: false,
                    networkName: "",
                    signalStrength: -100,
                    securityType: "",
                    hasPermission: true,
                    errorMessage: "WiFi interface available but not connected",
                    isWiFiEnabled: true,
                    linkQuality: 0.0,
                    hasLocationPermission: self.checkLocationPermission()
                )
                print("Alternative method detected WiFi interface but not connected")
            }
            
            semaphore.signal()
        }
        
        pathMonitor.start(queue: DispatchQueue.global())
        _ = semaphore.wait(timeout: .now() + 2.0) // Wait up to 2 seconds for more reliable results
        pathMonitor.cancel()
        
        return result
    }
    
    // Helper method to check active network interfaces
    private func getActiveNetworkInterfaces() -> [String] {
        var interfaces: [String] = []
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            print("Failed to get network interfaces")
            return interfaces
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)
            let flags = interface.ifa_flags
            
            // Check if interface is up and running
            if (flags & UInt32(IFF_UP)) != 0 && (flags & UInt32(IFF_RUNNING)) != 0 {
                interfaces.append(name)
                print("Active interface found: \(name)")
            }
            
            ptr = interface.ifa_next
        }
        
        return interfaces
    }
    
    // Helper method to check if WiFi is likely active based on interface names
    private func isWiFiLikelyActive() -> Bool {
        let activeInterfaces = getActiveNetworkInterfaces()
        
        // Look for typical WiFi interface names on macOS
        let wifiPatterns = ["en0", "en1", "en2"] // Common WiFi interface names
        
        for interface in activeInterfaces {
            // Check if this looks like a WiFi interface
            if wifiPatterns.contains(interface) {
                // Additional check: en0 is usually WiFi on most Macs
                if interface == "en0" {
                    print("Interface \(interface) detected - likely WiFi (en0 is typically WiFi)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func calculateLinkQuality(rssi: Int) -> Double {
        // Convert RSSI to a quality percentage (0.0 to 1.0)
        // RSSI typically ranges from -30 (excellent) to -90 (poor)
        let normalizedRssi = max(-90, min(-30, rssi))
        return Double(normalizedRssi + 90) / 60.0
    }
    
    private func getSecurityType(from interface: CWInterface) -> String {
        let security = interface.security()
        
        switch security {
        case .none:
            return "Open"
        case .WEP:
            return "WEP"
        case .wpaPersonal:
            return "WPA Personal"
        case .wpaPersonalMixed:
            return "WPA/WPA2 Personal"
        case .wpa2Personal:
            return "WPA2 Personal"
        case .personal:
            return "WPA3 Personal"
        case .dynamicWEP:
            return "Dynamic WEP"
        case .wpaEnterprise:
            return "WPA Enterprise"
        case .wpaEnterpriseMixed:
            return "WPA/WPA2 Enterprise"
        case .wpa2Enterprise:
            return "WPA2 Enterprise"
        case .enterprise:
            return "WPA3 Enterprise"
        @unknown default:
            return "Unknown"
        }
    }
    
    // Helper function to request location permission manually
    func requestLocationPermission() {
        guard let manager = locationManager else { return }
        
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
    }
    
    // Helper function to get signal strength as a percentage
    func getSignalStrengthPercentage() -> Int {
        // RSSI typically ranges from -30 (excellent) to -90 (poor)
        // Convert to 0-100 percentage
        let rssi = wifiInfo.signalStrength
        let percentage = max(0, min(100, (rssi + 90) * 100 / 60))
        return percentage
    }
    
    // Helper function to get signal strength description
    func getSignalStrengthDescription() -> String {
        let percentage = getSignalStrengthPercentage()
        switch percentage {
        case 80...100:
            return "Excellent"
        case 60...79:
            return "Good"
        case 40...59:
            return "Fair"
        case 20...39:
            return "Weak"
        default:
            return "Poor"
        }
    }
    
    // Helper function to get WiFi icon name
    func getWiFiIconName() -> String {
        if !wifiInfo.isWiFiEnabled {
            return "wifi.slash"
        }
        
        if !wifiInfo.isConnected {
            return "wifi.exclamationmark"
        }
        
        if !wifiInfo.hasLocationPermission {
            return "wifi.router"
        }
        
        let percentage = getSignalStrengthPercentage()
        switch percentage {
        case 75...100:
            return "wifi"
        case 50...74:
            return "wifi"
        case 25...49:
            return "wifi"
        default:
            return "wifi"
        }
    }
    
    // Helper function to get WiFi icon color
    func getWiFiIconColor() -> String {
        if !wifiInfo.isWiFiEnabled {
            return "secondary"
        }
        
        if !wifiInfo.isConnected {
            return "orange"
        }
        
        if !wifiInfo.hasLocationPermission {
            return "blue"
        }
        
        let percentage = getSignalStrengthPercentage()
        switch percentage {
        case 75...100:
            return "green"
        case 50...74:
            return "yellow"
        case 25...49:
            return "orange"
        default:
            return "red"
        }
    }
}