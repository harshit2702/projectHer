//
//  SharedModels.swift
//  PanduWidgets
//
//  Shared models and API service for Widget Extension
//  NOTE: This is a copy of the main app's WidgetAPIService for the extension target
//

import Foundation

// MARK: - App Config (Widget Version)

struct AppConfig {
    static let serverURL = "http://100.114.99.6:8000"
    static let apiKey = "your-secret-key-change-this"
}

// MARK: - API Response Models

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

// MARK: - Live Activity Attributes

import ActivityKit

/// Transit Live Activity Attributes
struct PanduTransitAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var minutesRemaining: Int
        var progress: Double
    }
    
    var origin: String
    var originDisplay: String
    var destination: String
    var destinationDisplay: String
    var etaTimestamp: TimeInterval
}

/// Sleep Live Activity Attributes
struct PanduSleepAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sleepPhase: String
        var hoursUntilWake: Double
    }
    
    var wakeTimestamp: TimeInterval
    var wakeTimeDisplay: String
}

// MARK: - Widget API Service

class WidgetAPIService {
    static let shared = WidgetAPIService()
    
    static let appGroupIdentifier = "group.com.projecther.shared"
    
    private let baseURL: String
    private let apiKey: String
    
    private init() {
        let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier)
        self.baseURL = sharedDefaults?.string(forKey: "serverURL") ?? AppConfig.serverURL
        self.apiKey = sharedDefaults?.string(forKey: "apiKey") ?? AppConfig.apiKey
    }
    
    func fetchWidgetStatus() async throws -> WidgetStatusResponse {
        guard let url = URL(string: baseURL + "/widget/status") else {
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
        
        return try JSONDecoder().decode(WidgetStatusResponse.self, from: data)
    }
    
    // MARK: - Caching
    
    func cacheWidgetData(_ data: WidgetStatusResponse) {
        guard let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier) else { return }
        
        let cached = CachedWidgetData(status: data, cachedAt: Date())
        if let encoded = try? JSONEncoder().encode(cached) {
            sharedDefaults.set(encoded, forKey: "cachedWidgetStatus")
        }
    }
    
    func loadCachedWidgetData() -> CachedWidgetData? {
        guard let sharedDefaults = UserDefaults(suiteName: WidgetAPIService.appGroupIdentifier),
              let data = sharedDefaults.data(forKey: "cachedWidgetStatus"),
              let cached = try? JSONDecoder().decode(CachedWidgetData.self, from: data) else {
            return nil
        }
        return cached
    }
}

struct CachedWidgetData: Codable {
    let status: WidgetStatusResponse
    let cachedAt: Date
    
    var isStale: Bool {
        Date().timeIntervalSince(cachedAt) > 300
    }
}
