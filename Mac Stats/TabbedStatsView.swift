//
//  TabbedStatsView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

enum StatsCategory: String, CaseIterable {
    case overview = "Overview"
    case performance = "Performance" 
    case storage = "Storage"
    case network = "Network"
    case power = "Power"
    case system = "System"
    
    var icon: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .performance: return "speedometer"
        case .storage: return "internaldrive.fill"
        case .network: return "network"
        case .power: return "bolt.fill"
        case .system: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .overview: return .blue
        case .performance: return .orange
        case .storage: return .purple
        case .network: return .green
        case .power: return .yellow
        case .system: return .gray
        }
    }
}

struct TabbedStatsView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var externalIPManager: ExternalIPManager
    @Environment(\.openWindow) private var openWindow
    @State private var selectedCategory: StatsCategory = .overview
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Category Picker
            categoryPicker
            
            // Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    contentForCategory(selectedCategory)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            print("TabbedStatsView appeared")
            if !systemMonitor.initialDataLoaded {
                print("Data not loaded, forcing refresh...")
                systemMonitor.refreshAllData()
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("Mac Stats")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: {
                    print("Refresh button pressed - forcing data refresh")
                    systemMonitor.refreshAllData()
                    externalIPManager.refreshExternalIP()
                    systemMonitor.testSystemCalls()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .help("Refresh Data")
                
                Button("Settings") {
                    openWindow(id: "settings")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Category Picker
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatsCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func categoryButton(for category: StatsCategory) -> some View {
        Button(action: {
            selectedCategory = category
        }) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedCategory == category ? category.color.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedCategory == category ? category.color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(selectedCategory == category ? category.color : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Content for Categories
    @ViewBuilder
    private func contentForCategory(_ category: StatsCategory) -> some View {
        switch category {
        case .overview:
            overviewContent
        case .performance:
            performanceContent
        case .storage:
            storageContent
        case .network:
            networkContent
        case .power:
            powerContent
        case .system:
            systemContent
        }
    }
    
    // MARK: - Overview Content
    private var overviewContent: some View {
        VStack(spacing: 12) {
            // Quick stats grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // CPU Summary
                if preferences.showCPU {
                    CompactStatsCard(
                        title: "CPU Usage",
                        value: String(format: "%.1f%%", systemMonitor.cpuUsage),
                        icon: "cpu",
                        color: usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)),
                        subtitle: systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo
                    )
                }
                
                // Memory Summary
                if preferences.showMemory {
                    let memoryPercent = (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
                    CompactStatsCard(
                        title: "Memory Usage",
                        value: String(format: "%.1f%%", memoryPercent),
                        icon: "memorychip",
                        color: memoryUsageColor(for: memoryPercent),
                        subtitle: String(format: "%.1f / %.1f GB", systemMonitor.memoryUsage.used, systemMonitor.memoryUsage.total)
                    )
                }
                
                // Disk Summary
                if preferences.showDisk {
                    let diskPercent = ((systemMonitor.diskUsage.total - systemMonitor.diskUsage.free) / systemMonitor.diskUsage.total) * 100
                    CompactStatsCard(
                        title: "Disk Usage",
                        value: String(format: "%.1f%%", diskPercent),
                        icon: "internaldrive",
                        color: .purple,
                        subtitle: String(format: "%.0f GB free", systemMonitor.diskUsage.free)
                    )
                }
                
                // Network Summary
                if preferences.showNetwork {
                    let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
                    let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                    CompactStatsCard(
                        title: "Network",
                        value: "\(downloadFormatted.value) \(downloadFormatted.unit)",
                        icon: "arrow.down.circle",
                        color: .blue,
                        subtitle: "Download"
                    )
                }
            }
            
            // System Overview Card
            systemOverviewCard
            
            // Quick Battery/UPS Status
            if systemMonitor.batteryInfo.present {
                quickBatteryCard
            } else if systemMonitor.upsInfo.present && systemMonitor.upsInfo.name != "Power Device" {
                quickUPSCard
            }
        }
    }
    
    // MARK: - Performance Content
    private var performanceContent: some View {
        VStack(spacing: 12) {
            if preferences.showCPU {
                fullCPUCard
            }
            
            if preferences.showMemory {
                fullMemoryCard
            }
            
            // Combined processes card
            if !systemMonitor.topProcesses.isEmpty || !systemMonitor.topMemoryProcesses.isEmpty {
                processesCard
            }
        }
    }
    
    // MARK: - Storage Content
    private var storageContent: some View {
        VStack(spacing: 12) {
            if preferences.showDisk {
                fullDiskCard
            }
            
            // Future: Add more storage-related cards here
            // - Individual disk info
            // - Network attached storage
            // - External drives
        }
    }
    
    // MARK: - Network Content
    private var networkContent: some View {
        VStack(spacing: 12) {
            if preferences.showNetwork {
                fullNetworkCard
            }
            
            // Network interfaces card
            networkInterfacesCard
            
            // External IP card
            if !externalIPManager.externalIP.isEmpty {
                externalIPCard
            }
        }
    }
    
    // MARK: - Power Content
    private var powerContent: some View {
        VStack(spacing: 12) {
            if preferences.showPowerConsumption && systemMonitor.powerConsumptionInfo.totalSystemPower > 0 {
                fullPowerConsumptionCard
            }
            
            if systemMonitor.batteryInfo.present {
                fullBatteryCard
            }
            
            if systemMonitor.upsInfo.present {
                fullUPSCard
            }
        }
    }
    
    // MARK: - System Content
    private var systemContent: some View {
        VStack(spacing: 12) {
            fullSystemInfoCard
            
            if preferences.showCPUTemperature {
                temperatureCard
            }
            
            // System resources card
            systemResourcesCard
        }
    }
    
    // MARK: - Card Implementations
    
    private var systemOverviewCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "System Overview", icon: "desktopcomputer", color: .blue)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    InfoRowView(label: "Model", value: systemMonitor.systemInfo.modelName.isEmpty ? "Loading..." : systemMonitor.systemInfo.modelName)
                    InfoRowView(label: "Uptime", value: formatUptime(systemMonitor.systemInfo.uptime))
                    InfoRowView(label: "macOS", value: systemMonitor.systemInfo.macOSVersion)
                    InfoRowView(label: "Chip", value: systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                }
            }
        }
    }
    
    private var quickBatteryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                CardHeaderView(title: "Battery", icon: getBatteryIconName(), color: getBatteryIconColor())
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Charge Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", systemMonitor.batteryInfo.chargeLevel))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(batteryChargeColor(for: systemMonitor.batteryInfo.chargeLevel))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(systemMonitor.batteryInfo.isCharging ? "Charging" : "Not Charging")
                            .font(.caption)
                            .foregroundColor(systemMonitor.batteryInfo.isCharging ? .green : .secondary)
                        if systemMonitor.batteryInfo.timeRemaining > 0 {
                            Text(formatTime(systemMonitor.batteryInfo.timeRemaining))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var quickUPSCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                CardHeaderView(title: "UPS", icon: getUPSIconName(), color: getUPSIconColor())
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Power Source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(systemMonitor.upsInfo.powerSource.isEmpty ? "AC Power" : systemMonitor.upsInfo.powerSource)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                    }
                    
                    Spacer()
                    
                    if systemMonitor.upsInfo.chargeLevel > 0 {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Charge")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f%%", systemMonitor.upsInfo.chargeLevel))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(upsChargeColor(for: systemMonitor.upsInfo.chargeLevel))
                        }
                    }
                }
            }
        }
    }
    
    // Include all the existing card implementations from CardBasedStatsView
    private var fullCPUCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "CPU Usage", icon: "cpu", color: .orange)
                
                VStack(alignment: .leading, spacing: 12) {
                    // CPU Usage Progress with frequency info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Current Usage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", systemMonitor.cpuUsage))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        ProgressView(value: systemMonitor.cpuUsage, total: 100)
                            .tint(usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)))
                            .scaleEffect(y: 1.5)
                    }
                    
                    // CPU Info Row
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Multi-core")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // CPU Sparkline with enhanced info
                    if !systemMonitor.cpuHistory.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Usage Trend")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                let avgUsage = systemMonitor.cpuHistory.reduce(0, +) / Double(systemMonitor.cpuHistory.count)
                                let maxUsage = systemMonitor.cpuHistory.max() ?? 0
                                
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("Avg: \(String(format: "%.1f%%", avgUsage))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                    Text("Peak: \(String(format: "%.1f%%", maxUsage))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(usageColor(for: maxUsage, thresholds: (30, 70)))
                                }
                            }
                            
                            SparklineView(
                                data: systemMonitor.cpuHistory,
                                lineColor: usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)),
                                lineWidth: 2
                            )
                            .frame(height: 35)
                        }
                    }
                    
                    // Top CPU Processes
                    if !systemMonitor.topProcesses.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Top CPU Processes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                if systemMonitor.initialDataLoaded {
                                    ForEach(systemMonitor.topProcesses.prefix(5)) { process in
                                        enhancedProcessRowView(process: process, isCPUView: true)
                                    }
                                } else {
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Add the remaining card implementations (memory, network, etc.)
    // For brevity, I'll include placeholders - these should use the same implementations from CardBasedStatsView
    
    private var fullMemoryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Memory Usage", icon: "memorychip", color: .blue)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Used Memory")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f GB / %.1f GB", systemMonitor.memoryUsage.used, systemMonitor.memoryUsage.total))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        ProgressView(value: systemMonitor.memoryUsage.used, total: systemMonitor.memoryUsage.total)
                            .tint(memoryUsageColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                            .scaleEffect(y: 1.5)
                    }
                    
                    // Enhanced memory breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("Free")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            let freeMemory = systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used
                            let freePercent = (freeMemory / systemMonitor.memoryUsage.total) * 100
                            
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%.1f GB", freeMemory))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.green)
                                Text(String(format: "%.1f%%", freePercent))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.green)
                            }
                        }
                        
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                Text("Used")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            let usedPercent = (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
                            
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%.1f GB", systemMonitor.memoryUsage.used))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f%%", usedPercent))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Memory pressure indicator
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(memoryPressureColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                                    .frame(width: 8, height: 8)
                                Text("Pressure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(memoryPressureText(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(memoryPressureColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                        }
                    }
                    
                    // Top Memory Processes with enhanced display
                    if !systemMonitor.topMemoryProcesses.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Top Memory Processes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                let totalMemUsage = systemMonitor.topMemoryProcesses.prefix(5).reduce(0) { $0 + $1.memoryUsage }
                                Text("Total: \(String(format: "%.1f%%", totalMemUsage))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .opacity(0.7)
                                    .monospacedDigit()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                if systemMonitor.initialDataLoaded {
                                    ForEach(systemMonitor.topMemoryProcesses.prefix(5)) { process in
                                        enhancedProcessRowView(process: process, isCPUView: false)
                                    }
                                } else {
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var fullNetworkCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Network Activity", icon: "network", color: .green)
                
                VStack(alignment: .leading, spacing: 8) {
                    let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
                    let uploadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.upload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                    let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                    
                    // Current speeds with enhanced display
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                Text("Upload")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("\(uploadFormatted.value) \(uploadFormatted.unit)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                // Upload sparkline
                                if !systemMonitor.uploadHistory.isEmpty {
                                    SparklineView(
                                        data: systemMonitor.uploadHistory.map { $0 / 1000 }, // Convert to KB for better scale
                                        lineColor: .red,
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 60, height: 25)
                                }
                            }
                        }
                        
                        Divider()
                            .frame(height: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                Text("Download")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("\(downloadFormatted.value) \(downloadFormatted.unit)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                                
                                Spacer()
                                
                                // Download sparkline
                                if !systemMonitor.downloadHistory.isEmpty {
                                    SparklineView(
                                        data: systemMonitor.downloadHistory.map { $0 / 1000 }, // Convert to KB for better scale
                                        lineColor: .blue,
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 60, height: 25)
                                }
                            }
                        }
                    }
                    
                    // Peak speeds
                    if !systemMonitor.uploadHistory.isEmpty || !systemMonitor.downloadHistory.isEmpty {
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Peak Speeds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if let maxUpload = systemMonitor.uploadHistory.max() {
                                        let maxUploadFormatted = NetworkFormatter.formatNetworkValue(maxUpload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↑ \(maxUploadFormatted.value) \(maxUploadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.red)
                                    }
                                    
                                    if let maxDownload = systemMonitor.downloadHistory.max() {
                                        let maxDownloadFormatted = NetworkFormatter.formatNetworkValue(maxDownload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↓ \(maxDownloadFormatted.value) \(maxDownloadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if !systemMonitor.uploadHistory.isEmpty {
                                        let avgUpload = systemMonitor.uploadHistory.reduce(0, +) / Double(systemMonitor.uploadHistory.count)
                                        let avgUploadFormatted = NetworkFormatter.formatNetworkValue(avgUpload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↑ \(avgUploadFormatted.value) \(avgUploadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.red)
                                    }
                                    
                                    if !systemMonitor.downloadHistory.isEmpty {
                                        let avgDownload = systemMonitor.downloadHistory.reduce(0, +) / Double(systemMonitor.downloadHistory.count)
                                        let avgDownloadFormatted = NetworkFormatter.formatNetworkValue(avgDownload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↓ \(avgDownloadFormatted.value) \(avgDownloadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    private var fullDiskCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Disk Usage", icon: "internaldrive", color: .purple)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Used Space")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f GB / %.0f GB", systemMonitor.diskUsage.total - systemMonitor.diskUsage.free, systemMonitor.diskUsage.total))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        ProgressView(value: systemMonitor.diskUsage.total - systemMonitor.diskUsage.free, total: systemMonitor.diskUsage.total)
                            .tint(.purple)
                            .scaleEffect(y: 1.5)
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Free")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.0f GB", systemMonitor.diskUsage.free))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                            Text("Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f%% (%.0f GB)", ((systemMonitor.diskUsage.total - systemMonitor.diskUsage.free) / systemMonitor.diskUsage.total) * 100, systemMonitor.diskUsage.total - systemMonitor.diskUsage.free))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.purple)
                    }
                }
            }
        }
    }
    
    // Add helper functions for memory pressure
    private func memoryPressureColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<60:
            return .green
        case 60..<80:
            return .yellow
        case 80...100:
            return .red
        default:
            return .gray
        }
    }
    
    private func memoryPressureText(for percentage: Double) -> String {
        switch percentage {
        case 0..<60:
            return "Normal"
        case 60..<80:
            return "Warning"
        case 80...100:
            return "Critical"
        default:
            return "Unknown"
        }
    }
    
    // Add the remaining card implementations (memory, network, etc.)
    // For brevity, I'll include placeholders - these should use the same implementations from CardBasedStatsView
    
    private var fullPowerConsumptionCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Power Consumption", icon: "bolt.fill", color: .yellow)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "power")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                        Text("Total System")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f W", systemMonitor.powerConsumptionInfo.totalSystemPower))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                    }
                    
                    if systemMonitor.powerConsumptionInfo.cpuPower > 0 {
                        InfoRowView(label: "CPU", value: String(format: "%.2f W", systemMonitor.powerConsumptionInfo.cpuPower), valueColor: .orange)
                    }
                    
                    if systemMonitor.powerConsumptionInfo.gpuPower > 0 {
                        InfoRowView(label: "GPU", value: String(format: "%.2f W", systemMonitor.powerConsumptionInfo.gpuPower), valueColor: .blue)
                    }
                    
                    // Power Adapter Information (only show on laptops when adapter is connected)
                    let adapterInfo = systemMonitor.powerConsumptionInfo.adapterInfo
                    if adapterInfo.isConnected && adapterInfo.wattage > 0 {
                        Divider()
                        
                        // Adapter model and wattage
                        HStack {
                            Image(systemName: getPowerAdapterIcon(for: adapterInfo.type))
                                .foregroundColor(.green)
                                .font(.subheadline)
                            Text("Power Adapter")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(adapterInfo.wattage)W \(adapterInfo.type)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                if !adapterInfo.model.isEmpty && adapterInfo.model != "Unknown" {
                                    Text(adapterInfo.model)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // Input power and efficiency
                        if adapterInfo.inputPower > 0 {
                            let usagePercent = (adapterInfo.inputPower / Double(adapterInfo.wattage)) * 100
                            
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    Text("Input Power")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "%.1f W", adapterInfo.inputPower))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .foregroundColor(.blue)
                                    Text(String(format: "%.0f%% of capacity", usagePercent))
                                        .font(.caption2)
                                        .monospacedDigit()
                                        .foregroundColor(getAdapterUsageColor(for: usagePercent))
                                }
                            }
                            
                            // Visual progress bar for adapter usage
                            VStack(alignment: .leading, spacing: 2) {
                                ProgressView(value: adapterInfo.inputPower, total: Double(adapterInfo.wattage))
                                    .tint(getAdapterUsageColor(for: usagePercent))
                                    .scaleEffect(y: 0.8)
                            }
                        }
                        
                        // Charging efficiency if available
                        if adapterInfo.efficiency > 0 {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "speedometer")
                                        .foregroundColor(.purple)
                                        .font(.caption)
                                    Text("Efficiency")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f%%", adapterInfo.efficiency))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(getEfficiencyColor(for: adapterInfo.efficiency))
                            }
                        }
                    }
                    
                    if systemMonitor.powerConsumptionInfo.isEstimate {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text(adapterInfo.isConnected ? "Power data estimated" : "Estimated based on system load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var fullBatteryCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Battery Status", icon: getBatteryIconName(), color: getBatteryIconColor())
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Charge Level")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", systemMonitor.batteryInfo.chargeLevel))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        ProgressView(value: systemMonitor.batteryInfo.chargeLevel, total: 100)
                            .tint(batteryChargeColor(for: systemMonitor.batteryInfo.chargeLevel))
                            .scaleEffect(y: 1.5)
                    }
                    
                    InfoRowView(label: "Cycle Count", value: "\(systemMonitor.batteryInfo.cycleCount)")
                    InfoRowView(label: "Time Remaining", value: formatTime(systemMonitor.batteryInfo.timeRemaining))
                    InfoRowView(label: "Max Capacity", value: "\(systemMonitor.batteryInfo.maxCapacity)%")
                    
                    if systemMonitor.batteryInfo.health != "Unknown" {
                        InfoRowView(label: "Health", value: systemMonitor.batteryInfo.health)
                    }
                    
                    if systemMonitor.batteryInfo.temperature > 0 {
                        InfoRowView(label: "Temperature", value: String(format: "%.1f°C", systemMonitor.batteryInfo.temperature))
                    }
                    
                    if systemMonitor.batteryInfo.voltage > 0 {
                        InfoRowView(label: "Voltage", value: String(format: "%.0f mV", systemMonitor.batteryInfo.voltage))
                    }
                    
                    if systemMonitor.batteryInfo.amperage != 0 {
                        InfoRowView(label: "Current", value: String(format: "%.0f mA", systemMonitor.batteryInfo.amperage))
                    }
                    
                    HStack {
                        Text("Charging")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(systemMonitor.batteryInfo.isCharging ? "Yes" : "No")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(systemMonitor.batteryInfo.isCharging ? .green : .secondary)
                    }
                }
            }
        }
    }
    
    private var fullUPSCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "UPS Status", icon: getUPSIconName(), color: getUPSIconColor())
                
                VStack(alignment: .leading, spacing: 12) {
                    if systemMonitor.upsInfo.present && systemMonitor.upsInfo.chargeLevel > 0 {
                        // Full UPS info available
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Charge Level")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.0f%%", systemMonitor.upsInfo.chargeLevel))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            
                            ProgressView(value: systemMonitor.upsInfo.chargeLevel, total: 100)
                                .tint(upsChargeColor(for: systemMonitor.upsInfo.chargeLevel))
                                .scaleEffect(y: 1.5)
                        }
                        
                        InfoRowView(label: "Name", value: systemMonitor.upsInfo.name)
                        
                        if systemMonitor.upsInfo.timeRemaining > 0 {
                            InfoRowView(label: "Time Remaining", value: formatTime(systemMonitor.upsInfo.timeRemaining))
                        }
                        
                        InfoRowView(label: "Power Source", value: systemMonitor.upsInfo.powerSource.isEmpty ? "AC Power" : systemMonitor.upsInfo.powerSource, 
                                   valueColor: getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                        
                        if systemMonitor.upsInfo.voltage > 0 {
                            InfoRowView(label: "Voltage", value: String(format: "%.1f V", systemMonitor.upsInfo.voltage))
                        }
                        
                        if systemMonitor.upsInfo.loadPercentage > 0 {
                            InfoRowView(label: "Load", value: String(format: "%.1f%%", systemMonitor.upsInfo.loadPercentage))
                        }
                        
                        HStack {
                            Text("Charging")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(systemMonitor.upsInfo.isCharging ? "Yes" : "No")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(systemMonitor.upsInfo.isCharging ? .red : .green)
                        }
                    } else {
                        // Basic power source info
                        InfoRowView(label: "Power Source", value: systemMonitor.upsInfo.powerSource.isEmpty ? "AC Power" : systemMonitor.upsInfo.powerSource, 
                                   valueColor: getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                        
                        if !systemMonitor.upsInfo.name.isEmpty && systemMonitor.upsInfo.name != "Unknown" {
                            InfoRowView(label: "Device", value: systemMonitor.upsInfo.name)
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(systemMonitor.upsInfo.present ? "Limited UPS information" : "Checking for UPS...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var fullSystemInfoCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "System Information", icon: "info.circle", color: .blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRowView(label: "Model", value: systemMonitor.systemInfo.modelName.isEmpty ? "Loading..." : systemMonitor.systemInfo.modelName)
                    InfoRowView(label: "Chip", value: systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                    InfoRowView(label: "macOS", value: systemMonitor.systemInfo.macOSVersion)
                    InfoRowView(label: "Kernel", value: systemMonitor.systemInfo.kernelVersion)
                    InfoRowView(label: "Uptime", value: formatUptime(systemMonitor.systemInfo.uptime))
                    InfoRowView(label: "Boot Time", value: formatBootTime(systemMonitor.systemInfo.bootTime))
                    
                    // Physical memory info
                    let totalPhysicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / (1000 * 1000 * 1000)
                    InfoRowView(label: "Physical Memory", value: String(format: "%.0f GB", totalPhysicalMemory))
                }
            }
        }
    }
    
    private var temperatureCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "CPU Temperature", icon: "thermometer", color: .red)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Current Temperature")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(TemperatureMonitor.formatTemperature(systemMonitor.cpuTemperature, 
                                                                unit: preferences.temperatureUnit, 
                                                                showBoth: preferences.showBothTemperatureUnits))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundColor(temperatureColor(for: systemMonitor.cpuTemperature))
                    }
                    
                    // Temperature sparkline with enhanced info
                    if !systemMonitor.cpuTemperatureHistory.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text("Temperature Trend")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                let avgTemp = systemMonitor.cpuTemperatureHistory.reduce(0, +) / Double(systemMonitor.cpuTemperatureHistory.count)
                                let maxTemp = systemMonitor.cpuTemperatureHistory.max() ?? 0
                                
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("Avg: \(TemperatureMonitor.formatTemperature(avgTemp, unit: preferences.temperatureUnit, showBoth: false))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                    Text("Peak: \(TemperatureMonitor.formatTemperature(maxTemp, unit: preferences.temperatureUnit, showBoth: false))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(temperatureColor(for: maxTemp))
                                }
                            }
                            
                            SparklineView(
                                data: systemMonitor.cpuTemperatureHistory,
                                lineColor: temperatureColor(for: systemMonitor.cpuTemperature),
                                lineWidth: 2
                            )
                            .frame(height: 35)
                        }
                    }
                    
                    HStack {
                        if TemperatureMonitor.hasTemperatureSensors() {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Real sensors")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Estimated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if TemperatureMonitor.shouldSuggestToolInstallation() {
                            Button("Install macmon") {
                                showMacmonInstallation()
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private var systemResourcesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "System Resources", icon: "gear", color: .gray)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Processor count
                    InfoRowView(label: "CPU Cores", value: "\(ProcessInfo.processInfo.processorCount)")
                    
                    // Active processor count
                    InfoRowView(label: "Active Cores", value: "\(ProcessInfo.processInfo.activeProcessorCount)")
                    
                    // Process count
                    let processCount = systemMonitor.topProcesses.count + systemMonitor.topMemoryProcesses.count
                    InfoRowView(label: "Running Processes", value: "\(processCount)")
                    
                    // System load averages (if available)
                    var loadAvg = [Double](repeating: 0, count: 3)
                    let result = getloadavg(&loadAvg, 3)
                    if result != -1 {
                        Divider()
                        
                        HStack {
                            Text("Load Average")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("1m: \(String(format: "%.2f", loadAvg[0]))")
                                    .font(.caption)
                                    .monospacedDigit()
                                Text("5m: \(String(format: "%.2f", loadAvg[1]))")
                                    .font(.caption)
                                    .monospacedDigit()
                                Text("15m: \(String(format: "%.2f", loadAvg[2]))")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                    }
                    
                    // Thermal state (if available)
                    if ProcessInfo.processInfo.thermalState != .nominal {
                        Divider()
                        
                        HStack {
                            Image(systemName: "thermometer")
                                .foregroundColor(getThermalStateColor())
                                .font(.caption)
                            Text("Thermal State")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(getThermalStateText())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(getThermalStateColor())
                        }
                    }
                }
            }
        }
    }
    
    private var processesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Top Processes", icon: "list.bullet", color: .orange)
                
                VStack(alignment: .leading, spacing: 12) {
                    // CPU Processes
                    if !systemMonitor.topProcesses.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Top CPU Processes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(systemMonitor.topProcesses.prefix(5)) { process in
                                    enhancedProcessRowView(process: process, isCPUView: true)
                                }
                            }
                        }
                    }
                    
                    // Memory Processes
                    if !systemMonitor.topMemoryProcesses.isEmpty {
                        if !systemMonitor.topProcesses.isEmpty {
                            Divider()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "memorychip")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Top Memory Processes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(systemMonitor.topMemoryProcesses.prefix(5)) { process in
                                    enhancedProcessRowView(process: process, isCPUView: false)
                                }
                            }
                        }
                    }
                    
                    if systemMonitor.topProcesses.isEmpty && systemMonitor.topMemoryProcesses.isEmpty {
                        Text(systemMonitor.initialDataLoaded ? "No active processes" : "Loading processes...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
    }
    
    private var networkInterfacesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "Network Interface", icon: "network.badge.shield.half.filled", color: .green)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Active Interface")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: getNetworkInterfaceIcon(for: preferences.selectedNetworkInterface))
                                .foregroundColor(.green)
                                .font(.subheadline)
                            Text(preferences.selectedNetworkInterface)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Interface type description
                    HStack {
                        Text("Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(getNetworkInterfaceType(for: preferences.selectedNetworkInterface))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    // Network unit info
                    Divider()
                    
                    HStack {
                        Text("Display Units")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(preferences.networkUnit == .bits ? "Bits/s" : "Bytes/s")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Auto Scale")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(preferences.autoScaleNetwork ? "Enabled" : "Disabled")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(preferences.autoScaleNetwork ? .green : .secondary)
                    }
                    
                    // Total available interfaces count
                    if !systemMonitor.networkInterfaces.isEmpty {
                        Divider()
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Total Interfaces Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(systemMonitor.networkInterfaces.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var externalIPCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                CardHeaderView(title: "External IP", icon: "globe", color: .green)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("IP Address")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(externalIPManager.externalIP)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.green)
                    }
                    
                    if !externalIPManager.countryName.isEmpty {
                        HStack {
                            Text("Location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack(spacing: 6) {
                                Text(externalIPManager.flagEmoji)
                                    .font(.title2)
                                Text(externalIPManager.countryName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    if !externalIPManager.countryCode.isEmpty {
                        InfoRowView(label: "Country Code", value: externalIPManager.countryCode.uppercased())
                    }
                    
                    // Last updated info
                    if let lastUpdated = externalIPManager.lastUpdated {
                        Divider()
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Last Updated")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatLastUpdated(lastUpdated))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Loading state
                    if externalIPManager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Refreshing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Additional Helper Functions
    
    private func showMacmonInstallation() {
        let alert = NSAlert()
        alert.messageText = "Install macmon for Accurate Temperature"
        alert.informativeText = TemperatureMonitor.getInstallationInstructions()
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("brew install macmon", forType: .string)
        }
    }
    
    private func getPowerAdapterIcon(for type: String) -> String {
        switch type.lowercased() {
        case "magsafe 3", "magsafe3":
            return "cable.connector"
        case "magsafe":
            return "cable.connector"
        case "usb-c", "usbc":
            return "cable.connector.horizontal"
        case "lightning":
            return "bolt.fill"
        default:
            return "cable.connector"
        }
    }
    
    private func getAdapterUsageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return .green
        case 50..<75:
            return .yellow
        case 75..<90:
            return .orange
        case 90...100:
            return .red
        default:
            return .gray
        }
    }
    
    private func getEfficiencyColor(for efficiency: Double) -> Color {
        switch efficiency {
        case 90...100:
            return .green
        case 70..<90:
            return .yellow
        case 50..<70:
            return .orange
        case 0..<50:
            return .red
        default:
            return .gray
        }
    }
    
    private func temperatureColor(for temperatureCelsius: Double) -> Color {
        switch temperatureCelsius {
        case 0..<40:
            return .blue
        case 40..<65:
            return .green
        case 65..<80:
            return .yellow
        case 80..<95:
            return .orange
        case 95...150:
            return .red
        default:
            return .gray
        }
    }
    
    private func getThermalStateColor() -> Color {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    private func getThermalStateText() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "Normal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getNetworkInterfaceIcon(for interface: String) -> String {
        switch interface.lowercased() {
        case let iface where iface.hasPrefix("en"):
            return "ethernet"
        case let iface where iface.hasPrefix("wl") || iface.contains("wifi"):
            return "wifi"
        case "bond0":
            return "point.3.connected.trianglepath.dotted"
        case let iface where iface.hasPrefix("bridge"):
            return "network.badge.shield.half.filled"
        case let iface where iface.hasPrefix("utun") || iface.hasPrefix("ipsec"):
            return "lock.shield"
        default:
            return "network"
        }
    }
    
    private func getNetworkInterfaceType(for interface: String) -> String {
        switch interface.lowercased() {
        case "all":
            return "All Interfaces"
        case let iface where iface.hasPrefix("en"):
            return "Ethernet"
        case let iface where iface.hasPrefix("wl") || iface.contains("wifi"):
            return "Wi-Fi"
        case "bond0":
            return "Bonded Interface"
        case let iface where iface.hasPrefix("bridge"):
            return "Bridge"
        case let iface where iface.hasPrefix("utun") || iface.hasPrefix("ipsec"):
            return "VPN Tunnel"
        case let iface where iface.hasPrefix("lo"):
            return "Loopback"
        default:
            return "Network Interface"
        }
    }
    
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatBootTime(_ bootTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: bootTime)
    }
    
    private func enhancedProcessRowView(process: SystemProcessInfo, isCPUView: Bool) -> some View {
        HStack {
            HStack(spacing: 6) {
                // Process type indicator
                Image(systemName: getProcessIcon(for: process.name))
                    .foregroundColor(getProcessIconColor(for: process.name))
                    .font(.caption)
                    .frame(width: 12)
                
                Text(process.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Text(processValueText(process: process, isCPUView: isCPUView))
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(usageColor(for: isCPUView ? process.cpuUsage : process.memoryUsage, 
                                          thresholds: isCPUView ? (30, 70) : (5, 15)))
                .frame(width: 45, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    // Include all helper functions from the original CardBasedStatsView
    // (I'll skip duplicating them here for brevity, but they should all be included)
    
    private func getProcessIcon(for processName: String) -> String {
        let lowercaseName = processName.lowercased()
        
        if lowercaseName.contains("kernel") || lowercaseName.contains("system") {
            return "gear"
        } else if lowercaseName.contains("safari") || lowercaseName.contains("chrome") || lowercaseName.contains("firefox") {
            return "globe"
        } else if lowercaseName.contains("xcode") || lowercaseName.contains("code") || lowercaseName.contains("developer") {
            return "hammer"
        } else {
            return "app"
        }
    }
    
    private func getProcessIconColor(for processName: String) -> Color {
        let lowercaseName = processName.lowercased()
        
        if lowercaseName.contains("kernel") || lowercaseName.contains("system") {
            return .gray
        } else if lowercaseName.contains("safari") || lowercaseName.contains("chrome") || lowercaseName.contains("firefox") {
            return .blue
        } else if lowercaseName.contains("xcode") || lowercaseName.contains("code") {
            return .purple
        } else {
            return .secondary
        }
    }
    
    private func processValueText(process: SystemProcessInfo, isCPUView: Bool) -> String {
        let value = isCPUView ? process.cpuUsage : process.memoryUsage
        return "\(String(format: "%.1f", value))%"
    }
    
    private func usageColor(for usage: Double, thresholds: (low: Double, high: Double)) -> Color {
        switch usage {
        case 0..<thresholds.low:
            return .green
        case thresholds.low..<thresholds.high:
            return .yellow
        case thresholds.high...100:
            return .red
        default:
            return .gray
        }
    }
    
    private func memoryUsageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return .green
        case 50..<75:
            return .yellow
        case 75..<90:
            return .orange
        case 90...100:
            return .red
        default:
            return .gray
        }
    }
    
    private func getBatteryIconName() -> String {
        let charge = systemMonitor.batteryInfo.chargeLevel
        if systemMonitor.batteryInfo.isCharging {
            return "battery.100.bolt"
        } else {
            switch charge {
            case 90...100: return "battery.100"
            case 75..<90: return "battery.75"
            case 50..<75: return "battery.50"
            case 25..<50: return "battery.25"
            case 10..<25: return "battery.10"
            default: return "battery.0"
            }
        }
    }
    
    private func getBatteryIconColor() -> Color {
        let charge = systemMonitor.batteryInfo.chargeLevel
        if systemMonitor.batteryInfo.isCharging {
            return .green
        } else {
            switch charge {
            case 80...100: return .green
            case 20..<80: return .yellow
            default: return .red
            }
        }
    }
    
    private func batteryChargeColor(for charge: Double) -> Color {
        switch charge {
        case 0..<20: return .red
        case 20..<50: return .yellow
        case 50...100: return .green
        default: return .gray
        }
    }
    
    private func getUPSIconName() -> String {
        let charge = systemMonitor.upsInfo.chargeLevel
        if systemMonitor.upsInfo.isCharging {
            return "battery.100.bolt"
        } else {
            switch charge {
            case 90...100: return "battery.100"
            case 75..<90: return "battery.75"
            case 50..<75: return "battery.50"
            case 25..<50: return "battery.25"
            case 10..<25: return "battery.10"
            default: return "battery.0"
            }
        }
    }
    
    private func getUPSIconColor() -> Color {
        let charge = systemMonitor.upsInfo.chargeLevel
        if systemMonitor.upsInfo.isCharging {
            return .green
        } else {
            switch charge {
            case 80...100: return .green
            case 20..<80: return .yellow
            default: return .red
            }
        }
    }
    
    private func upsChargeColor(for charge: Double) -> Color {
        switch charge {
        case 0..<20: return .red
        case 20..<50: return .yellow
        case 50...100: return .green
        default: return .gray
        }
    }
    
    private func getPowerSourceColor(for powerSource: String) -> Color {
        switch powerSource {
        case "AC Power": return .green
        case "UPS Power": return .orange
        case "Battery Power": return .red
        default: return .secondary
        }
    }
    
    private func formatTime(_ minutes: Double) -> String {
        if minutes <= 0 || minutes == -1 || minutes.isNaN || minutes.isInfinite {
            return "Calculating..."
        }
        
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else if mins > 0 {
            return "\(mins)m"
        } else {
            return "Calculating..."
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let totalSeconds = Int(uptime)
        let days = totalSeconds / (24 * 3600)
        let hours = (totalSeconds % (24 * 3600)) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Compact Stats Card
struct CompactStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let subtitle: String
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.subheadline)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .monospacedDigit()
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}