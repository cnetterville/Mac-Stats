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
    @State private var systemMonitor = SystemMonitor()
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
                .environment(systemMonitor)
                .environmentObject(preferences)
                .environmentObject(ExternalIPManager.shared)
                .environmentObject(wifiManager)
                .onAppear { systemMonitor.viewerDidAppear() }
                .onDisappear { systemMonitor.viewerDidDisappear() }
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
            .environment(systemMonitor)
            .environmentObject(preferences)
            .environmentObject(ExternalIPManager.shared)
            .environmentObject(wifiManager)
            .onAppear {
                // Ensure SystemMonitor is properly initialized when main window appears
                initializeSystemMonitor()
                systemMonitor.viewerDidAppear()
            }
            .onDisappear {
                systemMonitor.viewerDidDisappear()
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(preferences)
                .environment(systemMonitor)
                .environmentObject(ExternalIPManager.shared)
                .environmentObject(wifiManager)
                .frame(width: 450, height: 600)
                .onAppear { systemMonitor.viewerDidAppear() }
                .onDisappear { systemMonitor.viewerDidDisappear() }
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
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var preferences: PreferencesManager
    @AppStorage("lastMenuTab") private var selectedTab: MonitorTab = .overview

    enum MonitorTab: String, CaseIterable {
        case overview = "Overview"
        case cpu = "CPU"
        case memory = "Memory"
        case network = "Network"
        case disk = "Disk"
        case power = "Power"
        case battery = "Battery"

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2.fill"
            case .cpu:      return "cpu.fill"
            case .memory:   return "memorychip.fill"
            case .network:  return "antenna.radiowaves.left.and.right"
            case .disk:     return "internaldrive.fill"
            case .power:    return "bolt.fill"
            case .battery:  return "battery.100"
            }
        }

        var color: Color {
            switch self {
            case .overview: return .primary
            case .cpu:      return .blue
            case .memory:   return .purple
            case .network:  return .green
            case .disk:     return .mint
            case .power:    return .yellow
            case .battery:  return .green
            }
        }

        var shortLabel: String {
            switch self {
            case .overview: return "All"
            case .cpu:      return "CPU"
            case .memory:   return "Mem"
            case .network:  return "Net"
            case .disk:     return "Disk"
            case .power:    return "Power"
            case .battery:  return "Batt"
            }
        }
    }

    private var visibleTabs: [MonitorTab] {
        MonitorTab.allCases.filter { $0 != .battery || systemMonitor.batteryInfo.present }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                // Tab bar + action buttons row
                HStack(spacing: 0) {
                    HStack(spacing: 2) {
                        ForEach(visibleTabs, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    selectedTab = tab
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(tab.shortLabel)
                                        .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .regular))
                                }
                                .foregroundColor(selectedTab == tab ? tab.color : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedTab == tab ? tab.color.opacity(0.15) : Color.clear)
                                        .animation(.easeInOut(duration: 0.18), value: selectedTab)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Button {
                            openWindow(id: "main")
                            dismissMenu()
                        } label: {
                            Image(systemName: "macwindow")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open Main Window")

                        Button {
                            openWindow(id: "settings")
                            dismissMenu()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open Settings")

                        Menu {
                            Button(role: .destructive, action: { NSApplication.shared.terminate(nil) }) {
                                Label("Quit Mac Stats", systemImage: "power")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("More")
                    }
                }

                // System info strip — shows data not duplicated in any tab
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatUptime(systemMonitor.systemInfo.uptime))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.7))
                    }

                    if !systemMonitor.systemInfo.macOSVersion.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(systemMonitor.systemInfo.macOSVersion)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if systemMonitor.timeMachineInfo.isConfigured {
                        HStack(spacing: 3) {
                            Image(systemName: systemMonitor.timeMachineInfo.isBackingUp
                                  ? "arrow.clockwise.circle.fill" : "clock.arrow.circlepath")
                                .font(.system(size: 9))
                                .foregroundColor(systemMonitor.timeMachineInfo.isBackingUp ? .blue : .secondary)
                            Text(systemMonitor.timeMachineInfo.isBackingUp
                                 ? "Backing up"
                                 : tmShortString(systemMonitor.timeMachineInfo.lastBackupDate))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary.opacity(0.7))
                        }
                    } else if systemMonitor.batteryInfo.present {
                        let pct = systemMonitor.batteryInfo.chargeLevel
                        HStack(spacing: 3) {
                            Image(systemName: systemMonitor.batteryInfo.isCharging ? "bolt.fill" : "battery.100")
                                .font(.system(size: 9))
                                .foregroundColor(pct < 20 ? .red : pct < 40 ? .orange : .green)
                            Text("\(Int(pct))%")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(pct < 20 ? .red : pct < 40 ? .orange : .primary.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                LiquidGlassBackground(material: .headerView, cornerRadius: 0, borderWidth: 0, borderOpacity: 0)
            )

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch selectedTab {
                    case .overview:
                        OverviewSectionView()
                            .environment(systemMonitor)
                    case .cpu:
                        CPUSectionView(openWindow: openWindow)
                            .environment(systemMonitor)
                    case .memory:
                        MemorySectionView(openWindow: openWindow)
                            .environment(systemMonitor)
                    case .network:
                        NetworkSectionView(openWindow: openWindow)
                            .environment(systemMonitor)
                    case .disk:
                        DiskSectionView()
                            .environment(systemMonitor)
                    case .power:
                        PowerSectionView()
                            .environment(systemMonitor)
                    case .battery:
                        BatterySectionView()
                            .environment(systemMonitor)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: selectedTab)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 350, height: 620)
    }

    // MARK: - Helpers

    private func formatUptime(_ uptime: TimeInterval) -> String {
        let t = Int(uptime)
        let d = t / 86400; let h = (t % 86400) / 3600; let m = (t % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return "\(m)m"
    }

    private func tmShortString(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func dismissMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.sendAction(Selector(("dismiss:")), to: nil, from: nil)
        }
    }
}

