//
//  BluetoothBatteryMonitor.swift
//  Mac Stats
//
//  Reads battery levels of connected Bluetooth peripherals (Magic Keyboard,
//  Magic Mouse, Magic Trackpad, some headsets) from the IORegistry.
//  Apple's Bluetooth HID services publish a "BatteryPercent" property that
//  updates as the device reports its charge.
//
//  Note: AirPods generally do NOT expose battery over this interface — their
//  levels travel over a proprietary BLE protocol with no public API. Devices
//  that don't report a battery simply won't appear in the list.
//
//  Refreshes every 30 s, and only while a view showing the list is visible
//  (start()/stop() from onAppear/onDisappear).
//

import Foundation
import CoreFoundation
import IOKit
import Observation

struct BluetoothPeripheral: Identifiable {
    let id: String          // device address / serial when available, else name
    let name: String
    let batteryPercent: Int

    /// SF Symbol guess based on the product name.
    var iconName: String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("keyboard") { return "keyboard.fill" }
        if lower.contains("mouse") { return "magicmouse.fill" }
        if lower.contains("trackpad") { return "rectangle.inset.filled" }
        if lower.contains("pencil") { return "pencil" }
        if lower.contains("headphone") || lower.contains("headset") { return "headphones" }
        if lower.contains("controller") || lower.contains("gamepad") { return "gamecontroller.fill" }
        return "dot.radiowaves.left.and.right"
    }
}

@Observable
final class BluetoothBatteryMonitor {

    var peripherals: [BluetoothPeripheral] = []
    var hasSampled = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var viewerCount = 0

    private static let refreshInterval: TimeInterval = 30.0

    // IOService classes that publish "BatteryPercent" for Bluetooth peripherals.
    // The first covers all modern Apple peripherals; the rest are older devices.
    private static let serviceClasses = [
        "AppleDeviceManagementHIDEventService",
        "BNBMouseDevice",
        "BNBTrackpadDevice",
        "AppleBluetoothHIDKeyboard",
        "AppleHSBluetoothDevice",
    ]

    // MARK: Lifecycle

    func start() {
        viewerCount += 1
        guard viewerCount == 1 else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        viewerCount = max(0, viewerCount - 1)
        guard viewerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let found = Self.readPeripherals()
            await MainActor.run {
                self.peripherals = found
                self.hasSampled = true
            }
        }
    }

    // MARK: Reading

    private static func readPeripherals() -> [BluetoothPeripheral] {
        var results: [BluetoothPeripheral] = []
        var seen = Set<String>()

        for className in serviceClasses {
            var iterator = io_iterator_t()
            guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                               IOServiceMatching(className),
                                               &iterator) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(iterator) }

            while true {
                let entry = IOIteratorNext(iterator)
                guard entry != 0 else { break }
                defer { IOObjectRelease(entry) }

                guard let percent = intProperty(entry, "BatteryPercent"),
                      percent >= 0 && percent <= 100 else { continue }

                let name = stringProperty(entry, "Product")
                    ?? stringProperty(entry, "ProductName")
                    ?? "Bluetooth Device"

                let key = stringProperty(entry, "DeviceAddress")
                    ?? stringProperty(entry, "SerialNumber")
                    ?? name

                guard !seen.contains(key) else { continue }
                seen.insert(key)

                results.append(BluetoothPeripheral(id: key, name: name, batteryPercent: percent))
            }
        }

        return results.sorted { $0.name < $1.name }
    }

    private static func intProperty(_ entry: io_registry_entry_t, _ key: String) -> Int? {
        guard let raw = IORegistryEntryCreateCFProperty(entry, key as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return (raw as? NSNumber)?.intValue
    }

    private static func stringProperty(_ entry: io_registry_entry_t, _ key: String) -> String? {
        guard let raw = IORegistryEntryCreateCFProperty(entry, key as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue(),
              let str = raw as? String else {
            return nil
        }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
