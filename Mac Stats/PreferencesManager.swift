//
//  PreferencesManager.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Foundation
import ServiceManagement
import Combine

enum NetworkUnit: Int, CaseIterable {
    case bytes = 0
    case bits = 1
}

enum NetworkMonitoringMode: Int, CaseIterable {
    case interface = 0
    case process = 1
    
    var name: String {
        switch self {
        case .interface: return "Interface-based"
        case .process: return "Process-based"
        }
    }
    
    var description: String {
        switch self {
        case .interface: return "Monitor total traffic by network interface (en0, Wi-Fi, etc.)"
        case .process: return "Monitor network usage by application/process"
        }
    }
}

enum TemperatureUnit: Int, CaseIterable {
    case celsius = 0
    case fahrenheit = 1
    
    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    var name: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }
}

class PreferencesManager: ObservableObject {
    // MARK: - Keys for UserDefaults
    private enum Keys: String {
        case showCPU = "showCPU"
        case showCPUTemperature = "showCPUTemperature"
        case showMemory = "showMemory"
        case showDisk = "showDisk"
        case showNetwork = "showNetwork"
        case showPowerConsumption = "showPowerConsumption"
        case showMenuBarCPU = "showMenuBarCPU"
        case showMenuBarMemory = "showMenuBarMemory"
        case showMenuBarDisk = "showMenuBarDisk"
        case showMenuBarNetwork = "showMenuBarNetwork"
        case showMenuBarUptime = "showMenuBarUptime"
        case showMenuBarPower = "showMenuBarPower"
        case showMenuBarCPUTemp = "showMenuBarCPUTemp"
        case showMenuBarFanSpeed = "showMenuBarFanSpeed"
        case updateInterval = "updateInterval"
        case powerUpdateInterval = "powerUpdateInterval"
        case launchAtStartup = "launchAtStartup"
        case selectedNetworkInterface = "selectedNetworkInterface"
        case networkUnit = "networkUnit"
        case networkMonitoringMode = "networkMonitoringMode"
        case autoScaleNetwork = "autoScaleNetwork"
        case temperatureUnit = "temperatureUnit"
        case showBothTemperatureUnits = "showBothTemperatureUnits"
        case useTabbedView = "useTabbedView"
        // Mailjet settings
        case mailjetEmailEnabled = "mailjetEmailEnabled"
        case mailjetFromEmail = "mailjetFromEmail"
        case mailjetFromName = "mailjetFromName"
        case mailjetToEmail = "mailjetToEmail"
        // UPS and IP notification settings
        case upsPowerChangeNotificationEnabled = "upsPowerChangeNotificationEnabled"
        case ipChangeNotificationEnabled = "ipChangeNotificationEnabled"
        case ipChangeNotificationInterval = "ipChangeNotificationInterval"
        // Scheduled IP checking
        case scheduledIPCheckEnabled = "scheduledIPCheckEnabled"
        case scheduledIPCheckInterval = "scheduledIPCheckInterval"
    }
    
    // MARK: - Published Properties
    @Published var showCPU: Bool = true
    @Published var showCPUTemperature: Bool = true
    @Published var showMemory: Bool = true
    @Published var showDisk: Bool = true
    @Published var showNetwork: Bool = true
    @Published var showPowerConsumption: Bool = true
    @Published var showMenuBarCPU: Bool = true
    @Published var showMenuBarMemory: Bool = true
    @Published var showMenuBarDisk: Bool = false
    @Published var showMenuBarNetwork: Bool = false
    @Published var showMenuBarUptime: Bool = false
    @Published var showMenuBarPower: Bool = false
    @Published var showMenuBarCPUTemp: Bool = false
    @Published var showMenuBarFanSpeed: Bool = false
    @Published var updateInterval: TimeInterval = 3.0  // Increased from 2 to 3 seconds for menubar app
    @Published var powerUpdateInterval: TimeInterval = 60.0  // Increased from 30 to 60 seconds - reduces macmon calls
    @Published var launchAtStartup: Bool = false
    @Published var selectedNetworkInterface: String = "All"
    @Published var networkUnit: NetworkUnit = .bytes
    @Published var networkMonitoringMode: NetworkMonitoringMode = .interface
    @Published var autoScaleNetwork: Bool = true
    @Published var temperatureUnit: TemperatureUnit = .celsius
    @Published var showBothTemperatureUnits: Bool = false
    @Published var useTabbedView: Bool = false  // New preference for view style
    
