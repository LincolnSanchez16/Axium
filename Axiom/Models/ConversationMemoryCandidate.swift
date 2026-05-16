//
//  ConversationMemoryCandidate.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct ConversationMemoryCandidate: Identifiable, Equatable, Codable {
    enum Category: String, CaseIterable, Equatable, Codable {
        case preferredName
        case preferredTone
        case workflowPreference
        case assistantBehaviorPreference
        case responsePreference
        case dislikedBehavior
        case preferredUIStyle
        case preferredProjectBehavior
        case slangMapping
        case commonPhrase
        case projectReference
        case activeFocusArea
        case interactionPattern
    }

    let id: UUID
    var sourceMessage: String
    var extractedMeaning: String
    var confidence: Double
    var category: Category
    var createdAt: Date
    var approved: Bool
    var rejected: Bool

    init(
        id: UUID = UUID(),
        sourceMessage: String,
        extractedMeaning: String,
        confidence: Double,
        category: Category,
        createdAt: Date = Date(),
        approved: Bool = false,
        rejected: Bool = false
    ) {
        self.id = id
        self.sourceMessage = sourceMessage
        self.extractedMeaning = extractedMeaning
        self.confidence = confidence
        self.category = category
        self.createdAt = createdAt
        self.approved = approved
        self.rejected = rejected
    }
}
