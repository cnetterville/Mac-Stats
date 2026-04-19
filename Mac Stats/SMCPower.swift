//
//  SMCPower.swift
//  Mac Stats
//
//  Reads total system power from the SMC (System Management Controller)
//  via IOKit. Uses the "PSTR" key, the same key macmon uses for sys_power.
//
//  Returns the wall-power draw of the entire Mac including CPU/GPU/ANE,
//  DRAM, display engine, storage, fans, and other components — unlike
//  IOReport "Energy Model" which only covers the SoC.
//

import Foundation
import IOKit

/// Read total system power (in watts) from the SMC "PSTR" key.
/// Returns nil if the SMC is unavailable or the key is not present on this model.
func readSMCSystemPower() -> Double? {
    let service = IOServiceGetMatchingService(0, IOServiceMatching("AppleSMC"))
    guard service != IO_OBJECT_NULL else { return nil }
    defer { IOObjectRelease(service) }

    var conn: io_connect_t = IO_OBJECT_NULL
    guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return nil }
    defer { IOServiceClose(conn) }

    guard let bytes = smcReadKey(conn, key: "PSTR", size: 4) else { return nil }

    // "PSTR" is an IEEE 754 float32 in little-endian byte order.
    var float32: Float32 = 0
    withUnsafeMutableBytes(of: &float32) { $0.copyBytes(from: bytes) }
    let watts = Double(float32)
    return watts > 0 ? watts : nil
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

private func smcReadKey(_ conn: io_connect_t, key: String, size: UInt32) -> [UInt8]? {
    // Encode the 4-char key as a big-endian UInt32 (e.g. "PSTR" → 0x50535452)
    let keyCode = key.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }

    var input = SMCParamStruct()
    var output = SMCParamStruct()
    input.key = keyCode
    input.keyInfo.dataSize = size
    input.data8 = 5  // kSMCReadKey

    let structSize = MemoryLayout<SMCParamStruct>.size
    var outSize = structSize

    let ret = IOConnectCallStructMethod(conn, 2, &input, structSize, &output, &outSize)
    guard ret == kIOReturnSuccess, output.result == 0 else { return nil }

    return withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(size))) }
}