    // Mailjet Email Notification Settings
    @Published var mailjetEmailEnabled: Bool = false
    @Published var mailjetAPIKey: String = ""
    @Published var mailjetAPISecret: String = ""
    @Published var mailjetFromEmail: String = ""
    @Published var mailjetFromName: String = ""
    @Published var mailjetToEmail: String = ""
    
    // UPS Power Change Notification Settings
    @Published var upsPowerChangeNotificationEnabled: Bool = true
    
    // IP Change Notification Settings
    @Published var ipChangeNotificationEnabled: Bool = false
    @Published var ipChangeNotificationInterval: Double = 300.0  // 5 minutes default
    
    // Scheduled IP Check Settings
    @Published var scheduledIPCheckEnabled: Bool = false
    @Published var scheduledIPCheckInterval: Double = 1800.0  // 30 minutes default
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private weak var systemMonitor: SystemMonitor?
    
    func setSystemMonitor(_ monitor: SystemMonitor) {
        self.systemMonitor = monitor
    }
    
    init() {
        loadUserDefaults()
        
        // Retrieve credentials from Keychain
        mailjetAPIKey = KeychainHelper.load(key: "mailjetAPIKey") ?? ""
        mailjetAPISecret = KeychainHelper.load(key: "mailjetAPISecret") ?? ""
        
        // Setup observers for automatic saving
        setupChangeObservers()
    }
    
