//
//  SystemMonitor+Battery.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation
import IOKit

extension SystemMonitor {
    // Battery cycle count and maximum capacity. Tries IOKit (instant, no subprocess)
    // first, falls back to system_profiler if the registry keys are missing.
    // Cached for 10 minutes regardless of source.
    func getBatteryDetails() -> (cycleCount: Int, maxCapacity: Int) {
        let now = Date()
        if let cached = cachedBatteryDetails,
           now.timeIntervalSince(lastBatteryDetailsUpdate) < 600 {
            return cached
        }

        if let details = readBatteryDetailsFromIOKit() {
            cachedBatteryDetails = details
            lastBatteryDetailsUpdate = now
            return details
        }

        if let details = readBatteryDetailsFromSystemProfiler() {
            cachedBatteryDetails = details
            lastBatteryDetailsUpdate = now
            return details
        }

        return (cycleCount: 0, maxCapacity: 100)
    }

    private func readBatteryDetailsFromIOKit() -> (cycleCount: Int, maxCapacity: Int)? {
        // AppleSmartBattery exists on both Intel and Apple Silicon laptops.
        for className in ["AppleSmartBattery", "AppleARMBattery"] {
            let service = IOServiceGetMatchingService(0, IOServiceMatching(className))
            guard service != IO_OBJECT_NULL else { continue }
            defer { IOObjectRelease(service) }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as NSDictionary? as? [String: Any] else {
                continue
            }

            let cycleCount = (dict["CycleCount"] as? Int) ?? 0
            let designCapacity = (dict["DesignCapacity"] as? Int) ?? 0
            let rawMaxCapacity = (dict["AppleRawMaxCapacity"] as? Int)
                              ?? (dict["NominalChargeCapacity"] as? Int)
                              ?? 0

            // Newer macOS exposes MaxCapacity directly as a percentage; older builds
            // require computing it from raw / design.
            let maxCapacityPct: Int
            if designCapacity > 0 && rawMaxCapacity > 0 {
                maxCapacityPct = Int((Double(rawMaxCapacity) / Double(designCapacity)) * 100.0)
            } else if let mc = dict["MaxCapacity"] as? Int, (1...100).contains(mc) {
                maxCapacityPct = mc
            } else {
                continue
            }

            guard cycleCount >= 0, (1...100).contains(maxCapacityPct) else { continue }
            return (cycleCount: cycleCount, maxCapacity: maxCapacityPct)
        }
        return nil
    }

    private func readBatteryDetailsFromSystemProfiler() -> (cycleCount: Int, maxCapacity: Int)? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPPowerDataType"]
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Error getting battery details: \(error)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        var cycleCount = 0
        var maxCapacity = 100
        for line in output.split(separator: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.contains("Cycle Count:") {
                let components = trimmedLine.split(separator: ":")
                if components.count > 1 {
                    cycleCount = Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            }
            if trimmedLine.contains("Maximum Capacity:") {
                let components = trimmedLine.split(separator: ":")
                if components.count > 1 {
                    let pct = components[1].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "%", with: "")
                    maxCapacity = Int(pct) ?? 100
                }
            }
        }
        return (cycleCount: cycleCount, maxCapacity: maxCapacity)
    }
}