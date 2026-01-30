//
//  projectHerApp.swift
//  projectHer
//
//  Created by Harshit Agarwal on 10/12/25.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct ProjectHerApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    // 1. Create the Database Container
    let sharedModelContainer: ModelContainer
    
    init() {
        do {
            sharedModelContainer = try ModelContainer(for: ChatMessage.self, ChatSession.self)
            
            // 2. Configure Background Manager with the DB
            BackgroundManager.shared.configure(container: sharedModelContainer)
            BackgroundManager.shared.register()
            
            // 3. Save API config to App Group for widgets
            WidgetAPIService.saveConfigToAppGroup()
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
                    print("App opened via notification: \(url)")
                    // Trigger manual sync when opened via notification/URL
                    BackgroundManager.shared.forceCheck()
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
