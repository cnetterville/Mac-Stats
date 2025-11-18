//
//  ExternalIPManager.swift
//  Mac Stats
//
//  Created by Curtis Netterville on 8/29/25.
//

import Foundation
import Combine

class ExternalIPManager: ObservableObject {
    static let shared = ExternalIPManager()
    
    @Published var externalIP: String = ""
    @Published var countryCode: String = ""
    @Published var countryName: String = ""
    @Published var ispName: String = ""
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date?
    
    private var previousIP: String = ""
    private var lastNotificationTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var preferences: PreferencesManager?
    private var scheduledCheckTimer: Timer?
    
    private init() {
        // Load cached data if available
        loadCachedData()
        // Load previous IP for comparison
        previousIP = externalIP
    }
    
    func setPreferences(_ preferences: PreferencesManager) {
        // Clear existing subscriptions first to prevent cycles
        cancellables.removeAll()
        
        self.preferences = preferences
        
        // Set up observers for scheduled checking with debouncing to prevent cycles
        preferences.$scheduledIPCheckEnabled
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] enabled in
                DispatchQueue.main.async {
                    self?.updateScheduledChecking(enabled: enabled)
                }
            }
            .store(in: &cancellables)
        
        preferences.$scheduledIPCheckInterval
            .removeDuplicates()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self, let prefs = self.preferences else { return }
                DispatchQueue.main.async {
                    self.updateScheduledChecking(enabled: prefs.scheduledIPCheckEnabled)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateScheduledChecking(enabled: Bool) {
        // Always cancel existing timer first
        scheduledCheckTimer?.invalidate()
        scheduledCheckTimer = nil
        
        guard enabled, let preferences = preferences else { 
            print("Scheduled IP checking disabled")
            return 
        }
        
        // Create new timer with the current interval
        let interval = max(300.0, preferences.scheduledIPCheckInterval) // Minimum 5 minutes
        scheduledCheckTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, let prefs = self.preferences else {
                timer.invalidate()
                return
            }
            
            // Only run if still enabled
            guard prefs.scheduledIPCheckEnabled else {
                timer.invalidate()
                return
            }
            
            self.refreshExternalIP()
        }
        
        print("Scheduled IP checking enabled with interval \(interval) seconds")
    }
    
    func refreshExternalIP() {
        guard !isLoading else { return }
        
        isLoading = true
        
        // Fetch external IP
        fetchExternalIP { [weak self] ip, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Error fetching external IP: \(error)")
                    return
                }
                
                guard let ip = ip, let self = self else { return }
                
                // Check if IP has changed
                let ipChanged = self.externalIP != ip && !self.externalIP.isEmpty
                
                self.externalIP = ip
                self.lastUpdated = Date()
                
                // Cache the IP
                self.cacheData()
                
                // Send notification if IP changed and notifications are enabled
                if ipChanged {
                    self.sendIPChangeNotificationIfNeeded()
                }
                
                // Fetch country and ISP information for the IP
                self.fetchIPInfo(for: ip) { countryCode, countryName, ispName, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("Error fetching IP info: \(error)")
                            return
                        }
                        
                        self.countryCode = countryCode ?? ""
                        self.countryName = countryName ?? ""
                        self.ispName = ispName ?? ""
                        
                        // Cache all data
                        self.cacheData()
                    }
                }
            }
        }
    }
    
    private func sendIPChangeNotificationIfNeeded() {
        guard let preferences = self.preferences else { return }
        
        // Check if IP change notifications are enabled
        guard preferences.ipChangeNotificationEnabled else { return }
        
        // Check if enough time has passed since last notification
        if let lastNotification = lastNotificationTime {
            let timeInterval = Date().timeIntervalSince(lastNotification)
            guard timeInterval >= preferences.ipChangeNotificationInterval else { return }
        }
        
        // Check if email notifications are enabled
        guard preferences.mailjetEmailEnabled else { return }
        
        // Send email notification
        sendIPChangeEmailNotification()
        
        // Update last notification time
        lastNotificationTime = Date()
    }
    
    private func sendIPChangeEmailNotification() {
        guard let preferences = self.preferences else { return }
        
        let subject = "External IP Address Changed"
        let oldIP = previousIP.isEmpty ? "Unknown" : previousIP
        let newIP = externalIP
        let timestamp = Date().formatted(date: .complete, time: .shortened)
        
        let message = """
        Your external IP address has changed.
        
        Previous IP: \(oldIP)
        New IP: \(newIP)
        Time: \(timestamp)
        
        This is an automated notification from Mac Stats.
        """
        
        // Use the "To" email if specified, otherwise use the "From" email
        let toEmail = preferences.mailjetToEmail.isEmpty ? preferences.mailjetFromEmail : preferences.mailjetToEmail
        
        EmailService.shared.sendMailjetEmail(
            apiKey: preferences.mailjetAPIKey,
            apiSecret: preferences.mailjetAPISecret,
            fromEmail: preferences.mailjetFromEmail,
            fromName: preferences.mailjetFromName.isEmpty ? "Mac Stats" : preferences.mailjetFromName,
            toEmail: toEmail,
            subject: subject,
            message: message
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("IP change notification sent successfully: \(response)")
                case .failure(let error):
                    print("Failed to send IP change notification: \(error)")
                }
            }
        }
        
        // Update previous IP
        previousIP = externalIP
    }
    
    private func fetchExternalIP(completion: @escaping (String?, Error?) -> Void) {
        let urls = [
            URL(string: "https://api.ipify.org")!,
            URL(string: "https://icanhazip.com")!,
            URL(string: "https://ident.me")!
        ]
        
        fetchFromURLs(urls: urls, completion: completion)
    }
    
    private func fetchFromURLs(urls: [URL], completion: @escaping (String?, Error?) -> Void) {
        guard let url = urls.first else {
            completion(nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No URLs to fetch from"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Try next URL if available
                if urls.count > 1 {
                    let remainingURLs = Array(urls[1...])
                    self.fetchFromURLs(urls: remainingURLs, completion: completion)
                } else {
                    completion(nil, error)
                }
                return
            }
            
            guard let data = data,
                  let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                if urls.count > 1 {
                    let remainingURLs = Array(urls[1...])
                    self.fetchFromURLs(urls: remainingURLs, completion: completion)
                } else {
                    completion(nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data received"]))
                }
                return
            }
            
            completion(ip, nil)
        }.resume()
    }
    
    private func fetchIPInfo(for ip: String, completion: @escaping (String?, String?, String?, Error?) -> Void) {
        guard !ip.isEmpty else {
            completion(nil, nil, nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty IP address"]))
            return
        }
        
        // Using ipinfo.io as the primary service (requires HTTPS)
        let urlString = "https://ipinfo.io/\(ip)/json"
        guard let url = URL(string: urlString) else {
            completion(nil, nil, nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, nil, nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, nil, nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // ipinfo.io returns country directly as a 2-letter code
                    let countryCode = json["country"] as? String
                    // Try to get country name, fallback to country code if not available
                    let countryName = json["country_name"] as? String ?? countryCode ?? ""
                    // Get ISP/organization name
                    let ispName = json["org"] as? String ?? ""
                    
                    if countryCode != nil || !ispName.isEmpty {
                        completion(countryCode, countryName, ispName, nil)
                    } else {
                        completion(nil, nil, nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No IP info found in response"]))
                    }
                } else {
                    completion(nil, nil, nil, NSError(domain: "ExternalIPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
                }
            } catch {
                completion(nil, nil, nil, error)
            }
        }.resume()
    }
    
    // MARK: - Caching
    
    private func cacheData() {
        let defaults = UserDefaults.standard
        defaults.set(externalIP, forKey: "cachedExternalIP")
        defaults.set(countryCode, forKey: "cachedCountryCode")
        defaults.set(countryName, forKey: "cachedCountryName")
        defaults.set(ispName, forKey: "cachedISPName")
        defaults.set(lastUpdated?.timeIntervalSince1970, forKey: "cachedExternalIPLastUpdated")
    }
    
    private func loadCachedData() {
        let defaults = UserDefaults.standard
        externalIP = defaults.string(forKey: "cachedExternalIP") ?? ""
        countryCode = defaults.string(forKey: "cachedCountryCode") ?? ""
        countryName = defaults.string(forKey: "cachedCountryName") ?? ""
        ispName = defaults.string(forKey: "cachedISPName") ?? ""
        
        let timestamp = defaults.double(forKey: "cachedExternalIPLastUpdated")
        if timestamp != 0 {
            lastUpdated = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    // MARK: - Utility
    
    deinit {
        scheduledCheckTimer?.invalidate()
    }
    
    var flagEmoji: String {
        return getFlagEmoji(for: countryCode)
    }
    
    func getFlagEmoji(for countryCode: String) -> String {
        guard countryCode.count == 2 else { return "🌐" }
        
        let base: UInt32 = 0x1F1E6 // Unicode value for regional indicator symbol letter A
        var flagEmoji = ""
        
        for char in countryCode.uppercased() {
            guard let asciiValue = char.asciiValue else { continue }
            let regionalIndicatorValue = base + UInt32(asciiValue - 65) // 65 is ASCII value for 'A'
            if let regionalIndicator = UnicodeScalar(regionalIndicatorValue) {
                flagEmoji.unicodeScalars.append(regionalIndicator)
            }
        }
        
        // The flag emoji should have 2 unicode scalars but appear as 1 character
        // So we check if we have exactly 2 unicode scalars instead of character count
        return flagEmoji.unicodeScalars.count == 2 ? flagEmoji : "🌐"
    }
}