// CPU Section
struct CPUSectionView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
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
                                
                                Text(formatTemp(systemMonitor.cpuTemperature))
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
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(formatUptime(systemMonitor.systemInfo.uptime))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
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

                // Per-core CPU breakdown
                if !systemMonitor.cpuCoreUsages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Per-Core Usage")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            if systemMonitor.pCoreCount > 0 {
                                HStack(spacing: 8) {
                                    HStack(spacing: 3) {
                                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                                        Text("P-cores").font(.system(size: 9)).foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 3) {
                                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                                        Text("E-cores").font(.system(size: 9)).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        CoreUsageGridView(
                            coreUsages: systemMonitor.cpuCoreUsages,
                            pCoreCount: systemMonitor.pCoreCount
                        )
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Load averages
                if systemMonitor.cpuLoadAverages.one > 0 {
                    Divider().opacity(0.3).padding(.horizontal, 20)
                    HStack(spacing: 0) {
                        Text("Load Avg")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        ForEach([(systemMonitor.cpuLoadAverages.one, "1m"),
                                 (systemMonitor.cpuLoadAverages.five, "5m"),
                                 (systemMonitor.cpuLoadAverages.fifteen, "15m")], id: \.1) { value, label in
                            VStack(spacing: 2) {
                                Text(String(format: "%.2f", value))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(value > 4 ? .red : value > 2 ? .orange : .primary)
                                Text(label)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }
    
    private func formatTemp(_ celsius: Double) -> String {
        preferences.temperatureUnit == .fahrenheit
            ? String(format: "%.0f°F", TemperatureMonitor.celsiusToFahrenheit(celsius))
            : String(format: "%.0f°C", celsius)
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let t = Int(uptime)
        let d = t / 86400; let h = (t % 86400) / 3600; let m = (t % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return "\(m)m"
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
        systemMonitor.thermalProfile.temperatureColor(temp)
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
    @Environment(SystemMonitor.self) private var systemMonitor
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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Composition / Pressure / Swap / Process counts
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Memory Composition")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(memoryPressureLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(memoryPressureColor.gradient)
                        )
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    compositionRow(label: "App", value: systemMonitor.memoryComposition.app, color: .purple)
                    compositionRow(label: "Wired", value: systemMonitor.memoryComposition.wired, color: .red)
                    compositionRow(label: "Compressed", value: systemMonitor.memoryComposition.compressed, color: .orange)
                    compositionRow(label: "Cached", value: systemMonitor.memoryComposition.cached, color: .blue)
                    compositionRow(label: "Free", value: systemMonitor.memoryComposition.free, color: .green)
                    if systemMonitor.swapUsage.total > 0 {
                        compositionRow(label: "Swap",
                                       value: systemMonitor.swapUsage.used,
                                       color: systemMonitor.swapUsage.used > 0.1 ? .orange : .secondary)
                    }
                }

                if systemMonitor.processCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(systemMonitor.processCount) processes · \(systemMonitor.threadCount) threads")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Memory History Chart
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Usage History")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Last \(systemMonitor.memoryHistory.count) samples")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    if !systemMonitor.memoryHistory.isEmpty {
                        MemorySparklineView(data: systemMonitor.memoryHistory)
                            .frame(height: 50)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(0.1))
                            .frame(height: 50)
                            .overlay(Text("Loading...").font(.system(size: 10)).foregroundColor(.secondary))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
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

    private var memoryPressureLabel: String {
        switch systemMonitor.memoryPressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    private var memoryPressureColor: Color {
        switch systemMonitor.memoryPressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    @ViewBuilder
    private func compositionRow(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.2f GB", value))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
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
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var externalIPManager: ExternalIPManager
    @EnvironmentObject var wifiManager: WiFiManager
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
    
    // Dynamically scale the gauge based on observed peak traffic
    private var dynamicScaleMbps: Double {
        let downloadPeak = systemMonitor.downloadHistory.map { ($0 * 8) / 1_000_000 }.max() ?? 0
        let uploadPeak = systemMonitor.uploadHistory.map { ($0 * 8) / 1_000_000 }.max() ?? 0
        let peak = max(totalMbps, downloadPeak + uploadPeak)
        let niceScales: [Double] = [1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 10000]
        return niceScales.first(where: { $0 >= peak * 1.25 }) ?? 10000
    }
    
    private var speedUnit: String {
        totalMbps >= 1000 ? "Gbps" : "Mbps"
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
                        // Local IP
                        if !systemMonitor.localIPAddress.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("Local IP")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            Text(systemMonitor.localIPAddress)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                            Divider()
                                .padding(.vertical, 2)
                        }

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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // WiFi Card
            if wifiManager.wifiInfo.isConnected && !wifiManager.wifiInfo.networkName.isEmpty {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: wifiSignalIcon(wifiManager.wifiInfo.linkQuality))
                                .font(.system(size: 18))
                                .foregroundStyle(Color.green.gradient)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(wifiManager.wifiInfo.networkName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            HStack(spacing: 8) {
                                Text(String(format: "%.0f%%", wifiManager.wifiInfo.linkQuality * 100))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.green)

                                if wifiManager.wifiInfo.channel > 0 {
                                    Text("Ch \(wifiManager.wifiInfo.channel)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }

                                if !wifiManager.wifiInfo.band.isEmpty {
                                    Text(wifiManager.wifiInfo.band)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Signal quality bar
                        VStack(spacing: 2) {
                            signalStrengthBars(quality: wifiManager.wifiInfo.linkQuality)
                            Text("\(wifiManager.wifiInfo.signalStrength) dBm")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

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
                            .trim(from: 0, to: min(totalMbps / dynamicScaleMbps, 1.0))
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
                            Text(speedUnit)
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
                                Text(formatSpeedWithUnit(downloadMbps))
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
                                Text(formatSpeedWithUnit(uploadMbps))
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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Session totals card
            if systemMonitor.sessionBytesDownloaded > 0 || systemMonitor.sessionBytesUploaded > 0 {
                HStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.blue.gradient)
                        Text("Downloaded")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatSessionBytes(systemMonitor.sessionBytesDownloaded))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Divider().frame(height: 36)
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.orange.gradient)
                        Text("Uploaded")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatSessionBytes(systemMonitor.sessionBytesUploaded))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

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
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .onAppear { systemMonitor.networkProcessesViewerDidAppear() }
        .onDisappear { systemMonitor.networkProcessesViewerDidDisappear() }
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

    private func formatSpeedWithUnit(_ mbps: Double) -> String {
        mbps >= 1000
            ? String(format: "%.2f Gbps", mbps / 1000)
            : "\(formatSpeed(mbps)) Mbps"
    }
    
    private func cleanISPName(_ ispName: String) -> String {
        if let asRange = ispName.range(of: "^AS\\d+\\s+", options: .regularExpression) {
            return String(ispName[asRange.upperBound...])
        }
        return ispName
    }

    private func wifiSignalIcon(_ quality: Double) -> String {
        switch quality {
        case 0.75...: return "wifi"
        case 0.5..<0.75: return "wifi"
        case 0.25..<0.5: return "wifi.exclamationmark"
        default: return "wifi.slash"
        }
    }

    @ViewBuilder
    private func signalStrengthBars(quality: Double) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Double(i + 1) <= quality * 4 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(4 + i * 3))
            }
        }
    }

    private func formatSessionBytes(_ bytes: Double) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.2f GB", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.0f KB", bytes / 1024)
        } else {
            return "< 1 KB"
        }
    }
}

// Disk Section
struct DiskSectionView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    
    private var usedDisk: Double {
        systemMonitor.diskUsage.total - systemMonitor.diskUsage.free
    }
    
    private var purelyFree: Double {
        max(systemMonitor.diskUsage.free - systemMonitor.diskUsage.purgeable, 0)
    }
    
    private var diskPercent: Double {
        guard systemMonitor.diskUsage.total > 0 else { return 0 }
        return (usedDisk / systemMonitor.diskUsage.total) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Disk Usage Card
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    // Circular progress gauge
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        
                        Circle()
                            .trim(from: 0, to: diskPercent / 100)
                            .stroke(
                                diskColor(diskPercent).gradient,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: diskPercent)
                        
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", diskPercent))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(diskColor(diskPercent))
                            Text("%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Storage stats
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "internaldrive.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.mint.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Used")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(formatGB(usedDisk))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.mint)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.green.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Free")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(formatGB(purelyFree))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.green)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(1)
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
                
                // Storage breakdown bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Storage Breakdown")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Total: \(formatGB(systemMonitor.diskUsage.total))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.mint, Color.mint.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(diskPercent / 100))
                            
                            HStack {
                                if diskPercent > 15 {
                                    Text(String(format: "%.1f%%", diskPercent))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.leading, 8)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 24)
                    
                    // Space legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.mint).frame(width: 6, height: 6)
                            Text("Used \(formatGB(usedDisk))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        if systemMonitor.diskUsage.purgeable > 1 {
                            HStack(spacing: 4) {
                                Circle().fill(Color.yellow.opacity(0.8)).frame(width: 6, height: 6)
                                Text("Purgeable \(formatGB(systemMonitor.diskUsage.purgeable))")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                            Text("Free \(formatGB(purelyFree))")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Disk I/O Rate badges
            if systemMonitor.diskReadRate > 0 || systemMonitor.diskWriteRate > 0 {
                HStack(spacing: 10) {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.mint)
                            .font(.system(size: 11))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Read").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(String(format: "%.1f MB/s", systemMonitor.diskReadRate))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.mint)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Write").font(.system(size: 9)).foregroundColor(.secondary)
                            Text(String(format: "%.1f MB/s", systemMonitor.diskWriteRate))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Disk I/O History
            if !systemMonitor.diskReadHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I/O History")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.mint).frame(width: 6, height: 6)
                            Text("Read").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        }
                        GenericSparklineView(data: systemMonitor.diskReadHistory, color: .mint)
                            .frame(height: 30)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                            Text("Write").font(.system(size: 9, weight: .medium)).foregroundColor(.secondary)
                        }
                        GenericSparklineView(data: systemMonitor.diskWriteHistory, color: .orange)
                            .frame(height: 30)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Top Disk Processes Section
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.mint)
                    Text("Top Disk Processes")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                if systemMonitor.topDiskProcesses.isEmpty {
                    Text("No significant disk activity")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    ForEach(Array(systemMonitor.topDiskProcesses.prefix(5).enumerated()), id: \.element.id) { index, process in
                        DiskProcessRowView(process: process, rank: index + 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Time Machine Card
            if systemMonitor.timeMachineInfo.isConfigured {
                HStack(spacing: 12) {
                    Image(systemName: systemMonitor.timeMachineInfo.isBackingUp
                          ? "arrow.clockwise.circle.fill"
                          : "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            systemMonitor.timeMachineInfo.isBackingUp
                                ? Color.blue.gradient
                                : Color.mint.gradient
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Time Machine")
                            .font(.system(size: 12, weight: .semibold))
                        if systemMonitor.timeMachineInfo.isBackingUp {
                            Text("Backing up…")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                        } else if let date = systemMonitor.timeMachineInfo.lastBackupDate {
                            Text("Last backup: \(relativeBackupString(date))")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No backups yet")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private func relativeBackupString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func diskColor(_ percent: Double) -> Color {
        switch percent {
        case 0..<60: return .mint
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func formatGB(_ gb: Double) -> String {
        if gb >= 1000 {
            return String(format: "%.1f TB", gb / 1000)
        } else {
            return String(format: "%.0f GB", gb)
        }
    }
}

// Disk Process Row View
struct DiskProcessRowView: View {
    let process: ProcessDiskInfo
    let rank: Int
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .mint
        }
    }
    
    private var usageWidth: CGFloat {
        // Scale bar relative to 10 MB/s max
        CGFloat(min(process.totalIO / (10 * 1_048_576), 1.0))
    }
    
    private func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fM", bytesPerSec / 1_048_576)
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0fK", bytesPerSec / 1024)
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
                        Text(formatRate(process.bytesRead))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.blue)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 7))
                        Text(formatRate(process.bytesWritten))
                            .font(.system(size: 8, design: .monospaced))
                    }
                    .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Usage bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.mint)
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
        .drawingGroup()
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

// MARK: - Per-Core CPU Usage Grid
struct CoreUsageGridView: View {
    let coreUsages: [Double]
    let pCoreCount: Int
    private let barH: CGFloat = 22

    private func coreColor(_ i: Int) -> Color {
        guard pCoreCount > 0 else { return .orange }
        return i < pCoreCount ? .orange : .blue
    }

    var body: some View {
        let perRow = min(coreUsages.count, 12)
        let rowCount = max(1, (coreUsages.count + perRow - 1) / perRow)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 4) {
                    let start = row * perRow
                    let end = min(start + perRow, coreUsages.count)
                    ForEach(start..<end, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", coreUsages[i]))
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundColor(coreColor(i))
                                .lineLimit(1)
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(coreColor(i).opacity(0.15))
                                    .frame(height: barH)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(coreColor(i))
                                    .frame(height: max(1, barH * CGFloat(coreUsages[i] / 100)))
                            }
                            .frame(height: barH)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// Power Sparkline View
struct PowerSparklineView: View {
    let data: [Double]
    let maxWatts: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Path { path in
                    for i in 0...4 {
                        let y = geometry.size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                LinearGradient(
                    colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1), Color.yellow.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .mask(areaPath(in: geometry.size))

                linePath(in: geometry.size)
                    .stroke(
                        LinearGradient(colors: [Color.yellow, Color.orange],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.yellow.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            let scale = max(maxWatts, data.max() ?? 1)
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / scale) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / scale) * size.height))
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            let scale = max(maxWatts, data.max() ?? 1)
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / scale) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / scale) * size.height))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}

