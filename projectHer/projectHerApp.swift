import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

@main
struct ProjectHerApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    // 1. Create the Database Container
    let sharedModelContainer: ModelContainer
    
    // Deep link action to trigger new chat
    @State private var pendingDeepLinkAction: DeepLinkAction?
    
    // 🆕 Call from Phone Recents - auto-opens call view
    @State private var showCallFromRecents = false
    @State private var isVideoCallFromRecents = true
    
    enum DeepLinkAction: Equatable {
        case openNewChat
        case openChat(sessionId: UUID?)
    }
    
    init() {
        // Must set callback BEFORE anything else - CallKit can call at any time
        // Use a static to bridge from init to SwiftUI state
        Self.setupCallRecentsCallback()
        
        do {
            sharedModelContainer = try ModelContainer(for: ChatMessage.self, ChatSession.self)
            
            // 2. Configure Background Manager with the DB
            BackgroundManager.shared.configure(container: sharedModelContainer)
            BackgroundManager.shared.register()
            
            // 3. Save API config to App Group for widgets
            WidgetAPIService.saveConfigToAppGroup()
            
            // 4. Force Siri to update its shortcut index
            updateSiriShortcuts()
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // Static callback registration - must be done before CallKit can fire
    private static func setupCallRecentsCallback() {
        print("📞 Setting up Phone Recents callback")
        BackgroundCallService.shared.onCallFromRecents = { isVideo in
            print("📞 CALLBACK FIRED: Call from Phone Recents (isVideo: \(isVideo))")
            // Post notification that can be observed by SwiftUI
            NotificationCenter.default.post(
                name: NSNotification.Name("CallFromRecents"),
                object: nil,
                userInfo: ["isVideo": isVideo]
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLinkAction: $pendingDeepLinkAction)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                    
                    // Sync calendar events on launch
                    Task {
                        await CalendarService.shared.syncIfNeeded()
                    }
                    
                    // Sync Live Activity state (iOS 16.1+)
                    if #available(iOS 16.1, *) {
                        Task {
                            await PanduLiveActivityManager.shared.syncWithServer()
                        }
                    }
                }
                .onOpenURL { url in
                    print("📱 App opened via URL: \(url)")
                    handleDeepLink(url)
                }
                // Listen for call from Phone Recents notification
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CallFromRecents"))) { notification in
                    print("📞 NOTIFICATION RECEIVED: CallFromRecents")
                    if let isVideo = notification.userInfo?["isVideo"] as? Bool {
                        print("📞 Opening call view (isVideo: \(isVideo))")
                        isVideoCallFromRecents = isVideo
                        showCallFromRecents = true
                    }
                }
                // Auto-present call when tapping from Phone Recents
                .fullScreenCover(isPresented: $showCallFromRecents) {
                    RecentsCallWrapper(isVideo: isVideoCallFromRecents)
                }
        }
        // 3. Inject Database into View Hierarchy
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                BackgroundManager.shared.scheduleNextFetch()
                // Refresh widgets when going to background
                WidgetCenter.shared.reloadAllTimelines()
                
            case .active:
                // Sync Live Activities when becoming active (iOS 16.1+)
                if #available(iOS 16.1, *) {
                    Task {
                        await PanduLiveActivityManager.shared.syncWithServer()
                    }
                }
                
                // 🆕 Check if widgets need refresh
                Task {
                    await checkWidgetRefresh()
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle deep links from notifications
    private func handleDeepLink(_ url: URL) {
        // Expected format: my-ai-app://open?action=newchat
        // or: my-ai-app://notification (legacy)
        
        if url.host == "notification" || url.path.contains("notification") {
            // Open new chat first, then sync
            pendingDeepLinkAction = .openNewChat
            
            // Delay forceCheck to allow new chat creation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                BackgroundManager.shared.forceCheck()
            }
        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let action = components.queryItems?.first(where: { $0.name == "action" })?.value {
            
            switch action {
            case "newchat":
                pendingDeepLinkAction = .openNewChat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    BackgroundManager.shared.forceCheck()
                }
            default:
                // Just force check for unknown actions
                BackgroundManager.shared.forceCheck()
            }
        } else {
            // Default: just force check
            BackgroundManager.shared.forceCheck()
        }
    }
    
    // MARK: - Siri Shortcuts Update
    
    /// Force Siri to re-index app shortcuts (helps with "Hey Siri" recognition)
    private func updateSiriShortcuts() {
        if #available(iOS 16.0, *) {
            Task {
                do {
                    try await PanduShortcuts.updateAppShortcutParameters()
                    print("✅ Siri shortcuts updated")
                } catch {
                    print("⚠️ Failed to update Siri shortcuts: \(error)")
                }
            }
        }
    }
    
    // MARK: - Widget Refresh Polling
    
    /// Checks if the server has new state that requires widget refresh
    private func checkWidgetRefresh() async {
        let lastCheck = UserDefaults.standard.double(forKey: "lastWidgetCheck")
        
        guard let url = URL(string: "\(AppConfig.serverURL)/widget/check?since=\(lastCheck)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 5
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return }
            
            struct WidgetCheckResponse: Decodable {
                let needs_refresh: Bool
                let last_change: Double
            }
            
            let checkResponse = try JSONDecoder().decode(WidgetCheckResponse.self, from: data)
            
            if checkResponse.needs_refresh {
                print("📱 Widget refresh needed, reloading timelines...")
                WidgetCenter.shared.reloadAllTimelines()
                UserDefaults.standard.set(checkResponse.last_change, forKey: "lastWidgetCheck")
            }
        } catch {
            print("Widget check failed: \(error)")
        }
    }
}

// MARK: - Recents Call Wrapper

/// Wrapper for handling calls initiated from Phone app Recents
/// Automatically presents AvatarView (video) or starts voice mode
struct RecentsCallWrapper: View {
    let isVideo: Bool
    
    @StateObject private var tts = TTSManager()
    @StateObject private var stt = LiveSTT(localeId: "en-IN")
    @State private var voiceMode = true
    
    var body: some View {
        AvatarView(tts: tts, stt: stt, voiceMode: $voiceMode)
            .onAppear {
                print("📞 Starting call from Phone Recents (video: \(isVideo))")
                Task {
                    try? await stt.requestPermissions()
                    try? stt.start()
                }
            }
    }
}
