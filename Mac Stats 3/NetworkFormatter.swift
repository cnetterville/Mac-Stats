//
//  NetworkFormatter.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation

class NetworkFormatter {
    enum UnitType {
        case bytes
        case bits
    }
    
    static func formatNetworkValue(_ value: Double, unitType: UnitType, autoScale: Bool = true) -> (value: String, unit: String) {
        // Convert to bits if needed
        let baseValue = unitType == .bits ? value * 8 : value
        
        if autoScale {
            return autoFormat(baseValue, unitType: unitType)
        } else {
            // Fixed format in base units (B/s or b/s)
            let unitString = unitType == .bits ? "b/s" : "B/s"
            return (value: String(format: "%.0f", baseValue), unit: unitString)
        }
    }
    
    private static func autoFormat(_ value: Double, unitType: UnitType) -> (value: String, unit: String) {
        let units = unitType == .bits ? ["b/s", "Kb/s", "Mb/s", "Gb/s"] : ["B/s", "KB/s", "MB/s", "GB/s"]
        let base: Double = unitType == .bits ? 1000 : 1024
        
        var tempValue = value
        var unitIndex = 0
        
        while tempValue >= base && unitIndex < units.count - 1 {
            tempValue /= base
            unitIndex += 1
        }
        
        // Format with appropriate precision
        let valueString: String
        if tempValue < 10 {
            valueString = String(format: "%.1f", tempValue)
        } else {
            valueString = String(format: "%.0f", tempValue)
        }
        
        return (value: valueString, unit: units[unitIndex])
    }
}