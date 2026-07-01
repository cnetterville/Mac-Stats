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
import Combine

// Rename ProcessInfo to SystemProcessInfo to avoid conflict with Foundation's ProcessInfo
struct SystemProcessInfo: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let cpuUsage: Double
    let memoryUsage: Double
}

// Struct to hold Process Network Information
struct ProcessNetworkInfo: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let bytesIn: Double // bytes per second
    let bytesOut: Double // bytes per second
    let connections: Int
    let state: String // "ESTABLISHED", "LISTEN", etc.
    
    // Total network usage for sorting
    var totalUsage: Double {
        return bytesIn + bytesOut
    }
}

// Struct to hold per-process disk I/O information
struct ProcessDiskInfo: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let bytesRead: Double     // bytes/sec
    let bytesWritten: Double  // bytes/sec
    var totalIO: Double { bytesRead + bytesWritten }
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

struct TimeMachineInfo: Equatable {
    let isConfigured: Bool
    let isBackingUp: Bool
    let lastBackupDate: Date?

    init(isConfigured: Bool = false, isBackingUp: Bool = false, lastBackupDate: Date? = nil) {
        self.isConfigured = isConfigured
        self.isBackingUp = isBackingUp
        self.lastBackupDate = lastBackupDate
    }
}

enum MemoryPressureLevel: String, Equatable {
    case normal, warning, critical
}

struct MemoryStats: Equatable {
    let used: Double           // GB (App + Wired + Compressed — Activity Monitor's "Memory Used")
    let total: Double          // GB
    let appMemory: Double      // GB — anonymous user memory
    let wired: Double          // GB — kernel-wired
    let compressed: Double     // GB — VM compressor working set
    let cached: Double         // GB — file-backed pages reclaimable on demand
    let free: Double           // GB
    let pressure: MemoryPressureLevel
}

// Struct to hold Battery information
struct BatteryInfo {
    let name: String
    let isCharging: Bool
    let isPluggedIn: Bool // AC adapter connected (covers the "plugged in, not charging" state)
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
        self.isPluggedIn = false
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

    init(name: String, isCharging: Bool, isPluggedIn: Bool, chargeLevel: Double, timeRemaining: Double, present: Bool, cycleCount: Int, health: String, temperature: Double, amperage: Double, voltage: Double, maxCapacity: Int = 100) {
        self.name = name
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
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

// Struct to hold Fan information
struct FanInfo {
    let rpm: Double
    let isEstimate: Bool
    let thermalState: Int
    let thermalPressure: String
    let maxRPM: Double
    let speeds: [Int]        // individual fan RPMs (empty when estimated)
    let maxSpeeds: [Int]     // individual fan max RPMs (empty when estimated)
    let targetSpeeds: [Int]  // individual fan target RPMs set by thermal management

    init() {
        self.rpm = 0.0
        self.isEstimate = true
        self.thermalState = 0
        self.thermalPressure = "Normal"
        self.maxRPM = 6000.0
        self.speeds = []
        self.maxSpeeds = []
        self.targetSpeeds = []
    }

    init(rpm: Double, isEstimate: Bool, thermalState: Int, thermalPressure: String,
         maxRPM: Double = 6000.0, speeds: [Int] = [], maxSpeeds: [Int] = [], targetSpeeds: [Int] = []) {
        self.rpm = rpm
        self.isEstimate = isEstimate
        self.thermalState = thermalState
        self.thermalPressure = thermalPressure
        self.maxRPM = maxRPM
        self.speeds = speeds
        self.maxSpeeds = maxSpeeds
        self.targetSpeeds = targetSpeeds
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

// Struct to hold Power Adapter information
struct PowerAdapterInfo {
    let isConnected: Bool
    let wattage: Int // Power adapter wattage (20, 30, 67, 96, 140, etc.)
    let type: String // "USB-C", "MagSafe", "MagSafe 3", "Lightning"
    let inputPower: Double // Current power draw in watts
    let efficiency: Double // Charging efficiency percentage
    let model: String // "67W USB-C Power Adapter"
    
    init() {
        self.isConnected = false
        self.wattage = 0
        self.type = "Unknown"
        self.inputPower = 0.0
        self.efficiency = 0.0
        self.model = "Unknown"
    }
    
    init(isConnected: Bool, wattage: Int, type: String, inputPower: Double, efficiency: Double, model: String) {
        self.isConnected = isConnected
        self.wattage = wattage
        self.type = type
        self.inputPower = inputPower
        self.efficiency = efficiency
        self.model = model
    }
}

// Struct to hold Power Consumption information
struct PowerConsumptionInfo {
    let cpuPower: Double // in watts
    let gpuPower: Double // in watts
    let totalSystemPower: Double // in watts (now represents whole system power)
    let timestamp: Date
    let isEstimate: Bool
    let adapterInfo: PowerAdapterInfo // Power adapter information
    
    init() {
        self.cpuPower = 0.0
        self.gpuPower = 0.0
        self.totalSystemPower = 0.0
        self.timestamp = Date()
        self.isEstimate = true
        self.adapterInfo = PowerAdapterInfo()
    }
    
    init(cpuPower: Double, gpuPower: Double, totalSystemPower: Double, timestamp: Date, isEstimate: Bool, adapterInfo: PowerAdapterInfo = PowerAdapterInfo()) {
        self.cpuPower = cpuPower
        self.gpuPower = gpuPower
        self.totalSystemPower = totalSystemPower
        self.timestamp = timestamp
        self.isEstimate = isEstimate
        self.adapterInfo = adapterInfo
    }
}

@Observable
class SystemMonitor {
    // MARK: - Constants
    private struct Constants {
        static let maxHistoryPoints = 30
        static let defaultUpdateInterval: TimeInterval = 3.0
        static let defaultPowerUpdateInterval: TimeInterval = 60.0
        static let externalIPRefreshInterval: TimeInterval = 30 * 60 // 30 minutes
        static let notificationCooldownPeriod: TimeInterval = 300 // 5 minutes
        static let gbDivisor: Double = 1000 * 1000 * 1000 // Use decimal GB
        static let processCountThreshold = 5
        static let minCpuUsageFilter = 0.1
        static let minMemoryUsageFilter = 0.1
        // Network interface assumptions: en2 is assumed to be WiFi to avoid interference with bonded interfaces (en0/en1)
        static let preferredWiFiInterface = "en2"
        static let systemInfoCacheInterval: TimeInterval = 300.0
        static let networkProcessUpdateInterval: TimeInterval = 5.0
        static let diskProcessUpdateInterval: TimeInterval = 5.0
        
        // Add caching to prevent excessive macmon calls
        static let powerConsumptionCacheInterval: TimeInterval = 15.0 // Cache power data for 15 seconds minimum
        static let macmonCallTimeout: TimeInterval = 3.0 // Reduce timeout for faster failure

        // Adaptive polling: when no popover/window is open, slow down to reduce idle CPU.
        static let idleStatsInterval: TimeInterval = 15.0
        static let idlePowerInterval: TimeInterval = 180.0
    }
    
    // MARK: - Published Properties
    var cpuUsage: Double = 0.0
    var cpuTemperature: Double = 0.0
    var fanInfo: FanInfo = FanInfo() // Add fan information
    var memoryUsage: (used: Double, total: Double) = (0.0, 0.0)
    var memoryComposition: (app: Double, wired: Double, compressed: Double, cached: Double, free: Double) = (0, 0, 0, 0, 0)
    var memoryPressure: MemoryPressureLevel = .normal
    var swapUsage: (used: Double, total: Double) = (0.0, 0.0)
    var processCount: Int = 0
    var threadCount: Int = 0
    var timeMachineInfo: TimeMachineInfo = TimeMachineInfo()
    var diskUsage: (free: Double, total: Double, purgeable: Double) = (0.0, 0.0, 0.0)
    var networkUsage: (upload: Double, download: Double) = (0.0, 0.0)
    var networkInterfaces: [String] = []
    var topProcesses: [SystemProcessInfo] = []
    var topMemoryProcesses: [SystemProcessInfo] = []
    var topNetworkProcesses: [ProcessNetworkInfo] = []
    var topDiskProcesses: [ProcessDiskInfo] = []
    var upsInfo: UPSInfo = UPSInfo() // UPS information
    var batteryInfo: BatteryInfo = BatteryInfo() // Battery information
    var systemInfo: SystemInfo = SystemInfo() // System information
    var powerConsumptionInfo: PowerConsumptionInfo = PowerConsumptionInfo() // Power consumption information
    var initialDataLoaded: Bool = false
    var gpuTemperature: Double = 0.0
    var ssdTemperature: Double = 0.0
    var memoryTemperature: Double = 0.0
    var dcInPower: Double = 0.0
    var diskReadRate: Double = 0.0
    var diskWriteRate: Double = 0.0
    var cpuCoreUsages: [Double] = []
    var pCoreCount: Int = 0
    var eCoreCount: Int = 0
    var cpuLoadAverages: (one: Double, five: Double, fifteen: Double) = (0, 0, 0)
    var localIPAddress: String = ""
    var cpuHistory: [Double] = []
    var cpuTemperatureHistory: [Double] = []
    var memoryHistory: [Double] = []
    var powerHistory: [Double] = []
    var fanHistory: [Double] = []
    var uploadHistory: [Double] = []
    var downloadHistory: [Double] = []
    var diskReadHistory: [Double] = []
    var diskWriteHistory: [Double] = []
    var sessionBytesDownloaded: Double = 0.0
    var sessionBytesUploaded: Double = 0.0

    /// Fires once per updateStats tick on the main thread. Used by legacy Combine
    /// subscribers (MenuBarImageManager, MenuBarLabelView) that still need an
    /// explicit "something updated" signal — @Observable removes objectWillChange.
    @ObservationIgnored
    let didUpdate = PassthroughSubject<Void, Never>()

    // MARK: - Private Properties
    private var previousUPSPowerState: Bool = false
    private var lastUPSPowerNotificationTime: Date?
    private var smoothedFanSpeeds: [Double] = []   // EMA-smoothed fan RPMs
    private var timer: Timer?
    private var powerTimer: Timer?
    private var updateInterval: TimeInterval = Constants.defaultUpdateInterval
    private var powerUpdateInterval: TimeInterval = Constants.defaultPowerUpdateInterval
    private var previousInterfaceStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var lastUpdateTime: Date = Date()
    private var externalIPRefreshTimer: Timer?
    private var previousCPUInfo = host_cpu_load_info()
    private var activeNetworkInterfaces: [String] = []
    private var hasBondedInterfaces: Bool = false // Track if we have a bonded configuration
    private var cachedSystemInfo: SystemInfo?
    private var lastSystemInfoUpdate: Date = Date.distantPast
    private var networkProcessUpdateCounter: Int = 0
    private var cachedNetworkProcesses: [ProcessNetworkInfo] = []
    private var diskProcessUpdateCounter: Int = 0
    private var cachedDiskProcesses: [ProcessDiskInfo] = []
    private var previousDiskIO: [Int32: (read: UInt64, written: UInt64, time: Date)] = [:]
    private var previousDiskIOStats: (read: UInt64, written: UInt64, time: Date)?
    private var previousCoreData: [Int32] = []
    private var cachedNettopPath: String? = nil  // resolved once; avoids repeated FileManager lookups
    
    // Add caching for power consumption to reduce macmon calls
    private var cachedPowerConsumption: PowerConsumptionInfo?
    private var lastPowerConsumptionUpdate: Date = Date.distantPast
    private var isFetchingPowerConsumption: Bool = false
    private var previousProcessCPUTimes: [pid_t: (user: UInt64, system: UInt64, time: Date)] = [:]
    private static let machTimeToSeconds: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000.0
    }()
    private var cachedSPPowerOutput: (wattage: Int, type: String, model: String, isConnected: Bool)?
    private var lastSPPowerUpdate: Date = Date.distantPast
    private var activeViewerCount: Int = 0
    /// Reference count of views currently displaying per-process network data.
    /// When zero, the expensive `nettop` subprocess is skipped each tick.
    private var activeNetworkProcessesViewerCount: Int = 0
    private var powerSourceNotifySource: CFRunLoopSource?
    private var timeMachineRefreshTask: Task<Void, Never>?

    // Cache for battery details (system_profiler is slow — cache for 10 minutes)
    var cachedBatteryDetails: (cycleCount: Int, maxCapacity: Int)?
    var lastBatteryDetailsUpdate: Date = Date.distantPast
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
        let split = Self.readPECoreSplit()
        pCoreCount = split.pCores
        eCoreCount = split.eCores
        // Data will be refreshed when the view appears.
        startMonitoring()
        startExternalIPRefresh()
        setupPowerSourceNotifications()
        startTimeMachineRefresh()
    }

    /// Time Machine status changes infrequently; refresh every 5 minutes on a
    /// background task to keep the tmutil subprocess off the hot path.
    private func startTimeMachineRefresh() {
        timeMachineRefreshTask?.cancel()
        timeMachineRefreshTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let info = self.fetchTimeMachineInfo()
                await MainActor.run {
                    if self.timeMachineInfo != info { self.timeMachineInfo = info }
                }
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 min
            }
        }
    }

