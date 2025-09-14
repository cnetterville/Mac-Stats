//
//  SystemMonitor.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Foundation
import Darwin
import AppKit
import IOKit
import IOKit.ps

// Rename ProcessInfo to SystemProcessInfo to avoid conflict with Foundation's ProcessInfo
struct SystemProcessInfo: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryUsage: Double
}

// Struct to hold UPS information
struct UPSInfo {
    let name: String
    let isCharging: Bool
    let chargeLevel: Double
    let timeRemaining: Double // in minutes
    let present: Bool
    let manufacturer: String
    let model: String
    let serialNumber: String
    let voltage: Double // in volts
    let loadPercentage: Double // percentage of UPS capacity being used
    let powerSource: String // "AC Power" or "UPS Power" or "Battery Power"
    
    init() {
        self.name = "Unknown"
        self.isCharging = false
        self.chargeLevel = 0.0
        self.timeRemaining = 0.0
        self.present = false
        self.manufacturer = "Unknown"
        self.model = "Unknown"
        self.serialNumber = "Unknown"
        self.voltage = 0.0
        self.loadPercentage = 0.0
        self.powerSource = "Unknown"
    }
    
    init(name: String, isCharging: Bool, chargeLevel: Double, timeRemaining: Double, present: Bool, manufacturer: String, model: String, serialNumber: String, voltage: Double, loadPercentage: Double, powerSource: String) {
        self.name = name
        self.isCharging = isCharging
        self.chargeLevel = chargeLevel
        self.timeRemaining = timeRemaining
        self.present = present
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.voltage = voltage
        self.loadPercentage = loadPercentage
        self.powerSource = powerSource
    }
    
    init(powerSource: String) {
        self.name = "Unknown"
        self.isCharging = false
        self.chargeLevel = 0.0
        self.timeRemaining = 0.0
        self.present = false
        self.manufacturer = "Unknown"
        self.model = "Unknown"
        self.serialNumber = "Unknown"
        self.voltage = 0.0
        self.loadPercentage = 0.0
        self.powerSource = powerSource
    }
}

// Struct to hold Battery information
struct BatteryInfo {
    let name: String
    let isCharging: Bool
    let chargeLevel: Double
    let timeRemaining: Double // in minutes
    let present: Bool
    let cycleCount: Int
    let health: String // "Good", "Fair", "Poor"
    let temperature: Double // in Celsius
    let amperage: Double // in mA
    let voltage: Double // in mV
    let maxCapacity: Int // Maximum capacity percentage
    
    init() {
        self.name = "Unknown"
        self.isCharging = false
        self.chargeLevel = 0.0
        self.timeRemaining = 0.0
        self.present = false
        self.cycleCount = 0
        self.health = "Unknown"
        self.temperature = 0.0
        self.amperage = 0.0
        self.voltage = 0.0
        self.maxCapacity = 100
    }
    
    init(name: String, isCharging: Bool, chargeLevel: Double, timeRemaining: Double, present: Bool, cycleCount: Int, health: String, temperature: Double, amperage: Double, voltage: Double, maxCapacity: Int = 100) {
        self.name = name
        self.isCharging = isCharging
        self.chargeLevel = chargeLevel
        self.timeRemaining = timeRemaining
        self.present = present
        self.cycleCount = cycleCount
        self.health = health
        self.temperature = temperature
        self.amperage = amperage
        self.voltage = voltage
        self.maxCapacity = maxCapacity
    }
}

// Struct to hold GPU information
struct GPUInfo {
    let name: String
    let utilization: Double
    let temperature: Double
    let memoryUsed: Double
    let memoryTotal: Double
    
    init() {
        self.name = "Unknown"
        self.utilization = 0.0
        self.temperature = 0.0
        self.memoryUsed = 0.0
        self.memoryTotal = 0.0
    }
    
    init(name: String, utilization: Double, temperature: Double, memoryUsed: Double, memoryTotal: Double) {
        self.name = name
        self.utilization = utilization
        self.temperature = temperature
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
    }
}

// Struct to hold Fan information
struct FanInfo: Identifiable {
    let id = UUID()
    let name: String
    let currentSpeed: Int
    let minSpeed: Int
    let maxSpeed: Int
    
    init(name: String, currentSpeed: Int, minSpeed: Int, maxSpeed: Int) {
        self.name = name
        self.currentSpeed = currentSpeed
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
    }
}

// Struct to hold Temperature sensors
struct TemperatureInfo: Identifiable {
    let id = UUID()
    let name: String
    let temperature: Double // in Celsius
    
    init(name: String, temperature: Double) {
        self.name = name
        self.temperature = temperature
    }
}

// Struct to hold System Information
struct SystemInfo {
    let modelName: String
    let macOSVersion: String
    let kernelVersion: String
    let uptime: TimeInterval
    let bootTime: Date
    let chipInfo: String  // Added chip information
    
    init() {
        self.modelName = "Unknown"
        self.macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.kernelVersion = "Unknown"
        self.uptime = 0
        self.bootTime = Date()
        self.chipInfo = "Unknown"
    }
    
    init(modelName: String, macOSVersion: String, kernelVersion: String, uptime: TimeInterval, bootTime: Date, chipInfo: String = "Unknown") {
        self.modelName = modelName
        self.macOSVersion = macOSVersion
        self.kernelVersion = kernelVersion
        self.uptime = uptime
        self.bootTime = bootTime
        self.chipInfo = chipInfo
    }
}

// Struct to hold Power Consumption information
struct PowerConsumptionInfo {
    let cpuPower: Double // in watts
    let gpuPower: Double // in watts
    let totalSystemPower: Double // in watts (now represents whole system power)
    let timestamp: Date
    let isEstimate: Bool
    
    init() {
        self.cpuPower = 0.0
        self.gpuPower = 0.0
        self.totalSystemPower = 0.0
        self.timestamp = Date()
        self.isEstimate = true
    }
    
