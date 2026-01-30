//
//  PanduLiveActivityWidget.swift
//  PanduWidgets
//
//  Widget Extension views for Live Activities (Dynamic Island + Lock Screen)
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Transit Live Activity Widget

@available(iOS 16.1, *)
struct PanduTransitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PanduTransitAttributes.self) { context in
            // Lock Screen / Banner view
            TransitLockScreenView(context: context)
                .activityBackgroundTint(Color.purple.opacity(0.2))
                .activitySystemActionForegroundColor(Color.purple)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("From")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.attributes.originDisplay)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("To")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.attributes.destinationDisplay)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text("🚶‍♀️")
                            .font(.title2)
                        Text("\(context.state.minutesRemaining) min")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Progress bar
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(.purple)
                        .padding(.horizontal)
                }
                
            } compactLeading: {
                // Compact left
                Text("🚶‍♀️")
            } compactTrailing: {
                // Compact right
                Text("\(context.state.minutesRemaining)m")
                    .font(.caption)
                    .monospacedDigit()
            } minimal: {
                // Minimal (when multiple activities)
                Text("🚶‍♀️")
            }
        }
    }
}

struct TransitLockScreenView: View {
    let context: ActivityViewContext<PanduTransitAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Pandu is on the move")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("🚶‍♀️")
                    .font(.title2)
            }
            
            // Route info
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading) {
                    Text(context.attributes.originDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading) {
                    Text(context.attributes.destinationDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // ETA
                VStack(alignment: .trailing) {
                    Text("\(context.state.minutesRemaining)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    Text("min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress
            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)
                .tint(.purple)
        }
        .padding()
    }
}

// MARK: - Sleep Live Activity Widget

@available(iOS 16.1, *)
struct PanduSleepLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PanduSleepAttributes.self) { context in
            // Lock Screen view
            SleepLockScreenView(context: context)
                .activityBackgroundTint(Color.indigo.opacity(0.2))
                .activitySystemActionForegroundColor(Color.indigo)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Phase")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatPhase(context.state.sleepPhase))
                            .font(.caption)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Wake")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.attributes.wakeTimeDisplay)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(sleepEmoji(for: context.state.sleepPhase))
                            .font(.largeTitle)
                        Text("Sleeping")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "alarm")
                            .foregroundColor(.indigo)
                        Text("\(String(format: "%.1f", context.state.hoursUntilWake))h until wake")
                            .font(.caption)
                    }
                }
                
            } compactLeading: {
                Text(sleepEmoji(for: context.state.sleepPhase))
            } compactTrailing: {
                Text(context.attributes.wakeTimeDisplay)
                    .font(.caption2)
            } minimal: {
                Text("💤")
            }
        }
    }
    
    func formatPhase(_ phase: String) -> String {
        switch phase {
        case "deep_sleep": return "Deep Sleep"
        case "light_sleep": return "Light Sleep"
        case "rem": return "REM"
        case "falling_asleep": return "Falling Asleep"
        case "drowsy": return "Drowsy"
        default: return phase.capitalized
        }
    }
    
    func sleepEmoji(for phase: String) -> String {
        switch phase {
        case "deep_sleep": return "😴"
        case "light_sleep": return "💤"
        case "rem": return "🌙"
        case "falling_asleep": return "😪"
        case "drowsy": return "🥱"
        default: return "💤"
        }
    }
}

struct SleepLockScreenView: View {
    let context: ActivityViewContext<PanduSleepAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Moon icon
            Text(sleepEmoji)
                .font(.system(size: 44))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Pandu is sleeping")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatPhase)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "alarm")
                        .font(.caption2)
                        .foregroundColor(.indigo)
                    Text("Wake at \(context.attributes.wakeTimeDisplay)")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Time until wake
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f", context.state.hoursUntilWake))
                    .font(.title)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("hours")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    var formatPhase: String {
        switch context.state.sleepPhase {
        case "deep_sleep": return "Deep Sleep 😴"
        case "light_sleep": return "Light Sleep 💤"
        case "rem": return "Dreaming 🌙"
        case "falling_asleep": return "Falling Asleep 😪"
        case "drowsy": return "Getting Drowsy 🥱"
        default: return context.state.sleepPhase.capitalized
        }
    }
    
    var sleepEmoji: String {
        switch context.state.sleepPhase {
        case "deep_sleep": return "😴"
        case "light_sleep": return "💤"
        case "rem": return "🌙"
        case "falling_asleep": return "😪"
        case "drowsy": return "🥱"
        default: return "💤"
        }
    }
}

// MARK: - Previews
// Note: Live Activity previews require running on a physical device
// The preview canvas doesn't support ActivityKit previews well

/*
 To test Live Activities:
 1. Build and run on a physical device
 2. Trigger a transit or sleep event from the server
 3. The Live Activity will appear on lock screen and Dynamic Island
*/