    private func updateLaunchAtStartupSetting() {
        if #available(macOS 13.0, *) {
            if launchAtStartup {
                do {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } catch {
                    print("Failed to register for launch at startup: \(error)")
                }
            } else {
                do {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to unregister for launch at startup: \(error)")
                }
            }
        }
    }
    
    func savePreferences() {
        saveUserDefaults()
    }
    
    private func saveUserDefaults() {
        UserDefaults.standard.set(showCPU, forKey: Keys.showCPU.rawValue)
        UserDefaults.standard.set(showCPUTemperature, forKey: Keys.showCPUTemperature.rawValue)
        UserDefaults.standard.set(showMemory, forKey: Keys.showMemory.rawValue)
        UserDefaults.standard.set(showDisk, forKey: Keys.showDisk.rawValue)
        UserDefaults.standard.set(showNetwork, forKey: Keys.showNetwork.rawValue)
        UserDefaults.standard.set(showPowerConsumption, forKey: Keys.showPowerConsumption.rawValue)
        UserDefaults.standard.set(showMenuBarCPU, forKey: Keys.showMenuBarCPU.rawValue)
        UserDefaults.standard.set(showMenuBarMemory, forKey: Keys.showMenuBarMemory.rawValue)
        UserDefaults.standard.set(showMenuBarDisk, forKey: Keys.showMenuBarDisk.rawValue)
        UserDefaults.standard.set(showMenuBarNetwork, forKey: Keys.showMenuBarNetwork.rawValue)
        UserDefaults.standard.set(showMenuBarUptime, forKey: Keys.showMenuBarUptime.rawValue)
        UserDefaults.standard.set(showMenuBarPower, forKey: Keys.showMenuBarPower.rawValue)
        UserDefaults.standard.set(showMenuBarCPUTemp, forKey: Keys.showMenuBarCPUTemp.rawValue)
        UserDefaults.standard.set(showMenuBarFanSpeed, forKey: Keys.showMenuBarFanSpeed.rawValue)
        UserDefaults.standard.set(updateInterval, forKey: Keys.updateInterval.rawValue)
        UserDefaults.standard.set(powerUpdateInterval, forKey: Keys.powerUpdateInterval.rawValue)
        UserDefaults.standard.set(launchAtStartup, forKey: Keys.launchAtStartup.rawValue)
        UserDefaults.standard.set(selectedNetworkInterface, forKey: Keys.selectedNetworkInterface.rawValue)
        UserDefaults.standard.set(networkUnit.rawValue, forKey: Keys.networkUnit.rawValue)
        UserDefaults.standard.set(networkMonitoringMode.rawValue, forKey: Keys.networkMonitoringMode.rawValue)
        UserDefaults.standard.set(autoScaleNetwork, forKey: Keys.autoScaleNetwork.rawValue)
        UserDefaults.standard.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit.rawValue)
        UserDefaults.standard.set(showBothTemperatureUnits, forKey: Keys.showBothTemperatureUnits.rawValue)
        UserDefaults.standard.set(useTabbedView, forKey: Keys.useTabbedView.rawValue)
        
        // Mailjet email notification settings
        UserDefaults.standard.set(mailjetEmailEnabled, forKey: Keys.mailjetEmailEnabled.rawValue)
        UserDefaults.standard.set(mailjetFromEmail, forKey: Keys.mailjetFromEmail.rawValue)
        UserDefaults.standard.set(mailjetFromName, forKey: Keys.mailjetFromName.rawValue)
        UserDefaults.standard.set(mailjetToEmail, forKey: Keys.mailjetToEmail.rawValue)
        
        // UPS and IP notification settings
        UserDefaults.standard.set(upsPowerChangeNotificationEnabled, forKey: Keys.upsPowerChangeNotificationEnabled.rawValue)
        UserDefaults.standard.set(ipChangeNotificationEnabled, forKey: Keys.ipChangeNotificationEnabled.rawValue)
        UserDefaults.standard.set(ipChangeNotificationInterval, forKey: Keys.ipChangeNotificationInterval.rawValue)
        
        // Scheduled IP check settings
        UserDefaults.standard.set(scheduledIPCheckEnabled, forKey: Keys.scheduledIPCheckEnabled.rawValue)
        UserDefaults.standard.set(scheduledIPCheckInterval, forKey: Keys.scheduledIPCheckInterval.rawValue)
        
        updateLaunchAtStartupSetting()
        
        // Store credentials in Keychain
        if !mailjetAPIKey.isEmpty {
            KeychainHelper.save(key: "mailjetAPIKey", value: mailjetAPIKey)
        }
        
        if !mailjetAPISecret.isEmpty {
            KeychainHelper.save(key: "mailjetAPISecret", value: mailjetAPISecret)
        }
    }
    
    private func loadUserDefaults() {
        showCPU = UserDefaults.standard.object(forKey: Keys.showCPU.rawValue) as? Bool ?? true
        showCPUTemperature = UserDefaults.standard.object(forKey: Keys.showCPUTemperature.rawValue) as? Bool ?? true
        showMemory = UserDefaults.standard.object(forKey: Keys.showMemory.rawValue) as? Bool ?? true
        showDisk = UserDefaults.standard.object(forKey: Keys.showDisk.rawValue) as? Bool ?? true
        showNetwork = UserDefaults.standard.object(forKey: Keys.showNetwork.rawValue) as? Bool ?? true
        showPowerConsumption = UserDefaults.standard.object(forKey: Keys.showPowerConsumption.rawValue) as? Bool ?? true
        showMenuBarCPU = UserDefaults.standard.object(forKey: Keys.showMenuBarCPU.rawValue) as? Bool ?? true
        showMenuBarMemory = UserDefaults.standard.object(forKey: Keys.showMenuBarMemory.rawValue) as? Bool ?? true
        showMenuBarDisk = UserDefaults.standard.object(forKey: Keys.showMenuBarDisk.rawValue) as? Bool ?? false
        showMenuBarNetwork = UserDefaults.standard.object(forKey: Keys.showMenuBarNetwork.rawValue) as? Bool ?? false
        showMenuBarUptime = UserDefaults.standard.object(forKey: Keys.showMenuBarUptime.rawValue) as? Bool ?? false
        showMenuBarPower = UserDefaults.standard.object(forKey: Keys.showMenuBarPower.rawValue) as? Bool ?? false
        showMenuBarCPUTemp = UserDefaults.standard.object(forKey: Keys.showMenuBarCPUTemp.rawValue) as? Bool ?? false
        showMenuBarFanSpeed = UserDefaults.standard.object(forKey: Keys.showMenuBarFanSpeed.rawValue) as? Bool ?? false
        updateInterval = UserDefaults.standard.double(forKey: Keys.updateInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.updateInterval.rawValue) : 3.0  // Default 3 seconds
        powerUpdateInterval = UserDefaults.standard.double(forKey: Keys.powerUpdateInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.powerUpdateInterval.rawValue) : 60.0  // Default 60 seconds
        launchAtStartup = UserDefaults.standard.bool(forKey: Keys.launchAtStartup.rawValue)
        selectedNetworkInterface = UserDefaults.standard.string(forKey: Keys.selectedNetworkInterface.rawValue) ?? "All"
        networkUnit = NetworkUnit(rawValue: UserDefaults.standard.integer(forKey: Keys.networkUnit.rawValue)) ?? .bytes
        networkMonitoringMode = NetworkMonitoringMode(rawValue: UserDefaults.standard.integer(forKey: Keys.networkMonitoringMode.rawValue)) ?? .interface
        autoScaleNetwork = UserDefaults.standard.object(forKey: Keys.autoScaleNetwork.rawValue) as? Bool ?? true
        temperatureUnit = TemperatureUnit(rawValue: UserDefaults.standard.integer(forKey: Keys.temperatureUnit.rawValue)) ?? .celsius
        showBothTemperatureUnits = UserDefaults.standard.bool(forKey: Keys.showBothTemperatureUnits.rawValue)
        useTabbedView = UserDefaults.standard.bool(forKey: Keys.useTabbedView.rawValue)
        
        // Mailjet email notification settings
        mailjetEmailEnabled = UserDefaults.standard.bool(forKey: Keys.mailjetEmailEnabled.rawValue)
        mailjetFromEmail = UserDefaults.standard.string(forKey: Keys.mailjetFromEmail.rawValue) ?? ""
        mailjetFromName = UserDefaults.standard.string(forKey: Keys.mailjetFromName.rawValue) ?? ""
        mailjetToEmail = UserDefaults.standard.string(forKey: Keys.mailjetToEmail.rawValue) ?? ""
        
        // UPS and IP notification settings
        upsPowerChangeNotificationEnabled = UserDefaults.standard.object(forKey: Keys.upsPowerChangeNotificationEnabled.rawValue) as? Bool ?? true
        ipChangeNotificationEnabled = UserDefaults.standard.bool(forKey: Keys.ipChangeNotificationEnabled.rawValue)
        ipChangeNotificationInterval = UserDefaults.standard.double(forKey: Keys.ipChangeNotificationInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.ipChangeNotificationInterval.rawValue) : 300.0
        
        // Scheduled IP check settings
        scheduledIPCheckEnabled = UserDefaults.standard.bool(forKey: Keys.scheduledIPCheckEnabled.rawValue)
        scheduledIPCheckInterval = UserDefaults.standard.double(forKey: Keys.scheduledIPCheckInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.scheduledIPCheckInterval.rawValue) : 1800.0
    }
    
    private func setupChangeObservers() {
        // Debounce all changes to reduce the frequency of saves
        // This prevents excessive UserDefaults writes when rapidly changing settings
        
        // Group 1: Display preferences
        let displayPublishers = Publishers.MergeMany([
            $showCPU.map { _ in () }.eraseToAnyPublisher(),
            $showCPUTemperature.map { _ in () }.eraseToAnyPublisher(),
            $showMemory.map { _ in () }.eraseToAnyPublisher(),
            $showDisk.map { _ in () }.eraseToAnyPublisher(),
            $showNetwork.map { _ in () }.eraseToAnyPublisher(),
            $showPowerConsumption.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 2: Menu bar preferences
        let menuBarPublishers = Publishers.MergeMany([
            $showMenuBarCPU.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarMemory.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarDisk.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarNetwork.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarUptime.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarPower.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarCPUTemp.map { _ in () }.eraseToAnyPublisher(),
            $showMenuBarFanSpeed.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 3: Update intervals and startup
        let systemPublishers = Publishers.MergeMany([
            $updateInterval.map { _ in () }.eraseToAnyPublisher(),
            $powerUpdateInterval.map { _ in () }.eraseToAnyPublisher(),
            $launchAtStartup.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 4: Network preferences
        let networkPublishers = Publishers.MergeMany([
            $selectedNetworkInterface.map { _ in () }.eraseToAnyPublisher(),
            $networkUnit.map { _ in () }.eraseToAnyPublisher(),
            $networkMonitoringMode.map { _ in () }.eraseToAnyPublisher(),
            $autoScaleNetwork.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 5: Temperature and UI preferences
        let uiPublishers = Publishers.MergeMany([
            $temperatureUnit.map { _ in () }.eraseToAnyPublisher(),
            $showBothTemperatureUnits.map { _ in () }.eraseToAnyPublisher(),
            $useTabbedView.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 6: Email notification settings
        let emailPublishers = Publishers.MergeMany([
            $mailjetEmailEnabled.map { _ in () }.eraseToAnyPublisher(),
            $mailjetAPIKey.map { _ in () }.eraseToAnyPublisher(),
            $mailjetAPISecret.map { _ in () }.eraseToAnyPublisher(),
            $mailjetFromEmail.map { _ in () }.eraseToAnyPublisher(),
            $mailjetFromName.map { _ in () }.eraseToAnyPublisher(),
            $mailjetToEmail.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Group 7: Notification preferences
        let notificationPublishers = Publishers.MergeMany([
            $upsPowerChangeNotificationEnabled.map { _ in () }.eraseToAnyPublisher(),
            $ipChangeNotificationEnabled.map { _ in () }.eraseToAnyPublisher(),
            $ipChangeNotificationInterval.map { _ in () }.eraseToAnyPublisher(),
            $scheduledIPCheckEnabled.map { _ in () }.eraseToAnyPublisher(),
            $scheduledIPCheckInterval.map { _ in () }.eraseToAnyPublisher()
        ])
        
        // Combine all groups
        Publishers.MergeMany([
            displayPublishers.eraseToAnyPublisher(),
            menuBarPublishers.eraseToAnyPublisher(),
            systemPublishers.eraseToAnyPublisher(),
            networkPublishers.eraseToAnyPublisher(),
            uiPublishers.eraseToAnyPublisher(),
            emailPublishers.eraseToAnyPublisher(),
            notificationPublishers.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
        .sink { [weak self] (_: Void) -> Void in
            self?.saveUserDefaults()
        }
        .store(in: &cancellables)
        
        // Separate observers for update intervals that need to update SystemMonitor
        $updateInterval
            .dropFirst() // Ignore initial value
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.systemMonitor?.updateMonitoringInterval(newValue)
            }
            .store(in: &cancellables)
        
        $powerUpdateInterval
            .dropFirst() // Ignore initial value
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.systemMonitor?.updatePowerMonitoringInterval(newValue)
            }
            .store(in: &cancellables)
    }
}