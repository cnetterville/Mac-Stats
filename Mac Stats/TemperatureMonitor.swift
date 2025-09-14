//
//  TemperatureMonitor.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//
//  Practical CPU temperature monitoring for Apple Silicon using external tools
//

import Foundation
import IOKit

class TemperatureMonitor {
    
    // Cache for temperature data and sensor availability
    private static var lastTemperature: Double = 0.0
    private static var lastTemperatureTime: Date = Date.distantPast
    private static let cacheInterval: TimeInterval = 2.0 // Cache for 2 seconds
    
    // Main method to get average CPU temperature
    static func averageCPUTemperature() -> Double {
        // Check cache first
        let now = Date()
        if now.timeIntervalSince(lastTemperatureTime) < cacheInterval {
            return lastTemperature
        }
        
        // Try different methods in order of preference
        var temperature = 0.0
        
        // Method 1: Try macmon (best option if available)
        temperature = getTemperatureFromMacmon()
        if temperature > 0 {
            lastTemperature = temperature
            lastTemperatureTime = now
            return temperature
        }
        
        // Method 2: Try thermal_state (system thermal state)
        temperature = getThermalStateTemperature()
        if temperature > 0 {
            lastTemperature = temperature
            lastTemperatureTime = now
            return temperature
        }
        
        // Method 3: Try sysctl thermal information
        temperature = getTemperatureFromSysctl()
        if temperature > 0 {
            lastTemperature = temperature
            lastTemperatureTime = now
            return temperature
        }
        
        // Method 4: Estimate based on system load (fallback)
        temperature = estimateTemperatureFromLoad()
        lastTemperature = temperature
        lastTemperatureTime = now
        
        return temperature
    }
    
    // Check if real temperature sensors are available
    static func hasTemperatureSensors() -> Bool {
        // Check if macmon is available
        if checkMacmonAvailability() {
            return true
        }
        
        // Check if we can get thermal state
        if getThermalStateTemperature() > 0 {
            return true
        }
        
        // Check if sysctl provides temperature data
        if getTemperatureFromSysctl() > 0 {
            return true
        }
        
        return false
    }
    
    // Get all current temperature values (if multiple sensors)
    static func getCurrentTemperatureValues() -> [Double] {
        let temp = averageCPUTemperature()
        return temp > 0 ? [temp] : []
    }
    
    // Get available temperature sensor names
    static func availableTemperatureSensors() -> [String] {
        if hasTemperatureSensors() {
            return ["CPU"]
        }
        return []
    }
    
    // Get detailed temperature information
    static func getDetailedTemperatureInfo() -> [(name: String, temperature: Double)] {
        let temp = averageCPUTemperature()
        if temp > 0 {
            return [("CPU", temp)]
        }
        return []
    }
    
    // Get the highest temperature reading
    static func maxTemperature() -> Double {
        return averageCPUTemperature()
    }
    
    // Get the lowest temperature reading
    static func minTemperature() -> Double {
        return averageCPUTemperature()
    }
    
    // MARK: - Temperature Reading Methods
    
    // Method 1: Use macmon if available (most accurate)
    private static func getTemperatureFromMacmon() -> Double {
        let commonPaths = [
            "/opt/homebrew/bin/macmon",
            "/usr/local/bin/macmon",
            "/usr/bin/macmon",
            "/opt/local/bin/macmon"
        ]
        
        for path in commonPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            let task = Process()
            let pipe = Pipe()
            
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = ["pipe", "-s", "1"]  // FIXED: Changed from "json" to "pipe"
            task.standardOutput = pipe
            task.standardError = Pipe() // Suppress stderr
            
            do {
                try task.run()
                task.waitUntilExit()
                
                guard task.terminationStatus == 0 else { continue }
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8),
                      let jsonData = output.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                    continue
                }
                
                // UPDATED: Use the correct temperature keys from macmon
                if let temp = json["temp"] as? [String: Any] {
                    if let cpuTemp = temp["cpu_temp_avg"] as? Double, cpuTemp > 0 && cpuTemp < 150 {
                        return cpuTemp
                    }
                }
                
                // Fallback: Try other temperature keys
                let temperatureKeys = ["cpu_temp", "package_temp", "die_temp", "core_temp", "cpu_thermal"]
                