    private func fetchTimeMachineInfo() -> TimeMachineInfo {
        // `destinationinfo` succeeds (and lists "Name = ...") whenever Time Machine
        // has a destination set, even if no backups exist yet. We use this rather
        // than `latestbackup` for the "configured" check because `latestbackup` may
        // require Full Disk Access or return non-zero with no backups available.
        let dest = runTMUtil(["destinationinfo"])
        let isConfigured = dest.stdout.range(of: #"(Name|ID)\s*[:=]"#,
                                             options: .regularExpression) != nil

        // Parse the latest backup date out of any path/snapshot identifier tmutil
        // hands back — `/Volumes/.../2024-01-15-143012`, `.backup`, or
        // `com.apple.TimeMachine.2024-01-15-143012.local` (APFS snapshot).
        let latest = runTMUtil(["latestbackup"])
        var lastBackupDate: Date? = nil
        let raw = latest.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            let lastComponent = (raw as NSString).lastPathComponent
            if let match = lastComponent.range(of: #"\d{4}-\d{2}-\d{2}-\d{6}"#,
                                               options: .regularExpression) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                formatter.timeZone = TimeZone.current
                lastBackupDate = formatter.date(from: String(lastComponent[match]))
            }
        }

        let status = runTMUtil(["status"])
        let isBackingUp = status.stdout.contains("Running = 1")

        #if DEBUG
        print("TM destinationinfo (exit \(dest.exitCode)): \(dest.stdout.prefix(80))")
        print("TM latestbackup (exit \(latest.exitCode)): \(latest.stdout.prefix(120))")
        if !latest.stderr.isEmpty { print("TM latestbackup stderr: \(latest.stderr)") }
        #endif

        // Even if `latestbackup` failed (e.g. needs Full Disk Access), still
        // report "configured" so the UI doesn't lie about TM being off.
        return TimeMachineInfo(
            isConfigured: isConfigured || lastBackupDate != nil,
            isBackingUp: isBackingUp,
            lastBackupDate: lastBackupDate
        )
    }

    private struct TMUtilResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func runTMUtil(_ args: [String]) -> TMUtilResult {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = args
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return TMUtilResult(exitCode: -1, stdout: "", stderr: "\(error)")
        }
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return TMUtilResult(exitCode: task.terminationStatus, stdout: stdout, stderr: stderr)
    }

    /// Subscribes to IOKit power source change events so plug/unplug and
    /// charging-state transitions update immediately, independent of the polling rate.
    private func setupPowerSourceNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: @convention(c) (UnsafeMutableRawPointer?) -> Void = { ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<SystemMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.refreshPowerSources()
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        powerSourceNotifySource = source
    }

    /// Lightweight refresh triggered by IOKit notifications — re-reads battery
    /// and UPS state only, leaving the rest of the stats to the polling timer.
    private func refreshPowerSources() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let powerBlob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
            let battery = self.getCurrentBatteryInfo(blob: powerBlob)
            let ups = self.getCurrentUPSInfo(blob: powerBlob)
            await MainActor.run {
                self.batteryInfo = battery
                self.upsInfo = ups
                self.checkAndNotifyUPSPowerChange()
                self.didUpdate.send()
            }
        }
    }

    private static func readPECoreSplit() -> (pCores: Int, eCores: Int) {
        var p: Int32 = 0; var e: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.perflevel0.physicalcpu", &p, &size, nil, 0)
        sysctlbyname("hw.perflevel1.physicalcpu", &e, &size, nil, 0)
        return (Int(p), Int(e))
    }
    
    func startMonitoring() {
        // Update intervals from preferences if available
        if let preferences = preferences {
            updateInterval = preferences.updateInterval
            powerUpdateInterval = preferences.powerUpdateInterval
        }

        updateStats()
        updatePowerConsumption()
        installTimers()
    }

    private func installTimers() {
        timer?.invalidate()
        powerTimer?.invalidate()

        let active = activeViewerCount > 0
        let statsInterval = active ? updateInterval : max(updateInterval, Constants.idleStatsInterval)
        let powerInterval = active ? powerUpdateInterval : max(powerUpdateInterval, Constants.idlePowerInterval)

        timer = Timer.scheduledTimer(withTimeInterval: statsInterval, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
        powerTimer = Timer.scheduledTimer(withTimeInterval: powerInterval, repeats: true) { [weak self] _ in
            self?.updatePowerConsumption()
        }
    }

    /// Called by views in onAppear to indicate the user is actively watching stats.
    /// Switches polling to the user-configured (fast) interval.
    func viewerDidAppear() {
        activeViewerCount += 1
        if activeViewerCount == 1 {
            // Transition from idle to active — refresh immediately and switch to fast intervals
            updateStats()
            installTimers()
        }
    }

    /// Called by views in onDisappear. When no views remain, polling slows to idle intervals.
    func viewerDidDisappear() {
        activeViewerCount = max(0, activeViewerCount - 1)
        if activeViewerCount == 0 {
            installTimers()
        }
    }

    /// Network-process views (the dropdown's Network tab, card-based view's
    /// process-monitoring mode) call this in onAppear so nettop is only run
    /// while someone is actually looking at the per-process list.
    func networkProcessesViewerDidAppear() {
        activeNetworkProcessesViewerCount += 1
        if activeNetworkProcessesViewerCount == 1 {
            // First viewer — refresh immediately so they don't wait for the next tick
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let procs = self.getTopNetworkProcesses(count: Constants.processCountThreshold)
                await MainActor.run {
                    self.cachedNetworkProcesses = procs
                    self.topNetworkProcesses = procs
                    self.networkProcessUpdateCounter = 0
                    self.didUpdate.send()
                }
            }
        }
    }

    func networkProcessesViewerDidDisappear() {
        activeNetworkProcessesViewerCount = max(0, activeNetworkProcessesViewerCount - 1)
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
        updateInterval = interval
        installTimers()
    }

    // New method to update power consumption interval
    func updatePowerMonitoringInterval(_ interval: TimeInterval) {
        powerUpdateInterval = interval
        installTimers()
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
    
    func refreshAllData() {
        #if DEBUG
        print(" SystemMonitor: Refreshing all system data...")
        #endif
        
        let group = DispatchGroup()
        var cpu: Double = 0.0
        var cpuTemp: Double = 0.0
        var fan: FanInfo = FanInfo()
        var memory: (used: Double, total: Double) = (0.0, 0.0)
        var disk: (free: Double, total: Double, purgeable: Double) = (0.0, 0.0, 0.0)
        var network: (upload: Double, download: Double) = (0.0, 0.0)
        var ups: UPSInfo = UPSInfo()
        var battery: BatteryInfo = BatteryInfo()
        var powerConsumption: PowerConsumptionInfo = PowerConsumptionInfo()
        var systemInfo: SystemInfo = SystemInfo()
        var processes: [SystemProcessInfo] = []
        var memoryProcesses: [SystemProcessInfo] = []
        var networkProcesses: [ProcessNetworkInfo] = []
        
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
            fan = self.getCurrentFanInfo()
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let stats = self.getMemoryStats()
            memory = (used: stats.used, total: stats.total)
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
            let both = self.getTopProcessesBoth(count: Constants.processCountThreshold)
            processes = both.cpu
            memoryProcesses = both.memory
            group.leave()
        }
        
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            networkProcesses = self.getTopNetworkProcesses(count: Constants.processCountThreshold)
            // Prime the disk I/O cache on first load so next tick has a baseline
            _ = self.getTopDiskProcesses(count: Constants.processCountThreshold)
            group.leave()
        }
        
        group.notify(queue: .main) {
            // Update history first
            self.updateCPUHistory(with: cpu)
            self.updateCPUTemperatureHistory(with: cpuTemp)
            self.updateNetworkHistory(upload: network.upload, download: network.download)
            let initMemPct = memory.total > 0 ? (memory.used / memory.total) * 100.0 : 0.0
            self.updateMemoryHistory(with: initMemPct)
            self.updateFanHistory(with: fan.rpm)
            
            // Update all published properties
            self.cpuUsage = cpu
            self.cpuTemperature = cpuTemp
            self.fanInfo = fan
            self.memoryUsage = memory
            self.diskUsage = disk
            self.networkUsage = network
            self.upsInfo = ups
            self.batteryInfo = battery
            self.powerConsumptionInfo = powerConsumption
            self.systemInfo = systemInfo
            self.topProcesses = processes
            self.topMemoryProcesses = memoryProcesses
            self.topNetworkProcesses = networkProcesses
            
            // Set this flag LAST to ensure all data is updated
            self.initialDataLoaded = true
            #if DEBUG
            print(" SystemMonitor: Initial data loaded successfully!")
            #endif
            
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
        var activeInterfaces: [String] = []
        var hasBond0 = false
        var hasEn0 = false
        var hasEn1 = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line starts with interface name (ends with colon)
            if let colonIndex = trimmedLine.firstIndex(of: ":"),
               colonIndex == trimmedLine.index(before: trimmedLine.endIndex) || 
               trimmedLine[trimmedLine.index(after: colonIndex)].isWhitespace {
                
                let interfaceName = String(trimmedLine[..<colonIndex])
                
                // Track specific interfaces for bonding detection
                if interfaceName == "bond0" {
                    hasBond0 = true
                    #if DEBUG
                    print(" Detected bond0 interface")
                    #endif
                }
                if interfaceName == "en0" {
                    hasEn0 = true
                    #if DEBUG
                    print(" Detected en0 interface")
                    #endif
                }
                if interfaceName == "en1" {
                    hasEn1 = true
                    #if DEBUG
                    print(" Detected en1 interface")
                    #endif
                }

                // Filter out loopback and inactive interfaces
                if !interfaceName.hasPrefix("lo") && interfaceName != "gif0" && interfaceName != "stf0" {
                    interfaces.append(interfaceName)

                    // Check if interface is active by looking for UP and RUNNING flags
                    if trimmedLine.contains("UP") && trimmedLine.contains("RUNNING") {
                        activeInterfaces.append(interfaceName)
                        #if DEBUG
                        print(" Active interface: \(interfaceName)")
                        #endif
                    }
                }
            }
        }
        
        #if DEBUG
        print(" Bond detection - bond0: \(hasBond0), en0: \(hasEn0), en1: \(hasEn1)")
        #endif
        
        // Add a "Combined" interface option if we have multiple active interfaces
        if activeInterfaces.count >= 2 {
            interfaces.append("Combined")
        }
        
        let sortedInterfaces = interfaces.sorted { interface1, interface2 in
            // Sort "Combined" to the end, then sort the rest alphabetically
            if interface1 == "Combined" {
                return false
            }
            if interface2 == "Combined" {
                return true
            }
            return interface1 < interface2
        }
        
        #if DEBUG
        print(" Final sorted interfaces: \(sortedInterfaces)")
        #endif
        
        // Thread-safe updates
        DispatchQueue.main.async {
            self.networkInterfaces = sortedInterfaces
            self.previousInterfaceStats.removeAll()
            self.lastUpdateTime = Date()
            
            // Store active interfaces for combined calculations
            self.activeNetworkInterfaces = activeInterfaces
            
            // Store bonding information for special handling
            self.hasBondedInterfaces = hasBond0 && hasEn0 && hasEn1
            
            // Get initial stats for each interface
            DispatchQueue.global(qos: .userInitiated).async {
                var initialStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
                for interface in sortedInterfaces {
                    if interface == "Combined" {
                        // For combined interface, sum all active interfaces
                        var combinedBytesIn: UInt64 = 0
                        var combinedBytesOut: UInt64 = 0
                        
                        for activeInterface in activeInterfaces {
                            let stats = self.getInterfaceStats(interface: activeInterface)
                            combinedBytesIn += stats.bytesIn
                            combinedBytesOut += stats.bytesOut
                        }
                        
                        initialStats[interface] = (bytesIn: combinedBytesIn, bytesOut: combinedBytesOut)
                    } else if interface == "bond0" && self.hasBondedInterfaces {
                        // For bond0, specifically sum en0 and en1
                        let en0Stats = self.getInterfaceStats(interface: "en0")
                        let en1Stats = self.getInterfaceStats(interface: "en1")
                        
                        let bondedBytesIn = en0Stats.bytesIn + en1Stats.bytesIn
                        let bondedBytesOut = en0Stats.bytesOut + en1Stats.bytesOut
                        
                        initialStats[interface] = (bytesIn: bondedBytesIn, bytesOut: bondedBytesOut)
                        #if DEBUG
                        print(" Bond0 detected: summing en0 and en1 traffic (In: \(bondedBytesIn), Out: \(bondedBytesOut))")
                        #endif
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
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            let addr = current.pointee
            if String(cString: addr.ifa_name) == interface,
               addr.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                return (
                    bytesIn: UInt64(data.pointee.ifi_ibytes),
                    bytesOut: UInt64(data.pointee.ifi_obytes)
                )
            }
            ptr = addr.ifa_next
        }
        return (bytesIn: 0, bytesOut: 0)
    }

    private func getAllInterfaceStats() -> [String: (bytesIn: UInt64, bytesOut: UInt64)] {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [:] }
        defer { freeifaddrs(ifaddr) }

        var result: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var ptr = ifaddr
        while let current = ptr {
            let addr = current.pointee
            let name = String(cString: addr.ifa_name)
            if addr.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                result[name] = (
                    bytesIn: UInt64(data.pointee.ifi_ibytes),
                    bytesOut: UInt64(data.pointee.ifi_obytes)
                )
            }
            ptr = addr.ifa_next
        }
        return result
    }

    private func updateStats() {
        // Run all independent data collectors as concurrent child tasks via `async let`.
        // The outer task suspends rather than blocking a GCD thread on a DispatchGroup wait.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            async let cpuGroup: (cpu: Double, cpuTemp: Double, fan: FanInfo, coreUsages: [Double], loadAverages: (one: Double, five: Double, fifteen: Double), localIP: String) = {
                let cpu = self.getCurrentCPU()
                let smcBatch = readSMCStatsBatch()
                let cpuTemp: Double
                if let temp = smcBatch.cpuTemperature {
                    cpuTemp = temp
                    TemperatureMonitor.updateCache(temp)
                } else {
                    cpuTemp = self.getCurrentCPUTemperature()
                }
                let fan = self.getCurrentFanInfo(smcFans: smcBatch.fans)
                let coreUsages = self.getPerCoreCPUUsage()
                let loadAverages = self.getCPULoadAverages()
                let localIP = self.getLocalIPAddress()
                return (cpu, cpuTemp, fan, coreUsages, loadAverages, localIP)
            }()

            async let memDiskGroup: (memory: MemoryStats,
                                     swap: (used: Double, total: Double),
                                     disk: (free: Double, total: Double, purgeable: Double),
                                     diskIO: (readMBps: Double, writeMBps: Double)) = (
                memory: self.getMemoryStats(),
                swap: self.getSwapUsage(),
                disk: self.getCurrentDisk(),
                diskIO: self.getDiskIORate()
            )

            async let network: (upload: Double, download: Double) = self.getCurrentNetwork()

            async let procs: (cpu: [SystemProcessInfo], memory: [SystemProcessInfo], processCount: Int, threadCount: Int) =
                self.getTopProcessesBoth(count: Constants.processCountThreshold)

            async let powerSources: (battery: BatteryInfo, ups: UPSInfo) = {
                let powerBlob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
                return (
                    battery: self.getCurrentBatteryInfo(blob: powerBlob),
                    ups: self.getCurrentUPSInfo(blob: powerBlob)
                )
            }()

            async let sysInfo: SystemInfo = self.getCachedOrFreshSystemInfo()

            let (cpu, cpuTemp, fan, coreUsages, loadAverages, localIP) = await cpuGroup
            let memDisk = await memDiskGroup
            let net = await network
            let processList = await procs
            let (battery, ups) = await powerSources
            let systemInfo = await sysInfo

            // Network/disk process lists use their own counter/cache (kept sequential).
            // The nettop subprocess is heavyweight, so we only run it when at least
            // one view is actually displaying the per-process list.
            self.networkProcessUpdateCounter += 1
            let networkProcesses: [ProcessNetworkInfo]
            if self.activeNetworkProcessesViewerCount > 0
                && self.networkProcessUpdateCounter >= Int(Constants.networkProcessUpdateInterval / self.updateInterval) {
                networkProcesses = self.getTopNetworkProcesses(count: Constants.processCountThreshold)
                self.cachedNetworkProcesses = networkProcesses
                self.networkProcessUpdateCounter = 0
            } else {
                networkProcesses = self.cachedNetworkProcesses
            }

            self.diskProcessUpdateCounter += 1
            let diskProcesses: [ProcessDiskInfo]
            if self.diskProcessUpdateCounter >= Int(Constants.diskProcessUpdateInterval / self.updateInterval) {
                diskProcesses = self.getTopDiskProcesses(count: Constants.processCountThreshold)
                self.cachedDiskProcesses = diskProcesses
                self.diskProcessUpdateCounter = 0
            } else {
                diskProcesses = self.cachedDiskProcesses
            }

            await MainActor.run {
                self.updateCPUHistory(with: cpu)
                self.updateCPUTemperatureHistory(with: cpuTemp)
                self.updateNetworkHistory(upload: net.upload, download: net.download)
                let memPct = memDisk.memory.total > 0 ? (memDisk.memory.used / memDisk.memory.total) * 100.0 : 0.0
                self.updateMemoryHistory(with: memPct)
                self.updateFanHistory(with: fan.rpm)

                // Only publish values that actually changed to suppress unnecessary SwiftUI redraws.
                if abs(self.cpuUsage - cpu) > 0.1 { self.cpuUsage = cpu }
                if abs(self.cpuTemperature - cpuTemp) > 0.5 { self.cpuTemperature = cpuTemp }
                if self.fanInfo.speeds != fan.speeds || abs(self.fanInfo.rpm - fan.rpm) > 50 { self.fanInfo = fan }
                let mem = memDisk.memory
                if abs(self.memoryUsage.used - mem.used) > 0.05 {
                    self.memoryUsage = (used: mem.used, total: mem.total)
                }
                let newComp = (app: mem.appMemory, wired: mem.wired, compressed: mem.compressed, cached: mem.cached, free: mem.free)
                if abs(self.memoryComposition.app - newComp.app) > 0.05
                    || abs(self.memoryComposition.compressed - newComp.compressed) > 0.05
                    || abs(self.memoryComposition.wired - newComp.wired) > 0.05 {
                    self.memoryComposition = newComp
                }
                if self.memoryPressure != mem.pressure { self.memoryPressure = mem.pressure }
                if abs(self.swapUsage.used - memDisk.swap.used) > 0.005
                    || abs(self.swapUsage.total - memDisk.swap.total) > 0.005 {
                    self.swapUsage = memDisk.swap
                }
                if abs(self.diskUsage.free - memDisk.disk.free) > 100_000_000 { self.diskUsage = memDisk.disk }
                if !coreUsages.isEmpty { self.cpuCoreUsages = coreUsages }
                if abs(self.cpuLoadAverages.one - loadAverages.one) > 0.01 { self.cpuLoadAverages = loadAverages }
                if self.localIPAddress != localIP { self.localIPAddress = localIP }
                if abs(self.diskReadRate - memDisk.diskIO.readMBps) > 0.05 { self.diskReadRate = memDisk.diskIO.readMBps }
                if abs(self.diskWriteRate - memDisk.diskIO.writeMBps) > 0.05 { self.diskWriteRate = memDisk.diskIO.writeMBps }
                self.updateDiskIOHistory(read: memDisk.diskIO.readMBps, write: memDisk.diskIO.writeMBps)
                self.networkUsage = net   // always assign — fluctuates every tick when active
                self.topProcesses = processList.cpu
                self.topMemoryProcesses = processList.memory
                if self.processCount != processList.processCount { self.processCount = processList.processCount }
                if self.threadCount != processList.threadCount { self.threadCount = processList.threadCount }
                self.topNetworkProcesses = networkProcesses
                self.topDiskProcesses = diskProcesses
                if abs(self.batteryInfo.chargeLevel - battery.chargeLevel) > 0.5
                    || self.batteryInfo.isCharging != battery.isCharging { self.batteryInfo = battery }
                if self.upsInfo.powerSource != ups.powerSource
                    || abs(self.upsInfo.chargeLevel - ups.chargeLevel) > 0.5 { self.upsInfo = ups }
                self.systemInfo = systemInfo
                self.initialDataLoaded = true

                self.checkAndNotifyUPSPowerChange()
                self.didUpdate.send()
            }
        }
    }
    
    // New method to update power consumption separately
    private func updatePowerConsumption() {
        DispatchQueue.global(qos: .userInitiated).async {
            let smcPowerBatch = readSMCPowerBatch()
            let powerConsumption = self.getCurrentPowerConsumption(smcSystemPower: smcPowerBatch.systemPower)
            let gpuTemp  = smcPowerBatch.gpuTemperature ?? 0.0
            let ssdTemp  = smcPowerBatch.ssdTemperature ?? 0.0
            let dcInWatts = smcPowerBatch.dcInPower ?? 0.0
            let memTemp  = smcPowerBatch.memoryTemperature ?? 0.0
            DispatchQueue.main.async {
                if abs(self.powerConsumptionInfo.totalSystemPower - powerConsumption.totalSystemPower) > 0.5 {
                    self.powerConsumptionInfo = powerConsumption
                }
                self.updatePowerHistory(with: dcInWatts > 0 ? dcInWatts : powerConsumption.totalSystemPower)
                if abs(self.gpuTemperature - gpuTemp) > 0.5     { self.gpuTemperature = gpuTemp }
                if abs(self.ssdTemperature - ssdTemp) > 0.5    { self.ssdTemperature = ssdTemp }
                if abs(self.dcInPower - dcInWatts) > 0.5       { self.dcInPower = dcInWatts }
                if abs(self.memoryTemperature - memTemp) > 0.5 { self.memoryTemperature = memTemp }
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
    
    private func updateMemoryHistory(with value: Double) {
        memoryHistory.append(value)
        if memoryHistory.count > Constants.maxHistoryPoints { memoryHistory.removeFirst() }
    }

    private func updatePowerHistory(with value: Double) {
        powerHistory.append(value)
        if powerHistory.count > Constants.maxHistoryPoints { powerHistory.removeFirst() }
    }

    private func updateFanHistory(with value: Double) {
        fanHistory.append(value)
        if fanHistory.count > Constants.maxHistoryPoints { fanHistory.removeFirst() }
    }

    // Update network history for sparklines
    private func updateNetworkHistory(upload: Double, download: Double) {
        uploadHistory.append(upload)
        downloadHistory.append(download)
        sessionBytesUploaded += upload * updateInterval
        sessionBytesDownloaded += download * updateInterval

        // Keep only the last Constants.maxHistoryPoints values
        if uploadHistory.count > Constants.maxHistoryPoints {
            uploadHistory.removeFirst()
        }

        if downloadHistory.count > Constants.maxHistoryPoints {
            downloadHistory.removeFirst()
        }
    }

    private func updateDiskIOHistory(read: Double, write: Double) {
        diskReadHistory.append(read)
        diskWriteHistory.append(write)
        if diskReadHistory.count > Constants.maxHistoryPoints { diskReadHistory.removeFirst() }
        if diskWriteHistory.count > Constants.maxHistoryPoints { diskWriteHistory.removeFirst() }
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
        } else {
            print(" CPU monitoring failed: host_statistics error \(result)")
        }
        
        return 0.0
    }
    
    private func getPerCoreCPUUsage() -> [Double] {
        var numCPUs: natural_t = 0
        var cpuInfoPtr: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &cpuInfoPtr, &numCPUInfo) == KERN_SUCCESS,
              let infoPtr = cpuInfoPtr else { return [] }
        let count = Int(numCPUInfo)
        let current = Array(UnsafeBufferPointer(start: infoPtr, count: count))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: infoPtr),
                      vm_size_t(count) * vm_size_t(MemoryLayout<Int32>.size))
        var usages: [Double] = []
        if !previousCoreData.isEmpty && previousCoreData.count == count {
            let stride = Int(CPU_STATE_MAX)
            for i in 0..<Int(numCPUs) {
                let user   = Double(current[i * stride + Int(CPU_STATE_USER)])
                let system = Double(current[i * stride + Int(CPU_STATE_SYSTEM)])
                let idle   = Double(current[i * stride + Int(CPU_STATE_IDLE)])
                let nice   = Double(current[i * stride + Int(CPU_STATE_NICE)])
                let prevUser   = Double(previousCoreData[i * stride + Int(CPU_STATE_USER)])
                let prevSystem = Double(previousCoreData[i * stride + Int(CPU_STATE_SYSTEM)])
                let prevIdle   = Double(previousCoreData[i * stride + Int(CPU_STATE_IDLE)])
                let prevNice   = Double(previousCoreData[i * stride + Int(CPU_STATE_NICE)])
                let active = (user - prevUser) + (system - prevSystem) + (nice - prevNice)
                let total  = active + (idle - prevIdle)
                usages.append(total > 0 ? min(100, (active / total) * 100) : 0)
            }
        }
        previousCoreData = current
        return usages
    }

    private func getCPULoadAverages() -> (one: Double, five: Double, fifteen: Double) {
        var loads: [Double] = [0, 0, 0]
        getloadavg(&loads, 3)
        return (one: loads[0], five: loads[1], fifteen: loads[2])
    }

    private func getLocalIPAddress() -> String {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "" }
        defer { freeifaddrs(ifaddr) }

        let preferred = preferences?.selectedNetworkInterface
        var fallback = ""

        var ptr = ifaddr
        while let current = ptr {
            let ifa = current.pointee
            let name = String(cString: ifa.ifa_name)
            if ifa.ifa_addr?.pointee.sa_family == UInt8(AF_INET),
               !name.hasPrefix("lo"),
               let sa = ifa.ifa_addr {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sa, socklen_t(MemoryLayout<sockaddr_in>.size),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    guard ip != "127.0.0.1" else { ptr = ifa.ifa_next; continue }
                    if let pref = preferred, pref != "All", pref != "Combined", name == pref {
                        return ip
                    }
                    if fallback.isEmpty { fallback = ip }
                }
            }
            ptr = ifa.ifa_next
        }
        return fallback
    }

    private func getDiskIORate() -> (readMBps: Double, writeMBps: Double) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
              IOServiceMatching("IOBlockStorageDriver"), &iter) == KERN_SUCCESS else { return (0, 0) }
        defer { IOObjectRelease(iter) }
        var service = IOIteratorNext(iter)
        while service != IO_OBJECT_NULL {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as NSDictionary? as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let r = stats["Bytes (Read)"] as? UInt64  { totalRead  += r }
                if let w = stats["Bytes (Write)"] as? UInt64 { totalWrite += w }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iter)
        }
        let now = Date()
        var result: (readMBps: Double, writeMBps: Double) = (0, 0)
        if let prev = previousDiskIOStats {
            let elapsed = now.timeIntervalSince(prev.time)
            if elapsed > 0 && elapsed < 30 {
                let rd = totalRead  >= prev.read    ? totalRead  - prev.read    : 0
                let wd = totalWrite >= prev.written ? totalWrite - prev.written : 0
                result = (Double(rd) / elapsed / 1_048_576, Double(wd) / elapsed / 1_048_576)
            }
        }
        previousDiskIOStats = (read: totalRead, written: totalWrite, time: now)
        return result
    }

    private func getCurrentCPUTemperature() -> Double {
        let temperature = TemperatureMonitor.averageCPUTemperature()
        return temperature
    }
    
    private func getMemoryStats() -> MemoryStats {
        var stats = vm_statistics64()
        let HOST_VM_INFO64_COUNT = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(HOST_VM_INFO64_COUNT)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: HOST_VM_INFO64_COUNT) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            print(" Memory monitoring failed: host_statistics64 error \(result)")
            return MemoryStats(used: 0, total: 0, appMemory: 0, wired: 0, compressed: 0, cached: 0, free: 0, pressure: .normal)
        }

        let pageSize = Double(vm_kernel_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let gb = Constants.gbDivisor

        // Activity Monitor breakdown
        let wiredBytes = Double(stats.wire_count) * pageSize
        let compressedBytes = Double(stats.compressor_page_count) * pageSize
        let purgeableBytes = Double(stats.purgeable_count) * pageSize
        let externalBytes = Double(stats.external_page_count) * pageSize
        let internalBytes = Double(stats.internal_page_count) * pageSize
        let freeBytes = Double(stats.free_count + stats.speculative_count) * pageSize

        let appBytes = max(internalBytes - purgeableBytes, 0)
        let cachedBytes = externalBytes + purgeableBytes
        let usedBytes = appBytes + wiredBytes + compressedBytes

        // Pressure heuristic: how much of physical memory the compressor is holding
        let compressionRatio = totalMemory > 0 ? compressedBytes / totalMemory : 0
        let pressure: MemoryPressureLevel
        if compressionRatio > 0.20 { pressure = .critical }
        else if compressionRatio > 0.10 { pressure = .warning }
        else { pressure = .normal }

        return MemoryStats(
            used: usedBytes / gb,
            total: totalMemory / gb,
            appMemory: appBytes / gb,
            wired: wiredBytes / gb,
            compressed: compressedBytes / gb,
            cached: cachedBytes / gb,
            free: freeBytes / gb,
            pressure: pressure
        )
    }

    private func getSwapUsage() -> (used: Double, total: Double) {
        var xsu = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &xsu, &size, nil, 0) == 0 else { return (0, 0) }
        let gb = Constants.gbDivisor
        return (used: Double(xsu.xsu_used) / gb, total: Double(xsu.xsu_total) / gb)
    }
    
    private func getCurrentDisk() -> (free: Double, total: Double, purgeable: Double) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacity,
               let availableForImportant = values.volumeAvailableCapacityForImportantUsage {
                
                // Convert to GB using constant
                let freeGB = Double(available) / Constants.gbDivisor
                let totalGB = Double(total) / Constants.gbDivisor
                let purgeableGB = Double(Int64(available) - Int64(availableForImportant)) / Constants.gbDivisor
                
                return (free: freeGB, total: totalGB, purgeable: purgeableGB)
            }
        } catch {
            print(" Disk monitoring failed: \(error)")
        }
        
        return (free: 0.0, total: 0.0, purgeable: 0.0)
    }
    
    private func getCurrentNetwork() -> (upload: Double, download: Double) {
        let currentTime = Date()
        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
        
        // Check which interface is selected
        let selectedInterface = preferences?.selectedNetworkInterface ?? "All"
        #if DEBUG
        print(" Selected interface for monitoring: '\(selectedInterface)'")
        #endif
        
        let allIfStats = getAllInterfaceStats()

        // Collect current stats for all interfaces
        var currentStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var totalBytesIn: UInt64 = 0
        var totalBytesOut: UInt64 = 0
        
        // Get current stats for all physical interfaces
        for interface in networkInterfaces {
            if interface == "Combined" {
                // Skip Combined in the main loop since it's virtual
                continue
            }
            
            if interface == "bond0" && hasBondedInterfaces {
                // For bond0, get its own stats directly rather than summing members
                // This is because bonded member interfaces often don't report inbound stats correctly
                let bond0Stats = allIfStats["bond0"] ?? (bytesIn: 0, bytesOut: 0)
                let en0Stats = allIfStats["en0"] ?? (bytesIn: 0, bytesOut: 0)
                let en1Stats = allIfStats["en1"] ?? (bytesIn: 0, bytesOut: 0)
                
                // Use bond0's inbound stats (which should be correct) and sum outbound from members
                // If bond0 doesn't have good stats, fall back to summing members
                let bondedBytesIn = bond0Stats.bytesIn > 0 ? bond0Stats.bytesIn : (en0Stats.bytesIn + en1Stats.bytesIn)
                let bondedBytesOut = bond0Stats.bytesOut > 0 ? bond0Stats.bytesOut : (en0Stats.bytesOut + en1Stats.bytesOut)
                
                currentStats[interface] = (bytesIn: bondedBytesIn, bytesOut: bondedBytesOut)
                totalBytesIn += bondedBytesIn
                totalBytesOut += bondedBytesOut
                
                #if DEBUG
                print(" Bond0 stats - bond0 direct: In=\(bond0Stats.bytesIn), Out=\(bond0Stats.bytesOut)")
                print(" Bond0 stats - en0: In=\(en0Stats.bytesIn), Out=\(en0Stats.bytesOut)")
                print(" Bond0 stats - en1: In=\(en1Stats.bytesIn), Out=\(en1Stats.bytesOut)")
                print(" Bond0 stats - Final: In=\(bondedBytesIn), Out=\(bondedBytesOut)")
                #endif
                
                // Don't double count en0 and en1 when bond0 is present
                continue
            }
            
            // Skip en0 and en1 if we're using bond0 (to avoid double counting)
            if hasBondedInterfaces && (interface == "en0" || interface == "en1") && networkInterfaces.contains("bond0") {
                continue
            }
            
            let stats = allIfStats[interface] ?? (bytesIn: 0, bytesOut: 0)
            currentStats[interface] = stats
            totalBytesIn += stats.bytesIn
            totalBytesOut += stats.bytesOut
        }
        
        // Handle Combined virtual interface stats
        if networkInterfaces.contains("Combined") {
            var combinedBytesIn: UInt64 = 0
            var combinedBytesOut: UInt64 = 0
            
            // Sum all active interfaces for the combined stats
            for activeInterface in activeNetworkInterfaces {
                // Special handling: if bond0 exists, use it instead of en0/en1
                if hasBondedInterfaces && (activeInterface == "en0" || activeInterface == "en1") && networkInterfaces.contains("bond0") {
                    continue // Skip en0/en1 as they're already counted in bond0
                }
                
                if activeInterface == "bond0" && hasBondedInterfaces {
                    // For bond0 in combined calculation, sum en0 and en1
                    let en0Stats = allIfStats["en0"] ?? (bytesIn: 0, bytesOut: 0)
                    let en1Stats = allIfStats["en1"] ?? (bytesIn: 0, bytesOut: 0)

                    combinedBytesIn += en0Stats.bytesIn + en1Stats.bytesIn
                    combinedBytesOut += en0Stats.bytesOut + en1Stats.bytesOut
                } else {
                    let stats = allIfStats[activeInterface] ?? (bytesIn: 0, bytesOut: 0)
                    combinedBytesIn += stats.bytesIn
                    combinedBytesOut += stats.bytesOut
                }
            }
            
            currentStats["Combined"] = (bytesIn: combinedBytesIn, bytesOut: combinedBytesOut)
        }
        
        // Calculate rates (bytes per second)
        if timeInterval > 0 {
            var bytesInRate: Double = 0
            var bytesOutRate: Double = 0
            
            if selectedInterface == "All" {
                // Calculate for all interfaces combined (exclude Combined to avoid double counting)
                var previousTotalBytesIn: UInt64 = 0
                var previousTotalBytesOut: UInt64 = 0
                
                for interface in networkInterfaces {
                    if interface == "Combined" {
                        continue // Skip Combined to avoid double counting
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
            } else if selectedInterface == "Combined" {
                // Special handling for Combined interface - uses aggregated active interface stats
                if let current = currentStats["Combined"],
                   let previous = previousInterfaceStats["Combined"] {
                    let bytesInDiff = current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                    let bytesOutDiff = current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                    
                    bytesInRate = Double(bytesInDiff) / timeInterval
                    bytesOutRate = Double(bytesOutDiff) / timeInterval
                }
            } else if selectedInterface == "bond0" && hasBondedInterfaces {
                // For bond0, try to get the most accurate stats
                let bond0Stats = allIfStats["bond0"] ?? (bytesIn: 0, bytesOut: 0)
                let en0Stats = allIfStats["en0"] ?? (bytesIn: 0, bytesOut: 0)
                let en1Stats = allIfStats["en1"] ?? (bytesIn: 0, bytesOut: 0)
                
                // Use bond0's inbound stats if available, otherwise sum members
                // Always sum outbound from members for accuracy
                let bondedBytesIn = bond0Stats.bytesIn > 0 ? bond0Stats.bytesIn : (en0Stats.bytesIn + en1Stats.bytesIn)
                let bondedBytesOut = bond0Stats.bytesOut > 0 ? bond0Stats.bytesOut : (en0Stats.bytesOut + en1Stats.bytesOut)
                
                currentStats[selectedInterface] = (bytesIn: bondedBytesIn, bytesOut: bondedBytesOut)
                
                #if DEBUG
                print(" Bond0 initial - bond0 direct: In=\(bond0Stats.bytesIn), Out=\(bond0Stats.bytesOut)")
                print(" Bond0 initial - en0: In=\(en0Stats.bytesIn), Out=\(en0Stats.bytesOut)")
                print(" Bond0 initial - en1: In=\(en1Stats.bytesIn), Out=\(en1Stats.bytesOut)")
                print(" Bond0 initial - Final: In=\(bondedBytesIn), Out=\(bondedBytesOut)")
                #endif
                
                if let current = currentStats[selectedInterface],
                   let previous = previousInterfaceStats[selectedInterface] {
                    let bytesInDiff = current.bytesIn >= previous.bytesIn ? (current.bytesIn - previous.bytesIn) : 0
                    let bytesOutDiff = current.bytesOut >= previous.bytesOut ? (current.bytesOut - previous.bytesOut) : 0
                    
                    bytesInRate = Double(bytesInDiff) / timeInterval
                    bytesOutRate = Double(bytesOutDiff) / timeInterval
                    
                    #if DEBUG
                    print(" Bond0 rate calculation: In: \(bytesInRate) B/s, Out: \(bytesOutRate) B/s")
                    print(" Bond0 differences: InDiff=\(bytesInDiff), OutDiff=\(bytesOutDiff), TimeInterval=\(timeInterval)")
                    #endif
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
    
    private func getTopProcessesBoth(count: Int) -> (cpu: [SystemProcessInfo], memory: [SystemProcessInfo], processCount: Int, threadCount: Int) {
        let now = Date()
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return ([], [], 0, 0) }

        var pidBuf = [pid_t](repeating: 0, count: Int(byteCount) / MemoryLayout<pid_t>.size + 1)
        let actualBytes = pidBuf.withUnsafeMutableBytes { ptr -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, ptr.baseAddress, Int32(ptr.count))
        }
        guard actualBytes > 0 else { return ([], [], 0, 0) }

        let pidCount = Int(actualBytes) / MemoryLayout<pid_t>.size
        let pids = pidBuf.prefix(pidCount).filter { $0 > 0 }
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)

        var cpuList: [SystemProcessInfo] = []
        var memList: [SystemProcessInfo] = []
        var newCPUTimes: [pid_t: (user: UInt64, system: UInt64, time: Date)] = [:]
        newCPUTimes.reserveCapacity(pids.count)
        var liveProcessCount = 0
        var liveThreadCount = 0

        for pid in pids {
            var taskInfo = proc_taskinfo()
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize) == taskInfoSize else { continue }

            liveProcessCount += 1
            liveThreadCount += Int(taskInfo.pti_threadnum)

            let userTime = taskInfo.pti_total_user
            let systemTime = taskInfo.pti_total_system
            newCPUTimes[pid] = (user: userTime, system: systemTime, time: now)

            let memPct = totalMemory > 0 ? (Double(taskInfo.pti_resident_size) / totalMemory) * 100.0 : 0.0
            var cpuPct = 0.0
            if let prev = previousProcessCPUTimes[pid] {
                let elapsed = now.timeIntervalSince(prev.time)
                if elapsed > 0.1 {
                    let userDelta = userTime >= prev.user ? userTime - prev.user : 0
                    let systemDelta = systemTime >= prev.system ? systemTime - prev.system : 0
                    cpuPct = Double(userDelta + systemDelta) * Self.machTimeToSeconds / elapsed * 100.0
                }
            }

            guard cpuPct > Constants.minCpuUsageFilter || memPct > Constants.minMemoryUsageFilter else { continue }
            var nameBuf = [CChar](repeating: 0, count: 1024)
            proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            let name = String(cString: nameBuf)
            guard !name.isEmpty else { continue }

            let info = SystemProcessInfo(pid: pid, name: name, cpuUsage: cpuPct, memoryUsage: memPct)
            if cpuPct > Constants.minCpuUsageFilter { cpuList.append(info) }
            if memPct > Constants.minMemoryUsageFilter { memList.append(info) }
        }

        previousProcessCPUTimes = newCPUTimes
        return (
            cpu: Array(cpuList.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(count)),
            memory: Array(memList.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(count)),
            processCount: liveProcessCount,
            threadCount: liveThreadCount
        )
    }
    
    // MARK: - Disk Process Monitoring

    private func getTopDiskProcesses(count: Int) -> [ProcessDiskInfo] {
        let now = Date()

        // Get all live PIDs
        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return cachedDiskProcesses }

        var pidBuf = [pid_t](repeating: 0, count: Int(byteCount) / MemoryLayout<pid_t>.size + 1)
        let actualBytes = pidBuf.withUnsafeMutableBytes { ptr -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, ptr.baseAddress, Int32(ptr.count))
        }
        guard actualBytes > 0 else { return cachedDiskProcesses }

        let pidCount = Int(actualBytes) / MemoryLayout<pid_t>.size
        let pids = pidBuf.prefix(pidCount).filter { $0 > 0 }

        var results: [ProcessDiskInfo] = []
        var newCache: [Int32: (read: UInt64, written: UInt64, time: Date)] = [:]
        newCache.reserveCapacity(pids.count)

        for pid in pids {
            var info = rusage_info_v4()
            // C idiom: proc_pid_rusage(pid, flavor, (rusage_info_t *)&info)
            // The kernel treats 'buffer' as a plain void* destination and copies
            // the rusage struct there — it does NOT dereference it as void**.
            // So we must pass &info bitcast to UnsafeMutablePointer<rusage_info_t?>,
            // not the address of a separate pointer variable (which overflows the stack).
            let ret = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
                ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, reboundPtr)
                }
            }
            guard ret == 0 else { continue }

            let curRead  = info.ri_diskio_bytesread
            let curWrite = info.ri_diskio_byteswritten
            newCache[pid] = (read: curRead, written: curWrite, time: now)

            guard let prev = previousDiskIO[pid] else { continue }
            let elapsed = now.timeIntervalSince(prev.time)
            guard elapsed > 0.1 else { continue }

            let readDelta  = curRead  >= prev.read    ? curRead  - prev.read    : 0
            let writeDelta = curWrite >= prev.written ? curWrite - prev.written : 0
            let readRate   = Double(readDelta)  / elapsed
            let writeRate  = Double(writeDelta) / elapsed

            // Skip processes with trivially low I/O (< 1 KB/s total)
            guard readRate + writeRate >= 1024 else { continue }

            var nameBuf = [CChar](repeating: 0, count: 1024)
            proc_name(pid, &nameBuf, UInt32(nameBuf.count))
            let name = String(cString: nameBuf)
            guard !name.isEmpty else { continue }

            results.append(ProcessDiskInfo(pid: pid, name: name,
                                           bytesRead: readRate,
                                           bytesWritten: writeRate))
        }

        previousDiskIO = newCache
        return Array(results.sorted { $0.totalIO > $1.totalIO }.prefix(count))
    }

    // MARK: - Process Network Monitoring Methods
    
    private func getTopNetworkProcesses(count: Int) -> [ProcessNetworkInfo] {
        return parseNettopOutput("NETTOP:" + getNettopData(), maxCount: count)
    }
    
    private func getNettopData() -> String {
        // Resolve the nettop binary path once; avoids 6 FileManager.fileExists calls on every tick.
        if cachedNettopPath == nil {
            let possiblePaths = [
                "/usr/bin/nettop",
                "/usr/sbin/nettop",
                "/bin/nettop",
                "/usr/local/bin/nettop",
                "/opt/homebrew/bin/nettop",
                "/opt/local/bin/nettop"
            ]
            cachedNettopPath = possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
            #if DEBUG
            if let found = cachedNettopPath { print(" nettop resolved to: \(found)") }
            else { print(" nettop not found in any standard location") }
            #endif
        }

        guard let path = cachedNettopPath,
              let output = executeCommand(path, ["-P", "-L", "1"]),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }
        return output
    }
    
    private func parseNettopOutput(_ output: String, maxCount: Int) -> [ProcessNetworkInfo] {
        let lines = output.split(separator: "\n")
        var processNetworkInfos: [ProcessNetworkInfo] = []
        
        #if DEBUG
        print(" Parsing nettop CSV format with \(lines.count) lines")
        #endif
        
        // Skip the header line (first line contains column names)
        for (lineIndex, line) in lines.enumerated().dropFirst() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.isEmpty { continue }
            
            if let processInfo = parseNettopCSVLine(String(trimmedLine), lineIndex: lineIndex) {
                processNetworkInfos.append(processInfo)
                #if DEBUG
                print(" Parsed: \(processInfo.name) (PID: \(processInfo.pid)) - In: \(processInfo.bytesIn), Out: \(processInfo.bytesOut)")
                #endif
            }
        }
        
        #if DEBUG
        print(" Successfully parsed \(processNetworkInfos.count) processes from nettop CSV")
        #endif
        
        // Filter out processes with zero network activity and sort by total usage
        let activeProcesses = processNetworkInfos.filter { $0.totalUsage > 0 }
        let sortedProcesses = activeProcesses.sorted { $0.totalUsage > $1.totalUsage }
        
        #if DEBUG
        print(" Found \(activeProcesses.count) processes with network activity")
        #endif
        
        return Array(sortedProcesses.prefix(maxCount))
    }
    
    private func parseNettopCSVLine(_ line: String, lineIndex: Int) -> ProcessNetworkInfo? {
        // Split by comma for CSV format
        let components = line.split(separator: ",").map { String($0) }
        
        // Expected format: time,process_name.PID,,,bytes_in,bytes_out,...
        guard components.count >= 6 else {
            #if DEBUG
            print(" Line \(lineIndex) has insufficient columns: \(components.count)")
            #endif
            return nil
        }
        
        // Extract process name and PID from second column (format: "process_name.PID")
        let processField = components[1]
        guard !processField.isEmpty else {
            #if DEBUG
            print(" Line \(lineIndex) has empty process field")
            #endif
            return nil
        }
        
        // Parse process_name.PID format
        var processName = processField
        var pid: Int32 = 0
        
        if let lastDotIndex = processField.lastIndex(of: ".") {
            let pidString = String(processField[processField.index(after: lastDotIndex)...])
            if let pidValue = Int32(pidString) {
                pid = pidValue
                processName = String(processField[..<lastDotIndex])
            }
        }
        
        // Extract bytes_in (5th column, index 4) and bytes_out (6th column, index 5)
        let bytesInString = components[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let bytesOutString = components[5].trimmingCharacters(in: .whitespacesAndNewlines)
        
        let bytesIn = Double(bytesInString) ?? 0.0
        let bytesOut = Double(bytesOutString) ?? 0.0
        
        // Only create entry if we have a valid process name
        guard !processName.isEmpty else {
            return nil
        }
        
        return ProcessNetworkInfo(
            pid: pid,
            name: processName,
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            connections: bytesIn > 0 || bytesOut > 0 ? 1 : 0,
            state: "ACTIVE"
        )
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
        
        let systemInfo = SystemInfo(
            modelName: modelName,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            kernelVersion: kernelVersion,
            uptime: uptime,
            bootTime: bootTime,
            chipInfo: chipInfo
        )
        
        cachedSystemInfo = systemInfo
        lastSystemInfoUpdate = Date()
        return systemInfo
    }
    
    // Helper to get hardware info in single call
    private func getHardwareInfo() -> (modelName: String, chipInfo: String)? {
        guard let output = executeCommand("/usr/sbin/system_profiler", ["SPHardwareDataType"]) else {
            // Fallback to sysctl for model name only
            let modelName = executeCommand("/usr/sbin/sysctl", ["-n", "hw.model"]) ?? "Unknown"
            return (modelName: modelName.trimmingCharacters(in: .whitespaces), chipInfo: "Unknown")
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
    
    private func getCachedOrFreshSystemInfo() -> SystemInfo {
        let now = Date()
        
        // Return cached info if it's still valid (less than 5 minutes old)
        if let cached = cachedSystemInfo,
           now.timeIntervalSince(lastSystemInfoUpdate) < Constants.systemInfoCacheInterval {
            // Still update uptime since that changes
            _ = cached
            let uptimeInfo = getUptimeInfo()
            return SystemInfo(
                modelName: cached.modelName,
                macOSVersion: cached.macOSVersion,
                kernelVersion: cached.kernelVersion,
                uptime: uptimeInfo.uptime,
                bootTime: uptimeInfo.bootTime,
                chipInfo: cached.chipInfo
            )
        }
        
        // Cache has expired, get fresh data
        let freshInfo = getCurrentSystemInfo()
        cachedSystemInfo = freshInfo
        lastSystemInfoUpdate = now
        return freshInfo
    }
    
    // Lightweight method to get just uptime info
    private func getUptimeInfo() -> (uptime: TimeInterval, bootTime: Date) {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        
        let result = sysctl(&mib, 2, &boottime, &size, nil, 0)
        if result == 0 {
            let bootTime = Date(timeIntervalSince1970: Double(boottime.tv_sec) + Double(boottime.tv_usec) / 1_000_000)
            let uptime = Date().timeIntervalSince(bootTime)
            return (uptime: uptime, bootTime: bootTime)
        }
        
        return (uptime: 0, bootTime: Date())
    }
    
    private func getCurrentFanInfo(smcFans: SMCFanData? = nil) -> FanInfo {
        let thermalInfo = TemperatureMonitor.getThermalInfo()

        // Try real fan data from SMC first
        if let fanData = smcFans ?? readSMCFans(), !fanData.speeds.isEmpty {
            // Apply EMA smoothing (alpha=0.4) to reduce SMC jitter.
            // Re-initialise smoothed array if fan count changes.
            let rawSpeeds = fanData.speeds.map(Double.init)
            let alpha = 0.4
            if smoothedFanSpeeds.count != rawSpeeds.count {
                smoothedFanSpeeds = rawSpeeds
            } else {
                smoothedFanSpeeds = zip(smoothedFanSpeeds, rawSpeeds)
                    .map { prev, raw in alpha * raw + (1 - alpha) * prev }
            }
            let smoothedInts = smoothedFanSpeeds.map { Int($0.rounded()) }
            let avgRPM = smoothedFanSpeeds.reduce(0, +) / Double(smoothedFanSpeeds.count)
            let maxRPM = fanData.maxSpeeds.max().map(Double.init) ?? 6000.0
            return FanInfo(
                rpm: avgRPM,
                isEstimate: false,
                thermalState: thermalInfo.state,
                thermalPressure: thermalInfo.pressure,
                maxRPM: maxRPM,
                speeds: smoothedInts,
                maxSpeeds: fanData.maxSpeeds,
                targetSpeeds: fanData.targetSpeeds
            )
        }

        // No fans detected on this hardware
        return FanInfo(
            rpm: 0,
            isEstimate: true,
            thermalState: thermalInfo.state,
            thermalPressure: thermalInfo.pressure,
            maxRPM: 6000.0
        )
    }
    
    private func getCurrentUPSInfo(blob preBlob: CFTypeRef? = nil) -> UPSInfo {
        // Accept a pre-fetched power source blob to avoid redundant IOPSCopyPowerSourcesInfo calls.
        guard let blob = preBlob ?? IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
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
        
        // No UPS found, return basic power source info (reuse the already-fetched blob)
        let powerSourceState = getPowerSourceState(blob: blob)
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
    
    // Helper method to get general power source state.
    // Accepts a pre-fetched blob to avoid an extra IOPSCopyPowerSourcesInfo call.
    private func getPowerSourceState(blob preBlob: CFTypeRef? = nil) -> String {
        guard let blob = preBlob ?? IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return "AC Power"
        }

        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return "AC Power"
        }

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
    
    private func getCurrentBatteryInfo(blob preBlob: CFTypeRef? = nil) -> BatteryInfo {
        // Accept a pre-fetched power source blob to avoid redundant IOPSCopyPowerSourcesInfo calls.
        guard let blob = preBlob ?? IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
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
            let powerSourceState = description[kIOPSPowerSourceStateKey] as? String ?? ""
            let isPluggedIn = powerSourceState == kIOPSACPowerValue
            let isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            let chargeLevel = (description[kIOPSCurrentCapacityKey] as? Int).map(Double.init) ?? 0.0
            // When charging, IOKit puts the ETA in TimeToFullCharge; TimeToEmpty is 0.
            // When discharging, TimeToEmpty is the runtime estimate. Either key can return
            // -1 meaning "still calculating" — preserved here so the UI can show that state.
            let timeKey = isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let timeRemaining = (description[timeKey] as? Int).map(Double.init) ?? 0.0
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
                    isPluggedIn: isPluggedIn,
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
    
    private func getCurrentPowerConsumption(smcSystemPower: Double? = nil) -> PowerConsumptionInfo {
        // Check cache first to avoid excessive macmon calls
        let now = Date()
        if let cached = cachedPowerConsumption,
           now.timeIntervalSince(lastPowerConsumptionUpdate) < Constants.powerConsumptionCacheInterval {
            return cached
        }
        
        // Prevent concurrent macmon executions
        guard !isFetchingPowerConsumption else {
            return cachedPowerConsumption ?? estimatePowerConsumption()
        }
        
        isFetchingPowerConsumption = true
        defer { isFetchingPowerConsumption = false }
        
        // Try macmon first
        var basePowerInfo: PowerConsumptionInfo
        
        if let powerData = getPowerConsumptionFromMacmon(smcSystemPower: smcSystemPower) {
            basePowerInfo = powerData
        } else {
            basePowerInfo = estimatePowerConsumption()
        }
        
        // Get power adapter info with current system power
        let adapterInfo = getCurrentPowerAdapterInfo(systemPower: basePowerInfo.totalSystemPower)
        
        // Create updated power info with adapter data
        let powerInfo = PowerConsumptionInfo(
            cpuPower: basePowerInfo.cpuPower,
            gpuPower: basePowerInfo.gpuPower,
            totalSystemPower: basePowerInfo.totalSystemPower,
            timestamp: basePowerInfo.timestamp,
            isEstimate: basePowerInfo.isEstimate,
            adapterInfo: adapterInfo
        )
        
        // Cache the result
        cachedPowerConsumption = powerInfo
        lastPowerConsumptionUpdate = now
        
        return powerInfo
    }
    
    // Updated method to detect power adapter information
    private func getCurrentPowerAdapterInfo(systemPower: Double) -> PowerAdapterInfo {
        // Only detect on laptops
        let modelName = systemInfo.modelName.lowercased()
        let isLaptop = modelName.contains("macbook") || 
                      modelName.contains("air") || 
                      batteryInfo.present
        
        if !isLaptop {
            return PowerAdapterInfo()
        }
        
        // Try system_profiler first for detailed info
        if let adapterInfo = getAdapterInfoFromSystemProfiler(systemPower: systemPower) {
            return adapterInfo
        }
        
        // Try IOKit as fallback
        return getAdapterInfoFromIOKit(systemPower: systemPower)
    }
    
    // Get adapter info from system_profiler SPPowerDataType (cached for 5 min)
    private func getAdapterInfoFromSystemProfiler(systemPower: Double) -> PowerAdapterInfo? {
        let now = Date()

        let parsed: (wattage: Int, type: String, model: String, isConnected: Bool)
        if let cached = cachedSPPowerOutput, now.timeIntervalSince(lastSPPowerUpdate) < 300 {
            parsed = cached
        } else {
            guard let output = executeCommand("/usr/sbin/system_profiler", ["SPPowerDataType"]) else {
                return nil
            }

            let lines = output.split(separator: "\n")
            var wattage = 0
            var type = "Unknown"
            var model = "Unknown"
            var isConnected = false

            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                if trimmedLine.contains("AC Charger Information:") {
                    isConnected = true
                }

                if trimmedLine.contains("Wattage (W):") {
                    let components = trimmedLine.split(separator: ":")
                    if components.count > 1 {
                        let wattageString = components[1].trimmingCharacters(in: .whitespaces)
                        wattage = Int(wattageString) ?? 0
                    }
                } else if trimmedLine.contains("Power Adapter:") {
                    let components = trimmedLine.split(separator: ":")
                    if components.count > 1 {
                        model = components[1].trimmingCharacters(in: .whitespaces)

                        let wattagePattern = try? NSRegularExpression(pattern: "(\\d+)W", options: [])
                        let range = NSRange(model.startIndex..<model.endIndex, in: model)
                        if let match = wattagePattern?.firstMatch(in: model, options: [], range: range),
                           let wattageRange = Range(match.range(at: 1), in: model) {
                            wattage = Int(String(model[wattageRange])) ?? 0
                        }

                        if model.lowercased().contains("magsafe") {
                            type = model.lowercased().contains("magsafe 3") ? "MagSafe 3" : "MagSafe"
                        } else if model.lowercased().contains("usb-c") || model.lowercased().contains("usbc") {
                            type = "USB-C"
                        } else if model.lowercased().contains("lightning") {
                            type = "Lightning"
                        }
                    }
                }

                if trimmedLine.contains("Connected:") && trimmedLine.contains("Yes") {
                    isConnected = true
                }
            }

            let result = (wattage: wattage, type: type, model: model, isConnected: isConnected)
            cachedSPPowerOutput = result
            lastSPPowerUpdate = now
            parsed = result
        }

        guard parsed.isConnected && parsed.wattage > 0 else { return nil }

        let inputPower = calculateInputPower(systemPower: systemPower)
        let efficiency = inputPower > 0 ? min((systemPower / inputPower) * 100, 100) : 0

        return PowerAdapterInfo(
            isConnected: parsed.isConnected,
            wattage: parsed.wattage,
            type: parsed.type,
            inputPower: inputPower,
            efficiency: efficiency,
            model: parsed.model
        )
    }
    
    // Get adapter info from IOKit (fallback)
    private func getAdapterInfoFromIOKit(systemPower: Double) -> PowerAdapterInfo {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return PowerAdapterInfo()
        }
        
        guard let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerAdapterInfo()
        }
        
        for ps in sources {
            guard let description = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            
            let powerSource = description[kIOPSPowerSourceStateKey] as? String ?? ""
            
            // Check if we're on AC power (adapter connected)
            if powerSource == kIOPSACPowerValue {
                // Try to get adapter wattage from various keys
                var wattage = 0
                var type = "USB-C" // Default assumption for modern Macs
                
                // Try different keys that might contain adapter info
                if let adapterWattage = description["AdapterWattage"] as? Int {
                    wattage = adapterWattage
                } else if let designCapacity = description["DesignCapacity"] as? Int {
                    // Sometimes design capacity can indicate adapter wattage
                    wattage = designCapacity
                }
                
                // If we couldn't get wattage from IOKit, estimate based on system
                if wattage == 0 {
                    wattage = estimateAdapterWattage()
                    type = estimateAdapterType()
                }
                
                let inputPower = calculateInputPower(systemPower: systemPower)
                let efficiency = wattage > 0 ? min((systemPower / Double(wattage)) * 100, 100) : 0
                
                return PowerAdapterInfo(
                    isConnected: true,
                    wattage: wattage,
                    type: type,
                    inputPower: inputPower,
                    efficiency: efficiency,
                    model: "\(wattage)W \(type) Power Adapter"
                )
            }
        }
        
        return PowerAdapterInfo()
    }
    
    private func estimateAdapterWattage() -> Int {
        let modelName = systemInfo.modelName.lowercased()
        
        if modelName.contains("macbook air") {
            if modelName.contains("15") {
                return 35 // 15" MacBook Air
            } else {
                return 30 // 13" MacBook Air
            }
        } else if modelName.contains("macbook pro") {
            if modelName.contains("16") {
                return 140 // 16" MacBook Pro
            } else if modelName.contains("14") {
                return 96 // 14" MacBook Pro
            } else if modelName.contains("13") {
                return 67 // 13" MacBook Pro
            }
        }
        
        // Default for unknown models
        return 67
    }
    
    // Estimate adapter type based on system model and age
    private func estimateAdapterType() -> String {
        let modelName = systemInfo.modelName.lowercased()
        
        // Most modern Macs use USB-C or MagSafe 3
        if modelName.contains("macbook pro") && (modelName.contains("14") || modelName.contains("16")) {
            return "MagSafe 3"
        } else if modelName.contains("macbook air") || modelName.contains("macbook pro") {
            return "USB-C"
        }
        
        return "USB-C"
    }
    
    // Calculate current input power from adapter
    private func calculateInputPower(systemPower: Double) -> Double {
        // If we have battery info and it's charging, we can estimate input power
        if batteryInfo.isCharging && batteryInfo.amperage > 0 && batteryInfo.voltage > 0 {
            // Convert mA to A and mV to V, then calculate watts
            let amperes = batteryInfo.amperage / 1000.0
            let volts = batteryInfo.voltage / 1000.0
            let batteryInputPower = abs(amperes * volts)
            
            // Add system consumption (total system power) to charging power
            return batteryInputPower + systemPower
        }
        
        // If not charging but on AC power, input power ≈ system consumption
        return systemPower
    }
    
    private func getPowerConsumptionFromMacmon(smcSystemPower: Double? = nil) -> PowerConsumptionInfo? {
        // Primary: call libIOReport directly — no subprocess, no session restrictions
        if let sample = sampleIOReportPower(intervalMs: 300) {
            // SMC "PSTR" gives total wall power (display, storage, fans, etc.)
            // Take the max of SMC and SoC power, matching macmon's sys_power logic.
            let smcPower = smcSystemPower ?? readSMCSystemPower() ?? 0.0
            let totalPower = max(smcPower, sample.total)
            return PowerConsumptionInfo(
                cpuPower: sample.cpu,
                gpuPower: sample.gpu,
                totalSystemPower: totalPower,
                timestamp: Date(),
                isEstimate: false
            )
        }

        // Fallback: try macmon subprocess (may not work in all contexts)
        let macmonPaths = [
            "/opt/homebrew/bin/macmon",
            "/usr/local/bin/macmon",
            "/usr/bin/macmon",
            "/opt/local/bin/macmon"
        ]

        for path in macmonPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let output = runMacmonStreamingFirstLine(path, timeout: Constants.macmonCallTimeout) {
                return parseMacmonJSONOutput(output)
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
        guard let preferences = preferences else { return }
        
        // Check if UPS power change notifications are enabled
        guard preferences.upsPowerChangeNotificationEnabled else { return }
        
        // Check if email notifications are enabled
        guard preferences.mailjetEmailEnabled else { return }
        
        // Check if we have UPS info and it's present
        guard upsInfo.present else { return }
        
        // Get current power state (true = on AC/charging, false = on UPS battery)
        let currentPowerState = upsInfo.powerSource == "AC Power"
        
        // Check if power state has changed
        let powerStateChanged = previousUPSPowerState != currentPowerState
        
        // Only proceed if there's been a state change
        guard powerStateChanged else {
            return
        }
        
        // Check cooldown period
        if let lastNotification = lastUPSPowerNotificationTime {
            let timeInterval = Date().timeIntervalSince(lastNotification)
            guard timeInterval >= Constants.notificationCooldownPeriod else {
                return
            }
        }
        
        // Send email notification
        sendUPSPowerChangeEmailNotification(isPowerRestored: currentPowerState)
        
        // Update tracking variables
        previousUPSPowerState = currentPowerState
        lastUPSPowerNotificationTime = Date()
    }
    
    private func sendUPSPowerChangeEmailNotification(isPowerRestored: Bool) {
        guard let preferences = preferences else { return }
        
        let subject: String
        let message: String
        let timestamp = Date().formatted(date: .complete, time: .shortened)
        let upsName = upsInfo.name != "Unknown" ? upsInfo.name : "UPS"
        
        if isPowerRestored {
            // Power restored
            subject = " UPS: AC Power Restored"
            message = """
            AC power has been restored to your system.
            
            UPS: \(upsName)
            Battery Level: \(String(format: "%.0f", upsInfo.chargeLevel))%
            Status: Power Restored
            Time: \(timestamp)
            
            Your system is now running on AC power and the UPS battery is charging.
            
            This is an automated notification from Mac Stats.
            """
        } else {
            // On battery power
            subject = " UPS: Running on Battery Power"
            let timeRemainingText = upsInfo.timeRemaining > 0 ? 
                String(format: "%.0f minutes", upsInfo.timeRemaining) : "Unknown"
            
            message = """
            Your system is now running on UPS battery power.
            
            UPS: \(upsName)
            Battery Level: \(String(format: "%.0f", upsInfo.chargeLevel))%
            Estimated Runtime: \(timeRemainingText)
            Status: On Battery
            Time: \(timestamp)
            
            Please check your power connection. The system will shut down when the UPS battery is depleted.
            
            This is an automated notification from Mac Stats.
            """
        }
        
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
                    print(" UPS power change notification sent successfully: \(response)")
                case .failure(let error):
                    print(" Failed to send UPS power change notification: \(error)")
                }
            }
        }
    }
    
    private func executeCommand(_ executablePath: String, _ arguments: [String]) -> String? {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: executablePath)
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            #if DEBUG
            if executablePath.contains("nettop") || executablePath.contains("lsof") {
                print(" Debug: Executing \(executablePath) with args: \(arguments)")
            }
            #endif
            
            let semaphore = DispatchSemaphore(value: 0)
            task.terminationHandler = { _ in semaphore.signal() }
            try task.run()

            if semaphore.wait(timeout: .now() + 10.0) == .timedOut {
                task.terminate()
                #if DEBUG
                print(" Command timeout: \(executablePath)")
                #endif
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            if task.terminationStatus != 0 {
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print(" Command failed: \(executablePath) (status: \(task.terminationStatus))")
                print(" Error output: \(errorOutput)")
                return nil
            }
            
            let result = String(data: data, encoding: .utf8)
            
            #if DEBUG
            if executablePath.contains("nettop") || executablePath.contains("lsof") {
                print(" Command succeeded: \(executablePath), output length: \(result?.count ?? 0)")
            }
            #endif
            
            return result
        } catch {
            print(" Error executing \(executablePath): \(error)")
            return nil
        }
    }
    
    // Run macmon and capture the first JSON line, then terminate.
    // - readabilityHandler fires fast when macmon writes its first sample (~500ms)
    // - terminationHandler fires immediately if macmon crashes, avoiding the full timeout wait
    private func runMacmonStreamingFirstLine(_ path: String, timeout: TimeInterval) -> String? {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["pipe", "-s", "1", "-i", "500"]
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        // Strip env vars injected by Xcode that can break native binaries
        var env = ProcessInfo.processInfo.environment
        for key in env.keys where key.hasPrefix("DYLD_") || key.hasPrefix("OBJC_") || key.hasPrefix("NSZombie") {
            env.removeValue(forKey: key)
        }
        task.environment = env

        let semaphore = DispatchSemaphore(value: 0)
        var capturedLine: String?
        var buffer = ""

        // Signal on output — fast path when macmon writes JSON
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            guard capturedLine == nil else { return }
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            buffer += chunk
            if let newlineRange = buffer.range(of: "\n") {
                let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                if !line.isEmpty {
                    capturedLine = line
                    semaphore.signal()
                }
            }
        }

        // Signal on termination — fast failure if macmon crashes without writing output
        task.terminationHandler = { proc in
            #if DEBUG
            if capturedLine == nil {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                print(" macmon exited (code \(proc.terminationStatus)) without output. stderr: \(stderr)")
            }
            #endif
            semaphore.signal()
        }

        do {
            try task.run()
        } catch {
            #if DEBUG
            print(" Error launching macmon: \(error)")
            #endif
            return nil
        }

        let waitResult = semaphore.wait(timeout: .now() + timeout)

        outputPipe.fileHandleForReading.readabilityHandler = nil
        if task.isRunning { task.terminate() }

        if waitResult == .timedOut {
            #if DEBUG
            print(" ⚠️ macmon timeout after \(timeout)s")
            #endif
            return nil
        }

        return capturedLine
    }
    
    deinit {
        stopMonitoring()
        stopExternalIPRefresh()
        timeMachineRefreshTask?.cancel()
        if let source = powerSourceNotifySource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }
}

