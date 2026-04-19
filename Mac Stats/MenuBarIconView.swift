//
//  MenuBarIconView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

struct MenuBarIconView: View {
    @EnvironmentObject var systemMonitor: SystemMonitor
    @EnvironmentObject var preferences: PreferencesManager
    
    private let compactFont = Font.system(size: 9, weight: .regular, design: .monospaced)
    private let dataFont = Font.system(size: 11, weight: .regular, design: .monospaced)
    private let networkFont = Font.system(size: 10, weight: .regular, design: .monospaced)
    private let compactSpacing: CGFloat = -3 // Reduced from -4 to -3
    
    var body: some View {
        Group {
            if shouldShowAnyStats() {
                enabledStatsView()
            } else {
                Text("Mac Stats")
                    .font(compactFont)
            }
        }
        .foregroundColor(.white)
        .frame(height: 22)
        .fixedSize(horizontal: true, vertical: false)
        .monospacedDigit()
    }
    
    private func shouldShowAnyStats() -> Bool {
        return (preferences.showCPU && preferences.showMenuBarCPU) ||
               (preferences.showMemory && preferences.showMenuBarMemory) ||
               (preferences.showDisk && preferences.showMenuBarDisk) ||
               (preferences.showNetwork && preferences.showMenuBarNetwork) ||
               preferences.showMenuBarUptime ||
               preferences.showMenuBarPower ||
               preferences.showMenuBarCPUTemp
    }
    
    private func enabledStatsView() -> some View {
        // Build an ordered list of enabled stat views. Dividers are inserted
        // automatically between items — adding a new stat requires only one entry here.
        var items: [AnyView] = []
        if preferences.showCPU     && preferences.showMenuBarCPU    { items.append(AnyView(cpuStatView())) }
        if preferences.showMemory  && preferences.showMenuBarMemory  { items.append(AnyView(memoryStatView())) }
        if preferences.showDisk    && preferences.showMenuBarDisk    { items.append(AnyView(diskStatView())) }
        if preferences.showNetwork && preferences.showMenuBarNetwork { items.append(AnyView(networkStatCompactView())) }
        if preferences.showMenuBarUptime                            { items.append(AnyView(uptimeStatView())) }
        if preferences.showMenuBarPower                             { items.append(AnyView(powerStatView())) }
        if preferences.showMenuBarCPUTemp                           { items.append(AnyView(cpuTempStatView())) }

        return HStack(alignment: .center, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                if i > 0 { statDivider() }
                items[i].padding(.horizontal, 4)
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder
    private func statDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1, height: 14)
    }
    