// Memory Sparkline View - mirrors CPUSparklineView with purple colouring
struct MemorySparklineView: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Path { path in
                    for i in 0...4 {
                        let y = geometry.size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))

                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .mask(areaPath(in: geometry.size))

                linePath(in: geometry.size)
                    .stroke(
                        LinearGradient(colors: [Color.purple, Color.purple.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Color.purple.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / 100) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / 100) * size.height))
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard !data.isEmpty else { return }
            let stepX = size.width / CGFloat(max(data.count - 1, 1))
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / 100) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / 100) * size.height))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}

// Generic sparkline for any already-scaled rate data (MB/s, etc.)
struct GenericSparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
                .mask(areaPath(in: geometry.size))

                linePath(in: geometry.size)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func linePath(in size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }
            let maxVal = max(data.max() ?? 1, 0.001)
            let stepX = size.width / CGFloat(data.count - 1)
            path.move(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / maxVal) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / maxVal) * size.height))
            }
        }
    }

    private func areaPath(in size: CGSize) -> Path {
        Path { path in
            guard data.count > 1 else { return }
            let maxVal = max(data.max() ?? 1, 0.001)
            let stepX = size.width / CGFloat(data.count - 1)
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height - CGFloat(data[0] / maxVal) * size.height))
            for (i, v) in data.enumerated() {
                path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height - CGFloat(v / maxVal) * size.height))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}

