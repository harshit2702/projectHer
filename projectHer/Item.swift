//
// Item.swift
// projectHer
//
// Created by Harshit Agarwal on 10/12/25.
//

import Foundation
import SwiftData

// MARK: - SwiftData Models

enum MessageStatus: String, Codable {
    case sending, sent, failed
}

@Model
final class ChatSession: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    var isActive: Bool
    var contextChainId: String
    
    // ✅ NEW: Relationship with Cascade Delete
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []
    
    init(title: String? = nil) {
        self.id = UUID()
        self.title = title ?? "Chat - \(Date().formatted(date: .abbreviated, time: .shortened))"
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.isActive = true
        self.contextChainId = UUID().uuidString
    }
}

@Model
final class ChatMessage: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var isUser: Bool
    var timestamp: Date
    var sentAt: Date
    var status: MessageStatus
    var usedContext: Bool = false
    var serverId: String? // 🆕 For linking to server memories
    var type: String?     // 🆕 e.g., "future_plan"
    var clientMessageId: String?
    
    // ✅ NEW: Link to parent session (replaces manual sessionId matching)
    var session: ChatSession?
    
    init(text: String, isUser: Bool, session: ChatSession, usedContext: Bool = false, serverId: String? = nil, type: String? = nil, clientMessageId: String? = nil) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.sentAt = Date()
        self.status = .sending
        self.session = session
        self.usedContext = usedContext
        self.serverId = serverId
        self.type = type
        self.clientMessageId = clientMessageId
    }
}

// MARK: - Network Models (JSON for API)

struct ChatRequest: Codable {
    let message: String
    let history: [HistoryItem]
    let context_chain_id: String?
    let client_message_id: String?
    let mood: String?
    let tone_instruction: String?
}

struct HistoryItem: Codable {
    let role: String
    let content: String
}

struct ServerResponse: Codable {
    let reply: String
    let context_used: Bool
    let status: String?
    let memory_id: String?
    let type: String?
    let outfit_changed: Bool?          // 🆕 True if outfit was changed via chat
    let outfit_changed_to: String?     // 🆕 The outfit ID to sync in iOS
    let client_message_id: String?
    let retry_after_seconds: Int?
    let ack_required: Bool?
    let memory_items_used: Int?
}

struct SyncResponse: Codable {
    let messages: [String]
    let count: Int
}