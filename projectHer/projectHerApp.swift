//
//  projectHerApp.swift
//  projectHer
//
//  Created by Harshit Agarwal on 10/12/25.
//

import SwiftUI
import SwiftData

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
            
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
            if newPhase == .background {
                BackgroundManager.shared.scheduleNextFetch()
            }
        }
    }
}
