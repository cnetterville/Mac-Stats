//
//  SettingsView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var externalIPManager: ExternalIPManager
    
    @State private var isTestingEmail = false
    @State private var testResultMessage = ""
    @State private var testResultColor: Color = .primary
    @State private var selectedTab: SettingsTab = .general
    
    // Enum to track tabs
    enum SettingsTab: Int, Hashable {
        case general = 0
        case network = 1
        case notifications = 2
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Form {
                Section("Main Window Style") {
                    Picker("Layout", selection: $preferences.useTabbedView) {
                        Text("Cards").tag(false)
                        Text("Tabbed").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Temperature Unit") {
                    Picker("Temperature Unit", selection: $preferences.temperatureUnit) {
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                    }
                    .pickerStyle(.segmented)
                    .animation(nil, value: preferences.temperatureUnit)
                }
                
                
                Section("Menu Bar Icon") {
                    Toggle("Show CPU in Menu Bar", isOn: $preferences.showMenuBarCPU)
                    if preferences.showMenuBarCPU {
                        Toggle("  Show CPU Chart", isOn: $preferences.showMenuBarCPUChart)
                    }
                    Toggle("Show Memory in Menu Bar", isOn: $preferences.showMenuBarMemory)
                    if preferences.showMenuBarMemory {
                        Toggle("  Show Memory Chart", isOn: $preferences.showMenuBarMemChart)
                    }
                    Toggle("Show Disk in Menu Bar", isOn: $preferences.showMenuBarDisk)
                    Toggle("Show Network in Menu Bar", isOn: $preferences.showMenuBarNetwork)
                    Toggle("Show Uptime in Menu Bar", isOn: $preferences.showMenuBarUptime)
                    Toggle("Show Power in Menu Bar", isOn: $preferences.showMenuBarPower)
                    if preferences.showMenuBarPower {
                        Toggle("  Show Power Chart", isOn: $preferences.showMenuBarPowerChart)
                    }
                    Toggle("Show CPU Temp in Menu Bar", isOn: $preferences.showMenuBarCPUTemp)
                    if preferences.showMenuBarCPUTemp {
                        Toggle("  Show Temp Chart", isOn: $preferences.showMenuBarTempChart)
                    }
                    Toggle("Show Fan Speed in Menu Bar", isOn: $preferences.showMenuBarFanSpeed)
                    if preferences.showMenuBarFanSpeed {
                        Toggle("  Show Fan Chart", isOn: $preferences.showMenuBarFanChart)
                    }
                    Toggle("Show Battery / Power in Menu Bar", isOn: $preferences.showMenuBarBattery)
                }
                
                Section("Menu Bar Order") {
                    Text("Drag rows to reorder stats in the menu bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    List {
                        ForEach(preferences.menuBarStatOrder) { stat in
                            HStack(spacing: 10) {
                                Image(systemName: stat.icon)
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text(stat.label)
                            }
                        }
                        .onMove { from, to in
                            preferences.menuBarStatOrder.move(fromOffsets: from, toOffset: to)
                        }
                    }
                    .frame(height: 220)
                }

                Section("Update Interval") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("General Stats Refresh")
                            .font(.headline)
                        
                        Slider(value: $preferences.updateInterval, in: 1...10, step: 0.5) {
                            Text("Update Interval")
                        } minimumValueLabel: {
                            Text("1s")
                        } maximumValueLabel: {
                            Text("10s")
                        }
                        
                        Text("Refresh every \(String(format: "%.1f", preferences.updateInterval)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Power Consumption Refresh")
                            .font(.headline)
                        
                        Slider(value: $preferences.powerUpdateInterval, in: 5...300, step: 5) {
                            Text("Power Update Interval")
                        } minimumValueLabel: {
                            Text("5s")
                        } maximumValueLabel: {
                            Text("300s")
                        }
                        
                        Text("Refresh macmon power data every \(Int(preferences.powerUpdateInterval)) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Startup") {
                    Toggle("Launch at Startup", isOn: $preferences.launchAtStartup)
                }
                
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(SettingsTab.general)
            
            NetworkSettingsView()
                .tabItem {
                    Label("Network", systemImage: "network")
                }
                .tag(SettingsTab.network)
            
            NotificationSettingsView(
                isTestingEmail: $isTestingEmail,
                testResultMessage: $testResultMessage,
                testResultColor: $testResultColor
            )
            .tabItem {
                Label("Notifications", systemImage: "bell")
            }
            .tag(SettingsTab.notifications)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct NetworkSettingsView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Environment(SystemMonitor.self) private var systemMonitor
    
    // Use local state instead of directly observing ExternalIPManager to avoid cycles
    @State private var currentIP: String = ""
    @State private var lastUpdated: Date?
    @State private var isRefreshing: Bool = false
    
    // Cache network interfaces to avoid repeated access to systemMonitor
    @State private var cachedNetworkInterfaces: [String] = []
    
    var body: some View {
        Form {
            Section("Monitoring Mode") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Network Monitoring")
                        .font(.headline)
                    
                    Picker("Network Monitoring", selection: $preferences.networkMonitoringMode) {
                        Text("Interface-based").tag(NetworkMonitoringMode.interface)
                        Text("Process-based").tag(NetworkMonitoringMode.process)
                    }
                    .pickerStyle(.segmented)
                    .animation(nil, value: preferences.networkMonitoringMode)
                    
                    Text(preferences.networkMonitoringMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if preferences.networkMonitoringMode == .process {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("Process monitoring may require elevated permissions for detailed data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            
            if preferences.networkMonitoringMode == .interface {
                Section("Network Interface") {
                    Picker("Interface", selection: $preferences.selectedNetworkInterface) {
                        Text("All Interfaces").tag("All")
                        ForEach(cachedNetworkInterfaces, id: \.self) { interface in
                            Text(interface).tag(interface)
                        }
                    }
                    .pickerStyle(.menu)
                    .animation(nil, value: preferences.selectedNetworkInterface)
                    
                    Button("Refresh Interfaces") {
                        refreshNetworkInterfaces()
                    }
                }
            }
            
            Section("Display Units") {
                Picker("Network Units", selection: $preferences.networkUnit) {
                    Text("Bytes").tag(NetworkUnit.bytes)
                    Text("Bits").tag(NetworkUnit.bits)
                }
                .pickerStyle(.segmented)
                .animation(nil, value: preferences.networkUnit)
                
                Toggle("Auto Scale Units", isOn: $preferences.autoScaleNetwork)
            }
            
            Section("Notification Settings") {
                Toggle("Enable IP Change Notifications", isOn: $preferences.ipChangeNotificationEnabled)
                
                if preferences.ipChangeNotificationEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notification Throttle")
                            Spacer()
                            Text(formatNotificationInterval(preferences.ipChangeNotificationInterval))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $preferences.ipChangeNotificationInterval, in: 60...3600, step: 60) {
                            Text("Notification Interval")
                        } minimumValueLabel: {
                            Text("1m")
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text("60m")
                                .font(.caption2)
                        }
                        .disabled(!preferences.ipChangeNotificationEnabled)
                        
                        Text("Minimum time between notifications to prevent spam")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Scheduled IP Checking") {
                Toggle("Enable Scheduled IP Checks", isOn: $preferences.scheduledIPCheckEnabled)
                
                if preferences.scheduledIPCheckEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Check Every")
                            Spacer()
                            Text(formatTimeInterval(preferences.scheduledIPCheckInterval))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $preferences.scheduledIPCheckInterval, in: 300...7200, step: 300) {
                            Text("Check Interval")
                        } minimumValueLabel: {
                            Text("5m")
                                .font(.caption2)
                        } maximumValueLabel: {
                            Text("2h")
                                .font(.caption2)
                        }
                        
                        Text("Automatically checks for IP changes at the specified interval")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if preferences.scheduledIPCheckEnabled && !preferences.ipChangeNotificationEnabled {
                    Text("⚠️ Enable IP Change Notifications above to receive alerts when changes are detected")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                }
            }
            
            Section("Manual IP Refresh") {
                HStack {
                    Button("Refresh IP Now") {
                        refreshIPManually()
                    }
                    .disabled(isRefreshing)
                    
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 20, height: 20)
                    }
                }
                
                if !currentIP.isEmpty {
                    HStack {
                        Text("Current IP:")
                        Spacer()
                        Text(currentIP)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                if let lastUpdated = lastUpdated {
                    HStack {
                        Text("Last Updated:")
                        Spacer()
                        Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            updateLocalState()
            updateCachedNetworkInterfaces()
        }
    }
    
    private func updateCachedNetworkInterfaces() {
        // Update cached interfaces from systemMonitor
        cachedNetworkInterfaces = systemMonitor.networkInterfaces
    }
    
    private func refreshNetworkInterfaces() {
        systemMonitor.refreshNetworkInterfaces()
        // Small delay to ensure systemMonitor has updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updateCachedNetworkInterfaces()
        }
    }
    
    private func updateLocalState() {
        let manager = ExternalIPManager.shared
        currentIP = manager.externalIP
        lastUpdated = manager.lastUpdated
        isRefreshing = manager.isLoading
    }
    
    private func refreshIPManually() {
        isRefreshing = true
        
        ExternalIPManager.shared.refreshExternalIP()
        
        // Update state after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateLocalState()
        }
        
        // Stop loading indicator after reasonable timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            isRefreshing = false
            updateLocalState()
        }
    }
    
    private func formatTimeInterval(_ interval: Double) -> String {
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatNotificationInterval(_ interval: Double) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        
        if minutes > 0 {
            if seconds > 0 {
                return "\(minutes)m \(seconds)s"
            } else {
                return "\(minutes)m"
            }
        } else {
            return "\(seconds)s"
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject var preferences: PreferencesManager
    @Binding var isTestingEmail: Bool
    @Binding var testResultMessage: String
    @Binding var testResultColor: Color
    
    var body: some View {
        Form {
            Section(header: Text("Mailjet Email Notifications")) {
                Toggle("Enable Email Notifications", isOn: $preferences.mailjetEmailEnabled)
                
                if preferences.mailjetEmailEnabled {
                    TextField("Mailjet API Key", text: $preferences.mailjetAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .disableAutocorrection(true)
                    
                    SecureField("Mailjet API Secret", text: $preferences.mailjetAPISecret)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    
                    TextField("From Email Address", text: $preferences.mailjetFromEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    TextField("From Display Name", text: $preferences.mailjetFromName)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                    
                    TextField("To Email Address", text: $preferences.mailjetToEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .disableAutocorrection(true)
                    
                    HStack {
                        Button("Send Test Email") {
                            sendTestEmail()
                        }
                        .disabled(isTestingEmail || 
                                 preferences.mailjetAPIKey.isEmpty || 
                                 preferences.mailjetAPISecret.isEmpty || 
                                 preferences.mailjetFromEmail.isEmpty)
                        
                        if isTestingEmail {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding(.top, 4)
                    
                    if !testResultMessage.isEmpty {
                        Text(testResultMessage)
                            .font(.caption)
                            .foregroundColor(testResultColor)
                            .padding(.top, 2)
                    }
                    
                    if !preferences.mailjetToEmail.isEmpty {
                        Text("Notifications will be sent to: \(preferences.mailjetToEmail)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
            
            Section(header: Text("UPS Power Change Notifications")) {
                Toggle("Notify on UPS Power Changes", isOn: $preferences.upsPowerChangeNotificationEnabled)
                
                if preferences.upsPowerChangeNotificationEnabled && preferences.mailjetEmailEnabled {
                    Text("You will receive email notifications when your UPS switches between AC power and battery power.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if preferences.upsPowerChangeNotificationEnabled && !preferences.mailjetEmailEnabled {
                    Text("Please enable and configure Mailjet email notifications above to receive UPS power change alerts.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section(header: Text("IP Change Notifications")) {
                Toggle("Notify on IP Changes", isOn: $preferences.ipChangeNotificationEnabled)
                
                if preferences.ipChangeNotificationEnabled && preferences.mailjetEmailEnabled {
                    Text("You will receive email notifications when your external IP address changes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if preferences.ipChangeNotificationEnabled && !preferences.mailjetEmailEnabled {
                    Text("Please enable and configure Mailjet email notifications above to receive IP change alerts.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func sendTestEmail() {
        isTestingEmail = true
        testResultMessage = ""
        
        // Use the "To" email if specified, otherwise use the "From" email
        let toEmail = preferences.mailjetToEmail.isEmpty ? preferences.mailjetFromEmail : preferences.mailjetToEmail
        
        EmailService.shared.sendTestEmail(
            apiKey: preferences.mailjetAPIKey,
            apiSecret: preferences.mailjetAPISecret,
            fromEmail: preferences.mailjetFromEmail,
            fromName: preferences.mailjetFromName.isEmpty ? "Mac Stats" : preferences.mailjetFromName,
            toEmail: toEmail
        ) { result in
            DispatchQueue.main.async {
                isTestingEmail = false
                
                switch result {
                case .success(let message):
                    testResultMessage = message
                    testResultColor = .green
                case .failure(let error):
                    testResultMessage = error.localizedDescription
                    testResultColor = .red
                }
            }
        }
    }
}