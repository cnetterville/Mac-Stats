//
//  Mac_StatsApp.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Combine
import ServiceManagement

@main
struct Mac_StatsApp: App {
    @StateObject private var systemMonitor = SystemMonitor()
    @StateObject private var preferences = PreferencesManager()
    @StateObject private var imageManager = MenuBarImageManager()
    
    init() {
        // Handle launch at startup registration
        setupLaunchAtStartup()
    }
    
    var body: some Scene {
        MenuBarExtra {
            // The content of the menu bar extra window
            StatsMenuView()
                .environmentObject(systemMonitor)
                .environmentObject(preferences)
                .environmentObject(ExternalIPManager.shared)
        } label: {
            // The view for the menu bar icon itself
            MenuBarLabelView(imageManager: imageManager, systemMonitor: systemMonitor, preferences: preferences)
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(preferences)
                .environmentObject(systemMonitor)
                .environmentObject(ExternalIPManager.shared)
                .frame(width: 450, height: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
                    // Ensure settings window stays prominent
                    if let window = notification.object as? NSWindow, window.title == "Settings" {
                        window.level = .floating
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
    }
    
    private func setupLaunchAtStartup() {
        if #available(macOS 13.0, *) {
            // Check if we should be registered for launch at startup
            if preferences.launchAtStartup {
                do {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } catch {
                    print("Failed to register for launch at startup: \(error)")
                }
            }
        }
    }
}

// A helper view for the menu bar label to handle initialization.
struct MenuBarLabelView: View {
    @ObservedObject var imageManager: MenuBarImageManager
    var systemMonitor: SystemMonitor
    var preferences: PreferencesManager
    
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        Group {
            if let image = imageManager.menuBarImage {
                Image(nsImage: image)
            } else {
                Text("...")
            }
        }
        .onAppear {
            // Initialize dependencies.
            systemMonitor.preferences = preferences  // Set the preferences reference
            ExternalIPManager.shared.setPreferences(preferences) // Set preferences for ExternalIPManager
            imageManager.updateDependencies(
                systemMonitor: systemMonitor,
                preferences: preferences
            )
            
            // Subscribe to system monitor changes to update menu bar image
            systemMonitor.objectWillChange
                .sink { _ in
                    DispatchQueue.main.async {
                        imageManager.forceImageUpdate()
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to preference changes
            preferences.$updateInterval
                .sink { newValue in
                    systemMonitor.updateMonitoringInterval(newValue)
                }
                .store(in: &cancellables)
            
            preferences.$powerUpdateInterval
                .sink { newValue in
                    systemMonitor.updatePowerMonitoringInterval(newValue)
                }
                .store(in: &cancellables)
            
            preferences.$selectedNetworkInterface
                .sink { _ in
                    systemMonitor.refreshAllData()
                }
                .store(in: &cancellables)
            
            // Perform the first data load.
            systemMonitor.refreshAllData()
            
            // Schedule additional updates to ensure image gets refreshed
            // after data has been loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                imageManager.forceImageUpdate()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                imageManager.forceImageUpdate()
            }
        }
    }
}