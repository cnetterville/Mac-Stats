//
//  ExtraStatsCards.swift
//  Mac Stats
//
//  Cards for the extra Performance-tab metrics (GPU utilization, CPU cluster
//  frequency, per-process energy impact) and Storage-tab metrics (NVMe SSD
//  health, Time Machine status). Rendered inside TabbedStatsView, which owns
//  the PerformanceExtrasMonitor / StorageExtrasMonitor instances.
//

import SwiftUI

// MARK: - GPU card

struct GPUUsageCard: View {
    let extras: PerformanceExtrasMonitor
    @Environment(SystemMonitor.self) private var systemMonitor

    var body: some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "GPU", icon: "square.stack.3d.up.fill", color: .orange)

                if let usage = extras.gpuUtilization {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Utilization")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.0f%%", usage))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundColor(.orange)
                        }

                        ProgressView(value: usage, total: 100)
                            .tint(.orange)
                            .scaleEffect(y: 1.5)

                        if extras.gpuHistory.count >= 2 {
                            SparklineView(data: extras.gpuHistory,
                                          lineColor: .orange,
                                          lineWidth: 1.5,
                                          fixedMin: 0,
                                          fixedMax: 100)
                                .frame(height: 36)
                        }

                        if systemMonitor.gpuTemperature > 0 {
                            Divider()
                            GlassInfoRowView(
                                label: "GPU Temperature",
                                value: String(format: "%.0f°C", systemMonitor.gpuTemperature),
                                valueColor: systemMonitor.gpuTemperature > 85 ? .red : .primary
                            )
                        }
                    }
                } else {
                    Text(extras.hasSampled
                         ? "GPU utilization is not available on this Mac"
                         : "Reading GPU statistics…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - CPU frequency card (Apple Silicon only)

struct CPUFrequencyCard: View {
    let extras: PerformanceExtrasMonitor

    var body: some View {
        if extras.frequencySupported {
            EnhancedCardView {
                VStack(alignment: .leading, spacing: 12) {
                    EnhancedCardHeaderView(title: "CPU Frequency", icon: "gauge.with.needle", color: .orange)

                    if let freq = extras.clusterFrequency {
                        VStack(alignment: .leading, spacing: 10) {
                            clusterRow(label: "Performance Cores",
                                       current: freq.pCoreMHz,
                                       max: freq.pCoreMaxMHz,
                                       color: .orange)
                            clusterRow(label: "Efficiency Cores",
                                       current: freq.eCoreMHz,
                                       max: freq.eCoreMaxMHz,
                                       color: .mint)

                            Text("Average active frequency over the last sample")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Measuring cluster frequencies…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clusterRow(label: String, current: Double, max maxValue: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatMHz(current))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(color)
                Text("/ \(formatMHz(maxValue))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            ProgressView(value: min(current, maxValue), total: maxValue > 0 ? maxValue : 1)
                .tint(color)
                .scaleEffect(y: 1.5)
        }
    }

    private func formatMHz(_ mhz: Double) -> String {
        mhz >= 1000
            ? String(format: "%.2f GHz", mhz / 1000)
            : String(format: "%.0f MHz", mhz)
    }
}

// MARK: - Energy impact card

struct EnergyImpactCard: View {
    let extras: PerformanceExtrasMonitor
    @Environment(SystemMonitor.self) private var systemMonitor

    var body: some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Energy Impact", icon: "bolt.circle.fill", color: .orange)

                if !extras.topEnergyProcesses.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(extras.topEnergyProcesses) { process in
                            HStack {
                                Text(process.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text(process.isEstimate
                                     ? String(format: "%.1f%% CPU", process.milliwatts)
                                     : formatPower(process.milliwatts))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.orange)
                            }
                        }

                        if !extras.energySupported {
                            Text("Per-process energy metering isn't available on this Mac — ranking by CPU time instead")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(extras.hasSampled
                         ? "Collecting energy samples…"
                         : "Reading process activity…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                Divider()

                GlassInfoRowView(label: "Processes", value: "\(systemMonitor.processCount)")
                GlassInfoRowView(label: "Threads", value: "\(systemMonitor.threadCount)")
            }
        }
    }

    private func formatPower(_ milliwatts: Double) -> String {
        milliwatts >= 1000
            ? String(format: "%.2f W", milliwatts / 1000)
            : String(format: "%.0f mW", milliwatts)
    }
}

// MARK: - SSD health card

struct SSDHealthCard: View {
    let extras: StorageExtrasMonitor

    var body: some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "SSD Health", icon: "waveform.path.ecg", color: .purple)

                if !extras.drives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(extras.drives) { drive in
                            driveSection(drive)
                            if drive.id != extras.drives.last?.id {
                                Divider()
                            }
                        }
                    }
                } else {
                    Text(extras.smartSampled
                         ? "No drives with NVMe SMART access found"
                         : "Reading SMART data…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private func driveSection(_ drive: NVMeDriveHealth) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(drive.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(drive.hasCriticalWarning ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(drive.hasCriticalWarning ? "Warning" : "Healthy")
                        .font(.caption)
                        .foregroundColor(drive.hasCriticalWarning ? .red : .green)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Life Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(drive.lifeRemainingPercent)%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundColor(lifeColor(drive.lifeRemainingPercent))
                }
                ProgressView(value: Double(drive.lifeRemainingPercent), total: 100)
                    .tint(lifeColor(drive.lifeRemainingPercent))
                    .scaleEffect(y: 1.5)
            }

            GlassInfoRowView(label: "Data Written", value: formatBytes(drive.dataWrittenBytes))
            GlassInfoRowView(label: "Data Read", value: formatBytes(drive.dataReadBytes))
            GlassInfoRowView(label: "Power On", value: formatHours(drive.powerOnHours))
            GlassInfoRowView(label: "Power Cycles", value: "\(drive.powerCycles)")
            if drive.unsafeShutdowns > 0 {
                GlassInfoRowView(label: "Unsafe Shutdowns", value: "\(drive.unsafeShutdowns)")
            }
            if drive.mediaErrors > 0 {
                GlassInfoRowView(label: "Media Errors", value: "\(drive.mediaErrors)", valueColor: .red)
            }
            if drive.temperatureC > 0 {
                GlassInfoRowView(
                    label: "Drive Temperature",
                    value: String(format: "%.0f°C", drive.temperatureC),
                    valueColor: drive.temperatureC > 70 ? .red : .primary
                )
            }
            GlassInfoRowView(label: "Available Spare", value: "\(drive.availableSpare)%")
        }
    }

    private func lifeColor(_ percent: Int) -> Color {
        if percent > 50 { return .green }
        if percent > 20 { return .yellow }
        return .red
    }

    private func formatBytes(_ bytes: Double) -> String {
        let tb = bytes / 1_000_000_000_000.0
        if tb >= 1 { return String(format: "%.2f TB", tb) }
        return String(format: "%.0f GB", bytes / 1_000_000_000.0)
    }

    private func formatHours(_ hours: UInt64) -> String {
        if hours >= 48 {
            return String(format: "%.1f days", Double(hours) / 24.0)
        }
        return "\(hours) hours"
    }
}

// MARK: - Time Machine card

struct TimeMachineCard: View {
    let extras: StorageExtrasMonitor

    var body: some View {
        EnhancedCardView {
            VStack(alignment: .leading, spacing: 12) {
                EnhancedCardHeaderView(title: "Time Machine", icon: "clock.arrow.circlepath", color: .purple)

                if extras.timeMachine.isConfigured {
                    VStack(alignment: .leading, spacing: 8) {
                        GlassInfoRowView(label: "Destination", value: extras.timeMachine.destinationName)
                        if !extras.timeMachine.destinationKind.isEmpty {
                            GlassInfoRowView(label: "Kind", value: extras.timeMachine.destinationKind)
                        }

                        if let lastBackup = extras.timeMachine.latestBackupDate {
                            HStack {
                                Text("Last Backup")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(backupAgeColor(lastBackup))
                                        .frame(width: 8, height: 8)
                                    Text(relativeDate(lastBackup))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(backupAgeColor(lastBackup))
                                }
                            }
                        } else if let reason = extras.timeMachine.latestBackupUnavailableReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(extras.timeMachineSampled
                         ? "Time Machine is not configured"
                         : "Checking Time Machine…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func backupAgeColor(_ date: Date) -> Color {
        let age = Date().timeIntervalSince(date)
        if age < 25 * 3600 { return .green }        // within ~a day
        if age < 7 * 24 * 3600 { return .yellow }   // within a week
        return .red
    }
}