// Power Section
struct PowerSectionView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var preferences: PreferencesManager

    private var watts: Double { systemMonitor.powerConsumptionInfo.totalSystemPower }
    private var cpuWatts: Double { systemMonitor.powerConsumptionInfo.cpuPower }
    private var gpuWatts: Double { systemMonitor.powerConsumptionInfo.gpuPower }
    private var isEstimate: Bool { systemMonitor.powerConsumptionInfo.isEstimate }
    private var temp: Double { systemMonitor.cpuTemperature }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main power card
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    // Watts gauge — ring scaled to 100 W
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0, to: min(watts / systemMonitor.thermalProfile.powerRed, 1))
                            .stroke(powerColor(watts).gradient,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: watts)
                        VStack(spacing: 1) {
                            Text(watts >= 100
                                 ? String(format: "%.0f", watts)
                                 : String(format: "%.1f", watts))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(powerColor(watts))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("W")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    // CPU / GPU breakdown badges
                    VStack(alignment: .leading, spacing: 8) {
                        if cpuWatts > 0 {
                            powerBadge(label: "CPU", value: cpuWatts, icon: "cpu.fill", color: .orange)
                        }
                        if gpuWatts > 0 {
                            powerBadge(label: "GPU", value: gpuWatts, icon: "display", color: .blue)
                        }
                        if cpuWatts == 0 && gpuWatts == 0 {
                            powerBadge(label: "System", value: watts, icon: "power", color: .yellow)
                        }
                    }

                    Spacer()
                }
                .padding(20)

                // Temperatures row
                HStack(spacing: 10) {
                    powerTempBadge(label: "CPU", temp: temp, icon: "thermometer.medium")
                    if systemMonitor.gpuTemperature > 0 {
                        powerTempBadge(label: "GPU", temp: systemMonitor.gpuTemperature, icon: "display")
                    }
                    if systemMonitor.memoryTemperature > 0 {
                        powerTempBadge(label: "RAM", temp: systemMonitor.memoryTemperature, icon: "memorychip")
                    }
                    if systemMonitor.ssdTemperature > 0 {
                        powerTempBadge(label: "SSD", temp: systemMonitor.ssdTemperature, icon: "internaldrive")
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Fan row
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "fan.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Fan")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            let rpm = systemMonitor.fanInfo.speeds.first.map { Double($0) }
                                        ?? systemMonitor.fanInfo.rpm
                            Text(String(format: "%.0f RPM", rpm))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.blue)
                            if let target = systemMonitor.fanInfo.targetSpeeds.first {
                                Text(String(format: "→ %d tgt", target))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, systemMonitor.dcInPower > 0 ? 8 : 16)

                // DC-in power row (if available)
                if systemMonitor.dcInPower > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "powerplug.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.green.gradient)
                        Text("Wall Power")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f W", systemMonitor.dcInPower))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Power History Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Power History")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Last \(systemMonitor.powerHistory.count) samples")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                if !systemMonitor.powerHistory.isEmpty {
                    PowerSparklineView(data: systemMonitor.powerHistory,
                                       maxWatts: systemMonitor.thermalProfile.powerRed)
                        .frame(height: 50)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.yellow.opacity(0.1))
                        .frame(height: 50)
                        .overlay(Text("Loading...").font(.system(size: 10)).foregroundColor(.secondary))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Battery card (shown when a battery is present, i.e. on laptops)
            if systemMonitor.batteryInfo.present {
                let battery = systemMonitor.batteryInfo
                let hasExtraStats = battery.cycleCount > 0
                    || (battery.maxCapacity > 0 && battery.maxCapacity <= 100)
                    || battery.temperature > 0
                    || (battery.amperage != 0 && battery.voltage > 0)
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: batteryIcon(battery.chargeLevel,
                                                       charging: battery.isCharging))
                            .font(.system(size: 14))
                            .foregroundColor(batteryColor(battery.chargeLevel))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Battery")
                                .font(.system(size: 11, weight: .semibold))
                            Text(battery.isCharging
                                 ? "Charging"
                                 : (battery.isPluggedIn ? "Plugged In" : "On Battery"))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", battery.chargeLevel))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(batteryColor(battery.chargeLevel))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                    ProgressView(value: battery.chargeLevel, total: 100)
                        .tint(batteryColor(battery.chargeLevel))
                        .padding(.horizontal, 20)
                        .padding(.bottom, (battery.timeRemaining > 0 || hasExtraStats) ? 8 : 16)

                    if battery.timeRemaining != 0 {
                        HStack {
                            Text(battery.isCharging ? "Time to Full" : "Time Remaining")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(battery.timeRemaining < 0
                                 ? "Calculating…"
                                 : formatMinutes(battery.timeRemaining))
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, hasExtraStats ? 8 : 14)
                    }

                    if hasExtraStats {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            if battery.cycleCount > 0 {
                                batteryStat(label: "Cycles", value: "\(battery.cycleCount)",
                                            icon: "arrow.triangle.2.circlepath", color: .blue)
                            }
                            if battery.maxCapacity > 0 && battery.maxCapacity <= 100 {
                                batteryStat(label: "Health", value: "\(battery.maxCapacity)%",
                                            icon: "heart.fill", color: healthColor(battery.maxCapacity))
                            }
                            if battery.temperature > 0 {
                                batteryStat(label: "Temp", value: formatTemp(battery.temperature),
                                            icon: "thermometer.medium",
                                            color: tempColor(battery.temperature))
                            }
                            if battery.amperage != 0 && battery.voltage > 0 {
                                let watts = abs(battery.amperage / 1000.0 * battery.voltage / 1000.0)
                                let charging = battery.amperage > 0
                                batteryStat(label: charging ? "Charge Rate" : "Discharge",
                                            value: String(format: "%.1f W", watts),
                                            icon: charging ? "bolt.fill" : "minus.plus.batteryblock",
                                            color: charging ? .green : .orange)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 14)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Adapter card
            let adapter = systemMonitor.powerConsumptionInfo.adapterInfo
            if adapter.isConnected && adapter.wattage > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.green.gradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Power Adapter")
                            .font(.system(size: 11, weight: .semibold))
                        let label = adapter.model.isEmpty || adapter.model == "Unknown"
                            ? "\(adapter.wattage)W \(adapter.type)"
                            : adapter.model
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(adapter.wattage)W")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer().frame(height: 16)
        }
    }

    @ViewBuilder
    private func powerTempBadge(label: String, temp: Double, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(tempColor(temp))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(formatTemp(temp))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(tempColor(temp))
            }
        }
    }

    @ViewBuilder
    private func powerBadge(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.gradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f W", value))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
    }

    private func formatTemp(_ celsius: Double) -> String {
        preferences.temperatureUnit == .fahrenheit
            ? String(format: "%.0f°F", TemperatureMonitor.celsiusToFahrenheit(celsius))
            : String(format: "%.0f°C", celsius)
    }

    private func powerColor(_ w: Double) -> Color {
        systemMonitor.thermalProfile.powerColor(w)
    }

    private func tempColor(_ c: Double) -> Color {
        systemMonitor.thermalProfile.temperatureColor(c)
    }

    private func batteryIcon(_ pct: Double, charging: Bool) -> String {
        if charging { return pct >= 99 ? "battery.100.bolt" : "battery.100.bolt" }
        switch pct {
        case 0..<12.5:  return "battery.0"
        case 12.5..<37.5: return "battery.25"
        case 37.5..<62.5: return "battery.50"
        case 62.5..<87.5: return "battery.75"
        default:         return "battery.100"
        }
    }

    private func batteryColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<20: return .red
        case 20..<40: return .orange
        default: return .green
        }
    }

    private func healthColor(_ pct: Int) -> Color {
        switch pct {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }

    @ViewBuilder
    private func batteryStat(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color.gradient)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m <= 0 { return "--" }
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
    }
}

