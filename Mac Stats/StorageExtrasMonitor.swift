//
//  StorageExtrasMonitor.swift
//  Mac Stats
//
//  Extra storage metrics for the Storage tab:
//    • NVMe SSD health via the IONVMeSMARTUserClient plug-in interface —
//      SSD wear (percentage used), lifetime data written/read, power-on hours,
//      power cycles, unsafe shutdowns, available spare, drive temperature.
//      Works for Apple internal SSDs and most third-party NVMe drives.
//      (Requires the app to be non-sandboxed, which Mac Stats is.)
//    • Time Machine status via `tmutil` — configured destinations and the
//      date of the latest backup.
//
//  SMART is refreshed every 60 s and Time Machine every 5 min, and only while
//  the Storage tab is visible (start()/stop() from onAppear/onDisappear).
//

import Foundation
import Darwin
import CoreFoundation
import IOKit
import Observation
import AppKit

// MARK: - Data types

struct NVMeDriveHealth: Identifiable {
    let id: Int
    let name: String
    let temperatureC: Double
    let percentageUsed: Int        // NVMe "Percentage Used" — wear estimate, can exceed 100
    let availableSpare: Int        // % of spare blocks remaining
    let spareThreshold: Int
    let dataReadBytes: Double
    let dataWrittenBytes: Double
    let powerOnHours: UInt64
    let powerCycles: UInt64
    let unsafeShutdowns: UInt64
    let mediaErrors: UInt64
    let criticalWarning: UInt8     // non-zero = trouble (spare low / temp / degraded / read-only)

    var lifeRemainingPercent: Int { max(0, 100 - percentageUsed) }
    var hasCriticalWarning: Bool { criticalWarning != 0 }
}

struct TimeMachineStatus {
    var isConfigured: Bool = false
    var destinationName: String = ""
    var destinationKind: String = ""   // "Local" or "Network"
    var destinationMounted: Bool = false
    var latestBackupDate: Date? = nil
    var latestBackupUnavailableReason: String? = nil
}

struct MountedVolume: Identifiable, Equatable {
    var id: String { mountPoint }
    let mountPoint: String
    let name: String
    let totalBytes: Double
    let freeBytes: Double
    let isRemovable: Bool
    let isEjectable: Bool

    var usedBytes: Double { max(totalBytes - freeBytes, 0) }
    var usedFraction: Double { totalBytes > 0 ? usedBytes / totalBytes : 0 }

    static func == (lhs: MountedVolume, rhs: MountedVolume) -> Bool {
        lhs.mountPoint == rhs.mountPoint
            && lhs.totalBytes == rhs.totalBytes
            && lhs.freeBytes == rhs.freeBytes
    }
}

// MARK: - Monitor

@Observable
final class StorageExtrasMonitor {

    var drives: [NVMeDriveHealth] = []
    var smartSampled: Bool = false
    var timeMachine: TimeMachineStatus = TimeMachineStatus()
    var timeMachineSampled: Bool = false
    var externalVolumes: [MountedVolume] = []
    var volumesSampled: Bool = false

    @ObservationIgnored private var smartTimer: Timer?
    @ObservationIgnored private var tmTimer: Timer?
    @ObservationIgnored private var volumeTimer: Timer?
    @ObservationIgnored private var viewerCount = 0
    @ObservationIgnored private var isSampling = false
    @ObservationIgnored private var mountObservers: [NSObjectProtocol] = []

    private static let smartInterval: TimeInterval = 60.0
    private static let tmInterval: TimeInterval = 300.0
    private static let volumeInterval: TimeInterval = 15.0

    // MARK: Lifecycle

    func start() {
        viewerCount += 1
        guard viewerCount == 1 else { return }
        refreshSMART()
        refreshTimeMachine()
        refreshVolumes()
        smartTimer = Timer.scheduledTimer(withTimeInterval: Self.smartInterval, repeats: true) { [weak self] _ in
            self?.refreshSMART()
        }
        tmTimer = Timer.scheduledTimer(withTimeInterval: Self.tmInterval, repeats: true) { [weak self] _ in
            self?.refreshTimeMachine()
        }
        volumeTimer = Timer.scheduledTimer(withTimeInterval: Self.volumeInterval, repeats: true) { [weak self] _ in
            self?.refreshVolumes()
        }

        let center = NSWorkspace.shared.notificationCenter
        let mountObserver = center.addObserver(forName: NSWorkspace.didMountNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.refreshVolumes()
        }
        let unmountObserver = center.addObserver(forName: NSWorkspace.didUnmountNotification,
                                                 object: nil, queue: .main) { [weak self] _ in
            self?.refreshVolumes()
        }
        mountObservers = [mountObserver, unmountObserver]
    }

