//
//  CalendarService.swift
//  projectHer
//
//  Handles calendar sync with EventKit (read-only)
//  Syncs upcoming events to server so Pandu can reference them naturally
//

import EventKit
import Foundation
import Combine

class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var lastSyncDate: Date?
    
    /// Number of days to look ahead
    private let lookaheadDays = 3
    
    private init() {
        checkAuthorization()
    }
    
    // MARK: - Authorization
    
    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    checkAuthorization()
                }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    checkAuthorization()
                }
                return granted
            }
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }
    
    /// Check if we have read access to calendar
    var hasAccess: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    // MARK: - Fetch Events
    
    /// Fetches calendar events for the next N days
    func fetchUpcomingEvents() -> [CalendarEvent] {
        guard hasAccess else {
            return []
        }
        
        let calendars = eventStore.calendars(for: .event)
        
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: lookaheadDays, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        let events = eventStore.events(matching: predicate)
        
        return events.map { event in
            CalendarEvent(
                title: event.title ?? "Event",
                startTimestamp: event.startDate.timeIntervalSince1970,
                endTimestamp: event.endDate.timeIntervalSince1970,
                isAllDay: event.isAllDay
            )
        }
    }
    
    // MARK: - Sync to Server
    
    /// Syncs calendar events to the server
    func syncToServer() async {
        let events = fetchUpcomingEvents()
        
        guard !events.isEmpty else {
            print("📅 No calendar events to sync")
            return
        }
        
        let eventDicts: [[String: Any]] = events.map { event in
            [
                "title": event.title,
                "start_timestamp": event.startTimestamp,
                "end_timestamp": event.endTimestamp,
                "is_all_day": event.isAllDay
            ]
        }
        
        do {
            try await WidgetAPIService.shared.syncCalendarEvents(eventDicts)
            await MainActor.run {
                lastSyncDate = Date()
            }
            print("📅 Synced \(events.count) calendar events to server")
        } catch {
            print("📅 Calendar sync failed: \(error)")
        }
    }
    
    /// Should be called periodically (e.g., on app launch, every hour)
    func syncIfNeeded() async {
        // Request access if needed (this triggers the system prompt)
        if authorizationStatus == .notDetermined {
            _ = await requestAccess()
        }
        
        // Bail out if we still don't have access
        guard hasAccess else {
            return
        }
        
        // Only sync if we haven't synced in the last hour
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 3600 {
            return
        }
        
        await syncToServer()
    }
}

// MARK: - Models

struct CalendarEvent: Identifiable {
    let id = UUID()
    let title: String
    let startTimestamp: TimeInterval
    let endTimestamp: TimeInterval
    let isAllDay: Bool
    
    var startDate: Date {
        Date(timeIntervalSince1970: startTimestamp)
    }
    
    var endDate: Date {
        Date(timeIntervalSince1970: endTimestamp)
    }
    
    /// Human-readable time description
    var timeDescription: String {
        if isAllDay {
            return "All day"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }
    
    /// Days from today (0 = today, 1 = tomorrow, etc.)
    var dayOffset: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let eventDay = calendar.startOfDay(for: startDate)
        return calendar.dateComponents([.day], from: today, to: eventDay).day ?? 0
    }
}