// Overview Section - at-a-glance dashboard across all subsystems
struct OverviewSectionView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var preferences: PreferencesManager

    private var memPercent: Double {
        guard systemMonitor.memoryUsage.total > 0 else { return 0 }
        return (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
    }

    private var diskPercent: Double {
        guard systemMonitor.diskUsage.total > 0 else { return 0 }
        return ((systemMonitor.diskUsage.total - systemMonitor.diskUsage.free) / systemMonitor.diskUsage.total) * 100
    }

    private var totalWatts: Double {
        systemMonitor.dcInPower > 0 ? systemMonitor.dcInPower : systemMonitor.powerConsumptionInfo.totalSystemPower
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // System identity card
            HStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.blue.gradient)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(systemMonitor.systemInfo.modelName.isEmpty ? "Mac" : systemMonitor.systemInfo.modelName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(systemMonitor.systemInfo.macOSVersion)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(formatUptime(systemMonitor.systemInfo.uptime))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackground)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Metrics grid — 3 columns, dynamic colors
            let battery = systemMonitor.batteryInfo
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                overviewMetric(icon: "cpu.fill", label: "CPU",
                               value: "\(Int(systemMonitor.cpuUsage))%",
                               color: cpuColor(systemMonitor.cpuUsage))
                overviewMetric(icon: "memorychip.fill", label: "Memory",
                               value: "\(Int(memPercent))%",
                               color: memColor(memPercent))
                overviewMetric(icon: "internaldrive.fill", label: "Disk",
                               value: "\(Int(diskPercent))%",
                               color: diskColor(diskPercent))
                overviewMetric(icon: "arrow.down", label: "Download",
                               value: downloadString(),
                               color: .green)
                overviewMetric(icon: "bolt.fill", label: "Power",
                               value: "\(Int(totalWatts))W",
                               color: systemMonitor.thermalProfile.powerColor(totalWatts))
                if battery.present {
                    let pct = battery.chargeLevel
                    overviewMetric(icon: battery.isCharging ? "bolt.fill" : "battery.100",
                                   label: "Battery",
                                   value: "\(Int(pct))%",
                                   color: pct < 20 ? .red : pct < 40 ? .orange : .green)
                } else {
                    overviewMetric(icon: "thermometer.medium", label: "CPU Temp",
                                   value: formatTemp(systemMonitor.cpuTemperature),
                                   color: systemMonitor.thermalProfile.temperatureColor(systemMonitor.cpuTemperature))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Time Machine card (if configured)
            if systemMonitor.timeMachineInfo.isConfigured {
                HStack(spacing: 12) {
                    Image(systemName: systemMonitor.timeMachineInfo.isBackingUp
                          ? "arrow.clockwise.circle.fill" : "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(systemMonitor.timeMachineInfo.isBackingUp
                            ? Color.blue.gradient : Color.mint.gradient)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Time Machine")
                            .font(.system(size: 11, weight: .semibold))
                        if systemMonitor.timeMachineInfo.isBackingUp {
                            Text("Backing up…")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        } else if let date = systemMonitor.timeMachineInfo.lastBackupDate {
                            Text("Last backup: \(relativeString(date))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No backups yet")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(cardBackground)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Top processes summary
            if !systemMonitor.topProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Top Processes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        if systemMonitor.processCount > 0 {
                            Text("\(systemMonitor.processCount) total")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    ForEach(Array(systemMonitor.topProcesses.prefix(3).enumerated()), id: \.element.id) { index, process in
                        ProcessRowView(process: process, rank: index + 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(cardBackground)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer().frame(height: 16)
        }
    }

    @ViewBuilder
    private func overviewMetric(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color.gradient)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.thinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    private func formatUptime(_ uptime: TimeInterval) -> String {
        let t = Int(uptime)
        let d = t / 86400; let h = (t % 86400) / 3600; let m = (t % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return "\(m)m"
    }

    private func downloadString() -> String {
        let mbps = (systemMonitor.networkUsage.download * 8) / 1_000_000
        if mbps >= 1000 { return String(format: "%.1fG", mbps / 1000) }
        if mbps >= 1    { return String(format: "%.0fM", mbps) }
        return String(format: "%.0fK", mbps * 1000)
    }

    private func relativeString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatTemp(_ celsius: Double) -> String {
        preferences.temperatureUnit == .fahrenheit
            ? String(format: "%.0f°F", TemperatureMonitor.celsiusToFahrenheit(celsius))
            : String(format: "%.0f°C", celsius)
    }

    private func cpuColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<80: return .orange
        default: return .red
        }
    }

    private func memColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<50: return .green
        case 50..<70: return .blue
        case 70..<85: return .orange
        default: return .red
        }
    }

    private func diskColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<60: return .mint
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// Battery Section - dedicated tab for laptops
struct BatterySectionView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
    @EnvironmentObject var preferences: PreferencesManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let battery = systemMonitor.batteryInfo

            // Charge card
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: batteryIcon(battery.chargeLevel, charging: battery.isCharging))
                        .font(.system(size: 14))
                        .foregroundColor(batteryColor(battery.chargeLevel))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Battery")
                            .font(.system(size: 11, weight: .semibold))
                        Text(battery.isCharging ? "Charging" : (battery.isPluggedIn ? "Plugged In" : "On Battery"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%%", battery.chargeLevel))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(batteryColor(battery.chargeLevel))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                ProgressView(value: battery.chargeLevel, total: 100)
                    .tint(batteryColor(battery.chargeLevel))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                if battery.timeRemaining != 0 {
                    HStack {
                        Text(battery.isCharging ? "Time to Full" : "Time Remaining")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(battery.timeRemaining < 0 ? "Calculating…" : formatMinutes(battery.timeRemaining))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .background(cardBackground)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Health & stats grid
            let hasExtraStats = battery.cycleCount > 0
                || (battery.maxCapacity > 0 && battery.maxCapacity <= 100)
                || battery.temperature > 0
                || (battery.amperage != 0 && battery.voltage > 0)
            if hasExtraStats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    if battery.cycleCount > 0 {
                        batteryStat(label: "Cycles", value: "\(battery.cycleCount)",
                                    icon: "arrow.triangle.2.circlepath", color: .blue)
                    }
                    if battery.maxCapacity > 0 && battery.maxCapacity <= 100 {
                        batteryStat(label: "Health", value: "\(battery.maxCapacity)%",
                                    icon: "heart.fill", color: healthColor(battery.maxCapacity))
                    }
                    if battery.temperature > 0 {
                        batteryStat(label: "Temp", value: formatTemp(battery.temperature),
                                    icon: "thermometer.medium",
                                    color: systemMonitor.thermalProfile.temperatureColor(battery.temperature))
                    }
                    if battery.amperage != 0 && battery.voltage > 0 {
                        let watts = abs(battery.amperage / 1000.0 * battery.voltage / 1000.0)
                        let charging = battery.amperage > 0
                        batteryStat(label: charging ? "Charge Rate" : "Discharge",
                                    value: String(format: "%.1f W", watts),
                                    icon: charging ? "bolt.fill" : "minus.plus.batteryblock",
                                    color: charging ? .green : .orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            // Adapter card
            let adapter = systemMonitor.powerConsumptionInfo.adapterInfo
            if adapter.isConnected && adapter.wattage > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.green.gradient)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Power Adapter")
                            .font(.system(size: 11, weight: .semibold))
                        let label = adapter.model.isEmpty || adapter.model == "Unknown"
                            ? "\(adapter.wattage)W \(adapter.type)"
                            : adapter.model
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(adapter.wattage)W")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(cardBackground)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer().frame(height: 16)
        }
    }

    @ViewBuilder
    private func batteryStat(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color.gradient)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color(NSColor.controlBackgroundColor).opacity(0.5)))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.thinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
    }

    private func batteryIcon(_ pct: Double, charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        switch pct {
        case 0..<12.5:    return "battery.0"
        case 12.5..<37.5: return "battery.25"
        case 37.5..<62.5: return "battery.50"
        case 62.5..<87.5: return "battery.75"
        default:          return "battery.100"
        }
    }

    private func batteryColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<20: return .red
        case 20..<40: return .orange
        default: return .green
        }
    }

    private func healthColor(_ pct: Int) -> Color {
        switch pct {
        case 80...: return .green
        case 60..<80: return .yellow
        default: return .orange
        }
    }

    private func formatTemp(_ celsius: Double) -> String {
        preferences.temperatureUnit == .fahrenheit
            ? String(format: "%.0f°F", TemperatureMonitor.celsiusToFahrenheit(celsius))
            : String(format: "%.0f°C", celsius)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let m = Int(minutes)
        if m <= 0 { return "--" }
        return m < 60 ? "\(m)m" : "\(m / 60)h \(m % 60)m"
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
            systemMonitor.didUpdate
                .sink { _ in
                    DispatchQueue.main.async {
                        imageManager.forceImageUpdate()
                    }
                }
                .store(in: &cancellables)
            
            // Network interface changes should trigger a refresh
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
