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
    private let networkFont = Font.system(size: 9, weight: .regular, design: .monospaced)
    private let compactSpacing: CGFloat = -4 // Reduced from -3 to -4
    
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
        .frame(maxWidth: 250, maxHeight: 22) // Reduced from 300 to 250
        .fixedSize()
        .monospacedDigit()
    }
    
    private func shouldShowAnyStats() -> Bool {
        return (preferences.showCPU && preferences.showMenuBarCPU) ||
               (preferences.showMemory && preferences.showMenuBarMemory) ||
               (preferences.showDisk && preferences.showMenuBarDisk) ||
               (preferences.showNetwork && preferences.showMenuBarNetwork) ||
               preferences.showMenuBarUptime
    }
    
    private func enabledStatsView() -> some View {
        HStack(alignment: .center, spacing: 2) { // Reduced from 3 to 2 to further decrease spacing
            if preferences.showCPU && preferences.showMenuBarCPU {
                cpuStatView()
            }
            if preferences.showMemory && preferences.showMenuBarMemory {
                memoryStatView()
            }
            if preferences.showDisk && preferences.showMenuBarDisk {
                diskStatView()
            }
            if preferences.showNetwork && preferences.showMenuBarNetwork {
                networkStatCompactView()
            }
            if preferences.showMenuBarUptime {
                uptimeStatView()
            }
        }
        .frame(maxWidth: 350) // Reduced from 400
        .monospacedDigit()
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
            HStack(spacing: 0) { // Reduced from 1 to 0
                Image(systemName: "arrow.up")
                    .font(compactFont)
                    .foregroundColor(.green)
                    .imageScale(.small)
                Text("UP")
                    .font(compactFont)
                    .padding(.leading, 0) // Removed padding
            }
            Text(formatCompactUptime(systemMonitor.systemInfo.uptime))
                .font(dataFont)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(width: 50) // Reduced from 60
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
            Text(String(format: "%.1fG", systemMonitor.memoryUsage.total - systemMonitor.memoryUsage.used))
                .font(dataFont)
        }
        .frame(width: 45) // Reduced from 50
        .monospacedDigit()
    }
    
    @ViewBuilder
    private func diskStatView() -> some View {
        VStack(alignment: .center, spacing: compactSpacing) {
            Text("DSK")
                .font(compactFont)
            Text(String(format: "%.0fG", systemMonitor.diskUsage.free))
                .font(dataFont)
        }
        .frame(width: 35) // Reduced from 40
        .monospacedDigit()
    }
    
    @ViewBuilder
    private func networkStatCompactView() -> some View {
        let unitType: NetworkFormatter.UnitType = preferences.networkUnit == .bits ? .bits : .bytes
        let uploadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.upload, unitType: unitType, autoScale: preferences.autoScaleNetwork)
        let downloadFormatted = NetworkFormatter.formatNetworkValue(systemMonitor.networkUsage.download, unitType: unitType, autoScale: preferences.autoScaleNetwork)
        
        let speedWidth: CGFloat = 25 // Reduced from 30
        let unitWidth: CGFloat = 28  // Reduced from 32

        HStack(alignment: .center, spacing: -4) { // Keep spacing between network data and NIC label
            VStack(alignment: .leading, spacing: compactSpacing) {
                HStack(spacing: 1) { // Reduced from 2 to 1
                    Text(uploadFormatted.value)
                        .frame(width: speedWidth, alignment: .trailing)
                        .font(networkFont)
                    Image(systemName: "arrow.up")
                        .foregroundColor(.red)
                        .imageScale(.small)
                    Text(uploadFormatted.unit)
                        .frame(width: unitWidth, alignment: .leading)
                        .font(networkFont)
                }
                
                HStack(spacing: 1) { // Reduced from 2 to 1
                    Text(downloadFormatted.value)
                        .frame(width: speedWidth, alignment: .trailing)
                        .font(networkFont)
                    Image(systemName: "arrow.down")
                        .foregroundColor(.blue)
                        .imageScale(.small)
                    Text(downloadFormatted.unit)
                        .frame(width: unitWidth, alignment: .leading)
                        .font(networkFont)
                }
            }
            
            // NIC label - placed to the right of all network data
            VStack(alignment: .center, spacing: -3) { // Changed from -1 to 0 for minimal letter spacing
                Text("N")
                    .font(compactFont)
                    .fontWeight(.regular)
                Text("I")
                    .font(compactFont)
                    .fontWeight(.regular)
                Text("C")
                    .font(compactFont)
                    .fontWeight(.regular)
            }
            .fixedSize()
        }
        .frame(width: 70) // Reduced from 80
        .monospacedDigit()
    }
}
