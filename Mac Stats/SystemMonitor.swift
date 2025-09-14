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
        var systemInfo: SystemInfo = SystemInfo()
        var processes: [SystemProcessInfo] = []
        var memoryProcesses: [SystemProcessInfo] = []
        
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
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            systemInfo = self.getCurrentSystemInfo()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            processes = self.getTopProcesses(count: Constants.processCountThreshold)
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            memoryProcesses = self.getTopMemoryProcesses(count: Constants.processCountThreshold)
            group.leave()
        }
        
        group.notify(queue: .main) {
            // Update history first
            self.updateCPUHistory(with: cpu)
            self.updateCPUTemperatureHistory(with: cpuTemp)
            self.updateNetworkHistory(upload: network.upload, download: network.download)
            
            // Update all published properties
            self.cpuUsage = cpu
            self.cpuTemperature = cpuTemp
            self.memoryUsage = memory
            self.diskUsage = disk
            self.networkUsage = network
            self.upsInfo = ups
            self.batteryInfo = battery
            self.powerConsumptionInfo = powerConsumption
            self.systemInfo = systemInfo
            self.topProcesses = processes
            self.topMemoryProcesses = memoryProcesses
            
            // Set this flag LAST to ensure all data is updated
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
        
        // Check if we have both en0 and en1, and if so, add a bond interface option
        let hasEn0 = interfaces.contains("en0")
        let hasEn1 = interfaces.contains("en1")
        
        if hasEn0 && hasEn1 {
            // Add bond0 as a virtual interface that combines en0 and en1
            interfaces.append("bond0")
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
                    if interface == "bond0" {
                        // For bond interface, sum en0 and en1 stats
                        var bondBytesIn: UInt64 = 0
                        var bondBytesOut: UInt64 = 0
                        
                        for bondInterface in ["en0", "en1"] {
                            let stats = self.getInterfaceStats(interface: bondInterface)
                            bondBytesIn += stats.bytesIn
                            bondBytesOut += stats.bytesOut
                        }
                        
                        initialStats[interface] = (bytesIn: bondBytesIn, bytesOut: bondBytesOut)
                    } else {
                        let stats = self.getInterfaceStats(interface: interface)
                        initialStats[interface] = stats
                    }
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
            let battery = self.getCurrentBatteryInfo()
            let systemInfo = self.getCurrentSystemInfo()
            
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
                self.batteryInfo = battery
                self.systemInfo = systemInfo
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
    
    // MARK: - Data Collection Methods
    
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
        let temperature = TemperatureMonitor.averageCPUTemperature()
        return temperature
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
            if interface == "bond0" {
                // Skip bond0 in the main loop since it's virtual
                continue
            }
            
            let stats = getInterfaceStats(interface: interface)
            currentStats[interface] = stats
            totalBytesIn += stats.bytesIn
            totalBytesOut += stats.bytesOut
        }
        
        // Handle bond0 virtual interface stats
        if networkInterfaces.contains("bond0") {
            var bondBytesIn: UInt64 = 0
            var bondBytesOut: UInt64 = 0
            
            for bondInterface in ["en0", "en1"] {
                if let stats = currentStats[bondInterface] {
                    bondBytesIn += stats.bytesIn
                    bondBytesOut += stats.bytesOut
                }
            }
            
            currentStats["bond0"] = (bytesIn: bondBytesIn, bytesOut: bondBytesOut)
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
                    if interface == "bond0" {
                        continue // Skip bond0 to avoid double counting
                    }
                    
                    if let previous = previousInterfaceStats[interface] {
                        previousTotalBytesIn += previous.bytesIn
                        previousTotalBytesOut += previous.bytesOut
                    }
                }
                
                let bytesInDiff = totalBytesIn >= previousTotalBytesIn ? (totalBytesIn - previousTotalBytesIn) : 0
                let bytesOutDiff = totalBytesOut >= previousTotalBytesOut ? (totalBytesOut - previousTotalBytesOut) : 0
                
                bytesInRate = Double(bytesInDiff) / timeInterval
                bytesOutRate = Double(bytesOutDiff) / timeInterval
            } else if selectedInterface == "bond0" {
                // Special handling for bond interface - uses aggregated en0 + en1 stats
                if let current = currentStats["bond0"],
                   let previous = previousInterfaceStats["bond0"] {
                    let bytesInDiff = current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                    let bytesOutDiff = current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                    
                    bytesInRate = Double(bytesInDiff) / timeInterval
                    bytesOutRate = Double(bytesOutDiff) / timeInterval
                }
            } else {
                // Calculate for specific interface only
                if let current = currentStats[selectedInterface],
                   let previous = previousInterfaceStats[selectedInterface] {
                    let bytesInDiff = current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                    let bytesOutDiff = current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                    
                    bytesInRate = Double(bytesInDiff) / timeInterval
                    bytesOutRate = Double(bytesOutDiff) / timeInterval
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
    
    private func getCurrentUPSInfo() -> UPSInfo {
        // Check for UPS devices using IOKit Power Sources
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return UPSInfo(powerSource: "AC Power")
        }
        
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return UPSInfo(powerSource: "AC Power")
        }
        
        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Extract power source information
            let name = description[kIOPSNameKey] as? String ?? "Unknown"
            let type = description[kIOPSTransportTypeKey] as? String ?? "Unknown"
            let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let chargeLevel = (description[kIOPSCurrentCapacityKey] as? Int).map(Double.init) ?? 0.0
            let timeRemaining = (description[kIOPSTimeToEmptyKey] as? Int).map(Double.init) ?? 0.0
            
            // Check if this is a battery device first (to exclude laptop batteries)
            let isBattery = name.lowercased().contains("battery") || 
                           name == "InternalBattery" ||
                           type.lowercased().contains("internal") ||
                           (type == "InternalBattery" || type == "Internal")
            
            // Skip if this is clearly an internal battery
            if isBattery {
                continue
            }
            
            // Enhanced UPS detection logic
            let nameContainsUPS = name.lowercased().contains("ups") || 
                                 name.lowercased().contains("uninterruptible")
            let typeContainsUPS = type.lowercased().contains("ups") || 
                                 type.lowercased().contains("uninterruptible")
            
            // Look for UPS-like patterns in the name (common UPS model patterns)
            let hasUPSModelPattern = name.contains("LE") || // Like your LE1000DG
                                    name.contains("CP") || // CyberPower
                                    name.contains("BR") || // APC Back-UPS
                                    name.contains("BE") || // APC Back-UPS
                                    name.contains("BX") || // APC Back-UPS
                                    name.contains("SMT") || // APC Smart-UPS
                                    name.contains("SMC") || // APC Smart-UPS
                                    name.contains("RT") ||  // APC Smart-UPS RT
                                    name.contains("SUA") || // APC Smart-UPS
                                    name.contains("DG")     // Common UPS suffix
            
            // Check if it has UPS characteristics:
            // - Has a charge level (UPS devices report battery charge)
            // - Is not an internal battery
            // - Has a model-like name (not generic)
            let hasUPSCharacteristics = chargeLevel > 0 && 
                                      !name.isEmpty && 
                                      name != "Unknown" &&
                                      name != "AC Power" &&
                                      name.count > 3 // Reasonable model name length
            
            let isUPS = nameContainsUPS || 
                       typeContainsUPS || 
                       hasUPSModelPattern ||
                       (hasUPSCharacteristics && !isBattery)
            
            if isUPS {
                return UPSInfo(
                    name: name,
                    isCharging: isCharging,
                    chargeLevel: chargeLevel,
                    timeRemaining: timeRemaining,
                    present: true,
                    manufacturer: "Unknown",
                    model: "Unknown", 
                    serialNumber: "Unknown",
                    voltage: (description[kIOPSVoltageKey] as? Int).map(Double.init) ?? 0.0,
                    loadPercentage: 0.0, // Not typically available from IOKit
                    powerSource: mapPowerSourceState(powerSource)
                )
            }
        }
        
        // No UPS found, return basic power source info
        let powerSourceState = getPowerSourceState()
        return UPSInfo(powerSource: powerSourceState)
    }
    
    // Helper method to map power source state
    private func mapPowerSourceState(_ state: String) -> String {
        switch state {
        case kIOPSACPowerValue:
            return "AC Power"
        case kIOPSBatteryPowerValue:
            return "UPS Power"
        default:
            return state.isEmpty ? "AC Power" : state
        }
    }
    
    // Helper method to get general power source state
    private func getPowerSourceState() -> String {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return "AC Power"
        }
        
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return "AC Power"
        }
        
        // Check if we're running on battery power
        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
                return mapPowerSourceState(powerSource)
            }
        }
        
        return "AC Power"
    }
    
    private func getCurrentBatteryInfo() -> BatteryInfo {
        // Check for battery devices using IOKit Power Sources
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return BatteryInfo()
        }
        
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatteryInfo()
        }
        
        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            // Extract power source information
            let name = description[kIOPSNameKey] as? String ?? "Unknown"
            let type = description[kIOPSTransportTypeKey] as? String ?? "Unknown"
            _ = description[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let chargeLevel = (description[kIOPSCurrentCapacityKey] as? Int).map(Double.init) ?? 0.0
            let timeRemaining = (description[kIOPSTimeToEmptyKey] as? Int).map(Double.init) ?? 0.0
            let maxCapacity = (description[kIOPSMaxCapacityKey] as? Int) ?? 100
            let voltage = (description[kIOPSVoltageKey] as? Int).map(Double.init) ?? 0.0
            
            // Try to get cycle count and amperage using string keys (these may not be available in all versions)
            let cycleCount = (description["CycleCount"] as? Int) ?? 
                            (description["BatteryCycleCount"] as? Int) ?? 0
            let amperage = (description["Amperage"] as? Int).map(Double.init) ?? 
                          (description["InstantAmperage"] as? Int).map(Double.init) ?? 0.0
            let temperature = (description["Temperature"] as? Int).map(Double.init) ?? 0.0
            
            // Check if this is a battery device (internal laptop battery)
            let isBattery = name.lowercased().contains("battery") || 
                           name == "InternalBattery" ||
                           type.lowercased().contains("internal") ||
                           (type == "InternalBattery" || type == "Internal")
            
            if isBattery {
                // Get more accurate cycle count and max capacity using system_profiler
                let batteryDetails = getBatteryDetails()
                let actualCycleCount = batteryDetails.cycleCount > 0 ? batteryDetails.cycleCount : cycleCount
                let actualMaxCapacity = batteryDetails.maxCapacity != 100 ? batteryDetails.maxCapacity : maxCapacity
                
                // Determine battery health based on max capacity
                var health = "Unknown"
                if actualMaxCapacity >= 80 {
                    health = "Good"
                } else if actualMaxCapacity >= 60 {
                    health = "Fair"
                } else {
                    health = "Poor"
                }
                
                return BatteryInfo(
                    name: name,
                    isCharging: isCharging,
                    chargeLevel: chargeLevel,
                    timeRemaining: timeRemaining,
                    present: true,
                    cycleCount: actualCycleCount,
                    health: health,
                    temperature: temperature,
                    amperage: amperage,
                    voltage: voltage,
                    maxCapacity: actualMaxCapacity
                )
            }
        }
        
        // No battery found
        return BatteryInfo()
    }
    
    private func getCurrentPowerConsumption() -> PowerConsumptionInfo {
        // Try macmon first
        if let powerData = getPowerConsumptionFromMacmon() {
            return powerData
        }
        
        // Fallback to estimation
        return estimatePowerConsumption()
    }
    
    private func getPowerConsumptionFromMacmon() -> PowerConsumptionInfo? {
        let macmonPaths = [
            "/opt/homebrew/bin/macmon",
            "/usr/local/bin/macmon",
            "/usr/bin/macmon",
            "/opt/local/bin/macmon"
        ]
        
        for path in macmonPaths {
            if FileManager.default.fileExists(atPath: path) {
                // Try the pipe command with JSON output for a single sample
                if let output = executeCommand(path, ["pipe", "-s", "1"]) {
                    return parseMacmonJSONOutput(output)
                }
            }
        }
        
        return nil
    }
    
    private func parseMacmonJSONOutput(_ output: String) -> PowerConsumptionInfo? {
        guard let data = output.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let cpuPower = json["cpu_power"] as? Double ?? 0.0
                let gpuPower = json["gpu_power"] as? Double ?? 0.0
                let anePower = json["ane_power"] as? Double ?? 0.0
                let allPower = json["all_power"] as? Double ?? 0.0
                let sysPower = json["sys_power"] as? Double ?? 0.0
                
                // Use sys_power if available (total system power), otherwise all_power, otherwise sum components
                let totalPower = sysPower > 0 ? sysPower : (allPower > 0 ? allPower : cpuPower + gpuPower + anePower)
                
                if totalPower > 0 || cpuPower > 0 || gpuPower > 0 {
                    return PowerConsumptionInfo(
                        cpuPower: cpuPower,
                        gpuPower: gpuPower,
                        totalSystemPower: totalPower,
                        timestamp: Date(),
                        isEstimate: false
                    )
                }
            }
        } catch {
            // Silently handle JSON parsing errors
        }
        
        return nil
    }
    
    private func estimatePowerConsumption() -> PowerConsumptionInfo {
        // Get chip info for better estimates
        let chipInfo = systemInfo.chipInfo.lowercased()
        let actualBasePower: Double
        let actualMaxCpuPower: Double
        let actualMaxGpuPower: Double
        
        if chipInfo.contains("m2") && chipInfo.contains("ultra") {
            actualBasePower = 15.0  // M2 Ultra higher base power
            actualMaxCpuPower = 50.0
            actualMaxGpuPower = 40.0
        } else if chipInfo.contains("m2") {
            actualBasePower = 10.0
            actualMaxCpuPower = 25.0
            actualMaxGpuPower = 20.0
        } else if chipInfo.contains("m1") {
            actualBasePower = 8.0
            actualMaxCpuPower = 20.0
            actualMaxGpuPower = 15.0
        } else {
            // Intel or unknown
            actualBasePower = 25.0
            actualMaxCpuPower = 60.0
            actualMaxGpuPower = 30.0
        }
        
        // Estimate CPU power based on usage
        let cpuPowerRatio = cpuUsage / 100.0
        let estimatedCpuPower = cpuPowerRatio * actualMaxCpuPower
        
        // Conservative GPU estimate
        let estimatedGpuPower = 0.3 * actualMaxGpuPower
        
        let totalEstimatedPower = actualBasePower + estimatedCpuPower + estimatedGpuPower
        
        return PowerConsumptionInfo(
            cpuPower: estimatedCpuPower,
            gpuPower: estimatedGpuPower,
            totalSystemPower: totalEstimatedPower,
            timestamp: Date(),
            isEstimate: true
        )
    }
    
    private func checkAndNotifyUPSPowerChange() {
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
    
    // func getBatteryDetails() -> (cycleCount: Int, maxCapacity: Int) { return (0, 100) }
    
    deinit {
        stopMonitoring()
        stopExternalIPRefresh()
    }
}