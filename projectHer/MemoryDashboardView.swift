import SwiftUI

struct MemoryDashboardView: View {
    @State private var memories: [MemoryItem] = []
    @State private var stats: MemoryStats?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading memories...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                        Button("Retry") {
                            loadMemories()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    // Stats Card
                    if let stats = stats {
                        VStack(spacing: 8) {
                            Text("\(stats.total_memories) Total Memories")
                                .font(.title2).bold()
                            HStack {
                                StatBadge(label: "Active", value: stats.by_status.active, color: .green)
                                StatBadge(label: "Archived", value: stats.by_status.archived, color: .gray)
                                StatBadge(label: "Resolved", value: stats.by_status.resolved, color: .blue)
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    // Memory List
                    if memories.isEmpty {
                        Text("No memories found.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(memories) { memory in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memory.text)
                                    .font(.body)
                                HStack {
                                    Text(memory.type.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(typeColor(memory.type).opacity(0.2))
                                        .cornerRadius(8)
                                    Spacer()
                                    Text("Score: \(String(format: "%.2f", memory.relevance))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Her Memories 💭")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                     NavigationLink(destination: MemorySearchView()) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear { loadMemories() }
        }
    }
    
    func loadMemories() {
        self.isLoading = true
        self.errorMessage = nil
        
        guard let url = URL(string: "\(AppConfig.serverURL)/memories/dashboard?limit=50") else {
            self.isLoading = false
            self.errorMessage = "Invalid URL configuration"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Failed to load: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(MemoryDashboardResponse.self, from: data)
                    self.memories = response.items
                } catch {
                    print("Decoding error: \(error)")
                    self.errorMessage = "Failed to process data"
                }
            }
        }.resume()
        
        // Load stats separately
        loadStats()
    }
    
    func loadStats() {
        guard let url = URL(string: "\(AppConfig.serverURL)/stats") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let statsData = try? JSONDecoder().decode(MemoryStats.self, from: data) {
                DispatchQueue.main.async {
                    self.stats = statsData
                }
            }
        }.resume()
    }
    
    func typeColor(_ type: String) -> Color {
        switch type {
        case "preference": return .orange
        case "identity": return .blue
        case "emotion": return .pink
        case "future_plan": return .purple
        case "important": return .red
        default: return .gray
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(value)")
                .font(.title3).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Models
// Models are now in MemoryModels.swift
