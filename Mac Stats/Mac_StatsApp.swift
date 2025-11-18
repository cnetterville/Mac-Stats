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
    @EnvironmentObject var preferences: PreferencesManager
    @State private var selectedTab: MonitorTab = .cpu
    
    enum MonitorTab: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case network = "Network"
        
        var icon: String {
            switch self {
            case .cpu: return "cpu.fill"
            case .memory: return "memorychip.fill"
            case .network: return "antenna.radiowaves.left.and.right"
            }
        }
        
        var color: Color {
            switch self {
            case .cpu: return .blue
            case .memory: return .purple
            case .network: return .green
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            VStack(spacing: 12) {
                // Title and icon (dynamic based on selected tab)
                HStack {
                    Image(systemName: selectedTab.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selectedTab.color.gradient)
                    Text("\(selectedTab.rawValue) Monitor")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Tab picker
                Picker("Monitor Type", selection: $selectedTab) {
                    ForEach(MonitorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                
                // Quick action buttons
                HStack(spacing: 8) {
                    Button(action: {
                        openWindow(id: "main")
                        dismissMenu()
                    }) {
                        Label("View Full Details", systemImage: "gauge")
                            .font(.system(size: 11, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button(action: {
                        openWindow(id: "settings")
                        dismissMenu()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(NSColor.controlBackgroundColor), Color(NSColor.controlBackgroundColor).opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Switch between CPU and Memory views
                    Group {
                        switch selectedTab {
                        case .cpu:
                            CPUSectionView(openWindow: openWindow)
                                .environmentObject(systemMonitor)
                        case .memory:
                            MemorySectionView(openWindow: openWindow)
                                .environmentObject(systemMonitor)
                        case .network:
                            NetworkSectionView(openWindow: openWindow)
                                .environmentObject(systemMonitor)
                        }
                    }
                    .id(selectedTab) // More efficient than complex transitions
                }
            }
            // Enable momentum scrolling
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 320, height: 520)
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
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
    @EnvironmentObject var preferences: PreferencesManager
    let openWindow: OpenWindowAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main CPU Usage Card
            VStack(spacing: 0) {
                // CPU Usage Display
                HStack(alignment: .top, spacing: 16) {
                    // Large percentage with circular progress
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: systemMonitor.cpuUsage / 100)
                            .stroke(
                                cpuColor(systemMonitor.cpuUsage).gradient,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: systemMonitor.cpuUsage)
                        
                        // Percentage text
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", systemMonitor.cpuUsage))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(cpuColor(systemMonitor.cpuUsage))
                            Text("%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Temperature and details
                    VStack(alignment: .leading, spacing: 12) {
                        // Temperature badge
                        HStack(spacing: 6) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 12))
                                .foregroundStyle(temperatureColor(systemMonitor.cpuTemperature).gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Temperature")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                // Display both C and F
                                let celsius = systemMonitor.cpuTemperature
                                let fahrenheit = TemperatureMonitor.celsiusToFahrenheit(celsius)
                                
                                Text(String(format: "%.0f°C / %.0f°F", celsius, fahrenheit))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(temperatureColor(systemMonitor.cpuTemperature))
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        
                        // Usage status
                        HStack(spacing: 4) {
                            Circle()
                                .fill(cpuColor(systemMonitor.cpuUsage))
                                .frame(width: 6, height: 6)
                            Text(cpuStatus(systemMonitor.cpuUsage))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
                
                // Usage History Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Usage History")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Last \(systemMonitor.cpuHistory.count) samples")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    if !systemMonitor.cpuHistory.isEmpty {
                        CPUSparklineView(data: systemMonitor.cpuHistory)
                            .frame(height: 50)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 50)
                            .overlay(
                                Text("Loading...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Top Processes Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Top Processes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                if systemMonitor.topProcesses.isEmpty {
                    Text("Loading processes...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(systemMonitor.topProcesses.prefix(5).enumerated()), id: \.element.id) { index, process in
                        ProcessRowView(process: process, rank: index + 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
    
    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func cpuStatus(_ usage: Double) -> String {
        switch usage {
        case 0..<30: return "Low Usage"
        case 30..<60: return "Normal"
        case 60..<80: return "High Usage"
        default: return "Very High"
        }
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case 0..<60: return .blue
        case 60..<80: return .green
        case 80..<95: return .orange
        default: return .red
        }
    }
}

// Process Row View - Polished design
struct ProcessRowView: View {
    let process: SystemProcessInfo
    let rank: Int
    
    // Cache computed colors
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    private var usageColor: Color {
        switch process.cpuUsage {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private var usageWidth: CGFloat {
        CGFloat(min(process.cpuUsage / 100, 1.0))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
            }
            
            // Process info
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.system(size: 8))
                    Text(String(format: "%.1f%%", process.cpuUsage))
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Usage bar - simplified without GeometryReader
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(usageColor)
                    .frame(width: 50 * usageWidth, height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(rank <= 3 ? 0.15 : 0))
        )
        .padding(.horizontal, 4)
        .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// Memory Section - Polished design matching CPU section
struct MemorySectionView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    let openWindow: OpenWindowAction
    
    private var memoryPercent: Double {
        guard systemMonitor.memoryUsage.total > 0 else { return 0 }
        return (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
    }
    
    private var memoryFree: Double {
        systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Memory Usage Card
            VStack(spacing: 0) {
                // Memory Usage Display
                HStack(alignment: .top, spacing: 16) {
                    // Large percentage with circular progress
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: memoryPercent / 100)
                            .stroke(
                                memoryColor(memoryPercent).gradient,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: memoryPercent)
                        
                        // Percentage text
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", memoryPercent))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(memoryColor(memoryPercent))
                            Text("%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Memory stats
                    VStack(alignment: .leading, spacing: 12) {
                        // Used memory badge
                        HStack(spacing: 6) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.purple.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Used")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f GB", systemMonitor.memoryUsage.used))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        
                        // Free memory badge
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.green.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Free")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f GB", memoryFree))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                    }
                    
                    Spacer()
                }
                .padding(20)
                
                // Memory breakdown
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory Breakdown")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Total: \(String(format: "%.2f GB", systemMonitor.memoryUsage.total))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    // Memory bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                            
                            // Used memory
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple, Color.purple.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(memoryPercent / 100))
                            
                            // Percentage overlay
                            HStack {
                                if memoryPercent > 15 {
                                    Text(String(format: "%.1f%%", memoryPercent))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.leading, 8)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Top Memory Processes Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.purple)
                    Text("Top Memory Processes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                if systemMonitor.topMemoryProcesses.isEmpty {
                    Text("Loading processes...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(systemMonitor.topMemoryProcesses.prefix(5).enumerated()), id: \.element.id) { index, process in
                        MemoryProcessRowView(process: process, rank: index + 1, totalMemory: systemMonitor.memoryUsage.total)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
    
    private func memoryColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<50: return .green
        case 50..<70: return .blue
        case 70..<85: return .orange
        default: return .red
        }
    }
}

// Memory Process Row View
struct MemoryProcessRowView: View {
    let process: SystemProcessInfo
    let rank: Int
    let totalMemory: Double
    
    private var memoryMB: Double {
        (totalMemory * 1024 * process.memoryUsage / 100)
    }
    
    private var memoryText: String {
        if memoryMB >= 1000 {
            return String(format: "%.2f GB", memoryMB / 1024)
        } else {
            return String(format: "%.0f MB", memoryMB)
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .purple
        }
    }
    
    private var usageColor: Color {
        switch process.memoryUsage {
        case 0..<3: return .green
        case 3..<6: return .blue
        case 6..<8: return .orange
        default: return .red
        }
    }
    
    private var usageWidth: CGFloat {
        CGFloat(min(process.memoryUsage / 10, 1.0))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
            }
            
            // Process info
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 8))
                    Text(memoryText)
                        .font(.system(size: 9, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Usage bar - simplified without GeometryReader
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(usageColor)
                    .frame(width: 50 * usageWidth, height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(rank <= 3 ? 0.15 : 0))
        )
        .padding(.horizontal, 4)
        .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// Network Section - Polished design matching CPU and Memory sections
struct NetworkSectionView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var externalIPManager: ExternalIPManager
    let openWindow: OpenWindowAction
    
    private var downloadMbps: Double {
        (systemMonitor.networkUsage.download * 8) / 1_000_000 // Convert bytes/s to Mbps
    }
    
    private var uploadMbps: Double {
        (systemMonitor.networkUsage.upload * 8) / 1_000_000 // Convert bytes/s to Mbps
    }
    
    private var totalMbps: Double {
        downloadMbps + uploadMbps
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // External IP and ISP Card
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    // Globe icon with flag emoji
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        if !externalIPManager.countryCode.isEmpty {
                            Text(externalIPManager.flagEmoji)
                                .font(.system(size: 28))
                        } else {
                            Image(systemName: "globe")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.blue.gradient)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // External IP
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("External IP")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if externalIPManager.isLoading {
                            Text("Loading...")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                        } else if !externalIPManager.externalIP.isEmpty {
                            Text(externalIPManager.externalIP)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                        } else {
                            Text("Not Available")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        // ISP Name
                        if !externalIPManager.ispName.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(cleanISPName(externalIPManager.ispName))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Refresh button
                    Button(action: {
                        externalIPManager.refreshExternalIP()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(externalIPManager.isLoading ? .secondary : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(externalIPManager.isLoading)
                    .rotationEffect(.degrees(externalIPManager.isLoading ? 360 : 0))
                    .animation(externalIPManager.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: externalIPManager.isLoading)
                }
                .padding(16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Main Network Usage Card
            VStack(spacing: 0) {
                // Network Usage Display
                HStack(alignment: .top, spacing: 16) {
                    // Total speed indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        
                        // Progress circle (based on a 100 Mbps scale)
                        Circle()
                            .trim(from: 0, to: min(totalMbps / 100, 1.0))
                            .stroke(
                                Color.green.gradient,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: totalMbps)
                        
                        // Speed text
                        VStack(spacing: 2) {
                            Text(formatSpeed(totalMbps))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("Mbps")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    // Download and Upload stats
                    VStack(alignment: .leading, spacing: 12) {
                        // Download badge
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.blue.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Download")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(formatSpeed(downloadMbps)) Mbps")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.blue)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        
                        // Upload badge
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upload")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("\(formatSpeed(uploadMbps)) Mbps")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.orange)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                    }
                    
                    Spacer()
                }
                .padding(20)
                
                // Network History Charts
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Network Activity")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Last \(systemMonitor.downloadHistory.count) samples")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    // Download history
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                            Text("Download")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if !systemMonitor.downloadHistory.isEmpty {
                            NetworkSparklineView(data: systemMonitor.downloadHistory, color: .blue)
                                .frame(height: 35)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 35)
                        }
                    }
                    
                    // Upload history
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("Upload")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        if !systemMonitor.uploadHistory.isEmpty {
                            NetworkSparklineView(data: systemMonitor.uploadHistory, color: .orange)
                                .frame(height: 35)
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                                .frame(height: 35)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Top Network Processes Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text("Top Network Processes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                if systemMonitor.topNetworkProcesses.isEmpty {
                    Text("Loading processes...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(systemMonitor.topNetworkProcesses.prefix(5).enumerated()), id: \.element.id) { index, process in
                        NetworkProcessRowView(process: process, rank: index + 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.3))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1000 {
            return String(format: "%.1f", mbps / 1000)
        } else if mbps >= 10 {
            return String(format: "%.1f", mbps)
        } else {
            return String(format: "%.2f", mbps)
        }
    }
    
    private func cleanISPName(_ ispName: String) -> String {
        // Remove AS number prefix (e.g., "AS15169 Google LLC" -> "Google LLC")
        if let asRange = ispName.range(of: "^AS\\d+\\s+", options: .regularExpression) {
            return String(ispName[asRange.upperBound...])
        }
        return ispName
    }
}

// Network Process Row View
struct NetworkProcessRowView: View {
    let process: ProcessNetworkInfo
    let rank: Int
    
    private var downloadMbps: Double {
        (process.bytesIn * 8) / 1_000_000
    }
    
    private var uploadMbps: Double {
        (process.bytesOut * 8) / 1_000_000
    }
    
    private var totalMbps: Double {
        downloadMbps + uploadMbps
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .green
        }
    }
    
    private var usageWidth: CGFloat {
        CGFloat(min(totalMbps / 10, 1.0))
    }
    
    private func formatSpeed(_ mbps: Double) -> String {
        if mbps >= 1 {
            return String(format: "%.1fM", mbps)
        } else if mbps >= 0.001 {
            return String(format: "%.0fK", mbps * 1000)
        } else {
            return "0K"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.15))
                    .frame(width: 24, height: 24)
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(rankColor)
            }
            
            // Process info
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 7))
                        Text(formatSpeed(downloadMbps))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.blue)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7))
                        Text(formatSpeed(uploadMbps))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Usage bar - simplified without GeometryReader
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green)
                    .frame(width: 50 * usageWidth, height: 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(rank <= 3 ? 0.15 : 0))
        )
        .padding(.horizontal, 4)
        .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// Network Sparkline View
struct NetworkSparklineView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Gradient fill
                LinearGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.1),
                        color.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    areaPath(in: geometry.size)
                )
                
                // Line path
                linePath(in: geometry.size)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: color.opacity(0.3), radius: 1, x: 0, y: 0.5)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            
            // Convert to Mbps and find max
            let mbpsData = data.map { ($0 * 8) / 1_000_000 }
            let maxValue = max(mbpsData.max() ?? 1, 0.1)
            let stepX = size.width / CGFloat(max(mbpsData.count - 1, 1))
            let stepY = size.height
            
            path.move(to: CGPoint(
                x: 0,
                y: stepY - (CGFloat(mbpsData[0]) / CGFloat(maxValue)) * stepY
            ))
            
            for (index, value) in mbpsData.enumerated() {
                let x = CGFloat(index) * stepX
                let y = stepY - (CGFloat(value) / CGFloat(maxValue)) * stepY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            
            let mbpsData = data.map { ($0 * 8) / 1_000_000 }
            let maxValue = max(mbpsData.max() ?? 1, 0.1)
            let stepX = size.width / CGFloat(max(mbpsData.count - 1, 1))
            let stepY = size.height
            
            path.move(to: CGPoint(x: 0, y: stepY))
            path.addLine(to: CGPoint(
                x: 0,
                y: stepY - (CGFloat(mbpsData[0]) / CGFloat(maxValue)) * stepY
            ))
            
            for (index, value) in mbpsData.enumerated() {
                let x = CGFloat(index) * stepX
                let y = stepY - (CGFloat(value) / CGFloat(maxValue)) * stepY
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            path.addLine(to: CGPoint(x: size.width, y: stepY))
            path.closeSubpath()
        }
    }
}

// CPU Sparkline View - Enhanced with gradient fill
struct CPUSparklineView: View {
    let data: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background grid lines
                Path { path in
                    for i in 0...4 {
                        let y = geometry.size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                
                // Gradient fill
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.blue.opacity(0.1),
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    areaPath(in: geometry.size)
                )
                
                // Line path
                linePath(in: geometry.size)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            
            let maxValue = max(data.max() ?? 100, 1)
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            let stepY = size.height
            
            path.move(to: CGPoint(
                x: 0,
                y: stepY - (CGFloat(data[0]) / CGFloat(maxValue)) * stepY
            ))
            
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = stepY - (CGFloat(value) / CGFloat(maxValue)) * stepY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            
            let maxValue = max(data.max() ?? 100, 1)
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            let stepY = size.height
            
            // Start at bottom left
            path.move(to: CGPoint(x: 0, y: stepY))
            
            // Draw line to first data point
            path.addLine(to: CGPoint(
                x: 0,
                y: stepY - (CGFloat(data[0]) / CGFloat(maxValue)) * stepY
            ))
            
            // Draw through all data points
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = stepY - (CGFloat(value) / CGFloat(maxValue)) * stepY
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            // Complete the area back to bottom
            path.addLine(to: CGPoint(x: size.width, y: stepY))
            path.closeSubpath()
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