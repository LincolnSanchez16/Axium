//
//  FocusedWorkspaceMode.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

enum FocusedWorkspaceMode: String, CaseIterable, Equatable, Codable {
    case conversation
    case projectOverview
    case notes
    case tasks
    case metrics
    case files
    case activity
    case integrations
    case memory
    case editProject

    var displayName: String {
        switch self {
        case .conversation: return "Conversation"
        case .projectOverview: return "Overview"
        case .notes: return "Notes"
        case .tasks: return "Tasks"
        case .metrics: return "Metrics"
        case .files: return "Files"
        case .activity: return "Activity"
        case .integrations: return "Integrations"
        case .memory: return "Memory"
        case .editProject: return "Edit"
        }
    }

    var systemImage: String {
        switch self {
        case .conversation: return "sparkles"
        case .projectOverview: return "rectangle.grid.1x2"
        case .notes: return "note.text"
        case .tasks: return "checklist"
        case .metrics: return "chart.line.uptrend.xyaxis"
        case .files: return "shippingbox"
        case .activity: return "clock.arrow.circlepath"
        case .integrations: return "link"
        case .memory: return "brain.head.profile"
        case .editProject: return "slider.horizontal.3"
        }
    }

    var contextPrompt: String {
        switch self {
        case .conversation:
            return "Conversation is the center. Ask Axium what to focus on next."
        case .projectOverview:
            return "A compact read on the current project context."
        case .notes:
            return "Capture or review what Axium should remember for this project."
        case .tasks:
            return "Focus on next actions, priority, and work that is stuck."
        case .metrics:
            return "Only real connected or manually added metrics appear here."
        case .files:
            return "Browse real project files and attached artifacts."
        case .activity:
            return "Review the timeline of real project actions."
        case .integrations:
            return "Prepare connections without pretending data is live."
        case .memory:
            return "Review the transparent memory foundation for this project."
        case .editProject:
            return "Adjust core project context."
        }
    }

    static func from(intent: AssistantIntent.Kind) -> FocusedWorkspaceMode {
        switch intent {
        case .focusConversation:
            return .conversation
        case .viewNotes:
            return .notes
        case .viewTasks, .summarizePriorities, .addTask:
            return .tasks
        case .viewMetrics:
            return .metrics
        case .viewActivity:
            return .activity
        case .viewFiles:
            return .files
        case .addNote:
            return .notes
        case .createFile:
            return .files
        case .connectIntegration:
            return .integrations
        case .editProject:
            return .editProject
        case .openProject:
            return .conversation
        default:
            return .conversation
        }
    }

    static func from(module: DynamicModule.Kind) -> FocusedWorkspaceMode? {
        switch module {
        case .projectOverview:
            return .projectOverview
        case .notes, .addNote:
            return .notes
        case .tasks, .priorities, .addTask:
            return .tasks
        case .metrics, .graphs:
            return .metrics
        case .files:
            return .files
        case .activityTimeline:
            return .activity
        case .integrations:
            return .integrations
        case .projectMemory, .projectDecisions, .projectBlockers, .projectOpenQuestions:
            return .memory
        case .projectEdit:
            return .editProject
        default:
            return nil
        }
    }
}

struct PrimaryContext: Equatable, Codable {
    var projectId: UUID?
    var conversationId: UUID?
    var flowId: String?
    var focusMode: FocusedWorkspaceMode
}

struct SecondaryContext: Equatable, Codable {
    var suggestedModes: [FocusedWorkspaceMode]
    var suggestedActions: [SuggestedReply]
}

struct BackgroundContext: Equatable, Codable {
    var availableModules: [DynamicModule.Kind]
    var hiddenModules: [DynamicModule.Kind]
}
