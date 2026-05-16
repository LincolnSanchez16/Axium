//
//  GlobalContextModels.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct GlobalNote: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var source: String
    var pinned: Bool

    init(id: UUID = UUID(), title: String, body: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), tags: [String] = [], source: String = "Manual", pinned: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.source = source
        self.pinned = pinned
    }
}

struct GlobalTask: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var details: String
    var status: ProjectTask.Status
    var priority: ProjectPriority
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, details: String = "", status: ProjectTask.Status = .todo, priority: ProjectPriority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), completedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

struct GlobalReminder: Identifiable, Equatable, Codable {
    enum Status: String, CaseIterable, Equatable, Codable {
        case pending
        case completed
        case dismissed
    }

    let id: UUID
    var title: String
    var details: String
    var remindAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var status: Status
    var source: String

    init(id: UUID = UUID(), title: String, details: String = "", remindAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), status: Status = .pending, source: String = "Manual") {
        self.id = id
        self.title = title
        self.details = details
        self.remindAt = remindAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.source = source
    }
}

struct GlobalCalendarItem: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var details: String
    var startDate: Date
    var endDate: Date?
    var location: String?
    var source: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, details: String = "", startDate: Date, endDate: Date? = nil, location: String? = nil, source: String = "Manual", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.details = details
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct GlobalConversationSession: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var messages: [ConversationMessage]
    var summary: String?
    var createdAt: Date
    var updatedAt: Date
    var savedToProjectId: UUID?
    var extractedItems: [String]

    init(id: UUID = UUID(), title: String, messages: [ConversationMessage] = [], summary: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), savedToProjectId: UUID? = nil, extractedItems: [String] = []) {
        self.id = id
        self.title = title
        self.messages = messages
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.savedToProjectId = savedToProjectId
        self.extractedItems = extractedItems
    }
}

struct UnsavedWorkingContext: Identifiable, Equatable, Codable {
    let id: UUID
    var currentTopic: String?
    var recentMessages: [ConversationMessage]
    var extractedIdeas: [String]
    var extractedProducts: [String]
    var extractedTasks: [String]
    var extractedQuestions: [String]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), currentTopic: String? = nil, recentMessages: [ConversationMessage] = [], extractedIdeas: [String] = [], extractedProducts: [String] = [], extractedTasks: [String] = [], extractedQuestions: [String] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.currentTopic = currentTopic
        self.recentMessages = recentMessages
        self.extractedIdeas = extractedIdeas
        self.extractedProducts = extractedProducts
        self.extractedTasks = extractedTasks
        self.extractedQuestions = extractedQuestions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct GlobalContextSnapshot: Equatable, Codable {
    var notes: [GlobalNote] = []
    var tasks: [GlobalTask] = []
    var reminders: [GlobalReminder] = []
    var calendarItems: [GlobalCalendarItem] = []
    var conversationSessions: [GlobalConversationSession] = []
    var workingContext: UnsavedWorkingContext = UnsavedWorkingContext()
    var globalMemory: [MemoryItem] = []
}

enum ContextDestination: Equatable {
    case globalNote
    case globalTask
    case globalReminder
    case globalCalendarItem
    case globalMemory
    case unsavedConversation
    case currentProject
    case existingProject(UUID)
    case newProject
    case unknown
}
