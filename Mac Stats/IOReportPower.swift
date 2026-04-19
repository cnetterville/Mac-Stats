//
//  IOReportPower.swift
//  Mac Stats
//
//  Reads Apple Silicon CPU/GPU/ANE power directly from libIOReport.dylib
//  using dlopen/dlsym — no subprocess, no special entitlements needed.
//
//  Channel matching mirrors macmon (github.com/vladkens/macmon):
//    CPU: channels ending in "CPU Energy"   (mJ units)
//    GPU: exact channel "GPU Energy"         (nJ units)
//    ANE: channels starting with "ANE"       (mJ units)
//

import Darwin
import CoreFoundation
import Foundation

struct IOReportPower {
    let cpu: Double    // watts
    let gpu: Double    // watts
    let ane: Double    // watts
    let total: Double  // watts (cpu + gpu + ane)
}

/// Sample Apple Silicon power via IOReport.
/// Blocks the calling thread for approximately `intervalMs` milliseconds.
/// Returns nil if libIOReport.dylib is unavailable or returns no data.
func sampleIOReportPower(intervalMs: Int = 300) -> IOReportPower? {
    guard let lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW | RTLD_LOCAL) else { return nil }

    typealias RP = UnsafeMutableRawPointer

    typealias FnCopy  = @convention(c) (CFString?, CFString?, UInt64, UInt64, UInt64) -> RP?
    typealias FnSub   = @convention(c) (RP?, RP, UnsafeMutablePointer<RP?>?, UInt64, RP?) -> RP?
    typealias FnSmp   = @convention(c) (RP?, RP, RP?) -> RP?
    typealias FnDelta = @convention(c) (RP, RP, RP?) -> RP?
    typealias FnVal   = @convention(c) (RP, UnsafeMutablePointer<Int32>?) -> Int64
    typealias FnName  = @convention(c) (RP) -> RP?
    typealias FnUnit  = @convention(c) (RP) -> RP?

    func sym<T>(_ name: String) -> T? {
        dlsym(lib, name).map { unsafeBitCast($0, to: T.self) }
    }

    guard let fCopy:  FnCopy  = sym("IOReportCopyChannelsInGroup"),
          let fSub:   FnSub   = sym("IOReportCreateSubscription"),
          let fSmp:   FnSmp   = sym("IOReportCreateSamples"),
          let fDelta: FnDelta = sym("IOReportCreateSamplesDelta"),
          let fVal:   FnVal   = sym("IOReportSimpleGetIntegerValue"),
          let fName:  FnName  = sym("IOReportChannelGetChannelName"),
          let fUnit:  FnUnit  = sym("IOReportChannelGetUnitLabel")
    else { return nil }

    // ── Get Energy Model channels ─────────────────────────────────────────────
    guard let chRaw = fCopy("Energy Model" as CFString, nil, 0, 0, 0) else { return nil }
    let channels = Unmanaged<CFMutableDictionary>.fromOpaque(chRaw).takeRetainedValue()
    let chRP = unsafeBitCast(channels, to: RP.self)

    // ── Create IOReport subscription ──────────────────────────────────────────
    var subbedRaw: RP? = nil
    guard let sub = fSub(nil, chRP, &subbedRaw, 0, nil), let sRaw = subbedRaw else { return nil }
    let subbed = Unmanaged<CFMutableDictionary>.fromOpaque(sRaw).takeRetainedValue()
    let subbedRP = unsafeBitCast(subbed, to: RP.self)

    // ── Two samples bracketing the measurement interval ───────────────────────
    guard let s1Raw = fSmp(sub, subbedRP, nil) else { return nil }
    let s1 = Unmanaged<CFDictionary>.fromOpaque(s1Raw).takeRetainedValue()

    Thread.sleep(forTimeInterval: Double(intervalMs) / 1000.0)

    guard let s2Raw = fSmp(sub, subbedRP, nil) else { return nil }
    let s2 = Unmanaged<CFDictionary>.fromOpaque(s2Raw).takeRetainedValue()

    // ── Energy delta ──────────────────────────────────────────────────────────
    guard let deltaRaw = fDelta(
        unsafeBitCast(s1, to: RP.self),
        unsafeBitCast(s2, to: RP.self),
        nil
    ) else { return nil }
    let delta = Unmanaged<CFDictionary>.fromOpaque(deltaRaw).takeRetainedValue()

    // ── Iterate channels ──────────────────────────────────────────────────────
    let keyRP = unsafeBitCast("IOReportChannels" as CFString, to: UnsafeRawPointer.self)
    guard let arrPtr = CFDictionaryGetValue(delta, keyRP) else { return nil }
    let chArray = Unmanaged<CFArray>.fromOpaque(arrPtr).takeUnretainedValue()

    var cpuW = 0.0, gpuW = 0.0, aneW = 0.0

    for i in 0..<CFArrayGetCount(chArray) {
        guard let elemPtr = CFArrayGetValueAtIndex(chArray, i) else { continue }
        let elemRP = RP(mutating: elemPtr)

        var idx: Int32 = 0
        let rawVal = fVal(elemRP, &idx)
        guard rawVal > 0 else { continue }

        guard let namePtr = fName(elemRP) else { continue }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String

        // Channel selection matching macmon's approach:
        //   CPU: "DIE_0_CPU Energy", "DIE_1_CPU Energy", … (ends with "CPU Energy")
        //   GPU: "GPU Energy" (exact — the aggregate GPU energy counter)
        //   ANE: "ANE0_0", "ANE0_1", … (starts with "ANE")
        let isCPU = name.hasSuffix("CPU Energy")
        let isGPU = name == "GPU Energy"
        let isANE = name.hasPrefix("ANE")
        guard isCPU || isGPU || isANE else { continue }

        // Get the channel's unit label so we convert correctly.
        // CPU/ANE channels are in mJ; "GPU Energy" is in nJ.
        let unitStr: String
        if let unitPtr = fUnit(elemRP) {
            unitStr = Unmanaged<CFString>.fromOpaque(unitPtr).takeUnretainedValue() as String
        } else {
            unitStr = "mJ"
        }

        // Convert energy delta to average power over the interval.
        //   mJ/ms = W  (1 millijoule per millisecond = 1 watt)
        //   nJ/ms = μW  → divide by 1,000,000 to get W
        let watts: Double
        switch unitStr {
        case "mJ":
            watts = Double(rawVal) / Double(intervalMs)
        case "nJ":
            watts = Double(rawVal) / Double(intervalMs) / 1_000_000.0
        default:
            watts = Double(rawVal) / Double(intervalMs)
        }

        if isCPU      { cpuW += watts }
        else if isGPU { gpuW += watts }
        else          { aneW += watts }
    }

    let total = cpuW + gpuW + aneW
    guard total > 0 else { return nil }
    return IOReportPower(cpu: cpuW, gpu: gpuW, ane: aneW, total: total)
}
