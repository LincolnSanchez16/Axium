//
//  ActivityEvent.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct ActivityEvent: Identifiable, Equatable, Codable {
    enum EventType: String, CaseIterable, Equatable, Codable {
        case projectCreated
        case projectOpened
        case noteAdded
        case noteUpdated
        case taskCreated
        case taskCompleted
        case fileCreated
        case metricUpdated
        case integrationConnected
        case integrationSync
        case integrationSynced
        case assistantAction
        case decisionLogged
        case blockerAdded

        var displayName: String {
            switch self {
            case .projectCreated:
                return "Project Created"
            case .projectOpened:
                return "Project Opened"
            case .noteAdded:
                return "Note Added"
            case .noteUpdated:
                return "Note Updated"
            case .taskCreated:
                return "Task Created"
            case .taskCompleted:
                return "Task Completed"
            case .fileCreated:
                return "File Created"
            case .metricUpdated:
                return "Metric Updated"
            case .integrationConnected:
                return "Integration Connected"
            case .integrationSync:
                return "Integration Sync"
            case .integrationSynced:
                return "Integration Synced"
            case .assistantAction:
                return "Assistant Action"
            case .decisionLogged:
                return "Decision Logged"
            case .blockerAdded:
                return "Blocker Added"
            }
        }

        var systemImage: String {
            switch self {
            case .projectCreated:
                return "sparkles"
            case .projectOpened:
                return "folder"
            case .noteAdded:
                return "note.text"
            case .noteUpdated:
                return "note.text"
            case .taskCreated:
                return "checklist"
            case .taskCompleted:
                return "checkmark.circle"
            case .fileCreated:
                return "doc.badge.plus"
            case .metricUpdated:
                return "chart.line.uptrend.xyaxis"
            case .integrationConnected:
                return "link.badge.plus"
            case .integrationSync:
                return "arrow.triangle.2.circlepath"
            case .integrationSynced:
                return "arrow.triangle.2.circlepath"
            case .assistantAction:
                return "wand.and.stars"
            case .decisionLogged:
                return "checkmark.seal"
            case .blockerAdded:
                return "exclamationmark.triangle"
            }
        }
    }

    let id: UUID
    var projectId: UUID?
    var title: String
    var details: String
    var type: EventType
    var timestamp: Date

    init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        title: String,
        details: String = "",
        type: EventType,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.details = details
        self.type = type
        self.timestamp = timestamp
    }
}
