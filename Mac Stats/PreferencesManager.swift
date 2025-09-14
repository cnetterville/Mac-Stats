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
        case updateInterval = "updateInterval"
        case powerUpdateInterval = "powerUpdateInterval"
        case launchAtStartup = "launchAtStartup"
        case selectedNetworkInterface = "selectedNetworkInterface"
        case networkUnit = "networkUnit"
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
    @Published var updateInterval: TimeInterval = 2.0
    @Published var powerUpdateInterval: TimeInterval = 30.0
    @Published var launchAtStartup: Bool = false
    @Published var selectedNetworkInterface: String = "All"
    @Published var networkUnit: NetworkUnit = .bytes
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
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
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
        UserDefaults.standard.set(updateInterval, forKey: Keys.updateInterval.rawValue)
        UserDefaults.standard.set(powerUpdateInterval, forKey: Keys.powerUpdateInterval.rawValue)
        UserDefaults.standard.set(launchAtStartup, forKey: Keys.launchAtStartup.rawValue)
        UserDefaults.standard.set(selectedNetworkInterface, forKey: Keys.selectedNetworkInterface.rawValue)
        UserDefaults.standard.set(networkUnit.rawValue, forKey: Keys.networkUnit.rawValue)
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
        updateInterval = UserDefaults.standard.double(forKey: Keys.updateInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.updateInterval.rawValue) : 2.0
        powerUpdateInterval = UserDefaults.standard.double(forKey: Keys.powerUpdateInterval.rawValue) != 0 ? UserDefaults.standard.double(forKey: Keys.powerUpdateInterval.rawValue) : 30.0
        launchAtStartup = UserDefaults.standard.bool(forKey: Keys.launchAtStartup.rawValue)
        selectedNetworkInterface = UserDefaults.standard.string(forKey: Keys.selectedNetworkInterface.rawValue) ?? "All"
        networkUnit = NetworkUnit(rawValue: UserDefaults.standard.integer(forKey: Keys.networkUnit.rawValue)) ?? .bytes
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
    }
    
    private func setupChangeObservers() {
        // Add observers for automatic saving when values change
        $showCPU.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showCPUTemperature.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMemory.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showDisk.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showNetwork.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showPowerConsumption.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMenuBarCPU.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMenuBarMemory.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMenuBarDisk.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMenuBarNetwork.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showMenuBarUptime.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $updateInterval.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $powerUpdateInterval.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $launchAtStartup.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $selectedNetworkInterface.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $networkUnit.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $autoScaleNetwork.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $temperatureUnit.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $showBothTemperatureUnits.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $useTabbedView.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        
        // Email notification settings
        $mailjetEmailEnabled.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $mailjetAPIKey.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $mailjetAPISecret.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $mailjetFromEmail.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $mailjetFromName.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $mailjetToEmail.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        
        // UPS and IP notification settings
        $upsPowerChangeNotificationEnabled.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $ipChangeNotificationEnabled.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
        $ipChangeNotificationInterval.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
    }
}