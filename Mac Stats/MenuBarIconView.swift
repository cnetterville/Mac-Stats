//
//  MenuBarIconView.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI

struct MenuBarIconView: View {
    @Environment(SystemMonitor.self) private var systemMonitor
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
        return preferences.showMenuBarCPU ||
               preferences.showMenuBarMemory ||
               preferences.showMenuBarDisk ||
               preferences.showMenuBarNetwork ||
               preferences.showMenuBarUptime ||
               preferences.showMenuBarPower ||
               preferences.showMenuBarCPUTemp ||
               preferences.showMenuBarFanSpeed
    }
    
    private var visibleStats: [MenuBarStatID] {
        preferences.menuBarStatOrder.filter { isStatEnabled($0) }
    }

    private func isStatEnabled(_ stat: MenuBarStatID) -> Bool {
        switch stat {
        case .cpu:      return preferences.showMenuBarCPU
        case .memory:   return preferences.showMenuBarMemory
        case .disk:     return preferences.showMenuBarDisk
        case .network:  return preferences.showMenuBarNetwork
        case .uptime:   return preferences.showMenuBarUptime
        case .power:    return preferences.showMenuBarPower
        case .cpuTemp:  return preferences.showMenuBarCPUTemp
        case .fanSpeed: return preferences.showMenuBarFanSpeed
        }
    }

    @ViewBuilder
    private func statView(for stat: MenuBarStatID) -> some View {
        switch stat {
        case .cpu:      cpuStatView()
        case .memory:   memoryStatView()
        case .disk:     diskStatView()
        case .network:  networkStatCompactView()
        case .uptime:   uptimeStatView()
        case .power:    powerStatView()
        case .cpuTemp:  cpuTempStatView()
        case .fanSpeed: fanStatView()
        }
    }

    private func enabledStatsView() -> some View {
        let stats = visibleStats
        return HStack(alignment: .center, spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element) { index, stat in
                if index > 0 { statDivider() }
                statView(for: stat).padding(.horizontal, 2)
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
            Image(systemName: "clock")
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
        HStack(spacing: 3) {
            VStack(alignment: .center, spacing: compactSpacing) {
                Text("CPU")
                    .font(compactFont)
                Text(systemMonitor.cpuUsage < 10 ? String(format: "%.0f%%", systemMonitor.cpuUsage) : String(format: "%02.0f%%", systemMonitor.cpuUsage))
                    .font(dataFont)
                    .foregroundColor(cpuUsageColor())
            }
            if preferences.showMenuBarCPUChart {
                SparklineView(data: systemMonitor.cpuHistory, lineColor: cpuUsageColor(), lineWidth: 1.0,
                              fixedMin: 0, fixedMax: 100)
                    .frame(width: 28, height: 16)
            }
        }
        .frame(width: preferences.showMenuBarCPUChart ? 66 : 35)
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
        let memPct = systemMonitor.memoryUsage.total > 0
            ? (systemMonitor.memoryUsage.used / systemMonitor.memoryUsage.total) * 100 : 0.0
        HStack(spacing: 3) {
            VStack(alignment: .center, spacing: compactSpacing) {
                Text("MEM")
                    .font(compactFont)
                Text(String(format: "%.0f%%", memPct))
                    .font(dataFont)
                    .foregroundColor(memUsageColor(memPct))
            }
            if preferences.showMenuBarMemChart {
                SparklineView(data: systemMonitor.memoryHistory, lineColor: memUsageColor(memPct), lineWidth: 1.0,
                              fixedMin: 0, fixedMax: 100)
                    .frame(width: 28, height: 16)
            }
        }
        .frame(width: preferences.showMenuBarMemChart ? 66 : 35)
        .monospacedDigit()
    }

    private func memUsageColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<60: return .white
        case 60..<85: return .yellow
        default:     return .red
        }
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
                .foregroundColor(diskUsageColor(used))
        }
        .frame(width: 35)
        .monospacedDigit()
    }

    private func diskUsageColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<75: return .white
        case 75..<90: return .yellow
        default:     return .red
        }
    }
    
    @ViewBuilder
    private func networkStatCompactView() -> some View {
        let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
        let uploadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.upload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
        let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)

        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 2) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.red)
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 9, alignment: .center)
                Text("\(uploadFormatted.value)\(uploadFormatted.unit)")
                    .font(networkFont)
                    .lineLimit(1)
            }
            HStack(spacing: 2) {
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 9, alignment: .center)
                Text("\(downloadFormatted.value)\(downloadFormatted.unit)")
                    .font(networkFont)
                    .lineLimit(1)
            }
        }
        .fixedSize()
        .monospacedDigit()
    }

    @ViewBuilder
    private func powerStatView() -> some View {
        let watts = systemMonitor.dcInPower > 0 ? systemMonitor.dcInPower : systemMonitor.powerConsumptionInfo.totalSystemPower
        HStack(spacing: 3) {
            VStack(alignment: .center, spacing: compactSpacing) {
                Text("PWR")
                    .font(compactFont)
                Text(String(format: "%.0fW", watts))
                    .font(dataFont)
                    .foregroundColor(powerColor(for: watts))
            }
            if preferences.showMenuBarPowerChart {
                SparklineView(data: systemMonitor.powerHistory, lineColor: powerColor(for: watts), lineWidth: 1.0,
                              fixedMin: 0)
                    .frame(width: 28, height: 16)
            }
        }
        .frame(width: preferences.showMenuBarPowerChart ? 73 : 42)
        .monospacedDigit()
    }

    @ViewBuilder
    private func cpuTempStatView() -> some View {
        let temp = systemMonitor.cpuTemperature
        let value = preferences.temperatureUnit == .fahrenheit
            ? TemperatureMonitor.celsiusToFahrenheit(temp) : temp
        let unit  = preferences.temperatureUnit == .fahrenheit ? "°F" : "°C"
        // Build display history in the current unit
        let tempHistory: [Double] = preferences.temperatureUnit == .fahrenheit
            ? systemMonitor.cpuTemperatureHistory.map { TemperatureMonitor.celsiusToFahrenheit($0) }
            : systemMonitor.cpuTemperatureHistory
        HStack(spacing: 3) {
            VStack(alignment: .center, spacing: compactSpacing) {
                Text("TMP")
                    .font(compactFont)
                Text(String(format: "%.0f\(unit)", value))
                    .font(dataFont)
                    .foregroundColor(tempColor(for: temp))
            }
            if preferences.showMenuBarTempChart {
                SparklineView(data: tempHistory, lineColor: tempColor(for: temp), lineWidth: 1.0)
                    .frame(width: 28, height: 16)
            }
        }
        .frame(width: preferences.showMenuBarTempChart ? 73 : 42)
        .monospacedDigit()
    }

    @ViewBuilder
    private func fanStatView() -> some View {
        let rpm = systemMonitor.fanInfo.rpm
        HStack(spacing: 3) {
            VStack(alignment: .center, spacing: compactSpacing) {
                Text("FAN")
                    .font(compactFont)
                Text(rpm > 0 ? formatRPM(rpm) : "---")
                    .font(dataFont)
            }
            if preferences.showMenuBarFanChart {
                SparklineView(data: systemMonitor.fanHistory, lineColor: .cyan, lineWidth: 1.0,
                              fixedMin: 0)
                    .frame(width: 28, height: 16)
            }
        }
        .frame(width: preferences.showMenuBarFanChart ? 73 : 42)
        .monospacedDigit()
    }

    private func formatRPM(_ rpm: Double) -> String {
        rpm >= 1000 ? String(format: "%.1fk", rpm / 1000) : String(format: "%.0f", rpm)
    }

    private func powerColor(for watts: Double) -> Color {
        systemMonitor.thermalProfile.menuBarPowerColor(watts)
    }

    private func tempColor(for celsius: Double) -> Color {
        systemMonitor.thermalProfile.menuBarTemperatureColor(celsius)
    }
}