    func stop() {
        viewerCount = max(0, viewerCount - 1)
        guard viewerCount == 0 else { return }
        smartTimer?.invalidate()
        smartTimer = nil
        tmTimer?.invalidate()
        tmTimer = nil
        volumeTimer?.invalidate()
        volumeTimer = nil

        let center = NSWorkspace.shared.notificationCenter
        mountObservers.forEach { center.removeObserver($0) }
        mountObservers.removeAll()
    }

    private func refreshSMART() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let drives = Self.readAllNVMeSMART()
            await MainActor.run {
                self.drives = drives
                self.smartSampled = true
            }
        }
    }

    private func refreshTimeMachine() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let status = Self.readTimeMachineStatus()
            await MainActor.run {
                self.timeMachine = status
                self.timeMachineSampled = true
            }
        }
    }

    private func refreshVolumes() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let volumes = Self.readExternalVolumes()
            await MainActor.run {
                if self.externalVolumes != volumes {
                    self.externalVolumes = volumes
                }
                self.volumesSampled = true
            }
        }
    }

    // MARK: - Mounted volumes

    /// Lists non-boot volumes worth showing: external/removable disks and
    /// cloud-sync mount points. Mirrors the exclusion rules Finder uses to
    /// hide system/simulator/Time-Machine-sparsebundle volumes.
    private static func readExternalVolumes() -> [MountedVolume] {
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey
        ], options: [.skipHiddenVolumes]) else { return [] }

        var results: [MountedVolume] = []

        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsInternalKey
            ]) else { continue }

            let path = url.path
            let name = values.volumeName ?? "Unknown"
            let isInternal = values.volumeIsInternal ?? true
            let isRemovable = values.volumeIsRemovable ?? false
            let isEjectable = values.volumeIsEjectable ?? false

            guard !path.hasPrefix("/System"),
                  !path.hasPrefix("/private"),
                  !path.hasPrefix("/usr"),
                  !path.hasPrefix("/dev"),
                  path != "/",
                  path != "/System/Volumes/Data",
                  !path.contains("CoreSimulator") else { continue }

            let lowerName = name.lowercased()
            guard !lowerName.contains("time machine"),
                  !path.contains(".timemachine"),
                  !path.contains("TimeMachine"),
                  !lowerName.contains("simulator"),
                  !lowerName.contains("watchos"),
                  !lowerName.contains("ios") else { continue }

            var shouldInclude = false
            if path.hasPrefix("/Volumes/") {
                shouldInclude = (name != "Macintosh HD" && !path.hasSuffix("/Macintosh HD"))
            } else if (isRemovable || isEjectable) && !isInternal {
                shouldInclude = true
            }
            guard shouldInclude else { continue }

            let total = values.volumeTotalCapacity ?? 0
            guard total > 100_000_000 else { continue }
            let available = values.volumeAvailableCapacity ?? 0

            results.append(MountedVolume(
                mountPoint: path,
                name: name,
                totalBytes: Double(total),
                freeBytes: Double(available),
                isRemovable: isRemovable,
                isEjectable: isEjectable
            ))
        }

        return results.sorted { $0.name < $1.name }
    }

    // MARK: - NVMe SMART

    // CFUUIDs for the NVMe SMART plug-in interface (from IOKit/storage/nvme headers).
    private static var nvmeSMARTUserClientTypeID: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
            0xAA, 0x0F, 0xA6, 0xF9, 0xC2, 0xD6, 0x45, 0x7F,
            0xB1, 0x0B, 0x59, 0xA1, 0x32, 0x53, 0x29, 0x2F)
    }
    private static var nvmeSMARTInterfaceID: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
            0xCC, 0xD1, 0xDB, 0x19, 0xFD, 0x9A, 0x4D, 0xAF,
            0xBF, 0x95, 0x12, 0x45, 0x4B, 0x23, 0x0A, 0xB6)
    }
    // kIOCFPlugInInterfaceID — C244E858-109C-11D4-91D4-0050E4C6426F — defined inline
    // because the symbol doesn't bridge through Swift's IOKit module overlay.
    private static var ioPlugInInterfaceID: CFUUID {
        CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
            0xC2, 0x44, 0xE8, 0x58, 0x10, 0x9C, 0x11, 0xD4,
            0x91, 0xD4, 0x00, 0x50, 0xE4, 0xC6, 0x42, 0x6F)
    }

    private static func readAllNVMeSMART() -> [NVMeDriveHealth] {
        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("IONVMeBlockStorageDevice"),
                                           &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var results: [NVMeDriveHealth] = []
        var index = 0

        while true {
            let device = IOIteratorNext(iterator)
            guard device != 0 else { break }
            defer { IOObjectRelease(device) }

            // Walk up from the block storage device to the controller that
            // advertises "NVMe SMART Capable".
            guard let controller = findSMARTCapableAncestor(of: device) else { continue }
            defer { IOObjectRelease(controller) }

            let name = driveName(for: device) ?? "NVMe SSD \(index + 1)"
            if let health = readSMART(from: controller, id: index, name: name) {
                results.append(health)
                index += 1
            }
        }
        return results
    }

    /// Returns a retained registry entry (caller releases) with "NVMe SMART Capable" == true,
    /// starting at `entry` and walking up the IOService plane.
    private static func findSMARTCapableAncestor(of entry: io_registry_entry_t) -> io_registry_entry_t? {
        var current: io_registry_entry_t = entry
        IOObjectRetain(current)

        for _ in 0..<8 {
            if let capable = IORegistryEntryCreateCFProperty(current, "NVMe SMART Capable" as CFString,
                                                             kCFAllocatorDefault, 0)?.takeRetainedValue(),
               let flag = capable as? Bool, flag {
                return current
            }
            var parent = io_registry_entry_t()
            let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            IOObjectRelease(current)
            guard kr == KERN_SUCCESS else { return nil }
            current = parent
        }
        IOObjectRelease(current)
        return nil
    }

    /// Pulls a friendly product name off the block storage device's characteristics.
    private static func driveName(for device: io_registry_entry_t) -> String? {
        guard let raw = IORegistryEntryCreateCFProperty(device, "Device Characteristics" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue(),
              let dict = raw as? [String: Any],
              let product = dict["Product Name"] as? String else { return nil }
        let trimmed = product.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func readSMART(from controller: io_registry_entry_t, id: Int, name: String) -> NVMeDriveHealth? {
        var pluginInterface: UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score: Int32 = 0

        guard IOCreatePlugInInterfaceForService(controller,
                                                nvmeSMARTUserClientTypeID,
                                                ioPlugInInterfaceID,
                                                &pluginInterface,
                                                &score) == KERN_SUCCESS,
              let plugin = pluginInterface else { return nil }
        defer { IODestroyPlugInInterface(plugin) }

        guard let queryInterface = plugin.pointee?.pointee.QueryInterface else { return nil }
        var smartInterfaceRaw: LPVOID? = nil
        let qiResult = queryInterface(plugin,
                                      CFUUIDGetUUIDBytes(nvmeSMARTInterfaceID),
                                      &smartInterfaceRaw)
        // S_OK is a macro that doesn't import into Swift; it's simply 0.
        guard qiResult == 0, let smartInterface = smartInterfaceRaw else { return nil }

        // smartInterface is an IONVMeSMARTInterface** (COM-style: pointer to a
        // pointer to a struct of function pointers). Rather than modeling the whole
        // C struct in Swift, load the entries we need at their fixed byte offsets:
        //   0  _reserved            32 version (UInt16)
        //   8  QueryInterface       34 revision (UInt16)
        //   16 AddRef               40 SMARTReadData
        //   24 Release              48 GetIdentifyData
        typealias ReleaseFn       = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
        typealias SMARTReadFn     = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> IOReturn
        typealias GetIdentifyFn   = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UInt32) -> IOReturn

        let vtable = smartInterface.assumingMemoryBound(to: UnsafeMutableRawPointer.self).pointee
        let releaseFn  = unsafeBitCast(vtable.load(fromByteOffset: 24, as: UnsafeRawPointer.self), to: ReleaseFn.self)
        defer { _ = releaseFn(smartInterface) }
        let smartReadFn = unsafeBitCast(vtable.load(fromByteOffset: 40, as: UnsafeRawPointer.self), to: SMARTReadFn.self)

        // NVMe SMART / Health Information log page is 512 bytes.
        var log = [UInt8](repeating: 0, count: 512)
        let readResult = log.withUnsafeMutableBytes { buf in
            smartReadFn(smartInterface, buf.baseAddress)
        }
        guard readResult == kIOReturnSuccess else { return nil }

        func le16(_ offset: Int) -> UInt16 {
            UInt16(log[offset]) | (UInt16(log[offset + 1]) << 8)
        }
        // 128-bit little-endian fields; the low 8 bytes are more than enough range.
        func le64(_ offset: Int) -> UInt64 {
            var value: UInt64 = 0
            for i in (0..<8).reversed() {
                value = (value << 8) | UInt64(log[offset + i])
            }
            return value
        }

        let kelvin = Double(le16(1))
        let dataUnitsRead = le64(32)
        let dataUnitsWritten = le64(48)

        // Prefer the model name from the NVMe identify data when available.
        var resolvedName = name
        let identifyFnRaw = vtable.load(fromByteOffset: 48, as: UnsafeRawPointer.self)
        let identifyFn = unsafeBitCast(identifyFnRaw, to: GetIdentifyFn.self)
        var identify = [UInt8](repeating: 0, count: 4096)
        let identifyResult = identify.withUnsafeMutableBytes { buf in
            identifyFn(smartInterface, buf.baseAddress, 0)
        }
        if identifyResult == kIOReturnSuccess {
            // Identify Controller: model number is ASCII at bytes 24..63.
            let modelBytes = identify[24..<64].filter { $0 != 0 }
            if let model = String(bytes: modelBytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !model.isEmpty {
                resolvedName = model
            }
        }

        return NVMeDriveHealth(
            id: id,
            name: resolvedName,
            temperatureC: kelvin > 0 ? kelvin - 273.15 : 0,
            percentageUsed: Int(log[5]),
            availableSpare: Int(log[3]),
            spareThreshold: Int(log[4]),
            dataReadBytes: Double(dataUnitsRead) * 512_000.0,      // units of 1000 × 512 B
            dataWrittenBytes: Double(dataUnitsWritten) * 512_000.0,
            powerOnHours: le64(128),
            powerCycles: le64(112),
            unsafeShutdowns: le64(144),
            mediaErrors: le64(160),
            criticalWarning: log[0]
        )
    }

    // MARK: - Time Machine

    private static func readTimeMachineStatus() -> TimeMachineStatus {
        var status = TimeMachineStatus()

        guard let destInfo = runCommand("/usr/bin/tmutil", ["destinationinfo"]) else { return status }
        if destInfo.contains("No destinations configured") {
            return status
        }

        // Parse the first destination block ("Name : …", "Kind : …", "Mount Point : …").
        for line in destInfo.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "Name" where status.destinationName.isEmpty:
                status.destinationName = value
                status.isConfigured = true
            case "Kind" where status.destinationKind.isEmpty:
                status.destinationKind = value
            case "Mount Point":
                status.destinationMounted = true
            default:
                break
            }
        }
        guard status.isConfigured else { return status }

        // Latest backup — needs Full Disk Access on modern macOS; degrade gracefully.
        if let latest = runCommand("/usr/bin/tmutil", ["latestbackup"]),
           let date = extractBackupDate(from: latest) {
            status.latestBackupDate = date
        } else {
            status.latestBackupUnavailableReason =
                "Grant Mac Stats Full Disk Access to see backup history"
        }
        return status
    }

    /// Finds a "yyyy-MM-dd-HHmmss" stamp anywhere in tmutil output and converts it to a Date.
    private static func extractBackupDate(from output: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{4}-\d{2}-\d{2})-(\d{6})"#) else { return nil }
        let range = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: range)
        guard let last = matches.last,
              let matchRange = Range(last.range, in: output) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: String(output[matchRange]))
    }

    private static func runCommand(_ path: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
