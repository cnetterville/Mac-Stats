//
//  NetworkFormatter.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation

struct NetworkFormatter {
    enum UnitType {
        case bits
        case bytes
    }
    
    static func formatNetworkValue(_ value: Double, unitType: UnitType, autoScale: Bool) -> (value: String, unit: String) {
        let convertedValue = unitType == .bits ? value * 8 : value // Convert to bits if needed
        
        if autoScale {
            return formatWithAutoScale(convertedValue, unitType: unitType)
        } else {
            return formatWithoutAutoScale(convertedValue, unitType: unitType)
        }
    }
    
    private static func formatWithAutoScale(_ value: Double, unitType: UnitType) -> (value: String, unit: String) {
        let unitSuffix = unitType == .bits ? "bps" : "B/s"
        
        switch abs(value) {
        case 0..<1_000:
            return (String(format: "%.0f", value), unitSuffix)
        case 1_000..<1_000_000:
            return (String(format: "%.1f", value / 1_000), "K\(unitSuffix)")
        case 1_000_000..<1_000_000_000:
            return (String(format: "%.1f", value / 1_000_000), "M\(unitSuffix)")
        case 1_000_000_000..<1_000_000_000_000:
            return (String(format: "%.1f", value / 1_000_000_000), "G\(unitSuffix)")
        default:
            return (String(format: "%.1f", value / 1_000_000_000_000), "T\(unitSuffix)")
        }
    }
    
    private static func formatWithoutAutoScale(_ value: Double, unitType: UnitType) -> (value: String, unit: String) {
        let unitSuffix = unitType == .bits ? "bps" : "B/s"
        return (String(format: "%.0f", value), unitSuffix)
    }
}