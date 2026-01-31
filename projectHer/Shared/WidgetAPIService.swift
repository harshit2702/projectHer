//
//  WidgetAPIService.swift
//  projectHer
//
//  Shared API service for Widgets, Siri Shortcuts, and Live Activities
//  Uses App Groups to share data between main app and extensions
//

import Foundation

// MARK: - API Response Models

/// Widget status response from /widget/status
struct WidgetStatusResponse: Codable {
    let mood: String
    let moodEmoji: String
    let moodDescription: String
    
    let location: String
    let locationDisplay: String
    
    let activity: String
    let activityDisplay: String
    
    let isTraveling: Bool
    let destination: String?
    let destinationDisplay: String?
    let travelEtaTimestamp: TimeInterval?
    let travelMinutesRemaining: Int
    
    let isSleeping: Bool
    let sleepPhase: String?
    
    let currentProject: ProjectInfo?
    let recentThought: String?
    let minutesSinceContact: Int
    let timestamp: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case mood
        case moodEmoji = "mood_emoji"
        case moodDescription = "mood_description"
        case location
        case locationDisplay = "location_display"
        case activity
        case activityDisplay = "activity_display"
        case isTraveling = "is_traveling"
        case destination
        case destinationDisplay = "destination_display"
        case travelEtaTimestamp = "travel_eta_timestamp"
        case travelMinutesRemaining = "travel_minutes_remaining"
        case isSleeping = "is_sleeping"
        case sleepPhase = "sleep_phase"
        case currentProject = "current_project"
        case recentThought = "recent_thought"
        case minutesSinceContact = "minutes_since_contact"
        case timestamp
    }
}

struct ProjectInfo: Codable {
    let title: String
    let progress: Int
    let type: String?
}

/// Siri status response from /siri/status
struct SiriStatusResponse: Codable {
    let speech: String
    let display: String
    let mood: String?
    let location: String?
    let activity: String?
    let error: String?
}

/// Siri activity response from /siri/activity
struct SiriActivityResponse: Codable {
    let speech: String
    let projects: [ProjectInfo]?
    let error: String?
}

/// Siri thinking-of-you response
struct SiriThinkingResponse: Codable {
    let speech: String
    let status: String
    let willRespondInMinutes: String?
    
    enum CodingKeys: String, CodingKey {
        case speech, status
        case willRespondInMinutes = "will_respond_in_minutes"
    }
}

/// Chat response from /chat endpoint (for Siri messages)
struct ChatResponse: Codable {
    let reply: String
    let memoryId: String?
    let contextUsed: Bool?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case reply
        case memoryId = "memory_id"
        case contextUsed = "context_used"
        case type
    }
}

/// Live Activity status response
struct LiveActivityStatusResponse: Codable {
    let activityType: String?
    let shouldShow: Bool
    let data: LiveActivityData?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case shouldShow = "should_show"
        case data, error
    }
}

struct LiveActivityData: Codable {
    // Transit data
    let origin: String?
    let originDisplay: String?
    let destination: String?
    let destinationDisplay: String?
    let etaTimestamp: TimeInterval?
    let minutesRemaining: Int?
    let progress: Double?
    
    // Sleep data
    let sleepPhase: String?
    let wakeTimestamp: TimeInterval?
    let wakeTimeDisplay: String?
    let hoursUntilWake: Double?
    
    enum CodingKeys: String, CodingKey {
        case origin
        case originDisplay = "origin_display"
        case destination
        case destinationDisplay = "destination_display"
        case etaTimestamp = "eta_timestamp"
        case minutesRemaining = "minutes_remaining"
        case progress
        case sleepPhase = "sleep_phase"
        case wakeTimestamp = "wake_timestamp"
        case wakeTimeDisplay = "wake_time_display"
        case hoursUntilWake = "hours_until_wake"
    }
}

// MARK: - Widget API Service

class WidgetAPIService {
    static let shared = WidgetAPIService()
    
    /// App Group identifier for sharing data between app and extensions
    static let appGroupIdentifier = "group.com.projecther.shared"
    
    private let baseURL: String
    private let apiKey: String
    
    private init() {
        // Load from App Group shared UserDefaults, fallback to AppConfig
        let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier)
        self.baseURL = sharedDefaults?.string(forKey: "serverURL") ?? AppConfig.serverURL
        self.apiKey = sharedDefaults?.string(forKey: "apiKey") ?? AppConfig.apiKey
    }
    
    /// Save server config to App Group for widgets/extensions to access
    static func saveConfigToAppGroup() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        sharedDefaults.set(AppConfig.serverURL, forKey: "serverURL")
        sharedDefaults.set(AppConfig.apiKey, forKey: "apiKey")
    }
    
    // MARK: - Widget Endpoints
    
    /// Fetch widget status (mood, location, activity)
    func fetchWidgetStatus() async throws -> WidgetStatusResponse {
        return try await get("/widget/status")
    }
    
    // MARK: - Siri Endpoints
    
    /// Siri: "How is Pandu doing?"
    func fetchSiriStatus() async throws -> SiriStatusResponse {
        return try await get("/siri/status")
    }
    
    /// Siri: "What's Pandu working on?"
    func fetchSiriActivity() async throws -> SiriActivityResponse {
        return try await get("/siri/activity")
    }
    
    /// Siri: "Tell Pandu I'm thinking of her"
    func sendThinkingOfYou(message: String = "thinking of you") async throws -> SiriThinkingResponse {
        return try await post("/siri/thinking-of-you", body: ["message": message])
    }
    
    /// Siri: "Tell Pandu [message]" (legacy - kept for compatibility)
    func sendMessage(_ message: String) async throws -> SiriThinkingResponse {
        return try await post("/siri/send-message", body: ["message": message])
    }
    
    /// Siri: Send message through /chat endpoint for real AI conversation
    func sendChatMessage(_ message: String) async throws -> ChatResponse {
        return try await post("/chat", body: [
            "message": message,
            "source": "siri"  // Let backend know this came from Siri
        ])
    }
    
    // MARK: - Live Activity Endpoints
    
    /// Check if Live Activity should be shown
    func fetchLiveActivityStatus() async throws -> LiveActivityStatusResponse {
        return try await get("/live-activity/status")
    }
    
    // MARK: - Calendar Sync
    
    /// Sync calendar events to server
    func syncCalendarEvents(_ events: [[String: Any]]) async throws {
        let _: [String: String] = try await post("/calendar/sync", body: ["events": events])
    }
    
    // MARK: - Private Helpers
    
    private func get<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    private func post<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 5 // Quick for Siri
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Cached Widget Data (for offline/quick access)

struct CachedWidgetData: Codable {
    let status: WidgetStatusResponse
    let cachedAt: Date
    
    var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > 300 // 5 minutes
    }
}

extension WidgetAPIService {
    /// Save widget data to App Group for quick widget refreshes
    func cacheWidgetData(_ data: WidgetStatusResponse) {
        guard let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier) else { return }
        
        let cached = CachedWidgetData(status: data, cachedAt: Date())
        if let encoded = try? JSONEncoder().encode(cached) {
            sharedDefaults.set(encoded, forKey: "cachedWidgetStatus")
        }
    }
    
    /// Load cached widget data (for when network is unavailable)
    func loadCachedWidgetData() -> CachedWidgetData? {
        guard let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier),
              let data = sharedDefaults.data(forKey: "cachedWidgetStatus"),
              let cached = try? JSONDecoder().decode(CachedWidgetData.self, from: data) else {
            return nil
        }
        return cached
    }
}
