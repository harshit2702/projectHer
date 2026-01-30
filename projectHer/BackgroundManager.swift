//
// BackgroundManager.swift
// projectHer
//

import Foundation
import BackgroundTasks
import UserNotifications
import SwiftData

class BackgroundManager {
    static let shared = BackgroundManager()
    
    let taskId = "com.projecther.refresh"
    let serverURL = AppConfig.serverURL
    let apiKey = AppConfig.apiKey
    
    var modelContainer: ModelContainer?
    
    func configure(container: ModelContainer) {
        self.modelContainer = container
    }
    
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
    }
    
    func forceCheck() {
        print("👊 Forcing manual check...")
        checkServerForMessages { success in
            print("👊 Manual check finished. Success: \(success)")
        }
    }
    
    func scheduleNextFetch() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🕒 Background Task Scheduled")
        } catch {
            print("❌ Failed to schedule: \(error)")
        }
    }
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        checkServerForMessages { success in
            task.setTaskCompleted(success: success)
            self.scheduleNextFetch()
        }
    }
    
    private func checkServerForMessages(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverURL)/sync_messages") else {
            logSyncError("Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 20
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.logSyncError("Network error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    self.logSyncError("HTTP \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
            }
            
            guard let data = data else {
                self.logSyncError("Invalid response format")
                completion(false)
                return
            }
            
            // Decode on background thread, then process
            Task.detached(priority: .background) {
                guard let syncResponse = try? JSONDecoder().decode(SyncResponse.self, from: data) else {
                    self.logSyncError("Invalid response format")
                    completion(false)
                    return
                }
                
                if !syncResponse.messages.isEmpty {
                    await self.saveMessagesToDatabase(syncResponse.messages)
                    await MainActor.run {
                        self.logSyncSuccess()
                    }
                    completion(true)
                } else {
                    completion(true)
                }
            }
        }.resume()
    }
    
    // ✅ NEW: Proper async background save with relationships
    private func saveMessagesToDatabase(_ messages: [String]) async {
        guard let container = self.modelContainer else {
            logSyncError("No model container")
            return
        }
        
        // Create background context
        let context = ModelContext(container)
        
        do {
            // Fetch or create active session
            let fetchDescriptor = FetchDescriptor<ChatSession>(
                predicate: #Predicate { $0.isActive == true }
            )
            
            let activeSession: ChatSession
            if let existingSession = try context.fetch(fetchDescriptor).first {
                activeSession = existingSession
            } else {
                let newSession = ChatSession()
                context.insert(newSession)
                activeSession = newSession
            }
            
            // ✅ Create messages with relationship
            for msgText in messages {
                let newMessage = ChatMessage(text: msgText, isUser: false, session: activeSession)
                newMessage.status = .sent
                context.insert(newMessage)
                
                // Add to session's messages array
                activeSession.messages.append(newMessage)
                
                // Trigger notification on main thread
                await MainActor.run {
                    self.triggerNotification(text: msgText)
                }
            }
            
            activeSession.lastMessageAt = Date()
            try context.save()
            
            print("✅ Saved \(messages.count) messages to database")
        } catch {
            logSyncError("Database save failed: \(error.localizedDescription)")
        }
    }
    
    private func logSyncError(_ error: String) {
        UserDefaults.standard.set(error, forKey: "lastSyncError")
        UserDefaults.standard.set(Date(), forKey: "lastSyncErrorTime")
        print("🔴 Sync failed: \(error)")
    }
    
    private func logSyncSuccess() {
        UserDefaults.standard.removeObject(forKey: "lastSyncError")
        UserDefaults.standard.set(Date(), forKey: "lastSuccessfulSync")
        print("🟢 Sync successful")
    }
    
    private func triggerNotification(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Pandu ❤️"
        content.body = text
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
