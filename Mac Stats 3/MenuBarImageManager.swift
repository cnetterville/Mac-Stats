//
//  MenuBarImageManager.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import SwiftUI
import Combine

class MenuBarImageManager: ObservableObject {
    @Published var menuBarImage: NSImage?
    
    private var systemMonitor: SystemMonitor?
    private var preferences: PreferencesManager?
    private var cancellables = Set<AnyCancellable>()
    
    // Track if we've received actual data (not just initial zero values)
    private var hasReceivedRealData = false
    
    // Default initializer for deferred setup
    init() {}
    
    // Method to set up dependencies after initialization
    func updateDependencies(systemMonitor: SystemMonitor, preferences: PreferencesManager) {
        self.systemMonitor = systemMonitor
        self.preferences = preferences
        
        // Subscribe to all relevant publishers
        systemMonitor.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce to reduce updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarImage()
            }
            .store(in: &cancellables)
        
        preferences.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce to reduce updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarImage()
            }
            .store(in: &cancellables)
            
        ExternalIPManager.shared.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main) // Debounce to reduce updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarImage()
            }
            .store(in: &cancellables)
    }
    
    // Explicitly trigger an image update
    func forceImageUpdate() {
        updateMenuBarImage()
    }
    
    private func updateMenuBarImage() {
        guard let systemMonitor = self.systemMonitor,
              let preferences = self.preferences else { return }
              
        // Check if we have real data (not just initial zero values)
        let hasRealCPUData = systemMonitor.cpuUsage > 0
        let hasRealMemoryData = systemMonitor.memoryUsage.used > 0
        let hasRealDiskData = systemMonitor.diskUsage.free > 0  // Changed from .used to .free
        let hasRealNetworkData = systemMonitor.networkUsage.upload > 0 || systemMonitor.networkUsage.download > 0
        
        let shouldShowAnyStats = (preferences.showCPU && preferences.showMenuBarCPU) ||
                                (preferences.showMemory && preferences.showMenuBarMemory) ||
                                (preferences.showDisk && preferences.showMenuBarDisk) ||
                                (preferences.showNetwork && preferences.showMenuBarNetwork)
        
        // If we should show stats but haven't received real data yet, wait a bit more
        if shouldShowAnyStats && !hasReceivedRealData {
            // Check if we now have real data
            if hasRealCPUData || hasRealMemoryData || hasRealDiskData || hasRealNetworkData {
                hasReceivedRealData = true
            } else {
                // Still waiting for real data, but let's update anyway after a delay
                // to avoid infinite waiting
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.hasReceivedRealData = true
                    self.updateMenuBarImage()
                }
                return
            }
        }
              
        let view = MenuBarIconView()
            .environmentObject(systemMonitor)
            .environmentObject(preferences)
            .environmentObject(ExternalIPManager.shared)
            .padding(.horizontal, 4)
            .background(Color.clear)
        
        Task { @MainActor in
            self.menuBarImage = view.snapshot()
        }
    }
}