    init(cpuPower: Double, gpuPower: Double, totalSystemPower: Double, timestamp: Date, isEstimate: Bool) {
        self.cpuPower = cpuPower
        self.gpuPower = gpuPower
        self.totalSystemPower = totalSystemPower
        self.timestamp = timestamp
        self.isEstimate = isEstimate
    }
}

class SystemMonitor: ObservableObject {
    // MARK: - Constants
    private struct Constants {
        static let maxHistoryPoints = 30
        static let defaultUpdateInterval: TimeInterval = 2.0
        static let defaultPowerUpdateInterval: TimeInterval = 30.0
        static let externalIPRefreshInterval: TimeInterval = 30 * 60 // 30 minutes
        static let notificationCooldownPeriod: TimeInterval = 300 // 5 minutes
        static let gbDivisor: Double = 1000 * 1000 * 1000 // Use decimal GB
        static let processCountThreshold = 5
        static let minCpuUsageFilter = 0.1
        static let minMemoryUsageFilter = 0.1
    }
    
    // MARK: - Published Properties
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var memoryUsage: (used: Double, total: Double) = (0.0, 0.0)
    @Published var diskUsage: (free: Double, total: Double) = (0.0, 0.0)
    @Published var networkUsage: (upload: Double, download: Double) = (0.0, 0.0)
    @Published var networkInterfaces: [String] = []
    @Published var topProcesses: [SystemProcessInfo] = []
    @Published var topMemoryProcesses: [SystemProcessInfo] = []
    @Published var upsInfo: UPSInfo = UPSInfo() // UPS information
    @Published var batteryInfo: BatteryInfo = BatteryInfo() // Battery information
    @Published var systemInfo: SystemInfo = SystemInfo() // System information
    @Published var powerConsumptionInfo: PowerConsumptionInfo = PowerConsumptionInfo() // Power consumption information
    @Published var initialDataLoaded: Bool = false
    @Published var cpuHistory: [Double] = []
    @Published var cpuTemperatureHistory: [Double] = []
    @Published var uploadHistory: [Double] = []
    @Published var downloadHistory: [Double] = []
    
    // MARK: - Private Properties
    private var previousUPSPowerState: Bool = false
    private var lastUPSPowerNotificationTime: Date?
    private var timer: Timer?
    private var powerTimer: Timer?
    private var updateInterval: TimeInterval = Constants.defaultUpdateInterval
    private var powerUpdateInterval: TimeInterval = Constants.defaultPowerUpdateInterval
    private var previousInterfaceStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var lastUpdateTime: Date = Date()
    private var externalIPRefreshTimer: Timer?
    private var previousCPUInfo = host_cpu_load_info()
    weak var preferences: PreferencesManager? {
        didSet {
            // Update intervals when preferences are set
            if let preferences = preferences {
                updateInterval = preferences.updateInterval
                powerUpdateInterval = preferences.powerUpdateInterval
            }
        }
    }
    
    init() {
        refreshNetworkInterfaces()
        // Data will be refreshed when the view appears.
        startMonitoring()
        startExternalIPRefresh()
    }
    
    func startMonitoring() {
        // Update intervals from preferences if available
        if let preferences = preferences {
            updateInterval = preferences.updateInterval
            powerUpdateInterval = preferences.powerUpdateInterval
        }
        
        // Update stats immediately and then schedule the timer
        updateStats()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        
        // Update power consumption immediately and then schedule the power timer
        updatePowerConsumption()
        powerTimer = Timer.scheduledTimer(withTimeInterval: powerUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePowerConsumption()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        powerTimer?.invalidate()
        powerTimer = nil
    }
    
    // Reset UPS power state tracking (useful when restarting monitoring)
    func resetUPSPowerStateTracking() {
        previousUPSPowerState = !upsInfo.isCharging  // Reset to current state
        lastUPSPowerNotificationTime = nil
    }
    
    func updateMonitoringInterval(_ interval: TimeInterval) {
        stopMonitoring()
        updateInterval = interval
        startMonitoring()
    }
    
    // New method to update power consumption interval
    func updatePowerMonitoringInterval(_ interval: TimeInterval) {
        powerTimer?.invalidate()
        powerTimer = nil
        powerUpdateInterval = interval
        
        // Restart power monitoring with new interval
        updatePowerConsumption()
        powerTimer = Timer.scheduledTimer(withTimeInterval: powerUpdateInterval, repeats: true) { [weak self] _ in
            self?.updatePowerConsumption()
        }
    }
    
    // Start a timer to refresh external IP every 30 minutes
    private func startExternalIPRefresh() {
        // Refresh immediately
        ExternalIPManager.shared.refreshExternalIP()
        
        // Then refresh every 30 minutes
        externalIPRefreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.externalIPRefreshInterval, repeats: true) { _ in
            ExternalIPManager.shared.refreshExternalIP()
        }
    }
    
    private func stopExternalIPRefresh() {
        externalIPRefreshTimer?.invalidate()
        externalIPRefreshTimer = nil
    }
    
