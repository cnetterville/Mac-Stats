//
//  PerformanceExtrasMonitor.swift
//  Mac Stats
//
//  Extra performance metrics for the Performance tab:
//    • GPU utilization %  — read from IOAccelerator "PerformanceStatistics"
//      (works on Apple Silicon and discrete/Intel GPUs)
//    • CPU cluster frequency (E-cores / P-cores) — IOReport "CPU Stats" state
//      residencies weighted by the pmgr voltage-state frequency tables
//      (Apple Silicon only; hidden on Intel)
//    • Top processes by energy impact — proc_pid_rusage ri_billed_energy deltas
//      (Apple Silicon; falls back to a CPU-based estimate elsewhere)
//
//  The monitor only samples while the Performance tab is visible: views call
//  start() in onAppear and stop() in onDisappear.
//

import Foundation
import Darwin
import CoreFoundation
import IOKit
import Observation

// MARK: - Data types

struct CPUClusterFrequency {
    let eCoreMHz: Double      // current average E-cluster frequency (active states)
    let pCoreMHz: Double      // current average P-cluster frequency (active states)
    let eCoreMaxMHz: Double   // top of the E-cluster frequency table
    let pCoreMaxMHz: Double   // top of the P-cluster frequency table
}

struct EnergyProcessInfo: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    /// Average power billed to the process over the sample interval, in milliwatts.
    /// When `isEstimate` is true this is a CPU-derived relative score instead.
    let milliwatts: Double
    let isEstimate: Bool
}

// MARK: - Monitor

@Observable
final class PerformanceExtrasMonitor {

    // Published state
    var gpuUtilization: Double? = nil          // 0–100, nil until first sample / unsupported
    var gpuHistory: [Double] = []
    var clusterFrequency: CPUClusterFrequency? = nil
    var frequencySupported: Bool = true        // false on Intel — card hides itself
    var topEnergyProcesses: [EnergyProcessInfo] = []
    var energySupported: Bool = true           // false when ri_billed_energy is always 0
    var hasSampled: Bool = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var isSampling = false
    @ObservationIgnored private var tickCount = 0
    @ObservationIgnored private var viewerCount = 0
    @ObservationIgnored private var previousEnergy: [pid_t: (energy: UInt64, cpuTime: UInt64, time: Date)] = [:]
    @ObservationIgnored private var zeroEnergySamples = 0

    private static let maxHistoryPoints = 30
    private static let sampleInterval: TimeInterval = 3.0
    /// Frequency sampling blocks its background thread ~500 ms, so only do it every other tick.
    private static let frequencyTickStride = 2

    // MARK: Lifecycle