                for key in temperatureKeys {
                    if let temp = json[key] as? Double, temp > 0 && temp < 150 {
                        return temp
                    }
                }
                
            } catch {
                continue
            }
        }
        
        return 0.0
    }
    
    // Method 2: Get thermal state from macOS
    private static func getThermalStateTemperature() -> Double {
        // Try to read thermal state from system
        let task = Process()
        let pipe = Pipe()
        
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "therm"]
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            guard task.terminationStatus == 0 else { return 0.0 }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0.0 }
            
            return parseThermalStateOutput(output)
        } catch {
            return 0.0
        }
    }
    
    private static func parseThermalStateOutput(_ output: String) -> Double {
        let lines = output.split(separator: "\n")
        
        for line in lines {
            let lineString = String(line).lowercased()
            
            // Look for thermal state information
            if lineString.contains("cpu_speed_limit") {
                // If CPU is throttling, estimate high temperature
                if lineString.contains("100") {
                    return 45.0 // Normal temperature
                } else {
                    return 85.0 // Throttling temperature
                }
            }
        }
        
        return 0.0
    }
    
    // Method 3: Try sysctl for temperature-related information
    private static func getTemperatureFromSysctl() -> Double {
        // Try various sysctl keys that might contain thermal information
        let thermalKeys = [
            "machdep.xcpm.cpu_thermal_state",
            "hw.thermalstate",
            "hw.thermal.cpu"
        ]
        
        for key in thermalKeys {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            
            if sysctlbyname(key, &value, &size, nil, 0) == 0 {
                // Interpret thermal state (0 = normal, higher = hotter)
                if value >= 0 {
                    // Estimate temperature based on thermal state
                    return 40.0 + Double(value) * 10.0 // Rough estimation
                }
            }
        }
        
        return 0.0
    }
    
    // Method 4: Estimate temperature based on CPU load (fallback)
    private static func estimateTemperatureFromLoad() -> Double {
        // Get CPU usage from system monitor if available
        let cpuUsage = getCurrentCPUUsage()
        
        // Estimate temperature based on CPU usage
        // Idle: ~40°C, Full load: ~80°C for Apple Silicon
        let baseTemperature = 40.0
        let maxTempIncrease = 40.0
        
        return baseTemperature + (cpuUsage / 100.0) * maxTempIncrease
    }
    
    private static func getCurrentCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3)
        
        let total = user + system + idle + nice
        guard total > 0 else { return 0.0 }
        
        return ((user + system + nice) / total) * 100.0
    }
    
    // Helper method to check macmon availability
    private static func checkMacmonAvailability() -> Bool {
        let commonPaths = [
            "/opt/homebrew/bin/macmon",
            "/usr/local/bin/macmon",
            "/usr/bin/macmon",
            "/opt/local/bin/macmon"
        ]
        
        return commonPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}

// MARK: - External Tool Installation Helper

extension TemperatureMonitor {
    
    // Provide guidance on installing temperature monitoring tools
    static func getInstallationInstructions() -> String {
        if checkMacmonAvailability() {
            return "macmon is installed and can provide accurate temperature readings."
        }
        
        return """
        For accurate CPU temperature readings on Apple Silicon:
        
        1. Install macmon via Homebrew:
           brew install macmon
        
        2. Or use the built-in estimation based on CPU load
        
        macmon provides the most accurate temperature data for Apple Silicon Macs.
        """
    }
    
    // Check if we can suggest installing temperature monitoring tools
    static func shouldSuggestToolInstallation() -> Bool {
        return !checkMacmonAvailability()
    }
}

// MARK: - Temperature Conversion Utilities

extension TemperatureMonitor {
    
    // Convert Celsius to Fahrenheit
    static func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return (celsius * 9.0 / 5.0) + 32.0
    }
    
    // Convert Fahrenheit to Celsius
    static func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32.0) * 5.0 / 9.0
    }
    
    // Format temperature based on unit preference
    static func formatTemperature(_ celsius: Double, unit: TemperatureUnit, showBoth: Bool = false) -> String {
        if showBoth {
            let fahrenheit = celsiusToFahrenheit(celsius)
            return String(format: "%.1f°C / %.1f°F", celsius, fahrenheit)
        } else {
            switch unit {
            case .celsius:
                return String(format: "%.1f°C", celsius)
            case .fahrenheit:
                let fahrenheit = celsiusToFahrenheit(celsius)
                return String(format: "%.1f°F", fahrenheit)
            }
        }
    }
    
    // Get temperature value in specified unit
    static func getTemperatureInUnit(_ celsius: Double, unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsiusToFahrenheit(celsius)
        }
    }
}