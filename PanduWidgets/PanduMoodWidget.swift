//
//  PanduMoodWidget.swift
//  PanduWidgets
//
//  Simple mood-only widget for minimal home screen presence
//

import WidgetKit
import SwiftUI

// MARK: - Mood Entry

struct PanduMoodEntry: TimelineEntry {
    let date: Date
    let moodEmoji: String
    let mood: String
    let isPlaceholder: Bool
    
    static var placeholder: PanduMoodEntry {
        PanduMoodEntry(
            date: Date(),
            moodEmoji: "😊",
            mood: "CONTENT",
            isPlaceholder: true
        )
    }
}

// MARK: - Provider

struct PanduMoodProvider: TimelineProvider {
    typealias Entry = PanduMoodEntry
    
    func placeholder(in context: Context) -> PanduMoodEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PanduMoodEntry) -> Void) {
        if let cached = WidgetAPIService.shared.loadCachedWidgetData() {
            completion(PanduMoodEntry(
                date: Date(),
                moodEmoji: cached.status.moodEmoji,
                mood: cached.status.mood,
                isPlaceholder: false
            ))
        } else {
            completion(.placeholder)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PanduMoodEntry>) -> Void) {
        Task {
            do {
                let status = try await WidgetAPIService.shared.fetchWidgetStatus()
                WidgetAPIService.shared.cacheWidgetData(status)
                
                let entry = PanduMoodEntry(
                    date: Date(),
                    moodEmoji: status.moodEmoji,
                    mood: status.mood,
                    isPlaceholder: false
                )
                
                let nextUpdate = Date().addingTimeInterval(900) // 15 min
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                if let cached = WidgetAPIService.shared.loadCachedWidgetData() {
                    let entry = PanduMoodEntry(
                        date: Date(),
                        moodEmoji: cached.status.moodEmoji,
                        mood: cached.status.mood,
                        isPlaceholder: false
                    )
                    let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
                    completion(timeline)
                } else {
                    let timeline = Timeline(entries: [PanduMoodEntry.placeholder], policy: .after(Date().addingTimeInterval(300)))
                    completion(timeline)
                }
            }
        }
    }
}

// MARK: - Views

struct PanduMoodWidgetEntryView: View {
    var entry: PanduMoodEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background gradient based on mood
            moodGradient
            
            Text(entry.moodEmoji)
                .font(.system(size: fontSize))
        }
        .containerBackground(for: .widget) {
            moodGradient
        }
    }
    
    var fontSize: CGFloat {
        switch family {
        case .systemSmall: return 64
        case .accessoryCircular: return 32
        default: return 48
        }
    }
    
    var moodGradient: LinearGradient {
        let colors: [Color]
        switch entry.mood {
        case "CONTENT", "PLAYFUL":
            colors = [.pink.opacity(0.4), .purple.opacity(0.3)]
        case "EXCITED":
            colors = [.orange.opacity(0.4), .yellow.opacity(0.3)]
        case "SAD", "DEPRESSED":
            colors = [.blue.opacity(0.4), .indigo.opacity(0.3)]
        case "ANXIOUS", "FRUSTRATED":
            colors = [.gray.opacity(0.4), .purple.opacity(0.3)]
        case "TIRED":
            colors = [.indigo.opacity(0.4), .blue.opacity(0.3)]
        case "MISSING_YOU":
            colors = [.pink.opacity(0.5), .red.opacity(0.3)]
        default:
            colors = [.purple.opacity(0.3), .pink.opacity(0.2)]
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Widget Configuration

struct PanduMoodWidget: Widget {
    let kind: String = "PanduMoodWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PanduMoodProvider()) { entry in
            PanduMoodWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pandu Mood")
        .description("Just her mood - simple and cute")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular
        ])
    }
}

// MARK: - Preview

struct PanduMoodWidget_Previews: PreviewProvider {
    static var previews: some View {
        PanduMoodWidgetEntryView(entry: .placeholder)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
