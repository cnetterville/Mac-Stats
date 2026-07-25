//
//  SystemDetailsMonitor.swift
//  Mac Stats
//
//  Extra identity/hardware details for the System tab and dropdown Overview:
//    • Hostname, serial number (IOPlatformExpertDevice), and OS build number
//      (kern.osversion) — static values, read once per app launch.
//    • Connected displays with pixel resolution and refresh rate, via
//      NSScreen + CoreGraphics. Refreshes on display connect/disconnect.
//

import Foundation
import AppKit
import CoreGraphics
import IOKit
import Observation

struct DisplayInfo: Identifiable {
    let id: Int
    let name: String
    let widthPx: Int
    let heightPx: Int
    let refreshRateHz: Double
    let isBuiltIn: Bool
    let isMain: Bool
}

@Observable
final class SystemDetailsMonitor {

    var hostname: String = ""
    var serialNumber: String = ""
    var buildNumber: String = ""
    var displays: [DisplayInfo] = []
    var hasSampled = false

    @ObservationIgnored private var viewerCount = 0
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var staticInfoLoaded = false

    // MARK: Lifecycle

    func start() {
        viewerCount += 1
        guard viewerCount == 1 else { return }

        if !staticInfoLoaded {
            loadStaticInfo()
        }
        refreshDisplays()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshDisplays()
        }
    }

    func stop() {
        viewerCount = max(0, viewerCount - 1)
        guard viewerCount == 0 else { return }
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    // MARK: - Static identity info (hostname / serial / build)

    private func loadStaticInfo() {
        staticInfoLoaded = true
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let hostname = Self.readHostname()
            let serial = Self.readSerialNumber()
            let build = Self.readBuildNumber()
            await MainActor.run {
                self.hostname = hostname
                self.serialNumber = serial
                self.buildNumber = build
                self.hasSampled = true
            }
        }
    }

    private static func readHostname() -> String {
        var name = ProcessInfo.processInfo.hostName
        if name.hasSuffix(".local") {
            name = String(name.dropLast(6))
        }
        return name.isEmpty ? "Unknown" : name
    }

    private static func readSerialNumber() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault,
                                                         IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return "Unknown" }
        defer { IOObjectRelease(platformExpert) }

        guard let raw = IORegistryEntryCreateCFProperty(platformExpert,
                                                         "IOPlatformSerialNumber" as CFString,
                                                         kCFAllocatorDefault, 0)?.takeRetainedValue(),
              let serial = raw as? String, !serial.isEmpty else { return "Unknown" }
        return serial
    }

    private static func readBuildNumber() -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    // MARK: - Displays (NSScreen / CoreGraphics — main-thread only)

    /// Must run on the main thread/actor since it reads NSScreen.screens.
    private func refreshDisplays() {
        var results: [DisplayInfo] = []

        for (index, screen) in NSScreen.screens.enumerated() {
            let scale = screen.backingScaleFactor
            let widthPx = Int((screen.frame.width * scale).rounded())
            let heightPx = Int((screen.frame.height * scale).rounded())

            var isBuiltIn = false
            if let numberValue = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                let displayID = CGDirectDisplayID(numberValue.uint32Value)
                isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
            }

            results.append(DisplayInfo(
                id: index,
                name: screen.localizedName,
                widthPx: widthPx,
                heightPx: heightPx,
                refreshRateHz: Double(screen.maximumFramesPerSecond),
                isBuiltIn: isBuiltIn,
                isMain: screen == NSScreen.main
            ))
        }

        displays = results
        hasSampled = true
    }
}
