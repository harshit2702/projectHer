//
//  PanduStatusWidget.swift
//  PanduWidgets
//
//  Main widget showing mood, location, and activity
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PanduStatusEntry: TimelineEntry {
    let date: Date
    let mood: String
    let moodEmoji: String
    let moodDescription: String
    let location: String
    let locationDisplay: String
    let activity: String
    let activityDisplay: String
    let isSleeping: Bool
    let sleepPhase: String?
    let currentProject: ProjectInfo?
    let minutesSinceContact: Int
    let isPlaceholder: Bool
    
    static var placeholder: PanduStatusEntry {
        PanduStatusEntry(
            date: Date(),
            mood: "CONTENT",
            moodEmoji: "😊",
            moodDescription: "feeling content",
            location: "bedroom",
            locationDisplay: "her bedroom 🛏️",
            activity: "chilling",
            activityDisplay: "Relaxing",
            isSleeping: false,
            sleepPhase: nil,
            currentProject: nil,
            minutesSinceContact: 0,
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct PanduStatusProvider: TimelineProvider {
    typealias Entry = PanduStatusEntry
    
    func placeholder(in context: Context) -> PanduStatusEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PanduStatusEntry) -> Void) {
        // For preview/gallery, try cache first then fetch
        if context.isPreview {
            if let cached = WidgetAPIService.shared.loadCachedWidgetData() {
                completion(entry(from: cached.status))
            } else {
                completion(.placeholder)
            }
        } else {
            // For actual widget, always try to fetch fresh data
            Task {
                do {
                    let status = try await WidgetAPIService.shared.fetchWidgetStatus()
                    WidgetAPIService.shared.cacheWidgetData(status)
                    completion(entry(from: status))
                } catch {
                    if let cached = WidgetAPIService.shared.loadCachedWidgetData() {
                        completion(entry(from: cached.status))
                    } else {
                        completion(.placeholder)
                    }
                }
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PanduStatusEntry>) -> Void) {
        Task {
            do {
                print("🔄 Widget: Fetching fresh status...")
                let status = try await WidgetAPIService.shared.fetchWidgetStatus()
                WidgetAPIService.shared.cacheWidgetData(status)
                
                let entry = self.entry(from: status)
                
                // 🆕 More aggressive refresh schedule
                let refreshInterval: TimeInterval
                if status.isTraveling {
                    refreshInterval = 60 // 1 minute during travel
                } else if status.isSleeping {
                    refreshInterval = 180 // 3 minutes during sleep (was 5)
                } else {
                    refreshInterval = 600 // 10 minutes normally (was 15)
                }
                
                print("📱 Widget: Updated! Mood=\(status.mood), Location=\(status.location), Next refresh in \(Int(refreshInterval/60))min")
                
                let nextUpdate = Date().addingTimeInterval(refreshInterval)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                print("⚠️ Widget: Fetch failed, using cache. Error: \(error)")
                // Use cached data on error
                if let cached = WidgetAPIService.shared.loadCachedWidgetData() {
                    let entry = self.entry(from: cached.status)
                    // Retry sooner on error
                    let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(120)))
                    completion(timeline)
                } else {
                    let timeline = Timeline(entries: [PanduStatusEntry.placeholder], policy: .after(Date().addingTimeInterval(120)))
                    completion(timeline)
                }
            }
        }
    }
    
    private func entry(from status: WidgetStatusResponse) -> PanduStatusEntry {
        PanduStatusEntry(
            date: Date(),
            mood: status.mood,
            moodEmoji: status.moodEmoji,
            moodDescription: status.moodDescription,
            location: status.location,
            locationDisplay: status.locationDisplay,
            activity: status.activity,
            activityDisplay: status.activityDisplay,
            isSleeping: status.isSleeping,
            sleepPhase: status.sleepPhase,
            currentProject: status.currentProject,
            minutesSinceContact: status.minutesSinceContact,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget Views

struct PanduStatusWidgetEntryView: View {
    var entry: PanduStatusEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mood
            HStack {
                Text(entry.moodEmoji)
                    .font(.system(size: 32))
                Spacer()
            }
            
            Spacer()
            
            // Location
            Text(entry.locationDisplay)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Activity
            Text(entry.activityDisplay)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding()
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: gradientColors(for: entry.mood),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.3)
        }
    }
    
    func gradientColors(for mood: String) -> [Color] {
        switch mood {
        case "CONTENT", "PLAYFUL":
            return [.pink.opacity(0.6), .purple.opacity(0.4)]
        case "EXCITED":
            return [.orange.opacity(0.6), .yellow.opacity(0.4)]
        case "SAD", "DEPRESSED":
            return [.blue.opacity(0.6), .indigo.opacity(0.4)]
        case "ANXIOUS", "FRUSTRATED":
            return [.gray.opacity(0.6), .purple.opacity(0.4)]
        case "TIRED":
            return [.indigo.opacity(0.6), .blue.opacity(0.4)]
        case "MISSING_YOU":
            return [.pink.opacity(0.7), .red.opacity(0.4)]
        default:
            return [.purple.opacity(0.5), .pink.opacity(0.3)]
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Mood
            VStack(alignment: .center, spacing: 4) {
                Text(entry.moodEmoji)
                    .font(.system(size: 48))
                Text(entry.moodDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(width: 80)
            
            Divider()
            
            // Right: Details
            VStack(alignment: .leading, spacing: 8) {
                // Location
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.pink)
                    Text(entry.locationDisplay)
                        .font(.subheadline)
                }
                
                // Activity
                HStack {
                    Image(systemName: activityIcon(for: entry.activity))
                        .foregroundColor(.purple)
                    Text(entry.activityDisplay)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Project (if any)
                if let project = entry.currentProject {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("\(project.title) (\(project.progress)%)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                // Time since contact
                if entry.minutesSinceContact > 60 {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        Text("Last seen \(formatTime(entry.minutesSinceContact))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    func activityIcon(for activity: String) -> String {
        switch activity {
        case "sleeping": return "moon.zzz.fill"
        case "working", "focused": return "laptopcomputer"
        case "reading": return "book.fill"
        case "eating": return "fork.knife"
        case "walking": return "figure.walk"
        case "exercising": return "figure.run"
        default: return "sparkles"
        }
    }
    
    func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m ago"
        } else if minutes < 1440 {
            return "\(minutes / 60)h ago"
        } else {
            return "\(minutes / 1440)d ago"
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Pandu")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text(entry.moodEmoji)
                    .font(.system(size: 36))
            }
            
            Divider()
            
            // Status Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Mood Card
                StatusCard(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Mood",
                    value: entry.moodDescription.capitalized
                )
                
                // Location Card
                StatusCard(
                    icon: "mappin.circle.fill",
                    iconColor: .blue,
                    title: "Location",
                    value: entry.locationDisplay.replacingOccurrences(of: " 🛏️", with: "")
                        .replacingOccurrences(of: " 🔬", with: "")
                        .replacingOccurrences(of: " 🍜", with: "")
                        .replacingOccurrences(of: " 🌳", with: "")
                )
                
                // Activity Card
                StatusCard(
                    icon: activityIcon(for: entry.activity),
                    iconColor: .purple,
                    title: "Activity",
                    value: entry.activityDisplay
                )
                
                // Project Card
                if let project = entry.currentProject {
                    StatusCard(
                        icon: "doc.text.fill",
                        iconColor: .orange,
                        title: "Working On",
                        value: "\(project.title) (\(project.progress)%)"
                    )
                } else {
                    StatusCard(
                        icon: "clock",
                        iconColor: .gray,
                        title: "Last Seen",
                        value: formatTime(entry.minutesSinceContact)
                    )
                }
            }
            
            Spacer()
            
            // Sleep indicator
            if entry.isSleeping, let phase = entry.sleepPhase {
                HStack {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundColor(.indigo)
                    Text("Sleep: \(phase.replacingOccurrences(of: "_", with: " ").capitalized)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    func activityIcon(for activity: String) -> String {
        switch activity {
        case "sleeping": return "moon.zzz.fill"
        case "working", "focused": return "laptopcomputer"
        case "reading": return "book.fill"
        case "eating": return "fork.knife"
        case "walking": return "figure.walk"
        case "exercising": return "figure.run"
        default: return "sparkles"
        }
    }
    
    func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m ago"
        } else if minutes < 1440 {
            return "\(minutes / 60)h ago"
        } else {
            return "\(minutes / 1440)d ago"
        }
    }
}

struct StatusCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Lock Screen Widgets

struct AccessoryCircularView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(entry.moodEmoji)
                .font(.title)
        }
    }
}

struct AccessoryRectangularView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        HStack {
            Text(entry.moodEmoji)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(entry.activityDisplay)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.locationDisplay)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct AccessoryInlineView: View {
    let entry: PanduStatusEntry
    
    var body: some View {
        Text("\(entry.moodEmoji) \(entry.activityDisplay)")
    }
}

// MARK: - Widget Configuration

struct PanduStatusWidget: Widget {
    let kind: String = "PanduStatusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PanduStatusProvider()) { entry in
            PanduStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pandu Status")
        .description("See what Pandu is up to right now")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Preview

struct PanduStatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PanduStatusWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            
            PanduStatusWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            PanduStatusWidgetEntryView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
