# Settings View Performance Fix

## Problem Summary
The Settings view was becoming unresponsive and hanging when navigating between tabs (General, Network, Notifications) and interacting with pickers.

## Root Causes Identified

### 1. **Excessive UserDefaults Saves**
The `PreferencesManager` had individual `.sink` observers for every single `@Published` property (31+ properties), each triggering an immediate save to:
- UserDefaults
- Keychain (for credentials)
- SMAppService (for launch at startup)

When switching tabs or changing picker values, this created a cascade of saves that blocked the main thread.

### 2. **Direct SystemMonitor Access in Picker**
The `NetworkSettingsView` was accessing `systemMonitor.networkInterfaces` directly in the Picker's ForEach loop. Every time the view re-rendered (which happens frequently during tab switching), it was accessing this potentially expensive property.

### 3. **Lack of View Identity Management**
The TabView items didn't have explicit tags, which could cause SwiftUI to unnecessarily recreate views when switching tabs.

### 4. **Picker Animation Overhead**
Segmented and menu pickers were triggering animations on every state change, adding overhead during rapid navigation.

## Solutions Implemented

### 1. **Debounced Preference Saving** (PreferencesManager.swift)
**Change**: Combined all individual property observers into a single debounced publisher that batches changes together.

**Before**:
```swift
$showCPU.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
$showMemory.sink { _ in self.saveUserDefaults() }.store(in: &cancellables)
// ... 31+ individual observers
```

**After**:
```swift
let allPublishers = Publishers.MergeMany(
    $showCPU.map { _ in () }.eraseToAnyPublisher(),
    $showMemory.map { _ in () }.eraseToAnyPublisher(),
    // ... all publishers merged
)

allPublishers
    .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
    .sink { [weak self] _ in
        self?.saveUserDefaults()
    }
    .store(in: &cancellables)
```

**Impact**: Settings are now saved in batches after 500ms of inactivity instead of on every single change. This dramatically reduces I/O operations.

### 2. **Cached Network Interfaces** (SettingsView.swift - NetworkSettingsView)
**Change**: Added local `@State` cache for network interfaces instead of accessing SystemMonitor repeatedly.

**Before**:
```swift
ForEach(systemMonitor.networkInterfaces, id: \.self) { interface in
    Text(interface).tag(interface)
}
```

**After**:
```swift
@State private var cachedNetworkInterfaces: [String] = []

// In body:
ForEach(cachedNetworkInterfaces, id: \.self) { interface in
    Text(interface).tag(interface)
}

// In onAppear:
.onAppear {
    updateCachedNetworkInterfaces()
}
```

**Impact**: Network interfaces are loaded once when the view appears rather than on every render cycle.

### 3. **Tab Identity Management** (SettingsView.swift)
**Change**: Added explicit tab selection state and tags to maintain view identity.

**Before**:
```swift
TabView {
    GeneralSettingsTab()
        .tabItem { Label("General", systemImage: "gear") }
}
```

**After**:
```swift
enum SettingsTab: Int, Hashable {
    case general = 0
    case network = 1
    case notifications = 2
}

@State private var selectedTab: SettingsTab = .general

TabView(selection: $selectedTab) {
    GeneralSettingsTab()
        .tabItem { Label("General", systemImage: "gear") }
        .tag(SettingsTab.general)
}
```

**Impact**: SwiftUI can now maintain view identity across tab switches, reducing unnecessary view recreation.

### 4. **Disabled Picker Animations** (SettingsView.swift)
**Change**: Added `.animation(nil, value:)` modifiers to all pickers to disable animations during value changes.

```swift
Picker("Network Monitoring", selection: $preferences.networkMonitoringMode) {
    Text("Interface-based").tag(NetworkMonitoringMode.interface)
    Text("Process-based").tag(NetworkMonitoringMode.process)
}
.pickerStyle(.segmented)
.animation(nil, value: preferences.networkMonitoringMode)
```

**Impact**: Eliminates animation overhead when switching between picker options, making the UI more responsive.

## Expected Results

After these changes, users should experience:

1. **Smooth tab switching**: No lag or hanging when moving between General, Network, and Notifications tabs
2. **Responsive pickers**: Instant feedback when changing picker values
3. **Reduced I/O**: Fewer writes to UserDefaults and Keychain
4. **Better battery life**: Less CPU usage from unnecessary view updates and file operations
5. **Maintained functionality**: All settings still save properly, just more efficiently

## Testing Recommendations

Test the following scenarios to verify the fix:

1. Rapidly switch between all three tabs multiple times
2. Change picker values in quick succession (temperature unit, network monitoring mode, network unit)
3. Toggle various settings on/off rapidly
4. Verify that all settings persist correctly after closing and reopening the app
5. Check that network interface picker updates correctly when clicking "Refresh Interfaces"

## Additional Notes

The ExternalIPManager already had some protections against cycles (debouncing, weak references), but if performance issues persist specifically with the Network tab, consider:
- Moving the IP refresh operations to a background queue
- Adding a loading state indicator for expensive operations
- Implementing more aggressive caching for IP-related data
