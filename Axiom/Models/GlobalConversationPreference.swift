//
//  GlobalConversationPreference.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct GlobalConversationPreference: Identifiable, Equatable, Codable {
    enum Category: String, CaseIterable, Equatable, Codable {
        case tone
        case workflow
        case responseStyle
        case assistantBehavior
        case uiStyle
        case projectBehavior
        case dislikedBehavior
    }

    let id: UUID
    var category: Category
    var value: String
    var sourceMessage: String
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date
    var enabled: Bool

    init(
        id: UUID = UUID(),
        category: Category,
        value: String,
        sourceMessage: String,
        confidence: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        enabled: Bool = true
    ) {
        self.id = id
        self.category = category
        self.value = value
        self.sourceMessage = sourceMessage
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.enabled = enabled
    }
}