    // Method to refresh all data immediately
    func refreshAllData() {
        let group = DispatchGroup()
        var cpu: Double = 0.0
        var cpuTemp: Double = 0.0
        var memory: (used: Double, total: Double) = (0.0, 0.0)
        var disk: (free: Double, total: Double) = (0.0, 0.0)
        var network: (upload: Double, download: Double) = (0.0, 0.0)
        var ups: UPSInfo = UPSInfo()
        var battery: BatteryInfo = BatteryInfo()
        var powerConsumption: PowerConsumptionInfo = PowerConsumptionInfo()
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            cpu = self.getCurrentCPU()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            cpuTemp = self.getCurrentCPUTemperature()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            memory = self.getCurrentMemory()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            disk = self.getCurrentDisk()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            network = self.getCurrentNetwork()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            ups = self.getCurrentUPSInfo()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            battery = self.getCurrentBatteryInfo()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            powerConsumption = self.getCurrentPowerConsumption()
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.updateCPUHistory(with: cpu)
            self.updateCPUTemperatureHistory(with: cpuTemp)
            self.updateNetworkHistory(upload: network.upload, download: network.download)
            self.cpuUsage = cpu
            self.cpuTemperature = cpuTemp
            self.memoryUsage = memory
            self.diskUsage = disk
            self.networkUsage = network
            self.upsInfo = ups
            self.batteryInfo = battery
            self.powerConsumptionInfo = powerConsumption
            self.initialDataLoaded = true
            
            // Reset UPS power state tracking after initial load
            self.resetUPSPowerStateTracking()
        }
    }
    
    func refreshNetworkInterfaces() {
        guard let output = executeCommand("/sbin/ifconfig", []) else {
            print("Error getting network interfaces")
            DispatchQueue.main.async {
                self.networkInterfaces = []
            }
            return
        }
        
        // More efficient parsing without regex
        let lines = output.split(separator: "\n")
        var interfaces: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line starts with interface name (ends with colon)
            if let colonIndex = trimmedLine.firstIndex(of: ":"),
               colonIndex == trimmedLine.index(before: trimmedLine.endIndex) || 
               trimmedLine[trimmedLine.index(after: colonIndex)].isWhitespace {
                
                let interfaceName = String(trimmedLine[..<colonIndex])
                
                // Filter out loopback and inactive interfaces
                if !interfaceName.hasPrefix("lo") && interfaceName != "gif0" && interfaceName != "stf0" {
                    interfaces.append(interfaceName)
                }
            }
        }
        
        let sortedInterfaces = interfaces.sorted()
        
        // Thread-safe updates
        DispatchQueue.main.async {
            self.networkInterfaces = sortedInterfaces
            self.previousInterfaceStats.removeAll()
            self.lastUpdateTime = Date()
            
            // Get initial stats for each interface
            DispatchQueue.global(qos: .userInitiated).async {
                var initialStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
                for interface in sortedInterfaces {
                    let stats: (bytesIn: UInt64, bytesOut: UInt64)
                    
                    // Special handling for bond interfaces
                    if self.isBondInterface(interface) {
                        stats = self.getBondInterfaceStats(bondInterface: interface)
                    } else {
                        stats = self.getInterfaceStats(interface: interface)
                    }
                    
                    initialStats[interface] = stats
                }
                
                DispatchQueue.main.async {
                    self.previousInterfaceStats = initialStats
                }
            }
        }
    }
    
    private func getInterfaceStats(interface: String) -> (bytesIn: UInt64, bytesOut: UInt64) {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        task.arguments = ["-b", "-I", interface]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse the output to get bytes in/out
                let lines = output.split(separator: "\n")
                for line in lines {
                    let components = line.split(separator: " ").map { String($0) }
                    if components.count >= 7 && components[0] == interface {
                        // Extract bytes in (6th column) and bytes out (9th column)
                        if let bytesIn = UInt64(components[6]), let bytesOut = UInt64(components[9]) {
                            return (bytesIn: bytesIn, bytesOut: bytesOut)
                        }
                    }
                }
            }
        } catch {
            print("Error getting stats for interface \(interface): \(error)")
        }
        
        return (bytesIn: 0, bytesOut: 0)
    }
    
    private func updateStats() {
        // Run updates on a background thread to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            let cpu = self.getCurrentCPU()
            let cpuTemp = self.getCurrentCPUTemperature()
            let memory = self.getCurrentMemory()
            let disk = self.getCurrentDisk()
            let network = self.getCurrentNetwork()
            let processes = self.getTopProcesses(count: Constants.processCountThreshold)
            let memoryProcesses = self.getTopMemoryProcesses(count: Constants.processCountThreshold)
            let ups = self.getCurrentUPSInfo()
            let battery = self.getCurrentBatteryInfo() // Get battery info
            let systemInfo = self.getCurrentSystemInfo()// Get system info
            // NOTE: Power consumption is now updated separately
            
            DispatchQueue.main.async {
                self.updateCPUHistory(with: cpu)
                self.updateCPUTemperatureHistory(with: cpuTemp)
                self.updateNetworkHistory(upload: network.upload, download: network.download)
                self.cpuUsage = cpu
                self.cpuTemperature = cpuTemp
                self.memoryUsage = memory
                self.diskUsage = disk
                self.networkUsage = network
                self.topProcesses = processes
                self.topMemoryProcesses = memoryProcesses
                self.upsInfo = ups
                self.batteryInfo = battery// Update battery info
                self.systemInfo = systemInfo// Update system info
                self.initialDataLoaded = true
                
                // Check for UPS power state changes and send notification if needed
                self.checkAndNotifyUPSPowerChange()
            }
        }
    }
    
    // New method to update power consumption separately
    private func updatePowerConsumption() {
        DispatchQueue.global(qos: .userInitiated).async {
            let powerConsumption = self.getCurrentPowerConsumption()
            
            DispatchQueue.main.async {
                self.powerConsumptionInfo = powerConsumption
            }
        }
    }
    
    // Check if UPS power state has changed and send notification if needed
    private func checkAndNotifyUPSPowerChange() {
        guard let preferences = self.preferences else { return }
        
        // Only proceed if UPS is present and notifications are enabled
        guard upsInfo.present && preferences.upsPowerChangeNotificationEnabled else { return }
        
        // Don't send notifications during initial startup until data is loaded
        guard initialDataLoaded else {
            // Set the initial power state without sending notification
            previousUPSPowerState = upsInfo.powerSource == "UPS Power"
            return
        }
        
        // Check if the power source has changed
        // When drawing from "AC Power", we're on AC; when drawing from "UPS Power", we're on battery
        let isOnBatteryPower = upsInfo.powerSource == "UPS Power"
        let powerStateChanged = previousUPSPowerState != isOnBatteryPower
        
        // Update the previous state
        previousUPSPowerState = isOnBatteryPower
        
        // If state changed and email notifications are enabled, send notification
        if powerStateChanged && preferences.mailjetEmailEnabled {
            self.sendUPSPowerChangeNotification(isOnBattery: isOnBatteryPower)
        }
    }
    
    // Send email notification when UPS power state changes
    private func sendUPSPowerChangeNotification(isOnBattery: Bool) {
        guard let preferences = self.preferences else { return }
        
        let notificationTimestamp = Date()
        
        // Check cooldown period using constant
        var timeSinceLastNotification: TimeInterval = 0
        if let lastNotification = lastUPSPowerNotificationTime {
            timeSinceLastNotification = notificationTimestamp.timeIntervalSince(lastNotification)
            
            // Only apply cooldown to power loss notifications to prevent spam
            if isOnBattery && timeSinceLastNotification < Constants.notificationCooldownPeriod {
                return 
            }
        }
        
        let subject = isOnBattery ? 
            "UPS Power Loss - Running on Battery" : 
            "UPS Power Restored - AC Power Available"
        
        let timestamp = notificationTimestamp.formatted(date: .complete, time: .shortened)
        
        // Format the duration string for power restoration
        let durationString = isOnBattery ? "" : self.formatDuration(timeSinceLastNotification)
        
        let message = isOnBattery ?
            """
            Power loss detected! Your UPS is now running on battery power.
            
            UPS Name: \(self.upsInfo.name)
            Current Charge: \(String(format: "%.1f", self.upsInfo.chargeLevel))%
            Estimated Time Remaining: \(self.formatTime(self.upsInfo.timeRemaining))
            Timestamp: \(timestamp)
            
            Please check your power supply immediately.
            
            This is an automated notification from Mac Stats.
            """ :
            """
            Power restored! Your UPS is now running on AC power.
            
            UPS Name: \(self.upsInfo.name)
            Current Charge: \(String(format: "%.1f", self.upsInfo.chargeLevel))%
            Power Outage Duration: \(durationString)
            Timestamp: \(timestamp)
            
            This is an automated notification from Mac Stats.
            """
        
        // Use the "To" email if specified, otherwise use the "From" email
        let toEmail = preferences.mailjetToEmail.isEmpty ? preferences.mailjetFromEmail : preferences.mailjetToEmail
        
        EmailService.shared.sendMailjetEmail(
            apiKey: preferences.mailjetAPIKey,
            apiSecret: preferences.mailjetAPISecret,
            fromEmail: preferences.mailjetFromEmail,
            fromName: preferences.mailjetFromName.isEmpty ? "Mac Stats" : preferences.mailjetFromName,
            toEmail: toEmail,
            subject: subject,
            message: message
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("UPS power change notification sent successfully: \(response)")
                case .failure(let error):
                    print("Failed to send UPS power change notification: \(error)")
                }
            }
        }
        
        // Update last notification time
        lastUPSPowerNotificationTime = notificationTimestamp
    }
    
    // Helper function to format time in hours and minutes (copied from StatsMenuView)
    private func formatTime(_ minutes: Double) -> String {
        // Handle invalid time values (-1 is used by macOS when time can't be calculated)
        if minutes <= 0 || minutes == -1 || minutes.isNaN || minutes.isInfinite {
            return "Calculating..."
        }
        
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // Update CPU history for sparkline
    private func updateCPUHistory(with cpuValue: Double) {
        cpuHistory.append(cpuValue)
        
        // Keep only the last Constants.maxHistoryPoints values
        if cpuHistory.count > Constants.maxHistoryPoints {
            cpuHistory.removeFirst()
        }
    }
    
    // Update CPU temperature history for sparkline
    private func updateCPUTemperatureHistory(with tempValue: Double) {
        cpuTemperatureHistory.append(tempValue)
        
        // Keep only the last Constants.maxHistoryPoints values
        if cpuTemperatureHistory.count > Constants.maxHistoryPoints {
            cpuTemperatureHistory.removeFirst()
        }
    }
    
    // Update network history for sparklines
    private func updateNetworkHistory(upload: Double, download: Double) {
        uploadHistory.append(upload)
        downloadHistory.append(download)
        
        // Keep only the last Constants.maxHistoryPoints values
        if uploadHistory.count > Constants.maxHistoryPoints {
            uploadHistory.removeFirst()
        }
        
        if downloadHistory.count > Constants.maxHistoryPoints {
            downloadHistory.removeFirst()
        }
    }
    
    // Get UPS information
    private func getCurrentUPSInfo() -> UPSInfo {
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return UPSInfo()
        }
        
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return UPSInfo()
        }
        
        // Get power source from pmset command
        let powerSource = getPowerSourceFromPMSet()
        
        // Look for UPS power source
        for powerSourceRef in powerSourcesList {
            if let powerSourceInfo = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSourceRef)?.takeUnretainedValue() as? [String: Any] {
                
                // Check if this is a UPS (not internal battery)
                if let type = powerSourceInfo[kIOPSTypeKey] as? String,
                   type == kIOPSUPSType {
                    
                    let name = powerSourceInfo[kIOPSNameKey] as? String ?? "UPS"
                    let isCharging = powerSourceInfo[kIOPSIsChargingKey] as? Bool ?? false
                    let chargeLevel = powerSourceInfo[kIOPSCurrentCapacityKey] as? Double ?? 0.0
                    let timeRemaining = powerSourceInfo[kIOPSTimeToEmptyKey] as? Double ?? 0.0
                    // Check if UPS is present - we can determine this from pmset output
                    let present = powerSource != "Unknown"
                    
                    // Additional UPS information
                    let manufacturer = powerSourceInfo["Manufacturer"] as? String ?? "Unknown"
                    let model = powerSourceInfo["Model"] as? String ?? "Unknown"
                    let serialNumber = powerSourceInfo["SerialNumber"] as? String ?? "Unknown"
                    let voltage = powerSourceInfo["Voltage"] as? Double ?? 0.0
                    let loadPercentage = powerSourceInfo["Load Percentage"] as? Double ?? 0.0
                    
                    return UPSInfo(
                        name: name,
                        isCharging: isCharging,
                        chargeLevel: chargeLevel,
                        timeRemaining: timeRemaining,
                        present: present,
                        manufacturer: manufacturer,
                        model: model,
                        serialNumber: serialNumber,
                        voltage: voltage,
                        loadPercentage: loadPercentage,
                        powerSource: powerSource // Use the power source from pmset
                    )
                }
            }
        }
        
        // No UPS found, but still return power source info if available
        return UPSInfo(powerSource: powerSource)
    }

    private func getPowerSourceFromPMSet() -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse the output to find the power source
                // Looking for lines like: "Now drawing from 'AC Power'"
                let lines = output.split(separator: "\n")
                for line in lines {
                    let lineString = String(line)
                    if lineString.contains("Now drawing from") {
                        // Extract the power source between single quotes
                        let pattern = "'([^']+)'"
                        if let regex = try? NSRegularExpression(pattern: pattern),
                           let match = regex.firstMatch(in: lineString, range: NSRange(location: 0, length: lineString.utf16.count)) {
                            let range = Range(match.range(at: 1), in: lineString)!
                            return String(lineString[range])
                        }
                    }
                }
            }
        } catch {
            print("Error running pmset command: \(error)")
        }
        
        return "Unknown"
    }
    
    // Helper function to detect if an interface is a bond interface
    private func isBondInterface(_ interfaceName: String) -> Bool {
        return interfaceName.hasPrefix("bond")
    }
    
    // Helper function to get constituent interfaces of a bond
    private func getBondConstituentInterfaces(_ bondInterface: String) -> [String] {
        // Try to get bond members from ifconfig output first
        if let members = getBondMembersFromIfconfig(bondInterface) {
            return members
        }
        
        // Fallback: For bond0, typically assume en0 and en1
        if bondInterface == "bond0" {
            // Check if en0 and en1 exist in our network interfaces
            let potentialMembers = ["en0", "en1"]
            return potentialMembers.filter { networkInterfaces.contains($0) }
        }
        
        // For other bond interfaces, try to infer from interface names
        if let bondNumber = bondInterface.replacingOccurrences(of: "bond", with: "").first?.wholeNumberValue {
            let startIndex = bondNumber * 2
            let potentialMembers = ["en\(startIndex)", "en\(startIndex + 1)"]
            return potentialMembers.filter { networkInterfaces.contains($0) }
        }
        
        return []
    }
    
    // Helper function to parse bond members from ifconfig output
    private func getBondMembersFromIfconfig(_ bondInterface: String) -> [String]? {
        guard let output = executeCommand("/sbin/ifconfig", [bondInterface]) else {
            return nil
        }
        
        var members: [String] = []
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            // Look for lines that mention member interfaces
            // Example: "member: en0 flags=3<LEARNING,SLAVE>"
            if trimmedLine.contains("member:") {
                let components = trimmedLine.split(separator: " ")
                if components.count >= 2 {
                    let memberInterface = String(components[1])
                    if !memberInterface.isEmpty && networkInterfaces.contains(memberInterface) {
                        members.append(memberInterface)
                    }
                }
            }
        }
        
        return members.isEmpty ? nil : members
    }
    
    // Helper function to get stats for bond interface by summing constituent interfaces
    private func getBondInterfaceStats(bondInterface: String) -> (bytesIn: UInt64, bytesOut: UInt64) {
        let constituentInterfaces = getBondConstituentInterfaces(bondInterface)
        
        guard !constituentInterfaces.isEmpty else {
            print("No constituent interfaces found for bond interface: \(bondInterface)")
            return (bytesIn: 0, bytesOut: 0)
        }
        
        print("Bond interface \(bondInterface) constituent interfaces: \(constituentInterfaces)")
        
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0
        
        for interface in constituentInterfaces {
            let stats = getInterfaceStats(interface: interface)
            totalBytesIn += stats.bytesIn
            totalBytesOut += stats.bytesOut
        }
        
        return (bytesIn: totalBytesIn, bytesOut: totalBytesOut)
    }
    
    // Get Battery information (laptop battery)
    private func getCurrentBatteryInfo() -> BatteryInfo {
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryInfo()
        }
        
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatteryInfo()
        }
        
        // Get additional battery details 
        // Removed getBatteryDetails function call
        
        // Look for Battery power source
        for powerSource in powerSourcesList {
            if let powerSourceInfo = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSource)?.takeUnretainedValue() as? [String: Any] {
                
                // Check if this is a Battery (internal battery)
                // Using string literal instead of undefined constant
                if let type = powerSourceInfo[kIOPSTypeKey] as? String,
                   type == "InternalBattery" {
                    
                    let name = powerSourceInfo[kIOPSNameKey] as? String ?? "Internal Battery"
                    let isCharging = powerSourceInfo[kIOPSIsChargingKey] as? Bool ?? false
                    let chargeLevel = powerSourceInfo[kIOPSCurrentCapacityKey] as? Double ?? 0.0
                    let present = powerSourceInfo[kIOPSIsPresentKey] as? Bool ?? false
                    
                    // Get cycle count - try multiple possible keys
                    let cycleCount: Int
                    if let count = powerSourceInfo["Cycle Count"] as? Int {
                        cycleCount = count
                    } else if let count = powerSourceInfo["AppleRawBatteryCycleCount"] as? Int {
                        cycleCount = count
                    } else {
                        cycleCount = 0
                    }
                    
                    let health = powerSourceInfo["BatteryHealth"] as? String ?? "Unknown"
                    
                    // Temperature conversion from 10ths of Kelvin to Celsius
                    let rawTemp = powerSourceInfo["Temperature"] as? Double ?? 0.0
                    let temperature = (rawTemp / 10.0) - 273.15 // Convert from 10ths of K to Celsius
                    
                    let amperage = powerSourceInfo["Amperage"] as? Double ?? 0.0
                    let voltage = powerSourceInfo["Voltage"] as? Double ?? 0.0
                    
                    // Get time remaining - use time to empty when discharging, time to full when charging
                    var timeRemaining = 0.0
                    if isCharging {
                        timeRemaining = powerSourceInfo[kIOPSTimeToFullChargeKey] as? Double ?? 0.0
                    } else {
                        timeRemaining = powerSourceInfo[kIOPSTimeToEmptyKey] as? Double ?? 0.0
                    }
                    
                    return BatteryInfo(
                        name: name,
                        isCharging: isCharging,
                        chargeLevel: chargeLevel,
                        timeRemaining: timeRemaining,
                        present: present,
                        cycleCount: cycleCount,
                        health: health,
                        temperature: temperature,
                        amperage: amperage,
                        voltage: voltage,
                        maxCapacity: 100 // Assume 100% max capacity
                    )
                }
            }
        }
        
        // No Battery found
        return BatteryInfo()
    }
    
    private func getCurrentCPU() -> Double {
        var cpuInfo = host_cpu_load_info()
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let user = Double(cpuInfo.cpu_ticks.0)
            let system = Double(cpuInfo.cpu_ticks.1)
            let idle = Double(cpuInfo.cpu_ticks.2)
            let nice = Double(cpuInfo.cpu_ticks.3)
            
            let prevUser = Double(previousCPUInfo.cpu_ticks.0)
            let prevSystem = Double(previousCPUInfo.cpu_ticks.1)
            let prevIdle = Double(previousCPUInfo.cpu_ticks.2)
            let prevNice = Double(previousCPUInfo.cpu_ticks.3)
            
            let total = (user - prevUser) + (system - prevSystem) + (idle - prevIdle) + (nice - prevNice)
            
            if total > 0 {
                let usage = ((user - prevUser + system - prevSystem + nice - prevNice) / total) * 100
                // Store current values for next calculation
                previousCPUInfo = cpuInfo
                return usage
            }
            
            // Store current values for next calculation
            previousCPUInfo = cpuInfo
        }
        
        return 0.0
    }
    
    private func getCurrentCPUTemperature() -> Double {
        return TemperatureMonitor.averageCPUTemperature()
    }
    
    private func getCurrentMemory() -> (used: Double, total: Double) {
        var stats = vm_statistics64()
        let HOST_VM_INFO64_COUNT = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(HOST_VM_INFO64_COUNT)
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: HOST_VM_INFO64_COUNT) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let pageSize = Double(vm_kernel_page_size)
            
            // Get total physical memory
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            
            // Correctly calculate used memory based on Activity Monitor's formula
            let wired = Double(stats.wire_count) * pageSize
            let active = Double(stats.active_count) * pageSize
            let compressed = Double(stats.compressor_page_count) * pageSize
            let used = wired + active + compressed

            // Convert to GB using constant
            let usedGB = used / Constants.gbDivisor
            let totalGB = Double(totalMemory) / Constants.gbDivisor
            
            return (used: usedGB, total: totalGB)
        }
        
        return (used: 0.0, total: 0.0)
    }
    
    private func getCurrentDisk() -> (free: Double, total: Double) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                // Convert to GB using constant
                let freeGB = Double(available) / Constants.gbDivisor
                let totalGB = Double(total) / Constants.gbDivisor
                
                return (free: freeGB, total: totalGB)
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        
        return (free: 0.0, total: 0.0)
    }
    
    private func getCurrentNetwork() -> (upload: Double, download: Double) {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
        
        // Check which interface is selected
        let selectedInterface = preferences?.selectedNetworkInterface ?? "All"
        
        // Collect current stats for all interfaces
        var currentStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0
        
        // Get current stats for all interfaces
        for interface in networkInterfaces {
            let stats: (bytesIn: UInt64, bytesOut: UInt64)
            
            // Special handling for bond interfaces
            if isBondInterface(interface) {
                stats = getBondInterfaceStats(bondInterface: interface)
            } else {
                stats = getInterfaceStats(interface: interface)
            }
            
            currentStats[interface] = stats
            totalBytesIn += stats.bytesIn
            totalBytesOut += stats.bytesOut
        }
        
        // Calculate rates (bytes per second)
        if timeInterval > 0 {
            var bytesInRate: Double = 0
            var bytesOutRate: Double = 0
            
            if selectedInterface == "All" {
                // Calculate for all interfaces combined
                var previousTotalBytesIn: UInt64 = 0
                var previousTotalBytesOut: UInt64 = 0
                
                for interface in networkInterfaces {
                    if let previous = previousInterfaceStats[interface] {
                        previousTotalBytesIn += previous.bytesIn
                        previousTotalBytesOut += previous.bytesOut
                    }
                }
                
                let bytesInDiff = totalBytesIn >= previousTotalBytesIn ? (totalBytesIn - previousTotalBytesIn) : 0
                let bytesOutDiff = totalBytesOut >= previousTotalBytesOut ? (totalBytesOut - previousTotalBytesOut) : 0
                
                bytesInRate = Double(bytesInDiff) / timeInterval
                bytesOutRate = Double(bytesOutDiff) / timeInterval
            } else {
                // Calculate for specific interface only
                if let current = currentStats[selectedInterface],
                   let previous = previousInterfaceStats[selectedInterface] {
                    let bytesInDiff = current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                    let bytesOutDiff = current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                    
                    bytesInRate = Double(bytesInDiff) / timeInterval
                    bytesOutRate = Double(bytesOutDiff) / timeInterval
                } else if isBondInterface(selectedInterface) {
                    // Special handling for bond interfaces - calculate based on constituent interfaces
                    let constituentInterfaces = getBondConstituentInterfaces(selectedInterface)
                    var constituentBytesInDiff: UInt64 = 0
                    var constituentBytesOutDiff: UInt64 = 0
                    
                    for constituentInterface in constituentInterfaces {
                        if let current = currentStats[constituentInterface],
                           let previous = previousInterfaceStats[constituentInterface] {
                            constituentBytesInDiff += current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                            constituentBytesOutDiff += current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                        }
                    }
                    
                    bytesInRate = Double(constituentBytesInDiff) / timeInterval
                    bytesOutRate = Double(constituentBytesOutDiff) / timeInterval
                }
            }
            
            // Thread-safe update of previous stats - do this on main thread
            DispatchQueue.main.async {
                self.previousInterfaceStats = currentStats
                self.lastUpdateTime = currentTime
            }
            
            return (upload: bytesOutRate, download: bytesInRate)
        }
        
        // Thread-safe update of previous stats even if we couldn't calculate rates
        DispatchQueue.main.async {
            self.previousInterfaceStats = currentStats
            self.lastUpdateTime = currentTime
        }
        
        return (upload: 0.0, download: 0.0)
    }
    
    private func getTopProcesses(count: Int) -> [SystemProcessInfo] {
        guard let output = executeCommand("/bin/ps", ["-A", "-o", "pid,%cpu,%mem,comm", "-c"]) else {
            print("Error getting process info")
            return []
        }
        
        let lines = output.split(separator: "\n").dropFirst() // Skip header
        var parsedProcesses: [SystemProcessInfo] = []
        parsedProcesses.reserveCapacity(lines.count) // Pre-allocate capacity
        
        for line in lines {
            let components = line.split(separator: " ").compactMap { $0.isEmpty ? nil : String($0) }
            
            guard components.count >= 4,
                  let pid = Int32(components[0]),
                  let cpu = Double(components[1].replacingOccurrences(of: "%", with: "")),
                  let mem = Double(components[2].replacingOccurrences(of: "%", with: "")) else {
                continue
            }
            
            let commandString = components[3...].joined(separator: " ")
            
            // Filter with constant threshold
            if cpu > Constants.minCpuUsageFilter || parsedProcesses.count < count {
                parsedProcesses.append(SystemProcessInfo(
                    pid: pid,
                    name: commandString,
                    cpuUsage: cpu,
                    memoryUsage: mem
                ))
            }
        }
        
        // Sort and return top processes
        return Array(parsedProcesses.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(count))
    }
    
    private func getTopMemoryProcesses(count: Int) -> [SystemProcessInfo] {
        guard let output = executeCommand("/bin/ps", ["-A", "-m", "-o", "pid,%mem,%cpu,comm", "-c"]) else {
            print("Error getting memory process info")
            return []
        }
        
        let lines = output.split(separator: "\n").dropFirst() // Skip header
        var parsedProcesses: [SystemProcessInfo] = []
        parsedProcesses.reserveCapacity(min(count + 5, lines.count))
        
        for line in lines.prefix(count + 5) { // Only process what we need
            let components = line.split(separator: " ").compactMap { $0.isEmpty ? nil : String($0) }
            
            guard components.count >= 4,
                  let pid = Int32(components[0]),
                  let mem = Double(components[1].replacingOccurrences(of: "%", with: "")),
                  let cpu = Double(components[2].replacingOccurrences(of: "%", with: "")) else {
                continue
            }
            
            let commandString = components[3...].joined(separator: " ")
            
            if mem > Constants.minMemoryUsageFilter {
                parsedProcesses.append(SystemProcessInfo(
                    pid: pid,
                    name: commandString,
                    cpuUsage: cpu,
                    memoryUsage: mem
                ))
            }
        }
        
        return Array(parsedProcesses.prefix(count))
    }

    private func getCurrentGPUInfo() -> GPUInfo {
        // This would require using a library like IOKit or external tools
        // For now, returning placeholder data
        return GPUInfo()
    }
    
    private func getCurrentFanInfo() -> [FanInfo] {
        // This would require accessing SMC (System Management Controller)
        // For now, returning placeholder data
        return []
    }
    
    private func getCurrentTemperatureInfo() -> [TemperatureInfo] {
        // This would require accessing SMC or using system_profiler
        // For now, returning placeholder data
        return []
    }
    
    private func getCurrentSystemInfo() -> SystemInfo {
        var modelName = "Unknown"
        var kernelVersion = "Unknown"
        var uptime: TimeInterval = 0
        var bootTime = Date()
        var chipInfo = "Unknown"
        
        // Get model name and chip info in a single system_profiler call
        if let hardwareInfo = getHardwareInfo() {
            modelName = hardwareInfo.modelName
            chipInfo = hardwareInfo.chipInfo
        }
        
        // Get kernel version
        kernelVersion = executeCommand("/usr/sbin/sysctl", ["-n", "kern.version"])?.split(separator: "\n").first.map(String.init) ?? "Unknown"
        
        // Get uptime using sysctl
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        
        let result = sysctl(&mib, 2, &boottime, &size, nil, 0)
        if result == 0 {
            bootTime = Date(timeIntervalSince1970: Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000)
            uptime = Date().timeIntervalSince(bootTime)
        }
        
        return SystemInfo(
            modelName: modelName,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            kernelVersion: kernelVersion,
            uptime: uptime,
            bootTime: bootTime,
            chipInfo: chipInfo
        )
    }
    
    // Helper to get hardware info in single call
    private func getHardwareInfo() -> (modelName: String, chipInfo: String)? {
        guard let output = executeCommand("/usr/sbin/system_profiler", ["SPHardwareDataType"]) else {
            // Fallback to sysctl for model name only
            let modelName = executeCommand("/usr/sbin/sysctl", ["-n", "hw.model"]) ?? "Unknown"
            return (modelName: modelName.trimmingCharacters(in: .whitespacesAndNewlines), chipInfo: "Unknown")
        }
        
        var modelName = "Unknown"
        var chipInfo = "Unknown"
        
        let lines = output.split(separator: "\n")
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.contains("Model Name:") {
                let components = trimmedLine.split(separator: ":")
                if components.count > 1 {
                    modelName = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.contains("Chip:") || trimmedLine.contains("Processor Name:") {
                let components = trimmedLine.split(separator: ":")
                if components.count > 1 {
                    chipInfo = components[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Break early if we have both values
            if modelName != "Unknown" && chipInfo != "Unknown" {
                break
            }
        }
        
        return (modelName: modelName, chipInfo: chipInfo)
    }

    // Helper function to execute commands
    private func executeCommand(_ executablePath: String, _ arguments: [String]) -> String? {
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            guard task.terminationStatus == 0 else { return nil }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("Error executing command \(executablePath): \(error)")
            return nil
        }
    }

    // Add method to fetch power consumption information
    private func getCurrentPowerConsumption() -> PowerConsumptionInfo {
        // First, try to get power data from macmon if available
        if let macmonData = getMacmonPowerData() {
            return macmonData
        }
        
        // Try to get power metrics from IOKit as fallback
        guard let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            // If we can't access power source info, fall back to estimation
            return estimatePowerConsumption()
        }
        
        guard let powerSourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            // If we can't get power sources list, fall back to estimation
            return estimatePowerConsumption()
        }
        
        // Variables to store different power measurements
        var hasPowerData = false
        var adapterPower: Double = 0.0 // Power from adapter if available
        
        // Look for power source with power metrics
        for powerSource in powerSourcesList {
            if let powerSourceInfo = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSource)?.takeUnretainedValue() as? [String: Any] {
                
                // Check if we're on AC power and get adapter details
                if let powerSourceState = powerSourceInfo[kIOPSPowerSourceStateKey] as? String,
                   powerSourceState == kIOPSACPowerValue {
                    
                    // Try to get adapter power information
                    if let adapterDetails = powerSourceInfo["AdapterDetails"] as? [String: Any] {
                        if let watts = adapterDetails["Watts"] as? Double {
                            adapterPower = watts
                            hasPowerData = true
                        } else if let voltage = adapterDetails["Voltage"] as? Double,
                                  let current = adapterDetails["Current"] as? Double {
                            adapterPower = (voltage / 1000.0) * (current / 1000.0) // Convert mV and mA to W
                            hasPowerData = true
                        }
                    }
                }
                
                // Try to get instantaneous power if available
                if let instantaneousPower = powerSourceInfo["InstantaneousPower"] as? Double, instantaneousPower > 0 {
                    adapterPower = instantaneousPower
                    hasPowerData = true
                }
            }
        }
        
        // If we have actual power data from the adapter
        if hasPowerData && adapterPower > 0 {
            // Distribute adapter power to components based on typical usage patterns
            // These percentages are estimates based on typical system power distribution
            let cpuPercentage: Double = 0.4  // CPU typically uses 40% of system power
            let gpuPercentage: Double = 0.2  // GPU typically uses 20% of system power
            let _: Double = 0.4  // Other components (fans, display, storage, etc.) 40%
            
            let cpuPower = adapterPower * cpuPercentage
            let gpuPower = adapterPower * gpuPercentage
            let totalSystemPower = adapterPower  // This is our best measurement of total system power
            
            return PowerConsumptionInfo(
                cpuPower: cpuPower,
                gpuPower: gpuPower,
                totalSystemPower: totalSystemPower,
                timestamp: Date(),
                isEstimate: false
            )
        }
        
        // If no power data available, fall back to estimation
        return estimatePowerConsumption()
    }
    
    // New method to get power data from macmon CLI tool
    private func getMacmonPowerData() -> PowerConsumptionInfo? {
        // Try common paths for macmon
        let commonPaths = [
            "/opt/homebrew/bin/macmon",   // Homebrew on Apple Silicon
            "/usr/local/bin/macmon",      // Homebrew on Intel
            "/usr/bin/macmon",            // System path
            "/opt/local/bin/macmon"       // MacPorts path
        ]
        
        for path in commonPaths {
            let macmonTask = Process()
            let macmonPipe = Pipe()
            macmonTask.executableURL = URL(fileURLWithPath: path)
            macmonTask.arguments = ["pipe", "-s", "1"] // Get one sample
            macmonTask.standardOutput = macmonPipe
            
            do {
                try macmonTask.run()
                macmonTask.waitUntilExit()
                
                if macmonTask.terminationStatus == 0 {
                    let data = macmonPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        return parseMacmonOutput(output)
                    }
                }
            } catch {
                continue // Try next path
            }
        }
        
        return nil
    }
    
    // Helper method to parse macmon JSON output
    private func parseMacmonOutput(_ output: String) -> PowerConsumptionInfo? {
        // Parse the JSON output from macmon
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Extract power values from macmon output
        let cpuPower = (json["cpu_power"] as? Double) ?? 0.0
        let gpuPower = (json["gpu_power"] as? Double) ?? 0.0
        let anePower = (json["ane_power"] as? Double) ?? 0.0  // Neural Engine power
        let ramPower = (json["ram_power"] as? Double) ?? 0.0
        let gpuRamPower = (json["gpu_ram_power"] as? Double) ?? 0.0
        
        // The sys_power field represents total system power consumption
        let totalSystemPower = (json["sys_power"] as? Double) ?? (cpuPower + gpuPower + anePower + ramPower + gpuRamPower)
        
        // If we have sys_power, use it as the total; otherwise sum the components
        let isEstimate = json["sys_power"] == nil
        
        return PowerConsumptionInfo(
            cpuPower: cpuPower,
            gpuPower: gpuPower,
            totalSystemPower: totalSystemPower,
            timestamp: Date(),
            isEstimate: isEstimate
        )
    }
    
    // Helper method to estimate power consumption based on system activity
    private func estimatePowerConsumption() -> PowerConsumptionInfo {
        let cpuUsage = getCurrentCPU()
        
        // Estimate total system power based on CPU usage
        // Using a more realistic range: 5W idle to 85W under full load for a typical desktop/laptop
        let idlePower: Double = 5.0    // Watts when system is idle
        let maxPower: Double = 85.0    // Watts when system is under full load
        
        // Non-linear power estimation (power consumption isn't linear with CPU usage)
        // Using a quadratic curve for more realistic estimation
        let normalizedCpu = cpuUsage / 100.0
        let powerFactor = normalizedCpu * normalizedCpu  // Square the CPU usage for non-linear curve
        let totalSystemPower = idlePower + (maxPower - idlePower) * powerFactor
        
        // Estimate component power based on typical distribution:
        // CPU: 40-50%, GPU: 15-25%, Other components: 30-40%
        let cpuPower = totalSystemPower * (0.45 + (cpuUsage / 100.0) * 0.05)  // 45-50% for CPU
        let gpuPower = totalSystemPower * (0.20 - (cpuUsage / 100.0) * 0.05)  // 15-20% for GPU
        
        return PowerConsumptionInfo(
            cpuPower: cpuPower,
            gpuPower: gpuPower,
            totalSystemPower: totalSystemPower,
            timestamp: Date(),
            isEstimate: true
        )
    }
    
    deinit {
        stopMonitoring()
        stopExternalIPRefresh()
    }
}