//
//  MemoryItem.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct MemoryItem: Identifiable, Equatable, Codable {
    enum MemoryType: String, CaseIterable, Equatable, Codable {
        case explicit
        case behavioral
        case inferred
        case correction
        case project
        case preference
        case language

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum MemoryScope: String, CaseIterable, Equatable, Codable {
        case global
        case project
        case behavioral
        case language
        case correction

        var displayName: String {
            rawValue.capitalized
        }
    }

    enum Confidence: String, CaseIterable, Equatable, Comparable, Codable {
        case low
        case medium
        case high

        var displayName: String {
            rawValue.capitalized
        }

        private var rank: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            }
        }

        static func < (lhs: MemoryItem.Confidence, rhs: MemoryItem.Confidence) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    enum Source: String, CaseIterable, Equatable, Codable {
        case userStated = "user_stated"
        case repeatedBehavior = "repeated_behavior"
        case inferredPattern = "inferred_pattern"
        case correction
        case projectContext = "project_context"
        case assistantAction = "assistant_action"

        var displayName: String {
            switch self {
            case .userStated: return "User Stated"
            case .repeatedBehavior: return "Repeated Behavior"
            case .inferredPattern: return "Inferred Pattern"
            case .correction: return "Correction"
            case .projectContext: return "Project Context"
            case .assistantAction: return "Assistant Action"
            }
        }
    }

    let id: UUID
    var type: MemoryType
    var category: String
    var content: String
    var source: Source
    var confidence: Confidence
    var createdAt: Date
    var updatedAt: Date
    var projectId: UUID?
    var tags: [String]
    var usageCount: Int
    var lastReferencedAt: Date?

    var scope: MemoryScope {
        switch type {
        case .behavioral:
            return .behavioral
        case .correction:
            return .correction
        case .language:
            return .language
        case .project:
            return .project
        case .explicit, .inferred, .preference:
            return projectId == nil ? .global : .project
        }
    }

    init(
        id: UUID = UUID(),
        type: MemoryType,
        category: String,
        content: String,
        source: Source,
        confidence: Confidence = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectId: UUID? = nil,
        tags: [String] = [],
        usageCount: Int = 0,
        lastReferencedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.content = content
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectId = projectId
        self.tags = tags
        self.usageCount = usageCount
        self.lastReferencedAt = lastReferencedAt
    }
}

struct MemoryRetrievalContext: Equatable, Codable {
    var userMessage: String
    var projectId: UUID?
    var intent: AssistantIntent.Kind?
    var tags: [String]

    init(
        userMessage: String,
        projectId: UUID? = nil,
        intent: AssistantIntent.Kind? = nil,
        tags: [String] = []
    ) {
        self.userMessage = userMessage
        self.projectId = projectId
        self.intent = intent
        self.tags = tags
    }
}
