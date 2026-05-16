//
//  ConversationPattern.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct ConversationPattern: Identifiable, Equatable, Codable {
    enum Category: String, CaseIterable, Equatable, Codable {
        case repeatedPhrase
        case correction
        case slang
        case workflow
        case projectBehavior
        case focusArea
    }

    let id: UUID
    var phrase: String
    var meaning: String?
    var category: Category
    var occurrences: Int
    var firstSeenAt: Date
    var lastSeenAt: Date
    var approved: Bool
    var rejected: Bool

    init(
        id: UUID = UUID(),
        phrase: String,
        meaning: String? = nil,
        category: Category,
        occurrences: Int = 1,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date(),
        approved: Bool = false,
        rejected: Bool = false
    ) {
        self.id = id
        self.phrase = phrase
        self.meaning = meaning
        self.category = category
        self.occurrences = occurrences
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.approved = approved
        self.rejected = rejected
    }
}
