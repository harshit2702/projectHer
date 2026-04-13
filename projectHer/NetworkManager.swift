// NetworkManager.swift

import Foundation

struct OutfitSyncResponse: Decodable {
    let status: String
    let reason: String?
}

struct MemoryRelevanceResponse: Decodable {
    let relevant_ids: [String]
}

class NetworkManager {
    static let shared = NetworkManager()
    
    // Update with your actual server URL
    private let baseURL = AppConfig.serverURL
    private let apiKey = AppConfig.apiKey
    
    private init() {}
    
    // MARK: - Outfit Sync
    func syncOutfit(modelId: String, description: String, style: String, reason: String) async throws -> OutfitSyncResponse {
        let endpoint = "\(baseURL)/state/outfit"
        let payload: [String: Any] = [
            "model_id": modelId,
            "outfit_description": description,
            "style": style,
            "change_reason": reason,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        return try await sendPostRequest(to: endpoint, body: payload, responseType: OutfitSyncResponse.self)
    }
    
    // MARK: - Call Sync
    func updateCallState(event: String, type: String, duration: TimeInterval = 0) async throws {
        let endpoint = "\(baseURL)/state/call"
        let payload: [String: Any] = [
            "event": event,
            "type": type,
            "duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        _ = try await sendPostRequest(to: endpoint, body: payload, responseType: [String: String].self)
    }
    
    // MARK: - Memory Relevance
    /// Returns the subset of memory IDs the backend considers still relevant.
    /// Memories whose IDs are absent from the response should be hidden.
    func filterMemoriesByRelevance(ids: [String]) async throws -> MemoryRelevanceResponse {
        let endpoint = "\(baseURL)/memories/relevance"
        let payload: [String: Any] = ["ids": ids]
        return try await sendPostRequest(to: endpoint, body: payload, responseType: MemoryRelevanceResponse.self)
    }
    
    // MARK: - Helpers
    private func sendPostRequest<T: Decodable>(to urlString: String, body: [String: Any], responseType: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             if let errorResponse = try? JSONDecoder().decode(T.self, from: data) {
                return errorResponse
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func sendGetRequest<T: Decodable>(to urlString: String, responseType: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}
