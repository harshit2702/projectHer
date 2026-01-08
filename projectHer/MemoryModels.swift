import Foundation

// MARK: - Shared Models

struct Pagination: Codable, Sendable {
    let page: Int
    let total: Int
    let has_more: Bool
}

struct StatusBreakdown: Codable, Sendable {
    let total: Int
    let active: Int
    let archived: Int
    let resolved: Int
}

// MARK: - Dashboard Models

struct MemoryItem: Codable, Identifiable, Sendable {
    let id: String
    let text: String
    let type: String
    let status: String
    let relevance: Double
    let timestamp: Double?
    let access_count: Int
}

struct MemoryDashboardResponse: Codable, Sendable {
    let items: [MemoryItem]
    let pagination: Pagination
    let stats: StatusBreakdown
}

struct MemoryStats: Codable, Sendable {
    let total_memories: Int
    let by_type: [String: Int]
    let by_status: StatusBreakdown
    let avg_relevance_score: Double
    let top_accessed_memories: [TopMemory]
}

struct TopMemory: Codable, Sendable {
    let text: String
    let access_count: Int
    let type: String
}

// MARK: - Search Models

struct MemorySearchResult: Codable, Identifiable, Sendable {
    let id: String
    let text: String
    let relevance: Double
    let type: String
    let status: String
}

struct MemorySearchResponse: Codable, Sendable {
    let results: [MemorySearchResult]
    let count: Int
    let query: String
}

// MARK: - Linking Models

struct MemoryLinkRequest: Codable, Sendable {
    let source_id: String
    let target_id: String
}
