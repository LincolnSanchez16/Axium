//
//  ConversationMessage.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

enum ConversationSpeaker: String, Equatable, Codable {
    case assistant
    case user
    case system
}

struct ConversationMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let speaker: ConversationSpeaker
    let text: String
    let timestamp: Date
    let suggestions: [SuggestedReply]

    init(
        id: UUID = UUID(),
        speaker: ConversationSpeaker,
        text: String,
        timestamp: Date = Date(),
        suggestions: [SuggestedReply] = []
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
        self.suggestions = suggestions
    }
}

struct SuggestedReply: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let payload: String

    init(_ title: String, payload: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.payload = payload ?? title
    }
}

struct ConversationFlowSnapshot: Equatable, Codable {
    let title: String
    let currentStep: Int
    let totalSteps: Int
    let prompt: String
    let collectedData: [String: String]
    let isComplete: Bool

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
}
