//
//  StatsMenuView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Foundation

struct StatsMenuView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var preferences: PreferencesManager
    @EnvironmentObject var externalIPManager: ExternalIPManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView()
            
            if preferences.showCPU {
                cpuStatView()
                cpuSparklineView()
                if preferences.showCPUTemperature {
                    cpuTemperatureView()
                }
                topProcessesView(processes: systemMonitor.topProcesses, title: "Top CPU Processes", isCPUView: true)
            }
            if preferences.showMemory {
                memoryStatView()
                topProcessesView(processes: systemMonitor.topMemoryProcesses, title: "Top Memory Processes", isCPUView: false)
            }
            if preferences.showDisk {
                diskStatView()
            }
            if preferences.showNetwork {
                networkStatView()
                networkSparklineView()
            }
            
            // Power Consumption
            if preferences.showPowerConsumption {
                powerConsumptionView()
            }
            
            // Battery Status
            batteryStatusView()
            
            // UPS Status
            upsStatusView()
            
            Divider()
            
            footerButtons()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 280, maxWidth: .infinity, alignment: .leading) // Allow dynamic width
        .onAppear {
            print("StatsMenuView appeared, processes count: \(systemMonitor.topProcesses.count)")
        }
    }
    
    private func headerView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // App title
            HStack {
                Image(systemName: "macwindow")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Mac Stats")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // Compact System Information card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("SYSTEM INFO")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                // Device info in single line
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(systemMonitor.systemInfo.modelName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(systemMonitor.systemInfo.chipInfo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                
                // Compact system stats in one row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text(formatUptime(systemMonitor.systemInfo.uptime))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .foregroundColor(.green)
                            .font(.caption2)
                        Text(formatBootTime(systemMonitor.systemInfo.bootTime))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(.bottom, 4)
    }

    private func cpuStatView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.orange)
                Text("CPU Usage")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ProgressView(value: systemMonitor.cpuUsage, total: 100) {
                Text(String(format: "%.0f%%", systemMonitor.cpuUsage))
                    .font(.caption)  // MATCHING: CPU usage uses .caption
                    .monospacedDigit()
            }
            .tint(usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)))
        }
    }
    
    // Sparkline view for CPU usage trend
    private func cpuSparklineView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                Text("CPU Trend (1 min)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            SparklineView(
                data: systemMonitor.cpuHistory,
                lineColor: usageColor(for: systemMonitor.cpuUsage, thresholds: (30, 70)),
                lineWidth: 2
            )
            .frame(height: 30)
            
            // Average CPU usage
            if !systemMonitor.cpuHistory.isEmpty {
                HStack {
                    Text("Avg:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", systemMonitor.cpuHistory.reduce(0, +) / Double(systemMonitor.cpuHistory.count)))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(usageColor(for: systemMonitor.cpuHistory.reduce(0, +) / Double(systemMonitor.cpuHistory.count), thresholds: (30, 70)))
                    Spacer()
                }
            }
        }
    }
    
    private func cpuTemperatureView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "thermometer")
                    .foregroundColor(.red)
                Text("CPU Temperature")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                
                // Show sensor availability status
                if TemperatureMonitor.hasTemperatureSensors() {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            HStack {
                // Temperature display with C/F support - using caption font to match other stats
                VStack(alignment: .leading, spacing: 2) {
                    if preferences.showBothTemperatureUnits {
                        // Show both units
                        Text(TemperatureMonitor.formatTemperature(systemMonitor.cpuTemperature, 
                                                                unit: preferences.temperatureUnit, 
                                                                showBoth: true))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundColor(temperatureColor(for: systemMonitor.cpuTemperature))
                    } else {
                        // Show selected unit
                        Text(TemperatureMonitor.formatTemperature(systemMonitor.cpuTemperature, 
                                                                unit: preferences.temperatureUnit, 
                                                                showBoth: false))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundColor(temperatureColor(for: systemMonitor.cpuTemperature))
                    }
                }
                
                Spacer()
                
                // Temperature sparkline
                if !systemMonitor.cpuTemperatureHistory.isEmpty {
                    SparklineView(
                        data: systemMonitor.cpuTemperatureHistory,
                        lineColor: temperatureColor(for: systemMonitor.cpuTemperature),
                        lineWidth: 1.5
                    )
                    .frame(width: 60, height: 20)
                }
            }
            
            // Show status message
            if TemperatureMonitor.hasTemperatureSensors() {
                // Show temperature range or average if we have history
                if !systemMonitor.cpuTemperatureHistory.isEmpty {
                    HStack {
                        Text("Avg:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        let avgTemp = systemMonitor.cpuTemperatureHistory.reduce(0, +) / Double(systemMonitor.cpuTemperatureHistory.count)
                        Text(TemperatureMonitor.formatTemperature(avgTemp, 
                                                                unit: preferences.temperatureUnit, 
                                                                showBoth: false))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        Spacer()
                        
                        Text("Real sensors")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            } else {
                HStack {
                    Text("Estimated based on CPU load")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    if TemperatureMonitor.shouldSuggestToolInstallation() {
                        Button("Install macmon") {
                            showMacmonInstallation()
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.top, 4)
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

    private func temperatureColor(for temperatureCelsius: Double) -> Color {
        // Always use Celsius for color thresholds regardless of display unit
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
    
    // Reusable function for displaying top processes
    private func topProcessesView(processes: [SystemProcessInfo], title: String, isCPUView: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isCPUView ? "cpu" : "memorychip")
                    .foregroundColor(isCPUView ? .orange : .blue)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            processListContent(processes: processes, isCPUView: isCPUView)
        }
        .padding(.top, 4)
    }
    
    // Reusable content for process lists
    @ViewBuilder
    private func processListContent(processes: [SystemProcessInfo], isCPUView: Bool) -> some View {
        if processes.isEmpty {
            Text(systemMonitor.initialDataLoaded ? "No active processes" : "Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            ForEach(processes.prefix(5)) { process in
                processRowView(process: process, isCPUView: isCPUView)
            }
        }
    }
    
    // Reusable row for process display
    private func processRowView(process: SystemProcessInfo, isCPUView: Bool) -> some View {
        HStack {
            Text(process.name)
                .font(.caption)
                .truncationMode(.tail)
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)
            Spacer()
            Text(processValueText(process: process, isCPUView: isCPUView))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(usageColor(for: isCPUView ? process.cpuUsage : process.memoryUsage, 
                                          thresholds: isCPUView ? (30, 70) : (5, 15)))
                .frame(width: 40, alignment: .trailing)
        }
    }
    
    // Helper to determine text for process value
    private func processValueText(process: SystemProcessInfo, isCPUView: Bool) -> String {
        let value = isCPUView ? process.cpuUsage : process.memoryUsage
        return "\(String(format: "%.1f", value))%"
    }
    
    // Generic usage color function
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

    private func memoryStatView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                Text("Memory")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ProgressView(value: systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used, total: systemMonitor.memoryUsage.total) {
                Text(String(format: "%.1fG free / %.1fG", systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used, systemMonitor.memoryUsage.total))
                    .font(.caption)
                    .monospacedDigit()
            }
            .tint(.blue)
        }
    }
    
    private func diskStatView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.purple)
                Text("Disk")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            ProgressView(value: systemMonitor.diskUsage.free, total: systemMonitor.diskUsage.total) {
                Text(String(format: "%.0fG free / %.0fG", systemMonitor.diskUsage.free, systemMonitor.diskUsage.total))
                    .font(.caption)
                    .monospacedDigit()
            }
            .tint(.purple)
        }
    }

    private func networkStatView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.green)
                Text("Network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
            let uploadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.upload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
            let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)
            
            networkDataRow(systemImage: "arrow.up.circle.fill", 
                          systemImageColor: .red,
                          label: "Upload:",
                          value: "\(uploadFormatted.value) \(uploadFormatted.unit)")
            
            networkDataRow(systemImage: "arrow.down.circle.fill",
                          systemImageColor: .blue,
                          label: "Download:",
                          value: "\(downloadFormatted.value) \(downloadFormatted.unit)")
            
            // External IP with country flag
            if !externalIPManager.externalIP.isEmpty {
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.green)
                    Text("External IP:")
                    Spacer()
                    HStack(spacing: 4) {
                        Text(externalIPManager.flagEmoji)
                        Text(externalIPManager.externalIP)
                    }
                }
                .font(.caption)
            }
        }
        .font(.caption)
    }
    
    // Sparkline view for network usage trend
    private func networkSparklineView() -> some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("Network Trend (1 min)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            MultiSeriesSparklineView(
                series: [
                    (data: systemMonitor.uploadHistory, color: .red),
                    (data: systemMonitor.downloadHistory, color: .blue)
                ],
                lineWidth: 2
            )
            .frame(height: 30)
            
            // Averages for network
            if !systemMonitor.uploadHistory.isEmpty || !systemMonitor.downloadHistory.isEmpty {
                HStack(spacing: 12) {
                    if !systemMonitor.uploadHistory.isEmpty {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 8, height: 2)
                            Text("Upload:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", (systemMonitor.uploadHistory.reduce(0, +) / Double(systemMonitor.uploadHistory.count)) / 1000))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.red)
                        }
                    }
                    
                    if !systemMonitor.downloadHistory.isEmpty {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 2)
                            Text("Download:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", (systemMonitor.downloadHistory.reduce(0, +) / Double(systemMonitor.downloadHistory.count)) / 1000))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // Power Consumption View
    @ViewBuilder
    private func powerConsumptionView() -> some View {
        // Only show if we have valid power consumption data
        if systemMonitor.powerConsumptionInfo.totalSystemPower > 0 {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("Power Consumption")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Total system power
                HStack {
                    Text("Total:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f W", systemMonitor.powerConsumptionInfo.totalSystemPower))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.yellow)
                    Spacer()
                }
                
                // CPU power
                HStack {
                    Text("CPU:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f W", systemMonitor.powerConsumptionInfo.cpuPower))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.orange)
                    Spacer()
                }
                
                // GPU power
                HStack {
                    Text("GPU:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f W", systemMonitor.powerConsumptionInfo.gpuPower))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
        }
    }
    
    // Helper function to format timestamp
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Battery Status View
    @ViewBuilder
    private func batteryStatusView() -> some View {
        // Only show if battery is present
        if systemMonitor.batteryInfo.present {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: getBatteryIconName())
                        .foregroundColor(getBatteryIconColor())
                    Text("Battery Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ProgressView(value: systemMonitor.batteryInfo.chargeLevel, total: 100) {
                    Text(String(format: "%.0f%%", systemMonitor.batteryInfo.chargeLevel))
                        .font(.caption)
                        .monospacedDigit()
                }
                .tint(batteryChargeColor(for: systemMonitor.batteryInfo.chargeLevel))
                
                // First row: Cycle Count on left, Time on right
                HStack {
                    Text("Cycle Count:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(systemMonitor.batteryInfo.cycleCount)")
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text("Time:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(systemMonitor.batteryInfo.timeRemaining))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                // Second row: Max Capacity on left, Health on right
                HStack {
                    Text("Max Capacity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(systemMonitor.batteryInfo.maxCapacity)%")
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if systemMonitor.batteryInfo.health != "Unknown" {
                        Text("Health:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(systemMonitor.batteryInfo.health)
                            .font(.caption)
                    }
                }
                
                // Third row: Temperature (if available)
                if systemMonitor.batteryInfo.temperature > 0 {
                    HStack {
                        Text("Temp:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f°C", systemMonitor.batteryInfo.temperature))
                            .font(.caption)
                            .monospacedDigit()
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    // Helper function to determine Battery icon based on charge level
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
    
    // Helper function to determine Battery icon color based on charge level
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
    
    // Helper function to determine color based on Battery charge level for progress bar
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
    
    // UPS Status View
    @ViewBuilder
    private func upsStatusView() -> some View {
        // Only show if UPS is present
        if systemMonitor.upsInfo.present {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: getUPSIconName())
                        .foregroundColor(getUPSIconColor())
                    Text("UPS Status")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                ProgressView(value: systemMonitor.upsInfo.chargeLevel, total: 100) {
                    Text(String(format: "%.0f%%", systemMonitor.upsInfo.chargeLevel))
                        .font(.caption)
                        .monospacedDigit()
                }
                .tint(upsChargeColor(for: systemMonitor.upsInfo.chargeLevel))
                
                HStack {
                    Text("Name:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(systemMonitor.upsInfo.name)
                        .font(.caption)
                        .truncationMode(.tail)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("Time:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatTime(systemMonitor.upsInfo.timeRemaining))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                // Display UPS power source and charging status
                HStack {
                    Text("Power:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // Parse pmset -g batt output to determine power source
                    Text(systemMonitor.upsInfo.powerSource)
                        .font(.caption)
                        .foregroundColor(getPowerSourceColor(for: systemMonitor.upsInfo.powerSource))
                    
                    Spacer()
                    
                    Text("Charging:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // Based on your requirement: "No" in green, "Yes" in red
                    if systemMonitor.upsInfo.isCharging {
                        Text("Yes")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("No")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    // Helper function to determine UPS icon based on charge level
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
    
    // Helper function to determine UPS icon color based on charge level
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
    
    // Helper function to determine color based on UPS charge level for progress bar
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
    
    // Helper function to determine color based on power source
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

    // Helper function to format time in hours and minutes
    private func formatTime(_ minutes: Double) -> String {
        // Handle invalid time values (-1 is used by macOS when time can't be calculated)
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
    
    // Helper function to format uptime in a readable format
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
    
    // Helper function to format boot time in a readable format
    private func formatBootTime(_ bootTime: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: bootTime)
    }
    
    // Reusable network data row
    private func networkDataRow(systemImage: String, systemImageColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(systemImageColor)
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }
    
    private func footerButtons() -> some View {
        HStack {
            Button("About...") {
                NSApp.orderFrontStandardAboutPanel()
                NSApp.activate(ignoringOtherApps: true)
            }
            
            Button("Settings...") {
                // MODIFIED: Better window activation to ensure settings window is at forefront
                openWindow(id: "settings")
                DispatchQueue.main.async {
                    // Find and activate the settings window
                    if let settingsWindow = NSApp.windows.first(where: { $0.title == "Settings" }) {
                        settingsWindow.makeKeyAndOrderFront(nil)
                        settingsWindow.level = .floating  // Keep window floating
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                // Close the menu bar extra window
                NSApp.sendAction(Selector(("dismiss:")), to: nil, from: nil)
            }
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}