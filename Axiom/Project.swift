//
//  Project.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct Project: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var description: String
    var category: String
    var status: ProjectStatus
    var priority: ProjectPriority
    let createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date?
    var localFolderPath: String?
    var summary: String
    var currentObjective: String
    var keyContext: String
    var notes: [ProjectNote]
    var tasks: [ProjectTask]
    var files: [ProjectFile]
    var metrics: [ProjectMetric]
    var integrations: [ProjectIntegration]
    var activityEvents: [ActivityEvent]
    var conversations: [ProjectConversation]
    var aliases: [String]
    var tags: [String]
    var linkedResources: [LinkedResource]
    var projectHealth: ProjectHealth
    var assistantMemory: [AssistantMemoryItem]
    var memoryItems: [MemoryItem]
    var openQuestions: [String]
    var decisions: [ProjectDecision]
    var blockers: [ProjectBlocker]
    var nextActions: [String]

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        category: String = "",
        status: ProjectStatus = .planning,
        priority: ProjectPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        localFolderPath: String? = nil,
        summary: String = "",
        currentObjective: String = "",
        keyContext: String = "",
        notes: [ProjectNote] = [],
        tasks: [ProjectTask] = [],
        files: [ProjectFile] = [],
        metrics: [ProjectMetric] = [],
        integrations: [ProjectIntegration] = [],
        activityEvents: [ActivityEvent] = [],
        conversations: [ProjectConversation] = [],
        aliases: [String] = [],
        tags: [String] = [],
        linkedResources: [LinkedResource] = [],
        projectHealth: ProjectHealth = .unknown,
        assistantMemory: [AssistantMemoryItem] = [],
        memoryItems: [MemoryItem] = [],
        openQuestions: [String] = [],
        decisions: [ProjectDecision] = [],
        blockers: [ProjectBlocker] = [],
        nextActions: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.localFolderPath = localFolderPath
        self.summary = summary
        self.currentObjective = currentObjective
        self.keyContext = keyContext
        self.notes = notes
        self.tasks = tasks
        self.files = files
        self.metrics = metrics
        self.integrations = integrations
        self.activityEvents = activityEvents
        self.conversations = conversations
        self.aliases = aliases
        self.tags = tags
        self.linkedResources = linkedResources
        self.projectHealth = projectHealth
        self.assistantMemory = assistantMemory
        self.memoryItems = memoryItems
        self.openQuestions = openQuestions
        self.decisions = decisions
        self.blockers = blockers
        self.nextActions = nextActions
    }

    static func createdWorkspace(name: String, folderURL: URL, actions: [FileAction]) -> Project {
        let now = Date()
        let id = UUID()
        let events = actions.map { action in
            ActivityEvent(
                projectId: id,
                title: action.title,
                details: action.url.path,
                type: action.kind == .folder ? .projectCreated : .fileCreated,
                timestamp: now
            )
        }

        let files = actions
            .filter { $0.kind == .file }
            .map { action in
                ProjectFile(
                    name: action.url.lastPathComponent,
                    path: action.url.path,
                    type: .document,
                    createdAt: now,
                    updatedAt: now,
                    source: "Axium local workspace",
                    description: "Created with the local workspace starter."
                )
            }

        return Project(
            id: id,
            name: name,
            description: "Local project workspace created by Axium.",
            status: .active,
            priority: .medium,
            createdAt: now,
            updatedAt: now,
            lastOpenedAt: now,
            localFolderPath: folderURL.path,
            summary: "Local workspace created by Axium.",
            files: files,
            activityEvents: events,
            aliases: [name.lowercased()],
            projectHealth: .needsContext
        )
    }
}

enum ProjectStatus: String, CaseIterable, Equatable, Codable {
    case planning
    case active
    case paused
    case completed
    case archived

    var displayName: String {
        rawValue.capitalized
    }
}

enum ProjectPriority: String, CaseIterable, Equatable, Comparable, Codable {
    case low
    case medium
    case high
    case urgent

