//
//  SystemMonitor+Battery.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation

// Extension to help with parsing system_profiler output
extension SystemMonitor {
    // Get battery cycle count and maximum capacity from system_profiler.
    // Results are cached for 10 minutes to avoid expensive subprocess launches on every tick.
    func getBatteryDetails() -> (cycleCount: Int, maxCapacity: Int) {
        let now = Date()
        if let cached = cachedBatteryDetails,
           now.timeIntervalSince(lastBatteryDetailsUpdate) < 600 {
            return cached
        }

        let task = Process()
        let pipe = Pipe()

        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPPowerDataType"]
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.split(separator: "\n")
                var cycleCount = 0
                var maxCapacity = 100

                for line in lines {
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

                let result = (cycleCount: cycleCount, maxCapacity: maxCapacity)
                cachedBatteryDetails = result
                lastBatteryDetailsUpdate = now
                return result
            }
        } catch {
            print("Error getting battery details: \(error)")
        }

        return (cycleCount: 0, maxCapacity: 100)
    }
}