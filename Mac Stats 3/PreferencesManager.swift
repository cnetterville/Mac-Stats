//
//  PreferencesManager.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Foundation
import ServiceManagement

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
    // Main toggle for each stat
    @Published var showCPU: Bool = true {
        didSet {
            UserDefaults.standard.set(showCPU, forKey: "showCPU")
        }
    }
    
    @Published var showCPUTemperature: Bool = true {
        didSet {
            UserDefaults.standard.set(showCPUTemperature, forKey: "showCPUTemperature")
        }
    }
    
    @Published var temperatureUnit: TemperatureUnit = .celsius {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "temperatureUnit")
        }
    }
    
    @Published var showBothTemperatureUnits: Bool = false {
        didSet {
            UserDefaults.standard.set(showBothTemperatureUnits, forKey: "showBothTemperatureUnits")
        }
    }

    @Published var showMemory: Bool = true {
        didSet {
            UserDefaults.standard.set(showMemory, forKey: "showMemory")
        }
    }
    
    @Published var showDisk: Bool = true {
        didSet {
            UserDefaults.standard.set(showDisk, forKey: "showDisk")
        }
    }
    
    @Published var showNetwork: Bool = true {
        didSet {
            UserDefaults.standard.set(showNetwork, forKey: "showNetwork")
        }
    }
    
    @Published var showPowerConsumption: Bool = UserDefaults.standard.object(forKey: "showPowerConsumption") as? Bool ?? true
    
    // Toggle for showing in menu bar icon
    @Published var showMenuBarCPU: Bool = true {
        didSet {
            UserDefaults.standard.set(showMenuBarCPU, forKey: "showMenuBarCPU")
        }
    }
    
    @Published var showMenuBarMemory: Bool = true {
        didSet {
            UserDefaults.standard.set(showMenuBarMemory, forKey: "showMenuBarMemory")
        }
    }
    
    @Published var showMenuBarDisk: Bool = true {
        didSet {
            UserDefaults.standard.set(showMenuBarDisk, forKey: "showMenuBarDisk")
        }
    }
    
    @Published var showMenuBarNetwork: Bool = true {
        didSet {
            UserDefaults.standard.set(showMenuBarNetwork, forKey: "showMenuBarNetwork")
        }
    }
    
    @Published var showMenuBarUptime: Bool = false {
        didSet {
            UserDefaults.standard.set(showMenuBarUptime, forKey: "showMenuBarUptime")
        }
    }
    
    // Network interface settings
    @Published var selectedNetworkInterface: String = "All" {
        didSet {
            UserDefaults.standard.set(selectedNetworkInterface, forKey: "selectedNetworkInterface")
        }
    }
    
    // Network unit settings
    @Published var networkUnit: NetworkUnit = .bytes {
        didSet {
            UserDefaults.standard.set(networkUnit.rawValue, forKey: "networkUnit")
        }
    }
    
    @Published var autoScaleNetwork: Bool = true {
        didSet {
            UserDefaults.standard.set(autoScaleNetwork, forKey: "autoScaleNetwork")
        }
    }
    
    // Update interval
    @Published var updateInterval: Double = 2.0 {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        }
    }
    
    // Power consumption update interval (for macmon polling)
    @Published var powerUpdateInterval: Double = 30.0 {
        didSet {
            UserDefaults.standard.set(powerUpdateInterval, forKey: "powerUpdateInterval")
        }
    }
    
    // Launch at startup
    @Published var launchAtStartup: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtStartup, forKey: "launchAtStartup")
            updateLaunchAtStartupSetting()
        }
    }
    
    // Mailjet Email Notification Settings
    @Published var mailjetEmailEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(mailjetEmailEnabled, forKey: "mailjetEmailEnabled")
        }
    }
    
    @Published var mailjetAPIKey: String = "" {
        didSet {
            // Store API key in Keychain for better security
            KeychainHelper.save(key: "mailjetAPIKey", value: mailjetAPIKey)
        }
    }
    
    @Published var mailjetAPISecret: String = "" {
        didSet {
            // Store API secret in Keychain for better security
            KeychainHelper.save(key: "mailjetAPISecret", value: mailjetAPISecret)
        }
    }
    
    @Published var mailjetFromEmail: String = "" {
        didSet {
            UserDefaults.standard.set(mailjetFromEmail, forKey: "mailjetFromEmail")
        }
    }
    
    @Published var mailjetFromName: String = "" {
        didSet {
            UserDefaults.standard.set(mailjetFromName, forKey: "mailjetFromName")
        }
    }
    
    @Published var mailjetToEmail: String = "" {
        didSet {
            UserDefaults.standard.set(mailjetToEmail, forKey: "mailjetToEmail")
        }
    }
    
    // UPS Power Change Notification Settings
    @Published var upsPowerChangeNotificationEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(upsPowerChangeNotificationEnabled, forKey: "upsPowerChangeNotificationEnabled")
        }
    }
    
    // IP Change Notification Settings
    @Published var ipChangeNotificationEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(ipChangeNotificationEnabled, forKey: "ipChangeNotificationEnabled")
        }
    }
    
    @Published var ipChangeNotificationInterval: Double = 300.0 { // 5 minutes default
        didSet {
            UserDefaults.standard.set(ipChangeNotificationInterval, forKey: "ipChangeNotificationInterval")
        }
    }
    
    init() {
        showCPU = UserDefaults.standard.object(forKey: "showCPU") as? Bool ?? true
        showCPUTemperature = UserDefaults.standard.object(forKey: "showCPUTemperature") as? Bool ?? true
        
        let temperatureUnitRaw = UserDefaults.standard.object(forKey: "temperatureUnit") as? Int ?? 0
        temperatureUnit = TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius
        showBothTemperatureUnits = UserDefaults.standard.object(forKey: "showBothTemperatureUnits") as? Bool ?? false
        
        showMemory = UserDefaults.standard.object(forKey: "showMemory") as? Bool ?? true
        showDisk = UserDefaults.standard.object(forKey: "showDisk") as? Bool ?? true
        showNetwork = UserDefaults.standard.object(forKey: "showNetwork") as? Bool ?? true
        
        showMenuBarCPU = UserDefaults.standard.object(forKey: "showMenuBarCPU") as? Bool ?? true
        showMenuBarMemory = UserDefaults.standard.object(forKey: "showMenuBarMemory") as? Bool ?? true
        showMenuBarDisk = UserDefaults.standard.object(forKey: "showMenuBarDisk") as? Bool ?? true
        showMenuBarNetwork = UserDefaults.standard.object(forKey: "showMenuBarNetwork") as? Bool ?? true
        
        selectedNetworkInterface = UserDefaults.standard.object(forKey: "selectedNetworkInterface") as? String ?? "All"
        
        let networkUnitRaw = UserDefaults.standard.object(forKey: "networkUnit") as? Int ?? 0
        networkUnit = NetworkUnit(rawValue: networkUnitRaw) ?? .bytes
        
        autoScaleNetwork = UserDefaults.standard.object(forKey: "autoScaleNetwork") as? Bool ?? true
        updateInterval = UserDefaults.standard.object(forKey: "updateInterval") as? Double ?? 2.0
        powerUpdateInterval = UserDefaults.standard.object(forKey: "powerUpdateInterval") as? Double ?? 30.0
        launchAtStartup = UserDefaults.standard.object(forKey: "launchAtStartup") as? Bool ?? false
        
        // Mailjet Email Notification Settings
        mailjetEmailEnabled = UserDefaults.standard.object(forKey: "mailjetEmailEnabled") as? Bool ?? false
        mailjetFromEmail = UserDefaults.standard.object(forKey: "mailjetFromEmail") as? String ?? ""
        mailjetToEmail = UserDefaults.standard.object(forKey: "mailjetToEmail") as? String ?? ""
        mailjetFromName = UserDefaults.standard.object(forKey: "mailjetFromName") as? String ?? ""
        
        // UPS Power Change Notification Settings
        upsPowerChangeNotificationEnabled = UserDefaults.standard.object(forKey: "upsPowerChangeNotificationEnabled") as? Bool ?? true
        
        // IP Change Notification Settings
        ipChangeNotificationEnabled = UserDefaults.standard.object(forKey: "ipChangeNotificationEnabled") as? Bool ?? false
        ipChangeNotificationInterval = UserDefaults.standard.object(forKey: "ipChangeNotificationInterval") as? Double ?? 300.0
        
        // Retrieve credentials from Keychain
        mailjetAPIKey = KeychainHelper.load(key: "mailjetAPIKey") ?? ""
        mailjetAPISecret = KeychainHelper.load(key: "mailjetAPISecret") ?? ""
        
        showMenuBarUptime = UserDefaults.standard.object(forKey: "showMenuBarUptime") as? Bool ?? false
    }
    
    private func updateLaunchAtStartupSetting() {
        if #available(macOS 13.0, *) {
            if launchAtStartup {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    print("Failed to register for launch at startup: \(error)")
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    print("Failed to unregister for launch at startup: \(error)")
                }
            }
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(showPowerConsumption, forKey: "showPowerConsumption")
    }
}