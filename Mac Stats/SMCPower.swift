//
//  SMCPower.swift
//  Mac Stats
//
//  Reads power, fan speed, and temperature data from the SMC
//  (System Management Controller) via IOKit.
//

import Foundation
import IOKit

// MARK: - Public API

/// Read total system power (in watts) from the SMC "PSTR" key.
/// Returns nil if the SMC is unavailable or the key is not present on this model.
func readSMCSystemPower() -> Double? {
    withSMCConnection { conn in
        guard let bytes = smcRead(conn, key: "PSTR", size: 4) else { return nil }
        var v: Float32 = 0
        withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: bytes) }
        let w = Double(v)
        return w > 0 ? w : nil
    }
}

/// Reads average CPU temperature (°C) directly from SMC P-core and E-core keys.
/// Returns nil if no recognised temperature keys respond on this model.
func readSMCCPUTemperature() -> Double? {
    // Apple Silicon P-core and E-core die temperature keys.
    // On Apple Silicon these return type 'flt' (IEEE 754 float, little-endian).
    // Older Intel Macs may use type 'sp78' (2-byte big-endian signed fixed-point).
    let keys = [
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j", // P-cores
        "Te05", "Te09"                                                       // E-cores
    ]
    return withSMCConnection { conn in
        var temps: [Double] = []
        for key in keys {
            guard let bytes = smcRead(conn, key: key, size: 4) else { continue }
            let celsius: Double
            if bytes.count >= 4 {
                // Decode as IEEE 754 float (little-endian, Apple Silicon native byte order)
                var value: Float32 = 0
                withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes[0..<4]) }
                celsius = Double(value)
            } else if bytes.count >= 2 {
                // sp78: 2-byte big-endian signed fixed-point, value = (Int16 / 256.0)
                let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
                celsius = Double(raw) / 256.0
            } else {
                continue
            }
            if celsius >= 20 && celsius < 120 { temps.append(celsius) }
        }
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }
}

struct SMCFanData {
    let speeds: [Int]    // actual RPM per fan
    let maxSpeeds: [Int] // max RPM per fan (from F{n}Mx key)
}

/// Returns actual and max RPM for each fan the SMC exposes on this Mac.
/// Returns nil if the SMC has no fan keys (fanless models).
func readSMCFans() -> SMCFanData? {
    withSMCConnection { conn in
        // FNum is a 1-byte key containing the fan count.
        guard let b = smcRead(conn, key: "FNum", size: 1) else { return nil }
        let count = Int(b[0])
        guard count > 0 && count < 20 else { return nil }

        var speeds: [Int] = []
        var maxSpeeds: [Int] = []
        for i in 0..<count {
            // F{n}Ac = actual speed, F{n}Mx = max speed
            // Type fpe2: 2-byte big-endian fixed-point, divide by 4 for RPM
            func readRPM(_ key: String) -> Int? {
                guard let bytes = smcRead(conn, key: key, size: 2) else { return nil }
                let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
                let rpm = Int((Double(raw) / 4.0).rounded())
                return rpm > 0 ? rpm : nil
            }
            if let rpm = readRPM("F\(i)Ac") { speeds.append(rpm) }
            if let rpm = readRPM("F\(i)Mx") { maxSpeeds.append(rpm) }
        }
        guard !speeds.isEmpty else { return nil }
        return SMCFanData(speeds: speeds, maxSpeeds: maxSpeeds)
    } ?? nil
}

/// Reads GPU die temperature (°C) from SMC.
/// Tries Apple Silicon keys Tg0D, Tg1D, then legacy TG0D.
func readSMCGPUTemperature() -> Double? {
    withSMCConnection { conn in
        for key in ["Tg0D", "Tg1D", "TG0D", "TG0P"] {
            guard let bytes = smcRead(conn, key: key, size: 4), bytes.count >= 4 else { continue }
            var value: Float32 = 0
            withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes[0..<4]) }
            let celsius = Double(value)
            if celsius >= 20 && celsius < 120 { return celsius }
        }
        return nil
    }
}

/// Reads NVMe/SSD temperature (°C) from SMC.
/// Tries the most common proximity and die keys across Apple Silicon and Intel Macs.
func readSMCSSDTemperature() -> Double? {
    withSMCConnection { conn in
        for key in ["TH0x", "TH0P", "TH1P", "TS0D", "TS0S"] {
            guard let bytes = smcRead(conn, key: key, size: 4), bytes.count >= 4 else { continue }
            var value: Float32 = 0
            withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes[0..<4]) }
            let celsius = Double(value)
            if celsius >= 20 && celsius < 100 { return celsius }
        }
        return nil
    }
}

/// Reads DC-in power (watts) from SMC key "PDTR" — the actual wattage being
/// drawn from the power adapter at this moment.
func readSMCDCInPower() -> Double? {
    withSMCConnection { conn in
        guard let bytes = smcRead(conn, key: "PDTR", size: 4), bytes.count >= 4 else { return nil }
        var value: Float32 = 0
        withUnsafeMutableBytes(of: &value) { $0.copyBytes(from: bytes[0..<4]) }
        let watts = Double(value)
        return watts > 0 ? watts : nil
    }
}

// MARK: - Connection helper

private func withSMCConnection<T>(_ body: (io_connect_t) -> T?) -> T? {
    let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSMC"))
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }

    var conn: io_connect_t = IO_OBJECT_NULL
    guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return nil }
    defer { IOServiceClose(conn) }

    return body(conn)
}

// MARK: - Private SMC struct layout

// These structs must match the Apple SMC driver's expected layout exactly.
// On ARM64 macOS the struct is 80 bytes (IOByteCount = UInt32 in the driver protocol).

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfo {
    var dataSize: UInt32 = 0        // UInt32 regardless of platform (driver protocol)
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var _pad: (UInt8, UInt8, UInt8) = (0, 0, 0)  // match C struct trailing padding → total 12 bytes
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

/// Two-step SMC read: first fetch key info to confirm the key exists and get its
/// exact data size, then read the value. More reliable than a single-step read.
private func smcRead(_ conn: io_connect_t, key: String, size: UInt32) -> [UInt8]? {
    let keyCode = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    let sz = MemoryLayout<SMCParamStruct>.size

    // Step 1: get key info (data8 = 9 = kSMCGetKeyInfo)
    var infoIn = SMCParamStruct(); var infoOut = SMCParamStruct()
    infoIn.key = keyCode; infoIn.data8 = 9
    var outSz = sz
    let infoRet = IOConnectCallStructMethod(conn, 2, &infoIn, sz, &infoOut, &outSz)
    guard infoRet == kIOReturnSuccess, infoOut.result == 0 else { return nil }
    let dataSize = infoOut.keyInfo.dataSize > 0 ? infoOut.keyInfo.dataSize : size

    // Step 2: read value (data8 = 5 = kSMCReadKey)
    var readIn = SMCParamStruct(); var readOut = SMCParamStruct()
    readIn.key = keyCode; readIn.keyInfo.dataSize = dataSize; readIn.data8 = 5
    outSz = sz
    let readRet = IOConnectCallStructMethod(conn, 2, &readIn, sz, &readOut, &outSz)
    guard readRet == kIOReturnSuccess, readOut.result == 0 else { return nil }

    return withUnsafeBytes(of: readOut.bytes) { Array($0.prefix(Int(dataSize))) }
}
