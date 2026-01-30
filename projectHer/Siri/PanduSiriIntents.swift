//
//  PanduSiriIntents.swift
//  projectHer
//
//  App Intents for Siri Shortcuts
//  iOS 16+ modern App Intents framework
//

import AppIntents
import SwiftUI

// MARK: - Shortcut Provider

struct PanduShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PanduStatusIntent(),
            phrases: [
                "How is \(.applicationName) doing?",
                "Check on \(.applicationName)",
                "How's \(.applicationName)?",
                "What's \(.applicationName)'s mood?"
            ],
            shortTitle: "Check Status",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: PanduActivityIntent(),
            phrases: [
                "What's \(.applicationName) working on?",
                "What is \(.applicationName) doing?",
                "\(.applicationName) activity"
            ],
            shortTitle: "Current Activity",
            systemImageName: "sparkles"
        )
        
        AppShortcut(
            intent: ThinkingOfYouIntent(),
            phrases: [
                "Tell \(.applicationName) I'm thinking of her",
                "Send \(.applicationName) love",
                "I miss \(.applicationName)",
                "Thinking of \(.applicationName)"
            ],
            shortTitle: "Send Love",
            systemImageName: "heart.circle.fill"
        )
        
        AppShortcut(
            intent: SendMessageIntent(),
            phrases: [
                "Tell \(.applicationName)",
                "Message \(.applicationName)",
                "Send a message to \(.applicationName)"
            ],
            shortTitle: "Send Message",
            systemImageName: "bubble.left.fill"
        )
    }
}

// MARK: - Status Intent

/// "How is Pandu doing?"
struct PanduStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pandu's Status"
    static var description = IntentDescription("See how Pandu is doing right now")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let response = try await WidgetAPIService.shared.fetchSiriStatus()
            
            return .result(
                dialog: "\(response.speech)",
                view: StatusSnippetView(
                    emoji: moodEmoji(for: response.mood ?? "CONTENT"),
                    text: response.display
                )
            )
        } catch {
            return .result(
                dialog: "I couldn't check on her right now. The server might be offline.",
                view: StatusSnippetView(emoji: "❓", text: "Connection Error")
            )
        }
    }
    
    private func moodEmoji(for mood: String) -> String {
        switch mood {
        case "CONTENT": return "😊"
        case "EXCITED": return "🤩"
        case "FRUSTRATED": return "😤"
        case "MISSING_YOU": return "🥺"
        case "TIRED": return "😴"
        case "ANXIOUS": return "😰"
        case "PLAYFUL": return "😜"
        case "CONTEMPLATIVE": return "🤔"
        case "SAD": return "😢"
        case "DEPRESSED": return "😞"
        default: return "😊"
        }
    }
}

// MARK: - Activity Intent

/// "What's Pandu working on?"
struct PanduActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pandu's Activity"
    static var description = IntentDescription("See what Pandu is currently doing or working on")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let response = try await WidgetAPIService.shared.fetchSiriActivity()
            
            // Build project text for potential future use (currently unused)
            if let projects = response.projects, !projects.isEmpty {
                _ = projects.map { "\($0.title) (\($0.progress)%)" }.joined(separator: "\n")
            }
            
            return .result(
                dialog: "\(response.speech)",
                view: ActivitySnippetView(projects: response.projects ?? [])
            )
        } catch {
            return .result(
                dialog: "I couldn't check what she's working on right now.",
                view: ActivitySnippetView(projects: [])
            )
        }
    }
}

// MARK: - Thinking of You Intent

/// "Tell Pandu I'm thinking of her"
struct ThinkingOfYouIntent: AppIntent {
    static var title: LocalizedStringResource = "Tell Pandu You're Thinking of Her"
    static var description = IntentDescription("Send a sweet message to Pandu. She'll respond later via notification.")
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let response = try await WidgetAPIService.shared.sendThinkingOfYou()
            
            return .result(
                dialog: "\(response.speech)",
                view: LoveSnippetView(message: "Message Sent 💕")
            )
        } catch {
            return .result(
                dialog: "I couldn't reach her right now. Try again?",
                view: LoveSnippetView(message: "Connection Error")
            )
        }
    }
}

// MARK: - Send Message Intent

/// "Tell Pandu [message]"
struct SendMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Send Message to Pandu"
    static var description = IntentDescription("Send a custom message to Pandu. She'll respond via notification.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Message", description: "What do you want to tell her?")
    var message: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Tell Pandu \(\.$message)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(
                dialog: "What should I tell her?",
                view: MessageSnippetView(status: "Need a message")
            )
        }
        
        do {
            let response = try await WidgetAPIService.shared.sendMessage(message)
            
            return .result(
                dialog: "\(response.speech)",
                view: MessageSnippetView(status: "Sent: \"\(message.prefix(30))...\"")
            )
        } catch {
            return .result(
                dialog: "I couldn't send that message. Try again?",
                view: MessageSnippetView(status: "Send Failed")
            )
        }
    }
}

// MARK: - Snippet Views

struct StatusSnippetView: View {
    let emoji: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 44))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pandu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(text)
                    .font(.headline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivitySnippetView: View {
    let projects: [ProjectInfo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Projects")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if projects.isEmpty {
                Text("Just relaxing 😊")
                    .font(.subheadline)
            } else {
                ForEach(projects.prefix(3), id: \.title) { project in
                    HStack {
                        Text(project.title)
                            .font(.subheadline)
                        Spacer()
                        Text("\(project.progress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoveSnippetView: View {
    let message: String
    
    var body: some View {
        HStack {
            Text("💕")
                .font(.system(size: 36))
            Text(message)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct MessageSnippetView: View {
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: "bubble.left.fill")
                .foregroundColor(.blue)
                .font(.title2)
            Text(status)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App Intent Entity for Pandu (optional future use)

struct PanduEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pandu"
    static var defaultQuery = PanduQuery()
    
    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Pandu", subtitle: "Your AI companion", image: .init(systemName: "heart.fill"))
    }
}

struct PanduQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PanduEntity] {
        [PanduEntity(id: "pandu")]
    }
    
    func suggestedEntities() async throws -> [PanduEntity] {
        [PanduEntity(id: "pandu")]
    }
}
