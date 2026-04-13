import SwiftUI

struct MemoryDashboardView: View {
    @State private var memories: [MemoryItem] = []
    @State private var stats: MemoryStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private enum RelevanceState { case checking, loaded(Set<String>), failed }
    @State private var relevanceState: RelevanceState = .checking

    /// Memories filtered by backend relevance check (show all while checking or on failure)
    private var displayedMemories: [MemoryItem] {
        if case .loaded(let ids) = relevanceState {
            return memories.filter { ids.contains($0.id) }
        }
        return memories
    }

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
                    if displayedMemories.isEmpty {
                        VStack(spacing: 8) {
                            if case .checking = relevanceState, !memories.isEmpty {
                                ProgressView("Checking relevance...")
                                    .padding(.top)
                            } else {
                                Text("No relevant memories found.")
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                    } else {
                        List(displayedMemories) { memory in
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
        self.relevanceState = .checking
        
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
                    // Check relevance for all loaded memories
                    self.checkRelevance(for: response.items)
                } catch {
                    print("Decoding error: \(error)")
                    self.errorMessage = "Failed to process data"
                }
            }
        }.resume()
        
        // Load stats separately
        loadStats()
    }

    /// Asks the backend which memories are still relevant; filters the displayed list.
    func checkRelevance(for items: [MemoryItem]) {
        let ids = items.map { $0.id }
        guard !ids.isEmpty else {
            self.relevanceState = .loaded([])
            return
        }

        Task {
            do {
                let response = try await NetworkManager.shared.filterMemoriesByRelevance(ids: ids)
                await MainActor.run {
                    self.relevanceState = .loaded(Set(response.relevant_ids))
                }
            } catch {
                print("⚠️ Relevance check failed: \(error.localizedDescription)")
                // On failure, show all memories so nothing is hidden unexpectedly
                await MainActor.run {
                    self.relevanceState = .failed
                }
            }
        }
    }
    
    func loadStats() {
        guard let url = URL(string: "\(AppConfig.serverURL)/stats") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            DispatchQueue.main.async {
                if let statsData = try? JSONDecoder().decode(MemoryStats.self, from: data) {
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
