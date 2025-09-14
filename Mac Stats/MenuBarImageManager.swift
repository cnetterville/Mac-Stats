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
    
    // Add a flag to prevent recursive updates
    private var isUpdating = false
    
    // Add a timer to batch updates
    private var updateTimer: Timer?
    
    // Cache the last image to avoid unnecessary updates
    private var cachedImageData: Data?
    
    // Default initializer for deferred setup
    init() {}
    
    // Method to set up dependencies after initialization
    func updateDependencies(systemMonitor: SystemMonitor, preferences: PreferencesManager) {
        self.systemMonitor = systemMonitor
        self.preferences = preferences
        
        // Subscribe to all relevant publishers with async updates
        systemMonitor.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleDelayedUpdate()
            }
            .store(in: &cancellables)
        
        preferences.objectWillChange
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main) // Even longer delay for preferences
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleDelayedUpdate()
            }
            .store(in: &cancellables)
            
        ExternalIPManager.shared.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleDelayedUpdate()
            }
            .store(in: &cancellables)
    }
    
    // Explicitly trigger an image update
    func forceImageUpdate() {
        scheduleDelayedUpdate()
    }
    
    // Schedule a delayed update to ensure we're completely outside any view update cycle
    private func scheduleDelayedUpdate() {
        // Prevent recursive calls
        guard !isUpdating else { return }
        
        // Cancel any existing timer
        updateTimer?.invalidate()
        
        // Schedule update with a longer delay to ensure we're outside view updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarImage()
            }
        }
    }
    
    @MainActor
    private func updateMenuBarImage() {
        // Prevent recursive calls
        guard !isUpdating else { return }
        isUpdating = true
        
        defer { 
            isUpdating = false 
            updateTimer?.invalidate()
            updateTimer = nil
        }
        
        guard let systemMonitor = self.systemMonitor,
              let preferences = self.preferences else { return }
              
        // Check if we have real data (not just initial zero values)
        let hasRealCPUData = systemMonitor.cpuUsage > 0
        let hasRealMemoryData = systemMonitor.memoryUsage.used > 0
        let hasRealDiskData = systemMonitor.diskUsage.free > 0
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
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await MainActor.run { [weak self] in
                        self?.hasReceivedRealData = true
                        self?.scheduleDelayedUpdate()
                    }
                }
                return
            }
        }
        
        // Create view and generate snapshot in isolated context
        Task.detached { [weak self, systemMonitor, preferences] in
            guard let self = self else { return }
            
            await MainActor.run {
                let view = MenuBarIconView()
                    .environmentObject(systemMonitor)
                    .environmentObject(preferences)
                    .environmentObject(ExternalIPManager.shared)
                    .padding(.horizontal, 4)
                    .background(Color.clear)
                
                // Create snapshot in a separate context
                let snapshot = view.snapshot()
                
                // Convert to data for comparison
                if let newImageData = snapshot?.tiffRepresentation {
                    // Only update if the image actually changed
                    if newImageData != self.cachedImageData {
                        self.cachedImageData = newImageData
                        
                        // Schedule the actual publishing outside of any potential view context
                        Task.detached {
                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            await MainActor.run { [weak self] in
                                self?.menuBarImage = snapshot
                            }
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