    func start() {
        viewerCount += 1
        guard viewerCount == 1 else { return }
        sample()   // immediate first sample so the card isn't empty for 3 s
        timer = Timer.scheduledTimer(withTimeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        viewerCount = max(0, viewerCount - 1)
        guard viewerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    // MARK: Sampling

    private func sample() {
        guard !isSampling else { return }
        isSampling = true
        let tick = tickCount
        tickCount += 1

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let gpu = Self.readGPUUtilization()
            let energy = self.sampleEnergyProcesses(count: 5)

            let freq: CPUClusterFrequency?
            let freqAvailable: Bool
            if tick % Self.frequencyTickStride == 0 {
                let f = Self.sampleClusterFrequency(intervalMs: 500)
                freq = f
                freqAvailable = (f != nil)
            } else {
                freq = nil
                freqAvailable = true
            }

            await MainActor.run {
                if let gpu {
                    self.gpuUtilization = gpu
                    self.gpuHistory.append(gpu)
                    if self.gpuHistory.count > Self.maxHistoryPoints {
                        self.gpuHistory.removeFirst(self.gpuHistory.count - Self.maxHistoryPoints)
                    }
                }
                if tick % Self.frequencyTickStride == 0 {
                    if let freq {
                        self.clusterFrequency = freq
                    } else if !freqAvailable && self.clusterFrequency == nil {
                        // Never produced data — most likely an Intel Mac. Hide the card.
                        self.frequencySupported = false
                    }
                }
                self.topEnergyProcesses = energy.processes
                self.energySupported = energy.supported
                self.hasSampled = true
                self.isSampling = false
            }
        }
    }

    // MARK: - GPU utilization (IOAccelerator)

    private static func readGPUUtilization() -> Double? {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IOAccelerator"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var best: Double? = nil
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }

            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = propsRef?.takeRetainedValue() as? [String: Any],
                  let stats = props["PerformanceStatistics"] as? [String: Any] else { continue }

            for key in ["Device Utilization %", "GPU Activity(%)", "Device Utilization"] {
                if let v = stats[key] as? Int {
                    best = max(best ?? 0, Double(v))
                } else if let v = stats[key] as? Double {
                    best = max(best ?? 0, v)
                }
            }
        }
        return best.map { min(max($0, 0), 100) }
    }

    // MARK: - CPU cluster frequency (IOReport + pmgr voltage states)

    /// Reads the per-cluster frequency tables published by the power manager.
    /// "voltage-states1-sram" = E-cluster, "voltage-states5-sram" = P-cluster.
    private static func pmgrFrequencyTable(key: String) -> [Double] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("AppleARMIODevice"),
                                           &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }

            var nameBuf = [CChar](repeating: 0, count: 128)
            guard IORegistryEntryGetName(entry, &nameBuf) == KERN_SUCCESS,
                  String(cString: nameBuf) == "pmgr" else { continue }

            guard let raw = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue(),
                  let data = raw as? Data else { return [] }

            var freqs: [Double] = []
            var offset = 0
            while offset + 8 <= data.count {
                // Little-endian u32 frequency, assembled byte-by-byte to avoid
                // any alignment assumptions.
                let value = UInt32(data[offset])
                    | (UInt32(data[offset + 1]) << 8)
                    | (UInt32(data[offset + 2]) << 16)
                    | (UInt32(data[offset + 3]) << 24)
                if value > 0 {
                    freqs.append(normalizedMHz(UInt64(value)))
                }
                offset += 8
            }
            return freqs
        }
        return []
    }

    /// Frequency tables are Hz on most chips but have used other units;
    /// normalize whatever we find to MHz.
    private static func normalizedMHz(_ raw: UInt64) -> Double {
        let v = Double(raw)
        if v >= 100_000_000 { return v / 1_000_000 }   // Hz
        if v >= 100_000 { return v / 1_000 }           // kHz
        return v                                        // already MHz
    }

    /// Samples IOReport "CPU Stats / CPU Complex Performance States" over `intervalMs`
    /// and converts state residencies into an average active frequency per cluster.
    /// Blocks the calling thread; run on a background queue. Returns nil on Intel.
    private static func sampleClusterFrequency(intervalMs: Int) -> CPUClusterFrequency? {
        let eFreqs = pmgrFrequencyTable(key: "voltage-states1-sram")
        let pFreqs = pmgrFrequencyTable(key: "voltage-states5-sram")
        guard !eFreqs.isEmpty, !pFreqs.isEmpty else { return nil }

        guard let lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW | RTLD_LOCAL) else { return nil }

        typealias RP = UnsafeMutableRawPointer
        typealias FnCopy   = @convention(c) (CFString?, CFString?, UInt64, UInt64, UInt64) -> RP?
        typealias FnSub    = @convention(c) (RP?, RP, UnsafeMutablePointer<RP?>?, UInt64, RP?) -> RP?
        typealias FnSmp    = @convention(c) (RP?, RP, RP?) -> RP?
        typealias FnDelta  = @convention(c) (RP, RP, RP?) -> RP?
        typealias FnName   = @convention(c) (RP) -> RP?
        typealias FnCount  = @convention(c) (RP) -> Int32
        typealias FnResid  = @convention(c) (RP, Int32) -> Int64

        func sym<T>(_ name: String) -> T? {
            dlsym(lib, name).map { unsafeBitCast($0, to: T.self) }
        }

        guard let fCopy:  FnCopy  = sym("IOReportCopyChannelsInGroup"),
              let fSub:   FnSub   = sym("IOReportCreateSubscription"),
              let fSmp:   FnSmp   = sym("IOReportCreateSamples"),
              let fDelta: FnDelta = sym("IOReportCreateSamplesDelta"),
              let fName:  FnName  = sym("IOReportChannelGetChannelName"),
              let fCount: FnCount = sym("IOReportStateGetCount"),
              let fResid: FnResid = sym("IOReportStateGetResidency")
        else { return nil }

        guard let chRaw = fCopy("CPU Stats" as CFString,
                                "CPU Complex Performance States" as CFString, 0, 0, 0) else { return nil }
        let channels = Unmanaged<CFMutableDictionary>.fromOpaque(chRaw).takeRetainedValue()
        let chRP = unsafeBitCast(channels, to: RP.self)

        var subbedRaw: RP? = nil
        guard let sub = fSub(nil, chRP, &subbedRaw, 0, nil), let sRaw = subbedRaw else { return nil }
        let subbed = Unmanaged<CFMutableDictionary>.fromOpaque(sRaw).takeRetainedValue()
        let subbedRP = unsafeBitCast(subbed, to: RP.self)

        guard let s1Raw = fSmp(sub, subbedRP, nil) else { return nil }
        let s1 = Unmanaged<CFDictionary>.fromOpaque(s1Raw).takeRetainedValue()

        Thread.sleep(forTimeInterval: Double(intervalMs) / 1000.0)

        guard let s2Raw = fSmp(sub, subbedRP, nil) else { return nil }
        let s2 = Unmanaged<CFDictionary>.fromOpaque(s2Raw).takeRetainedValue()

        guard let deltaRaw = fDelta(unsafeBitCast(s1, to: RP.self),
                                    unsafeBitCast(s2, to: RP.self), nil) else { return nil }
        let delta = Unmanaged<CFDictionary>.fromOpaque(deltaRaw).takeRetainedValue()

        let keyRP = unsafeBitCast("IOReportChannels" as CFString, to: UnsafeRawPointer.self)
        guard let arrPtr = CFDictionaryGetValue(delta, keyRP) else { return nil }
        let chArray = Unmanaged<CFArray>.fromOpaque(arrPtr).takeUnretainedValue()

        // Accumulate residency-weighted frequency per cluster type (summed across dies).
        var eWeighted = 0.0, eResidency = 0.0
        var pWeighted = 0.0, pResidency = 0.0

        for i in 0..<CFArrayGetCount(chArray) {
            guard let elemPtr = CFArrayGetValueAtIndex(chArray, i) else { continue }
            let elemRP = RP(mutating: elemPtr)

            guard let namePtr = fName(elemRP) else { continue }
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String

            let isECluster = name.contains("ECPU")
            let isPCluster = name.contains("PCPU")
            guard isECluster || isPCluster else { continue }

            let freqs = isECluster ? eFreqs : pFreqs
            let stateCount = Int(fCount(elemRP))
            guard stateCount > 0 else { continue }

            // Perf states occupy the tail of the state list (idle/off states first),
            // aligned with the end of the frequency table.
            let offset = stateCount - freqs.count

            for s in 0..<stateCount {
                let residency = Double(fResid(elemRP, Int32(s)))
                guard residency > 0 else { continue }
                let freqIndex = s - offset
                guard freqIndex >= 0 && freqIndex < freqs.count else { continue }
                if isECluster {
                    eWeighted += freqs[freqIndex] * residency
                    eResidency += residency
                } else {
                    pWeighted += freqs[freqIndex] * residency
                    pResidency += residency
                }
            }
        }

        guard eResidency > 0 || pResidency > 0 else { return nil }
        return CPUClusterFrequency(
            eCoreMHz: eResidency > 0 ? eWeighted / eResidency : 0,
            pCoreMHz: pResidency > 0 ? pWeighted / pResidency : 0,
            eCoreMaxMHz: eFreqs.max() ?? 0,
            pCoreMaxMHz: pFreqs.max() ?? 0
        )
    }

    // MARK: - Per-process energy impact

    private static let machTimeToSeconds: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000.0
    }()

    private func sampleEnergyProcesses(count: Int) -> (processes: [EnergyProcessInfo], supported: Bool) {
        let now = Date()

        let byteCount = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard byteCount > 0 else { return ([], energySupported) }
        var pidBuf = [pid_t](repeating: 0, count: Int(byteCount) / MemoryLayout<pid_t>.size + 1)
        let actualBytes = pidBuf.withUnsafeMutableBytes { ptr -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, ptr.baseAddress, Int32(ptr.count))
        }
        guard actualBytes > 0 else { return ([], energySupported) }
        let pids = pidBuf.prefix(Int(actualBytes) / MemoryLayout<pid_t>.size).filter { $0 > 0 }

        var newEnergy: [pid_t: (energy: UInt64, cpuTime: UInt64, time: Date)] = [:]
        newEnergy.reserveCapacity(pids.count)

        struct Sample { let pid: pid_t; let energyRate: Double; let cpuRate: Double }
        var samples: [Sample] = []
        var sawEnergy = false

        for pid in pids {
            var usage = rusage_info_current()
            let kr = withUnsafeMutablePointer(to: &usage) { ptr in
                ptr.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
                }
            }
            guard kr == 0 else { continue }

            let energy = usage.ri_billed_energy                     // nanojoules, 0 on Intel
            let cpuTime = usage.ri_user_time &+ usage.ri_system_time // mach ticks
            newEnergy[pid] = (energy: energy, cpuTime: cpuTime, time: now)
            if energy > 0 { sawEnergy = true }

            guard let prev = previousEnergy[pid] else { continue }
            let elapsed = now.timeIntervalSince(prev.time)
            guard elapsed > 0.1 else { continue }

            let energyDelta = energy >= prev.energy ? energy - prev.energy : 0
            let cpuDelta = cpuTime >= prev.cpuTime ? cpuTime - prev.cpuTime : 0
            samples.append(Sample(
                pid: pid,
                energyRate: Double(energyDelta) / elapsed,   // nJ/s == nW
                cpuRate: Double(cpuDelta) / elapsed
            ))
        }
        previousEnergy = newEnergy

        // Decide whether real energy accounting exists on this machine.
        var supported = energySupported
        if sawEnergy {
            supported = true
            zeroEnergySamples = 0
        } else {
            zeroEnergySamples += 1
            if zeroEnergySamples >= 3 { supported = false }
        }

        let ranked: [Sample]
        if supported {
            ranked = samples.filter { $0.energyRate > 0 }.sorted { $0.energyRate > $1.energyRate }
        } else {
            ranked = samples.filter { $0.cpuRate > 0 }.sorted { $0.cpuRate > $1.cpuRate }
        }

        var result: [EnergyProcessInfo] = []
        for sample in ranked.prefix(count) {
            var nameBuf = [CChar](repeating: 0, count: 1024)
            proc_name(sample.pid, &nameBuf, UInt32(nameBuf.count))
            let name = String(cString: nameBuf)
            guard !name.isEmpty else { continue }
            // In estimate mode the value is the process's CPU usage in percent instead of mW.
            let value = supported
                ? sample.energyRate / 1_000_000.0
                : sample.cpuRate * Self.machTimeToSeconds * 100.0
            result.append(EnergyProcessInfo(
                pid: sample.pid,
                name: name,
                milliwatts: value,
                isEstimate: !supported
            ))
        }
        return (result, supported)
    }
}
