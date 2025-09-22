//
//  CardBasedStatsView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

struct CardBasedStatsView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var externalIPManager: ExternalIPManager
    @EnvironmentObject var wifiManager: WiFiManager
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with glass effect
            headerView
            
            // Content with two vertical columns
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    // Left Column
                    VStack(spacing: 12) {
                        // System Info
                        systemInfoCard()
                        
                        // Memory
                        if preferences.showMemory {
                            memoryCard()
                        }
                        
                        // Disk
                        if preferences.showDisk {
                            diskCard()
                        }
                        
                        // UPS/Battery
                        if systemMonitor.batteryInfo.present {
                            batteryCard()
                        } else if systemMonitor.upsInfo.present && systemMonitor.upsInfo.name != "Power Device" {
                            upsCard()
                        }
                        
                        // WiFi
                        wifiCard()
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column
                    VStack(spacing: 12) {
                        // CPU
                        if preferences.showCPU {
                            cpuCard()
                        }
                        // Network
                        if preferences.showNetwork {
                            networkCard()
                        }
                        // Power Consumption
                        if preferences.showPowerConsumption && systemMonitor.powerConsumptionInfo.totalSystemPower > 0 {
                            powerConsumptionCard()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .liquidGlassWindow(material: LiquidGlassTheme.windowMaterial)
        .onAppear {
            print("CardBasedStatsView appeared")
            print("Debug - Current CPU: \(systemMonitor.cpuUsage)")
            print("Debug - Current Memory: \(systemMonitor.memoryUsage)")
            print("Debug - Current Disk: \(systemMonitor.diskUsage)")
            print("Debug - Current System Info: \(systemMonitor.systemInfo)")
            print("Debug - Initial data loaded: \(systemMonitor.initialDataLoaded)")
            
            // Force refresh if data appears to be empty
            if !systemMonitor.initialDataLoaded {
                print("Data not loaded, forcing refresh...")
                systemMonitor.refreshAllData()
            }
        }
    }
    
    // MARK: - Header View with Glass Effect
    private var headerView: some View {
        HStack {
            Text("Mac Stats")
                .font(.largeTitle)
                .fontWeight(.bold)
                .glassTextVibrancy()
            
            Spacer()
            
            HStack(spacing: 8) {
                GlassButton(action: {
                    print("Refresh button pressed - forcing data refresh")
                    systemMonitor.refreshAllData()
                    externalIPManager.refreshExternalIP()
                    wifiManager.refreshWiFiInfo()
                }, material: .thin) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .help("Refresh Data")
                
                GlassButton(action: {
                    openWindow(id: "settings")
                }, material: .thin) {
                    Text("Settings")
                }
            }
        }
        .glassToolbar(material: LiquidGlassTheme.headerMaterial)
    }
    
    // MARK: - Card Views with Enhanced Glass Effects
    
    private func systemInfoCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "System Information", icon: "info.circle", color: .blue)
                
                VStack(alignment: .leading, spacing: 8) {
                    GlassInfoRowView(label: "Model", value: systemMonitor.systemInfo.modelName.isEmpty ? "Loading..." : systemMonitor.systemInfo.modelName)
                    GlassInfoRowView(label: "Chip", value: systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                    GlassInfoRowView(label: "macOS", value: systemMonitor.systemInfo.macOSVersion)
                    GlassInfoRowView(label: "Uptime", value: formatUptime(systemMonitor.systemInfo.uptime))
                    GlassInfoRowView(label: "Boot Time", value: formatBootTime(systemMonitor.systemInfo.bootTime))
                }
            }
        }
    }
    
    private func cpuCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "CPU Usage", icon: "cpu", color: .orange)
                
                VStack(alignment: .leading, spacing: 12) {
                    // CPU Usage Progress with enhanced glass styling
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Current Usage")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(String(format: "%.1f%%", systemMonitor.cpuUsage))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .glassTextVibrancy()
                        }
                        
                        GlassProgressView(
                            value: systemMonitor.cpuUsage,
                            total: 100,
                            color: usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)),
                            height: 8
                        )
                    }
                    
                    // CPU Info Row
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .glassTextVibrancy()
                            Text(systemMonitor.systemInfo.chipInfo.isEmpty ? "Loading..." : systemMonitor.systemInfo.chipInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .glassTextVibrancy()
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.caption)
                                .glassTextVibrancy()
                            Text("Multi-core")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                        }
                    }
                    
                    // CPU Sparkline with enhanced info
                    if !systemMonitor.cpuHistory.isEmpty {
                        Divider()
                            .opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .glassTextVibrancy()
                                Text("Usage Trend")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                
                                let avgUsage = systemMonitor.cpuHistory.reduce(0, +) / Double(systemMonitor.cpuHistory.count)
                                let maxUsage = systemMonitor.cpuHistory.max() ?? 0
                                
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("Avg: \(String(format: "%.1f%%", avgUsage))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                        .glassTextVibrancy()
                                    Text("Peak: \(String(format: "%.1f%%", maxUsage))")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(usageColor(for: maxUsage, thresholds: (30, 70)))
                                        .glassTextVibrancy()
                                }
                            }
                            
                            GlassSparklineView(
                                data: systemMonitor.cpuHistory,
                                lineColor: usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)),
                                lineWidth: 2
                            )
                            .frame(height: 35)
                        }
                    }
                    
                    // CPU Temperature (if enabled) with enhanced sparkline
                    if preferences.showCPUTemperature {
                        Divider()
                            .opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "thermometer")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                                    .glassTextVibrancy()
                                Text("Temperature")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(TemperatureMonitor.formatTemperature(systemMonitor.cpuTemperature, 
                                                                            unit: preferences.temperatureUnit, 
                                                                            showBoth: preferences.showBothTemperatureUnits))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .foregroundColor(temperatureColor(for: systemMonitor.cpuTemperature))
                                        .glassTextVibrancy()
                                    
                                    // Temperature sparkline
                                    if !systemMonitor.cpuTemperatureHistory.isEmpty {
                                        GlassSparklineView(
                                            data: systemMonitor.cpuTemperatureHistory,
                                            lineColor: temperatureColor(for: systemMonitor.cpuTemperature),
                                            lineWidth: 1.5,
                                            fillGradient: false
                                        )
                                        .frame(width: 80, height: 20)
                                    }
                                }
                            }
                            
                            HStack {
                                if TemperatureMonitor.hasTemperatureSensors() {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                        .glassTextVibrancy()
                                    Text("Real sensors")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .glassTextVibrancy()
                                } else {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                        .glassTextVibrancy()
                                    Text("Estimated")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .glassTextVibrancy()
                                }
                                
                                Spacer()
                                
                                // Temperature stats
                                if !systemMonitor.cpuTemperatureHistory.isEmpty {
                                    let avgTemp = systemMonitor.cpuTemperatureHistory.reduce(0, +) / Double(systemMonitor.cpuTemperatureHistory.count)
                                    let maxTemp = systemMonitor.cpuTemperatureHistory.max() ?? 0
                                    
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text("Avg: \(TemperatureMonitor.formatTemperature(avgTemp, unit: preferences.temperatureUnit, showBoth: false))")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.secondary)
                                            .glassTextVibrancy()
                                        Text("Peak: \(TemperatureMonitor.formatTemperature(maxTemp, unit: preferences.temperatureUnit, showBoth: false))")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(temperatureColor(for: maxTemp))
                                            .glassTextVibrancy()
                                    }
                                }
                                
                                if TemperatureMonitor.shouldSuggestToolInstallation() {
                                    GlassButton(action: {
                                        showMacmonInstallation()
                                    }, material: .ultraThin) {
                                        Text("Install macmon")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Fan Speed Information
                    Divider()
                        .opacity(0.5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "fan")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                                .glassTextVibrancy()
                            Text("Fan Speed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.0f RPM", systemMonitor.fanInfo.rpm))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(fanSpeedColor(for: systemMonitor.fanInfo.rpm))
                                    .glassTextVibrancy()
                                
                                if systemMonitor.fanInfo.isEstimate {
                                    Text("Estimated")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .glassTextVibrancy()
                                }
                            }
                        }
                        
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: getThermalPressureIcon(for: systemMonitor.fanInfo.thermalState))
                                    .foregroundColor(getThermalPressureColor(for: systemMonitor.fanInfo.thermalState))
                                    .font(.caption)
                                    .glassTextVibrancy()
                                Text("Thermal: \(systemMonitor.fanInfo.thermalPressure)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            Spacer()
                            
                            Text(String(format: "%.0f%% of max", (systemMonitor.fanInfo.rpm / systemMonitor.fanInfo.maxRPM) * 100))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                        }
                        
                        // Mini fan speed progress bar with glass effect
                        GlassProgressView(
                            value: systemMonitor.fanInfo.rpm,
                            total: systemMonitor.fanInfo.maxRPM,
                            color: fanSpeedColor(for: systemMonitor.fanInfo.rpm),
                            height: 6
                        )
                    }
                    
                    // Top CPU Processes with enhanced display
                    if !systemMonitor.topProcesses.isEmpty {
                        Divider()
                            .opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .glassTextVibrancy()
                                Text("Top CPU Processes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                
                                Text("\(systemMonitor.topProcesses.count) of \(systemMonitor.topProcesses.count) shown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .opacity(0.7)
                                    .glassTextVibrancy()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                if systemMonitor.initialDataLoaded {
                                    ForEach(systemMonitor.topProcesses.prefix(5)) { process in
                                        enhancedGlassProcessRowView(process: process, isCPUView: true)
                                    }
                                } else {
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                        .glassTextVibrancy()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func memoryCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Memory Usage", icon: "memorychip", color: .blue)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Used Memory")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(String(format: "%.1f GB / %.1f GB", systemMonitor.memoryUsage.used, systemMonitor.memoryUsage.total))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .glassTextVibrancy()
                        }
                        
                        GlassProgressView(
                            value: systemMonitor.memoryUsage.used,
                            total: systemMonitor.memoryUsage.total,
                            color: memoryUsageColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100),
                            height: 8
                        )
                    }
                    
                    // Enhanced memory breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .glassTextVibrancy()
                                Text("Free")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            Spacer()
                            
                            let freeMemory = systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used
                            let freePercent = (freeMemory / systemMonitor.memoryUsage.total) * 100
                            
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%.1f GB", freeMemory))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.green)
                                    .glassTextVibrancy()
                                Text(String(format: "%.1f%%", freePercent))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.green)
                                    .glassTextVibrancy()
                            }
                        }
                        
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .glassTextVibrancy()
                                Text("Used")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            Spacer()
                            
                            let usedPercent = (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100
                            
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "%.1f GB", systemMonitor.memoryUsage.used))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                                    .glassTextVibrancy()
                                Text(String(format: "%.1f%%", usedPercent))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                                    .glassTextVibrancy()
                            }
                        }
                        
                        // Memory pressure indicator
                        HStack {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(memoryPressureColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                                    .frame(width: 8, height: 8)
                                    .glassTextVibrancy()
                                Text("Pressure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            Spacer()
                            
                            Text(memoryPressureText(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(memoryPressureColor(for: systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total * 100))
                                .glassTextVibrancy()
                        }
                    }
                    
                    // Top Memory Processes with enhanced display
                    if !systemMonitor.topMemoryProcesses.isEmpty {
                        Divider()
                            .opacity(0.5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                    .glassTextVibrancy()
                                Text("Top Memory Processes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                
                                let totalMemUsage = systemMonitor.topMemoryProcesses.prefix(5).reduce(0) { $0 + $1.memoryUsage }
                                Text("Total: \(String(format: "%.1f%%", totalMemUsage))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .opacity(0.7)
                                    .monospacedDigit()
                                    .glassTextVibrancy()
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                if systemMonitor.initialDataLoaded {
                                    ForEach(systemMonitor.topMemoryProcesses.prefix(5)) { process in
                                        enhancedGlassProcessRowView(process: process, isCPUView: false)
                                    }
                                } else {
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                        .glassTextVibrancy()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func networkCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Network Activity", icon: "network", color: .green)
                
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
                                    .glassTextVibrancy()
                                Text("Upload")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            HStack {
                                Text("\(uploadFormatted.value) \(uploadFormatted.unit)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.red)
                                    .glassTextVibrancy()
                                
                                Spacer()
                                
                                // Upload sparkline
                                if !systemMonitor.uploadHistory.isEmpty {
                                    GlassSparklineView(
                                        data: systemMonitor.uploadHistory.map { $0 / 1000 }, // Convert to KB for better scale
                                        lineColor: .red,
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 60, height: 25)
                                }
                            }
                        }
                        
                        Divider()
                            .opacity(0.5)
                            .frame(height: 50)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                    .glassTextVibrancy()
                                Text("Download")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            HStack {
                                Text("\(downloadFormatted.value) \(downloadFormatted.unit)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(.blue)
                                    .glassTextVibrancy()
                                
                                Spacer()
                                
                                // Download sparkline
                                if !systemMonitor.downloadHistory.isEmpty {
                                    GlassSparklineView(
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
                            .opacity(0.5)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Peak Speeds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                
                                HStack {
                                    if let maxUpload = systemMonitor.uploadHistory.max() {
                                        let maxUploadFormatted = NetworkFormatter.formatNetworkValue(maxUpload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↑ \(maxUploadFormatted.value) \(maxUploadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.red)
                                            .glassTextVibrancy()
                                    }
                                    
                                    if let maxDownload = systemMonitor.downloadHistory.max() {
                                        let maxDownloadFormatted = NetworkFormatter.formatNetworkValue(maxDownload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↓ \(maxDownloadFormatted.value) \(maxDownloadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.blue)
                                            .glassTextVibrancy()
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Average")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                
                                HStack {
                                    if !systemMonitor.uploadHistory.isEmpty {
                                        let avgUpload = systemMonitor.uploadHistory.reduce(0, +) / Double(systemMonitor.uploadHistory.count)
                                        let avgUploadFormatted = NetworkFormatter.formatNetworkValue(avgUpload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↑ \(avgUploadFormatted.value) \(avgUploadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.red)
                                            .glassTextVibrancy()
                                    }
                                    
                                    if !systemMonitor.downloadHistory.isEmpty {
                                        let avgDownload = systemMonitor.downloadHistory.reduce(0, +) / Double(systemMonitor.downloadHistory.count)
                                        let avgDownloadFormatted = NetworkFormatter.formatNetworkValue(avgDownload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
                                        Text("↓ \(avgDownloadFormatted.value) \(avgDownloadFormatted.unit)")
                                            .font(.caption)
                                            .monospacedDigit()
                                            .foregroundColor(.blue)
                                            .glassTextVibrancy()
                                    }
                                }
                            }
                        }
                    }
                    
                    // External IP with enhanced info
                    if !externalIPManager.externalIP.isEmpty {
                        Divider()
                            .opacity(0.5)
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.green)
                                .font(.subheadline)
                                .glassTextVibrancy()
                            Text("External IP")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            HStack(spacing: 6) {
                                Text(externalIPManager.flagEmoji)
                                    .font(.title3)
                                    .glassTextVibrancy()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(externalIPManager.externalIP)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                        .glassTextVibrancy()
                                    if !externalIPManager.countryName.isEmpty {
                                        Text(externalIPManager.countryName)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .glassTextVibrancy()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func diskCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Disk Usage", icon: "internaldrive", color: .purple)
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Used Space")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(String(format: "%.0f GB / %.0f GB", systemMonitor.diskUsage.total - systemMonitor.diskUsage.free, systemMonitor.diskUsage.total))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .glassTextVibrancy()
                        }
                        
                        GlassProgressView(
                            value: systemMonitor.diskUsage.total - systemMonitor.diskUsage.free,
                            total: systemMonitor.diskUsage.total,
                            color: .purple,
                            height: 8
                        )
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .glassTextVibrancy()
                            Text("Free")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                        }
                        Spacer()
                        Text(String(format: "%.0f GB", systemMonitor.diskUsage.free))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.green)
                            .glassTextVibrancy()
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                                .glassTextVibrancy()
                            Text("Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                        }
                        Spacer()
                        Text(String(format: "%.1f%% (%.0f GB)", ((systemMonitor.diskUsage.total - systemMonitor.diskUsage.free) / systemMonitor.diskUsage.total) * 100, systemMonitor.diskUsage.total - systemMonitor.diskUsage.free))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(.purple)
                            .glassTextVibrancy()
                    }
                }
            }
        }
    }
    
    private func powerConsumptionCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Power Consumption", icon: "bolt.fill", color: .yellow)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "power")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                            .glassTextVibrancy()
                        Text("Total System")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .glassTextVibrancy()
                        Spacer()
                        Text(String(format: "%.2f W", systemMonitor.powerConsumptionInfo.totalSystemPower))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.yellow)
                            .glassTextVibrancy()
                    }
                    
                    if systemMonitor.powerConsumptionInfo.cpuPower > 0 {
                        InfoRowView(label: "CPU", value: String(format: "%.2f W", systemMonitor.powerConsumptionInfo.cpuPower), valueColor: .orange)
                    }
                    
                    if systemMonitor.powerConsumptionInfo.gpuPower > 0 {
                        InfoRowView(label: "GPU", value: String(format: "%.2f W", systemMonitor.powerConsumptionInfo.gpuPower), valueColor: .blue)
                    }
                    
                    if systemMonitor.powerConsumptionInfo.isEstimate {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .glassTextVibrancy()
                            Text("Estimated based on system load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private func batteryCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Battery Status", icon: getBatteryIconName(), color: getBatteryIconColor())
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Charge Level")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(String(format: "%.0f%%", systemMonitor.batteryInfo.chargeLevel))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .glassTextVibrancy()
                        }
                        
                        GlassProgressView(
                            value: systemMonitor.batteryInfo.chargeLevel,
                            total: 100,
                            color: batteryChargeColor(for: systemMonitor.batteryInfo.chargeLevel),
                            height: 8
                        )
                    }
                    
                    InfoRowView(label: "Cycle Count", value: "\(systemMonitor.batteryInfo.cycleCount)")
                    InfoRowView(label: "Time Remaining", value: formatTime(systemMonitor.batteryInfo.timeRemaining))
                    InfoRowView(label: "Max Capacity", value: "\(systemMonitor.batteryInfo.maxCapacity)%")
                    
                    if systemMonitor.batteryInfo.health != "Unknown" {
                        InfoRowView(label: "Health", value: systemMonitor.batteryInfo.health)
                    }
                }
            }
        }
    }
    
    private func upsCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "UPS Status", icon: getUPSIconName(), color: getUPSIconColor())
                
                VStack(alignment: .leading, spacing: 12) {
                    if systemMonitor.upsInfo.present && systemMonitor.upsInfo.chargeLevel > 0 {
                        // Full UPS info available
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Charge Level")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                Text(String(format: "%.0f%%", systemMonitor.upsInfo.chargeLevel))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .glassTextVibrancy()
                            }
                            
                            GlassProgressView(
                                value: systemMonitor.upsInfo.chargeLevel,
                                total: 100,
                                color: upsChargeColor(for: systemMonitor.upsInfo.chargeLevel),
                                height: 8
                            )
                        }
                        
                        InfoRowView(label: "Name", value: systemMonitor.upsInfo.name)
                        
                        if systemMonitor.upsInfo.timeRemaining > 0 {
                            InfoRowView(label: "Time Remaining", value: formatTime(systemMonitor.upsInfo.timeRemaining))
                        }
                        
                        InfoRowView(label: "Power Source", value: systemMonitor.upsInfo.powerSource.isEmpty ? "AC Power" : systemMonitor.upsInfo.powerSource, 
                                   valueColor: getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                        
                        HStack {
                            Text("Charging")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(systemMonitor.upsInfo.isCharging ? "Yes" : "No")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(systemMonitor.upsInfo.isCharging ? .red : .green)
                                .glassTextVibrancy()
                        }
                    } else {
                        // Basic power source info
                        InfoRowView(label: "Power Source", value: systemMonitor.upsInfo.powerSource.isEmpty ? "AC Power" : systemMonitor.upsInfo.powerSource, 
                                   valueColor: getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                        
                        if !systemMonitor.upsInfo.name.isEmpty && systemMonitor.upsInfo.name != "Unknown" {
                            InfoRowView(label: "Device", value: systemMonitor.upsInfo.name)
                        }
                    }
                }
            }
        }
    }
    
    private func wifiCard() -> some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(
                    title: "WiFi Status", 
                    icon: wifiManager.getWiFiIconName(), 
                    color: getWiFiCardColor()
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    if wifiManager.wifiInfo.isConnected {
                        // Connected WiFi info
                        HStack {
                            Text("Network")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            Text(wifiManager.wifiInfo.networkName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .glassTextVibrancy()
                        }
                        
                        HStack {
                            Text("Signal Strength")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                            Spacer()
                            HStack(spacing: 4) {
                                Text("\(wifiManager.wifiInfo.signalStrength) dBm")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(getSignalStrengthColor(for: wifiManager.wifiInfo.signalStrength))
                                    .glassTextVibrancy()
                                
                                Text("(\(wifiManager.getSignalStrengthPercentage())%)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                        }
                        
                        // Signal strength progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Signal Quality")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                                Spacer()
                                Text(wifiManager.getSignalStrengthDescription())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(getSignalStrengthColor(for: wifiManager.wifiInfo.signalStrength))
                                    .glassTextVibrancy()
                            }
                            
                            GlassProgressView(
                                value: Double(wifiManager.getSignalStrengthPercentage()),
                                total: 100,
                                color: getSignalStrengthColor(for: wifiManager.wifiInfo.signalStrength),
                                height: 8
                            )
                        }
                        
                        InfoRowView(
                            label: "Security", 
                            value: wifiManager.wifiInfo.securityType,
                            valueColor: getSecurityColor(for: wifiManager.wifiInfo.securityType)
                        )
                        
                    } else if !wifiManager.wifiInfo.hasPermission {
                        // Permission required
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.subheadline)
                                    .glassTextVibrancy()
                                Text("Permission Required")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                    .glassTextVibrancy()
                            }
                            
                            Text("WiFi information requires additional system permissions to access network details.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .glassTextVibrancy()
                            
                            if let errorMessage = wifiManager.wifiInfo.errorMessage {
                                Text(errorMessage)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .glassTextVibrancy()
                            }
                        }
                        
                    } else {
                        // Not connected
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .glassTextVibrancy()
                                Text("Not Connected")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .glassTextVibrancy()
                            }
                            
                            Text("Connect to a WiFi network to see detailed information.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .glassTextVibrancy()
                        }
                    }
                    
                    // Refresh button and status
                    Divider()
                        .opacity(0.5)
                    
                    HStack {
                        GlassButton(action: {
                            wifiManager.refreshWiFiInfo()
                        }, material: .ultraThin) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .glassTextVibrancy()
                                Text("Refresh")
                                    .font(.caption)
                                    .glassTextVibrancy()
                            }
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text("Status: \(wifiManager.wifiInfo.hasPermission ? "Active" : "Limited")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .glassTextVibrancy()
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Helper Views with Glass Effects
    
    private func enhancedGlassProcessRowView(process: SystemProcessInfo, isCPUView: Bool) -> some View {
        HStack {
            HStack(spacing: 6) {
                // Process type indicator
                Image(systemName: getProcessIcon(for: process.name))
                    .foregroundColor(getProcessIconColor(for: process.name))
                    .font(.caption)
                    .frame(width: 12)
                    .glassTextVibrancy()
                
                Text(process.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .glassTextVibrancy()
            }
            
            Spacer()
            
            // Main value
            Text(processValueText(process: process, isCPUView: isCPUView))
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(usageColor(for: isCPUView ? process.cpuUsage : process.memoryUsage, 
                                          thresholds: isCPUView ? (30, 70) : (5, 15)))
                .frame(width: 45, alignment: .trailing)
                .glassTextVibrancy()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .liquidGlass(material: .ultraThin, cornerRadius: 6, shadowRadius: 2, shadowOpacity: 0.1)
    }
    
    // MARK: - Helper Functions
    
    private func getWiFiCardColor() -> Color {
        if wifiManager.wifiInfo.isConnected {
            return getSignalStrengthColor(for: wifiManager.wifiInfo.signalStrength)
        } else if !wifiManager.wifiInfo.hasPermission {
            return .orange
        } else {
            return .secondary
        }
    }
    
    private func getSignalStrengthColor(for signalStrength: Int) -> Color {
        let percentage = max(0, min(100, (signalStrength + 90) * 100 / 60))
        switch percentage {
        case 75...100:
            return .green
        case 50..<75:
            return .yellow
        case 25..<50:
            return .orange
        default:
            return .red
        }
    }
    
    private func getSecurityColor(for securityType: String) -> Color {
        switch securityType.lowercased() {
        case "open":
            return .red
        case let type where type.contains("wpa3") || type.contains("enterprise"):
            return .green
        case let type where type.contains("wpa2"):
            return .blue
        case let type where type.contains("wpa"):
            return .yellow
        case "wep":
            return .orange
        default:
            return .secondary
        }
    }
    
    private func getProcessIcon(for processName: String) -> String {
        let lowercaseName = processName.lowercased()
        
        if lowercaseName.contains("kernel") || lowercaseName.contains("system") {
            return "gear"
        } else if lowercaseName.contains("safari") || lowercaseName.contains("chrome") || lowercaseName.contains("firefox") {
            return "globe"
        } else if lowercaseName.contains("xcode") || lowercaseName.contains("code") {
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
    
    private func getBatteryIconName() -> String {
        let charge = systemMonitor.batteryInfo.chargeLevel
        if systemMonitor.batteryInfo.isCharging {
            return "battery.100.bolt"
        } else {
            switch charge {
            case 90...100:
                return "battery.100"
            case 75..<90:
                return "battery.75"
            case 50..<75:
                return "battery.50"
            case 25..<50:
                return "battery.25"
            case 10..<25:
                return "battery.10"
            default:
                return "battery.0"
            }
        }
    }
    
    private func getBatteryIconColor() -> Color {
        let charge = systemMonitor.batteryInfo.chargeLevel
        if systemMonitor.batteryInfo.isCharging {
            return .green
        } else {
            switch charge {
            case 80...100:
                return .green
            case 20..<80:
                return .yellow
            default:
                return .red
            }
        }
    }
    
    private func batteryChargeColor(for charge: Double) -> Color {
        switch charge {
        case 0..<20:
            return .red
        case 20..<50:
            return .yellow
        case 50...100:
            return .green
        default:
            return .gray
        }
    }
    
    private func getUPSIconName() -> String {
        let charge = systemMonitor.upsInfo.chargeLevel
        if systemMonitor.upsInfo.isCharging {
            return "battery.100.bolt"
        } else {
            switch charge {
            case 90...100:
                return "battery.100"
            case 75..<90:
                return "battery.75"
            case 50..<75:
                return "battery.50"
            case 25..<50:
                return "battery.25"
            case 10..<25:
                return "battery.10"
            default:
                return "battery.0"
            }
        }
    }
    
    private func getUPSIconColor() -> Color {
        let charge = systemMonitor.upsInfo.chargeLevel
        if systemMonitor.upsInfo.isCharging {
            return .green
        } else {
            switch charge {
            case 80...100:
                return .green
            case 20..<80:
                return .yellow
            default:
                return .red
            }
        }
    }
    
    private func upsChargeColor(for charge: Double) -> Color {
        switch charge {
        case 0..<20:
            return .red
        case 20..<50:
            return .yellow
        case 50...100:
            return .green
        default:
            return .gray
        }
    }
    
    private func getPowerSourceColor(for powerSource: String) -> Color {
        switch powerSource {
        case "AC Power":
            return .green
        case "UPS Power":
            return .orange
        case "Battery Power":
            return .red
        default:
            return .secondary
        }
    }
    
    private func fanSpeedColor(for rpm: Double) -> Color {
        let percentage = (rpm / 6000.0) * 100 // Assuming max 6000 RPM
        switch percentage {
        case 0..<30:
            return .green
        case 30..<60:
            return .yellow
        case 60..<80:
            return .orange
        case 80...100:
            return .red
        default:
            return .gray
        }
    }
    
    private func getThermalPressureIcon(for state: Int) -> String {
        switch state {
        case 0:
            return "checkmark.circle.fill"
        case 1:
            return "exclamationmark.triangle.fill"
        case 2:
            return "thermometer.sun.fill"
        case 3:
            return "flame.fill"
        default:
            return "exclamationmark.octagon.fill"
        }
    }
    
    private func getThermalPressureColor(for state: Int) -> Color {
        switch state {
        case 0:
            return .green
        case 1:
            return .yellow
        case 2:
            return .orange
        case 3:
            return .red
        default:
            return .purple
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
    
    private func formatBootTime(_ bootTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: bootTime)
    }
}