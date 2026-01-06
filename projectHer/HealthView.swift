import SwiftUI
import SwiftData

struct HealthView: View {
    @State private var serverStatus: String = "Checking..."
    @State private var healthData: HealthData?
    @State private var lastSync: Date?
    @State private var lastSyncError: String?

    @Query private var allSessions: [ChatSession]
    @Query private var allMessages: [ChatMessage]

    // ⚠️ Configuration moved to AppConfig.swift
    let serverURL = AppConfig.serverURL
    
    var body: some View {
        NavigationView {
            List {
                // Server Status
                Section("Server Status") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(serverStatus)
                            .foregroundColor(serverStatus == "Online" ? .green : .red)
                    }
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(serverURL)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    if let sync = lastSync {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(sync.relativeTimeString())
                                .font(.caption)
                        }
                    }
                    if let error = lastSyncError {
                        VStack(alignment: .leading) {
                            Text("Last Sync Error")
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    Button("Test Connection") {
                        checkServerHealth()
                    }
                }
                
                // Memory Intelligence
                if let data = healthData, let stats = data.stats {
                    Section("Memory Intelligence") {
                        StatRow(label: "Total Memories", value: "\(stats.total_memories)")
                        StatRow(label: "Active", value: "\(stats.by_status.active)")
                        if let pending = data.pending_followups {
                            StatRow(label: "Pending Follow-ups", value: "\(pending)")
                        }
                        StatRow(label: "Avg Relevance", value: String(format: "%.2f", stats.avg_relevance_score))
                    }
                }
                
                // Memory Stats (Simple)
                if let data = healthData {
                    Section("Server Queue") {
                        HStack {
                            Text("Queue Size")
                            Spacer()
                            Text("\(data.queue_size)")
                        }
                    }
                }
                
                // App Info
                Section("App Info (on Device)") {
                    HStack {
                        Text("Total Sessions")
                        Spacer()
                        Text("\(allSessions.count)")
                    }
                    HStack {
                        Text("Total Messages")
                        Spacer()
                        Text("\(allMessages.count)")
                    }
                }
                
                // Actions
                Section("Actions") {
                    Button("Force Background Sync") {
                        BackgroundManager.shared.forceCheck()
                    }
                }
            }
            .navigationTitle("Health & Info")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        checkServerHealth()
                        loadSyncStatus()
                    }
                }
            }
        }
        .onAppear {
            checkServerHealth()
            loadSyncStatus()
        }
    }
    
    func checkServerHealth() {
        serverStatus = "Checking..."
        
        guard let url = URL(string: "\(serverURL)/health") else {
            serverStatus = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    serverStatus = "Offline"
                    print("Health check failed: \(error)")
                    return
                }
                
                if let data = data,
                   let health = try? JSONDecoder().decode(HealthData.self, from: data) {
                    serverStatus = "Online"
                    healthData = health
                    print("✅ Server healthy: \(health.memory_count) memories")
                } else {
                    serverStatus = "Error"
                }
            }
        }.resume()
    }
    
    func loadSyncStatus() {
        lastSync = UserDefaults.standard.object(forKey: "lastSuccessfulSync") as? Date
        lastSyncError = UserDefaults.standard.string(forKey: "lastSyncError")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct HealthData: Codable {
    let status: String
    let memory_count: Int
    let queue_size: Int
    let stats: MemoryStats?
    let pending_followups: Int?
}
