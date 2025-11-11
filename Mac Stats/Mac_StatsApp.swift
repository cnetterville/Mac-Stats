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
    @StateObject private var wifiManager = WiFiManager()
    
    init() {
        // Handle launch at startup registration
        setupLaunchAtStartup()
    }
    
    var body: some Scene {
        MenuBarExtra {
            // Simplified menu for quick access with environment access
            MenuBarDropdownView()
                .environmentObject(systemMonitor)
                .environmentObject(preferences)
                .environmentObject(ExternalIPManager.shared)
                .environmentObject(wifiManager)
        } label: {
            // The view for the menu bar icon itself
            MenuBarLabelView(imageManager: imageManager, systemMonitor: systemMonitor, preferences: preferences)
        }
        .menuBarExtraStyle(.window)

        // Main stats window - choice between card-based or tabbed layout
        Window("Mac Stats", id: "main") {
            Group {
                if preferences.useTabbedView {
                    TabbedStatsView()
                        .environmentObject(imageManager)
                } else {
                    CardBasedStatsView()
                        .environmentObject(imageManager)
                }
            }
            .environmentObject(systemMonitor)
            .environmentObject(preferences)
            .environmentObject(ExternalIPManager.shared)
            .environmentObject(wifiManager)
            .onAppear {
                // Ensure SystemMonitor is properly initialized when main window appears
                initializeSystemMonitor()
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(preferences)
                .environmentObject(systemMonitor)
                .environmentObject(ExternalIPManager.shared)
                .environmentObject(wifiManager)
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
    
    private func initializeSystemMonitor() {
        // Set preferences reference
        systemMonitor.preferences = preferences
        
        // Initialize external IP manager
        ExternalIPManager.shared.setPreferences(preferences)
        
        // Initialize WiFi manager
        wifiManager.refreshWiFiInfo()
        
        // Force a data refresh
        systemMonitor.refreshAllData()
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

// New dropdown menu view for the menu bar extra
struct MenuBarDropdownView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var systemMonitor: SystemMonitor
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // CPU Section
                CPUSectionView(openWindow: openWindow)
                    .environmentObject(systemMonitor)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Memory Section
                MemorySectionView(openWindow: openWindow)
                    .environmentObject(systemMonitor)
                
                // Bottom actions
                HStack(spacing: 16) {
                    Button("Settings") {
                        openWindow(id: "settings")
                        dismissMenu()
                    }
                    .buttonStyle(.plain)
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
            }
        }
        .frame(width: 300, height: 600)
    }
    
    private func dismissMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.sendAction(Selector(("dismiss:")), to: nil, from: nil)
        }
    }
}

// CPU Section
struct CPUSectionView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    let openWindow: OpenWindowAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    openWindow(id: "settings")
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Text("CPU")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 6)
            
            // Large percentage
            Text(String(format: "%.0f%%", systemMonitor.cpuUsage))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(cpuColor(systemMonitor.cpuUsage))
                .padding(.horizontal, 16)
                .padding(.top, 4)
            
            Text("Usage history")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // CPU history sparkline
            if !systemMonitor.cpuHistory.isEmpty {
                CPUSparklineView(data: systemMonitor.cpuHistory)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            Button(action: {
                openWindow(id: "main")
            }) {
                Text("Details")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Temperature
            VStack(alignment: .leading, spacing: 3) {
                Text("Temperature:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f°C", systemMonitor.cpuTemperature))
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            
            // Top processes
            Text("Top processes")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            ForEach(Array(systemMonitor.topProcesses.prefix(5)), id: \.id) { process in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                        Text(process.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                    }
                    Text(String(format: "%.1f%%", process.cpuUsage))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 6)
        }
    }
    
    private func cpuColor(_ usage: Double) -> Color {
        if usage < 30 { return .green }
        if usage < 70 { return .orange }
        return .red
    }
}

// Memory Section
struct MemorySectionView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    let openWindow: OpenWindowAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    openWindow(id: "settings")
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Text("Memory")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 6)
            
            // Large percentage
            let memPercent = (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
            Text(String(format: "%.0f%%", memPercent))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.top, 4)
            
            Text("Usage history")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Memory usage sparkline (using CPU history as proxy since we don't track memory history)
            if !systemMonitor.cpuHistory.isEmpty {
                MemorySparklineView(memoryPercent: memPercent)
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            } else {
                Rectangle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(height: 40)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            Button(action: {
                openWindow(id: "main")
            }) {
                Text("Details")
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Memory stats
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Total:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f GB", systemMonitor.memoryUsage.total))
                        .font(.system(size: 11, design: .monospaced))
                }
                
                HStack {
                    Text("Used:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f GB", systemMonitor.memoryUsage.used))
                        .font(.system(size: 11, design: .monospaced))
                }
                
                HStack {
                    Text("Free:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f GB", systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used))
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            
            // Top processes
            Text("Top processes")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            ForEach(Array(systemMonitor.topMemoryProcesses.prefix(5)), id: \.id) { process in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                        Text(process.name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                        Spacer()
                    }
                    let memoryMB = (systemMonitor.memoryUsage.total * 1024 * process.memoryUsage / 100)
                    Text(memoryMB >= 1000 ? String(format: "%.2f GB", memoryMB / 1024) : String(format: "%.0f MB", memoryMB))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 6)
        }
    }
}

// CPU Sparkline View
struct CPUSparklineView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let maxValue = max(data.max() ?? 100, 1)
                let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                let stepY = geometry.size.height
                
                path.move(to: CGPoint(x: 0, y: stepY - (CGFloat(data[0]) / CGFloat(maxValue)) * stepY))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = stepY - (CGFloat(value) / CGFloat(maxValue)) * stepY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
    }
}

// Memory Sparkline View
struct MemorySparklineView: View {
    let memoryPercent: Double
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Simple filled bar representing memory usage
                let fillHeight = geometry.size.height * CGFloat(memoryPercent / 100)
                path.addRect(CGRect(x: 0, y: geometry.size.height - fillHeight, width: geometry.size.width, height: fillHeight))
            }
            .fill(Color.purple)
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
            systemMonitor.preferences = preferences
            ExternalIPManager.shared.setPreferences(preferences)
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