// MARK: - Model-aware thermal thresholds

/// Per-model temperature and power warning thresholds.
/// Higher-end / desktop Macs run hotter and draw more power by design, so
/// a single fixed set of thresholds would produce false warnings on a Mac Pro
/// while under-warning on a fanless MacBook Air.
struct MacThermalProfile {
    let tempYellow: Double    // °C — caution
    let tempOrange: Double    // °C — hot
    let tempRed: Double       // °C — critical
    let powerYellow: Double   // W  — caution
    let powerOrange: Double   // W  — high
    let powerRed: Double      // W  — near limit

    func temperatureColor(_ celsius: Double) -> Color {
        switch celsius {
        case 0..<40:                   return .blue
        case 40..<tempYellow:          return .green
        case tempYellow..<tempOrange:  return .yellow
        case tempOrange..<tempRed:     return .orange
        case tempRed...:               return .red
        default:                       return .gray
        }
    }

    /// Menu-bar variant: uses `.white` instead of `.green` so text stays
    /// readable on the dark menu-bar background when everything is normal.
    func menuBarTemperatureColor(_ celsius: Double) -> Color {
        switch celsius {
        case 0..<tempYellow:           return .white
        case tempYellow..<tempOrange:  return .yellow
        case tempOrange..<tempRed:     return .orange
        case tempRed...:               return .red
        default:                       return .white
        }
    }

