//
//  ChatMessage.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

enum ChatMessageRole: String, Equatable, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: ChatMessageRole
    let content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: ChatMessageRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct ConversationSession: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "Current Session", messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }
}
