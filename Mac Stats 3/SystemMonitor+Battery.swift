//
//  SystemMonitor+Battery.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation

// Extension to help with parsing system_profiler output
extension SystemMonitor {
    // Get battery cycle count and maximum capacity from system_profiler
    func getBatteryDetails() -> (cycleCount: Int, maxCapacity: Int) {
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
                // Parse the output to get cycle count and maximum capacity
                let lines = output.split(separator: "\n")
                var cycleCount = 0
                var maxCapacity = 100
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    
                    // Look for Cycle Count
                    if trimmedLine.contains("Cycle Count:") {
                        let components = trimmedLine.split(separator: ":")
                        if components.count > 1 {
                            let valueString = components[1].trimmingCharacters(in: .whitespaces)
                            cycleCount = Int(valueString) ?? 0
                        }
                    }
                    
                    // Look for Maximum Capacity
                    if trimmedLine.contains("Maximum Capacity:") {
                        let components = trimmedLine.split(separator: ":")
                        if components.count > 1 {
                            let valueString = components[1].trimmingCharacters(in: .whitespaces)
                            // Remove the % sign and convert to integer
                            let percentageString = valueString.replacingOccurrences(of: "%", with: "")
                            maxCapacity = Int(percentageString) ?? 100
                        }
                    }
                }
                
                return (cycleCount: cycleCount, maxCapacity: maxCapacity)
            }
        } catch {
            print("Error getting battery details: \(error)")
        }
        
        return (cycleCount: 0, maxCapacity: 100)
    }
}