    var displayName: String {
        rawValue.capitalized
    }

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }

    static func < (lhs: ProjectPriority, rhs: ProjectPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum ProjectHealth: String, CaseIterable, Equatable, Codable {
    case healthy
    case needsContext
    case needsNextAction
    case blocked
    case stale
    case unknown

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .needsContext: return "Needs Context"
        case .needsNextAction: return "Needs Next Action"
        case .blocked: return "Blocked"
        case .stale: return "Stale"
        case .unknown: return "Unknown"
        }
    }
}

struct ProjectNote: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var source: String
    var pinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        source: String = "Manual",
        pinned: Bool = false
    ) {
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

struct ProjectFile: Identifiable, Equatable, Codable {
    enum FileType: String, CaseIterable, Equatable, Codable {
        case document
        case pdf
        case mindMap
        case code
        case image
        case audio
        case video
        case folder
        case other

        var displayName: String {
            switch self {
            case .mindMap: return "Mind Map"
            default: return rawValue.capitalized
            }
        }
    }

    let id: UUID
    var name: String
    var path: String
    var type: FileType
    var createdAt: Date
    var updatedAt: Date
    var source: String
    var description: String?

    init(
        id: UUID = UUID(),
        name: String,
        path: String = "",
        type: FileType = .other,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: String = "Manual",
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
        self.description = description
    }
}

struct ProjectIntegration: Identifiable, Equatable, Codable {
    enum Provider: String, CaseIterable, Equatable, Codable {
        case stripe
        case github
        case gmail
        case calendar
        case figma
        case notion
        case googleDrive
        case localFiles
        case customAPI

        var displayName: String {
            switch self {
            case .googleDrive: return "Google Drive"
            case .customAPI: return "Custom API"
            case .localFiles: return "Local Files"
            default: return rawValue.capitalized
            }
        }
    }

    enum Status: String, CaseIterable, Equatable, Codable {
        case notConnected
        case connected
        case needsAttention

        var displayName: String {
            switch self {
            case .notConnected: return "Not Connected"
            case .connected: return "Connected"
            case .needsAttention: return "Needs Attention"
            }
        }
    }

    let id: UUID
    var name: String
    var provider: Provider
    var status: Status
    var connectedAt: Date?
    var lastSyncedAt: Date?
    var capabilities: [String]
    var projectId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        provider: Provider,
        status: Status = .notConnected,
        connectedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        capabilities: [String] = [],
        projectId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.status = status
        self.connectedAt = connectedAt
        self.lastSyncedAt = lastSyncedAt
        self.capabilities = capabilities
        self.projectId = projectId
    }
}

struct ProjectConversation: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var messages: [ConversationMessage]
    var createdAt: Date
    var updatedAt: Date
    var projectId: UUID

    init(
        id: UUID = UUID(),
        title: String,
        messages: [ConversationMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectId: UUID
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectId = projectId
    }
}

struct AssistantMemoryItem: Identifiable, Equatable, Codable {
    let id: UUID
    var content: String
    var source: String
    var confidence: Double
    var createdAt: Date
    var updatedAt: Date
    var projectId: UUID?

    init(
        id: UUID = UUID(),
        content: String,
        source: String = "Assistant",
        confidence: Double = 0.5,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectId: UUID? = nil
    ) {
        self.id = id
        self.content = content
        self.source = source
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectId = projectId
    }
}

struct ProjectDecision: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var details: String
    var createdAt: Date
    var reason: String?

    init(id: UUID = UUID(), title: String, details: String = "", createdAt: Date = Date(), reason: String? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.reason = reason
    }
}

struct ProjectBlocker: Identifiable, Equatable, Codable {
    enum Severity: String, CaseIterable, Equatable, Comparable, Codable {
        case low
        case medium
        case high
        case critical

        var displayName: String {
            rawValue.capitalized
        }

        private var rank: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            case .critical: return 3
            }
        }

        static func < (lhs: ProjectBlocker.Severity, rhs: ProjectBlocker.Severity) -> Bool {
            lhs.rank < rhs.rank
        }
    }

    let id: UUID
    var title: String
    var details: String
    var severity: Severity
    var createdAt: Date
    var resolvedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        severity: Severity = .medium,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.severity = severity
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
}

struct LinkedResource: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var urlString: String
    var source: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, urlString: String, source: String = "Manual", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.source = source
        self.createdAt = createdAt
    }
}
