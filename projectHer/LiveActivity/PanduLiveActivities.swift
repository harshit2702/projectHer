//
//  PanduLiveActivities.swift
//  projectHer
//
//  Live Activities for Transit and Sleep tracking
//  Supports Dynamic Island on iPhone 14 Pro+
//

import ActivityKit
import WidgetKit
import SwiftUI
import Combine

// MARK: - Transit Activity

/// Attributes for tracking when Pandu is traveling
struct PanduTransitAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var minutesRemaining: Int
        var progress: Double // 0.0 to 1.0
    }
    
    var origin: String
    var originDisplay: String
    var destination: String
    var destinationDisplay: String
    var etaTimestamp: TimeInterval
}

// MARK: - Sleep Activity

/// Attributes for tracking when Pandu is sleeping
struct PanduSleepAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sleepPhase: String
        var hoursUntilWake: Double
    }
    
    var wakeTimestamp: TimeInterval
    var wakeTimeDisplay: String
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
class PanduLiveActivityManager: ObservableObject {
    static let shared = PanduLiveActivityManager()
    
    @Published var currentTransitActivity: Activity<PanduTransitAttributes>?
    @Published var currentSleepActivity: Activity<PanduSleepAttributes>?
    
    private var updateTimer: Timer?
    
    private init() {}
    
    // MARK: - Transit Activity
    
    func startTransitActivity(
        origin: String,
        originDisplay: String,
        destination: String,
        destinationDisplay: String,
        etaTimestamp: TimeInterval
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = PanduTransitAttributes(
            origin: origin,
            originDisplay: originDisplay,
            destination: destination,
            destinationDisplay: destinationDisplay,
            etaTimestamp: etaTimestamp
        )
        
        let now = Date().timeIntervalSince1970
        let totalDuration = etaTimestamp - now
        let initialState = PanduTransitAttributes.ContentState(
            minutesRemaining: max(0, Int((etaTimestamp - now) / 60)),
            progress: 0.0
        )
        
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentTransitActivity = activity
            startUpdateTimer(etaTimestamp: etaTimestamp, totalDuration: totalDuration)
            print("🚶 Transit Live Activity started: \(origin) → \(destination)")
        } catch {
            print("Failed to start transit activity: \(error)")
        }
    }
    
    func updateTransitActivity(minutesRemaining: Int, progress: Double) {
        guard let activity = currentTransitActivity else { return }
        
        let newState = PanduTransitAttributes.ContentState(
            minutesRemaining: minutesRemaining,
            progress: progress
        )
        
        Task {
            let content = ActivityContent(state: newState, staleDate: nil)
            await activity.update(content)
        }
    }
    
    func endTransitActivity() {
        guard let activity = currentTransitActivity else { return }
        
        let finalState = PanduTransitAttributes.ContentState(
            minutesRemaining: 0,
            progress: 1.0
        )
        
        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .default)
            await MainActor.run {
                currentTransitActivity = nil
            }
        }
        
        updateTimer?.invalidate()
        updateTimer = nil
        print("🏁 Transit Live Activity ended")
    }
    
    // MARK: - Sleep Activity
    
    func startSleepActivity(wakeTimestamp: TimeInterval, wakeTimeDisplay: String, initialPhase: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = PanduSleepAttributes(
            wakeTimestamp: wakeTimestamp,
            wakeTimeDisplay: wakeTimeDisplay
        )
        
        let now = Date().timeIntervalSince1970
        let initialState = PanduSleepAttributes.ContentState(
            sleepPhase: initialPhase,
            hoursUntilWake: max(0, (wakeTimestamp - now) / 3600)
        )
        
        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentSleepActivity = activity
            print("😴 Sleep Live Activity started, wake at \(wakeTimeDisplay)")
        } catch {
            print("Failed to start sleep activity: \(error)")
        }
    }
    
    func updateSleepActivity(phase: String, hoursUntilWake: Double) {
        guard let activity = currentSleepActivity else { return }
        
        let newState = PanduSleepAttributes.ContentState(
            sleepPhase: phase,
            hoursUntilWake: hoursUntilWake
        )
        
        Task {
            let content = ActivityContent(state: newState, staleDate: nil)
            await activity.update(content)
        }
    }
    
    func endSleepActivity() {
        guard let activity = currentSleepActivity else { return }
        
        let finalState = PanduSleepAttributes.ContentState(
            sleepPhase: "awake",
            hoursUntilWake: 0
        )
        
        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .default)
            await MainActor.run {
                currentSleepActivity = nil
            }
        }
        print("☀️ Sleep Live Activity ended")
    }
    
    // MARK: - Auto-Update from Server
    
    private func startUpdateTimer(etaTimestamp: TimeInterval, totalDuration: TimeInterval) {
        updateTimer?.invalidate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            let now = Date().timeIntervalSince1970
            let remaining = etaTimestamp - now
            
            if remaining <= 0 {
                self?.endTransitActivity()
            } else {
                let progress = 1.0 - (remaining / totalDuration)
                self?.updateTransitActivity(
                    minutesRemaining: Int(remaining / 60),
                    progress: min(1.0, max(0.0, progress))
                )
            }
        }
    }
    
    /// Call this periodically from the main app to sync Live Activity state with server
    func syncWithServer() async {
        do {
            let status = try await WidgetAPIService.shared.fetchLiveActivityStatus()
            
            await MainActor.run {
                switch status.activityType {
                case "transit":
                    if let data = status.data, status.shouldShow {
                        if currentTransitActivity == nil {
                            // Start new activity
                            startTransitActivity(
                                origin: data.origin ?? "",
                                originDisplay: data.originDisplay ?? "",
                                destination: data.destination ?? "",
                                destinationDisplay: data.destinationDisplay ?? "",
                                etaTimestamp: data.etaTimestamp ?? 0
                            )
                        } else {
                            // Update existing
                            updateTransitActivity(
                                minutesRemaining: data.minutesRemaining ?? 0,
                                progress: data.progress ?? 0
                            )
                        }
                    } else if currentTransitActivity != nil && !status.shouldShow {
                        endTransitActivity()
                    }
                    
                case "sleep":
                    if let data = status.data, status.shouldShow {
                        if currentSleepActivity == nil {
                            startSleepActivity(
                                wakeTimestamp: data.wakeTimestamp ?? 0,
                                wakeTimeDisplay: data.wakeTimeDisplay ?? "7:00 AM",
                                initialPhase: data.sleepPhase ?? "sleeping"
                            )
                        } else {
                            updateSleepActivity(
                                phase: data.sleepPhase ?? "sleeping",
                                hoursUntilWake: data.hoursUntilWake ?? 0
                            )
                        }
                    } else if currentSleepActivity != nil && !status.shouldShow {
                        endSleepActivity()
                    }
                    
                default:
                    // No activity needed, end any running ones
                    if currentTransitActivity != nil {
                        endTransitActivity()
                    }
                    if currentSleepActivity != nil {
                        endSleepActivity()
                    }
                }
            }
        } catch {
            print("Live Activity sync error: \(error)")
        }
    }
}