    private func formatCompactUptime(_ uptime: TimeInterval) -> String {
        let totalSeconds = Int(uptime)
        let days = totalSeconds / (24 * 3600)
        let hours = (totalSeconds % (24 * 3600)) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            // For days, show a more compact format
            return "\(days)d\(hours)h"
        } else if hours > 0 {
            // Always show minutes with proper formatting when less than a day
            return String(format: "%dh%02dm", hours, minutes)
        } else {
            // When less than an hour, show just minutes
            return "\(minutes)m"
        }
    }
    
    @ViewBuilder
    private func uptimeStatView() -> some View {
        VStack(alignment: .center, spacing: compactSpacing) {
            Image(systemName: "arrow.up")
                .font(compactFont)
                .foregroundColor(.green)
                .imageScale(.small)
            Text(formatCompactUptime(systemMonitor.systemInfo.uptime))
                .font(dataFont)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(width: 40)
        .monospacedDigit()
    }
    
    @ViewBuilder
    private func cpuStatView() -> some View {
        // Fixed width container to prevent jitter
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("CPU")
                .font(compactFont)
                // Keep CPU label always white
            Text(systemMonitor.cpuUsage < 10 ? String(format: "%.0f%%", systemMonitor.cpuUsage) : String(format: "%02.0f%%", systemMonitor.cpuUsage))
                .font(dataFont)
                .foregroundColor(cpuUsageColor()) // Only the percentage changes color
        }
        .frame(width: 35) // Reduced from 40
        .monospacedDigit()
    }
    
    private func cpuUsageColor() -> Color {
        let usage = systemMonitor.cpuUsage
        switch usage {
        case 0..<30:
            return .white
        case 30..<70:
            return .yellow
        case 70...100:
            return .red
        default:
            return .white
        }
    }
    
    @ViewBuilder
    private func memoryStatView() -> some View {
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("MEM")
                .font(compactFont)
            Text(String(format: "%.0f%%", systemMonitor.memoryUsage.total > 0 ? (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100 : 0))
                .font(dataFont)
        }
        .frame(width: 45) // Reduced from 50
        .monospacedDigit()
    }
    
    @ViewBuilder
    private func diskStatView() -> some View {
        let used = systemMonitor.diskUsage.total > 0
            ? ((systemMonitor.diskUsage.total - systemMonitor.diskUsage.free) / systemMonitor.diskUsage.total) * 100
            : 0.0
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("DSK")
                .font(compactFont)
            Text(String(format: "%.0f%%", used))
                .font(dataFont)
        }
        .frame(width: 35)
        .monospacedDigit()
    }
    
    @ViewBuilder
    private func networkStatCompactView() -> some View {
        let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
        let uploadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.upload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
        let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)
        
        let speedWidth: CGFloat = 32
        let unitWidth: CGFloat = 34

        HStack(alignment: .center, spacing: -8) {
            VStack(alignment: .leading, spacing: compactSpacing) {
                HStack(spacing: 1) {
                    Text(uploadFormatted.value)
                        .frame(width: speedWidth, alignment: .trailing)
                        .font(networkFont)
                    Text(uploadFormatted.unit)
                        .frame(width: unitWidth, alignment: .leading)
                        .font(networkFont)
                }
                
                HStack(spacing: 1) {
                    Text(downloadFormatted.value)
                        .frame(width: speedWidth, alignment: .trailing)
                        .font(networkFont)
                    Text(downloadFormatted.unit)
                        .frame(width: unitWidth, alignment: .leading)
                        .font(networkFont)
                }
            }
            
            HStack(spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    Image(systemName: "arrow.up")
                        .foregroundColor(.red)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                    Image(systemName: "arrow.down")
                        .foregroundColor(.blue)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
                
                VStack(alignment: .center, spacing: -4) {
                    Text("L")
                        .font(compactFont)
                        .fontWeight(.regular)
                    Text("A")
                        .font(compactFont)
                        .fontWeight(.regular)
                    Text("N")
                        .font(compactFont)
                        .fontWeight(.regular)
                }
                .fixedSize()
            }
        }
        .frame(width: 95)
        .monospacedDigit()
    }

    @ViewBuilder
    private func powerStatView() -> some View {
        let watts = systemMonitor.powerConsumptionInfo.totalSystemPower
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("PWR")
                .font(compactFont)
            Text(watts >= 100 ? String(format: "%.0fW", watts) : String(format: "%.1fW", watts))
                .font(dataFont)
                .foregroundColor(powerColor(for: watts))
        }
        .frame(width: 42)
        .monospacedDigit()
    }

    @ViewBuilder
    private func cpuTempStatView() -> some View {
        let temp = systemMonitor.cpuTemperature
        let value = preferences.temperatureUnit == .fahrenheit
            ? TemperatureMonitor.celsiusToFahrenheit(temp) : temp
        let unit  = preferences.temperatureUnit == .fahrenheit ? "°F" : "°C"
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("TMP")
                .font(compactFont)
            Text(String(format: "%.0f\(unit)", value))
                .font(dataFont)
                .foregroundColor(tempColor(for: temp))
        }
        .frame(width: 42)
        .monospacedDigit()
    }

    private func powerColor(for watts: Double) -> Color {
        switch watts {
        case 0..<30:  return .white
        case 30..<80: return .yellow
        default:      return .red
        }
    }

    private func tempColor(for celsius: Double) -> Color {
        switch celsius {
        case 0..<60:  return .white
        case 60..<80: return .yellow
        default:      return .red
        }
    }
}