    func powerColor(_ watts: Double) -> Color {
        switch watts {
        case 0..<powerYellow:            return .green
        case powerYellow..<powerOrange:  return .yellow
        case powerOrange..<powerRed:     return .orange
        case powerRed...:                return .red
        default:                         return .gray
        }
    }

    /// Menu-bar variant: uses `.white` at low wattages.
    func menuBarPowerColor(_ watts: Double) -> Color {
        switch watts {
        case 0..<powerYellow:            return .white
        case powerYellow..<powerOrange:  return .yellow
        case powerOrange..<powerRed:     return .orange
        case powerRed...:                return .red
        default:                         return .white
        }
    }
}

extension SystemMonitor {
    /// Returns the thermal/power colour thresholds appropriate for this Mac model.
    var thermalProfile: MacThermalProfile {
        let model   = systemInfo.modelName.lowercased()
        let chip    = systemInfo.chipInfo.lowercased()
        let isUltra = chip.contains("ultra")
        let isMax   = chip.contains("max")

        if model.contains("macbook air") || model.hasPrefix("macbookair") {
            // Fanless — throttles earlier, low sustained power envelope
            return MacThermalProfile(tempYellow: 65, tempOrange: 78, tempRed: 88,
                                     powerYellow: 12, powerOrange: 22, powerRed: 32)

        } else if model.contains("macbook pro") || model.hasPrefix("macbookpro") {
            if isMax || isUltra {
                return MacThermalProfile(tempYellow: 75, tempOrange: 90, tempRed: 100,
                                         powerYellow: 50, powerOrange: 80, powerRed: 110)
            } else {
                return MacThermalProfile(tempYellow: 72, tempOrange: 87, tempRed: 97,
                                         powerYellow: 30, powerOrange: 55, powerRed: 80)
            }

        } else if model.contains("mac studio") || model.hasPrefix("macstudio") {
            if isUltra {
                return MacThermalProfile(tempYellow: 82, tempOrange: 97, tempRed: 107,
                                         powerYellow: 120, powerOrange: 190, powerRed: 260)
            } else {
                return MacThermalProfile(tempYellow: 78, tempOrange: 93, tempRed: 103,
                                         powerYellow: 80, powerOrange: 130, powerRed: 180)
            }

        } else if model.contains("mac pro") || model.hasPrefix("macpro") {
            // Mac Pro — designed for extreme sustained workloads
            return MacThermalProfile(tempYellow: 85, tempOrange: 100, tempRed: 110,
                                     powerYellow: 150, powerOrange: 250, powerRed: 350)

        } else if model.contains("mac mini") || model.hasPrefix("macmini") {
            return MacThermalProfile(tempYellow: 70, tempOrange: 85, tempRed: 95,
                                     powerYellow: 25, powerOrange: 45, powerRed: 65)

        } else if model.contains("imac") {
            return MacThermalProfile(tempYellow: 75, tempOrange: 90, tempRed: 100,
                                     powerYellow: 50, powerOrange: 80, powerRed: 110)

        } else {
            // Unknown model — conservative mid-range defaults
            return MacThermalProfile(tempYellow: 70, tempOrange: 85, tempRed: 95,
                                     powerYellow: 30, powerOrange: 60, powerRed: 100)
        }
    }
}
