//
//  DynamicModule.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct DynamicModule: Identifiable, Equatable, Codable {
    enum Kind: String, CaseIterable, Equatable, Codable {
        case projectLibrary
        case projectOverview
        case notes
        case tasks
        case priorities
        case metrics
        case graphs
        case activityTimeline
        case files
        case integrations
        case projectWorkspace
        case projectHeader
        case projectMemory
        case projectDecisions
        case projectBlockers
        case projectOpenQuestions
        case projectEdit
        case addNote
        case addTask
        case assistantSuggestions
        case emptyState
        case briefing
        case projectCreation
        case projectSummaryPreview
        case workspacePreview
        case clarification
    }

    let id: UUID
    let kind: Kind
    let title: String
    let message: String?

    init(id: UUID = UUID(), kind: Kind, title: String? = nil, message: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.displayName
        self.message = message
    }
}

extension DynamicModule.Kind {
    var displayName: String {
        switch self {
        case .projectLibrary:
            return "Project Library"
        case .projectOverview:
            return "Project Overview"
        case .notes:
            return "Notes"
        case .tasks:
            return "Tasks"
        case .priorities:
            return "Priorities"
        case .metrics:
            return "Metrics"
        case .graphs:
            return "Graphs"
        case .activityTimeline:
            return "Activity"
        case .files:
            return "Files"
        case .integrations:
            return "Integrations"
        case .projectWorkspace:
            return "Project Workspace"
        case .projectHeader:
            return "Project Header"
        case .projectMemory:
            return "Project Memory"
        case .projectDecisions:
            return "Decisions"
        case .projectBlockers:
            return "Blockers"
        case .projectOpenQuestions:
            return "Open Questions"
        case .projectEdit:
            return "Edit Project"
        case .addNote:
            return "Add Note"
        case .addTask:
            return "Add Task"
        case .assistantSuggestions:
            return "Suggestions"
        case .emptyState:
            return "Empty State"
        case .briefing:
            return "Briefing"
        case .projectCreation:
            return "Create Project"
        case .projectSummaryPreview:
            return "Project Summary"
        case .workspacePreview:
            return "Workspace Preview"
        case .clarification:
            return "Clarification"
        }
    }
}

struct AssistantTurn: Identifiable, Equatable, Codable {
    let id: UUID
    let userMessage: String
    let intent: AssistantIntent
    let response: String
    let modules: [DynamicModule]
    let focusedProject: Project?
    let focusedProjectId: UUID?
    let focusedMode: FocusedWorkspaceMode
    let suggestions: [SuggestedReply]

    static let landing = AssistantTurn(
        userMessage: "",
        intent: AssistantIntent(kind: .greeting, confidence: 1.0),
        response: "",
        modules: [],
        focusedProject: nil,
        focusedProjectId: nil,
        focusedMode: .conversation,
        suggestions: []
    )

    init(
        userMessage: String,
        intent: AssistantIntent,
        response: String,
        modules: [DynamicModule],
        focusedProject: Project?,
        focusedProjectId: UUID? = nil,
        focusedMode: FocusedWorkspaceMode? = nil,
        suggestions: [SuggestedReply] = [],
        id: UUID = UUID()
    ) {
        self.id = id
        self.userMessage = userMessage
        self.intent = intent
        self.response = response
        self.modules = modules
        self.focusedProject = focusedProject
        self.focusedProjectId = focusedProjectId ?? focusedProject?.id
        self.focusedMode = focusedMode ?? modules.compactMap { FocusedWorkspaceMode.from(module: $0.kind) }.first ?? FocusedWorkspaceMode.from(intent: intent.id)
        self.suggestions = suggestions
    }
}
