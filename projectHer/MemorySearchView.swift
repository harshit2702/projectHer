import SwiftUI

struct MemorySearchView: View {
    @State private var searchQuery = ""
    @State private var results: [MemorySearchResult] = []
    @State private var isSearching = false
    
    var selectionMode: Bool = false
    var onSelect: ((MemorySearchResult) -> Void)? = nil
    
    var body: some View {
        NavigationView {
            Group {
                if isSearching {
                    ProgressView("Searching...")
                } else if results.isEmpty && !searchQuery.isEmpty {
                    VStack {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                        Text("No memories found")
                            .foregroundColor(.gray)
                    }
                } else if results.isEmpty {
                    VStack {
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundColor(.purple.opacity(0.5))
                            .padding(.bottom, 8)
                        Text("Search for specific memories, topics, or preferences.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }
                } else {
                    List(results) { result in
                        Button(action: {
                            if selectionMode {
                                onSelect?(result)
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.text)
                                    .font(.body)
                                HStack {
                                    Text(result.type.capitalized)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple)
                                        .cornerRadius(8)
                                    Spacer()
                                    Text("Relevance: \(String(format: "%.0f%%", result.relevance * 100))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(selectionMode ? "Select to Link 🔗" : "Memory Search 🔍")
        }
        .searchable(text: $searchQuery, prompt: selectionMode ? "Find memory to link..." : "Search her memories...")
        .onSubmit(of: .search) {
            performSearch()
        }
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                results = []
            }
        }
    }
    
    func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(AppConfig.serverURL)/memory/search?q=\(encodedQuery)&limit=20") else {
            isSearching = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                isSearching = false
                if let data = data,
                   let response = try? JSONDecoder().decode(MemorySearchResponse.self, from: data) {
                    results = response.results
                }
            }
        }.resume()
    }
}


