//
//  AssistantIntent.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct AssistantIntent: Identifiable, Equatable, Codable {
    enum Kind: String, CaseIterable, Equatable, Codable {
        case greeting
        case createProject
        case viewProjects
        case openProject
        case focusConversation
        case viewNotes
        case summarizePriorities
        case viewTasks
        case viewMetrics
        case viewActivity
        case viewFiles
        case addNote
        case addTask
        case editProject
        case createFile
        case generatePDF
        case generateMindMap
        case connectIntegration
        case unknown
    }

    let id: Kind
    let displayName: String
    let description: String
    let confidence: Double

    init(kind: Kind, confidence: Double = 1.0) {
        self.id = kind
        self.displayName = kind.displayName
        self.description = kind.description
        self.confidence = confidence
    }
}

extension AssistantIntent.Kind {
    var displayName: String {
        switch self {
        case .greeting:
            return "Greeting"
        case .createProject:
            return "Create Project"
        case .viewProjects:
            return "View Projects"
        case .openProject:
            return "Open Project"
        case .focusConversation:
            return "Conversation"
        case .viewNotes:
            return "View Notes"
        case .summarizePriorities:
            return "Summarize Priorities"
        case .viewTasks:
            return "View Tasks"
        case .viewMetrics:
            return "View Metrics"
        case .viewActivity:
            return "View Activity"
        case .viewFiles:
            return "View Files"
        case .addNote:
            return "Add Note"
        case .addTask:
            return "Add Task"
        case .editProject:
            return "Edit Project"
        case .createFile:
            return "Create File"
        case .generatePDF:
            return "Generate PDF"
        case .generateMindMap:
            return "Generate Mind Map"
        case .connectIntegration:
            return "Connect Integration"
        case .unknown:
            return "Unknown"
        }
    }

    var description: String {
        switch self {
        case .greeting:
            return "Respond with a concise project briefing or getting-started prompt."
        case .createProject:
            return "Prepare a project creation flow without creating files automatically."
        case .viewProjects:
            return "Show the project library from local project state."
        case .openProject:
            return "Open a known project by name or alias."
        case .focusConversation:
            return "Return the current workspace to the centered conversational state."
        case .viewNotes:
            return "Open note context for the current project."
        case .summarizePriorities:
            return "Summarize the most important tasks across projects."
        case .viewTasks:
            return "Show task modules scoped to the current project context."
        case .viewMetrics:
            return "Show metrics only when real metric data exists."
        case .viewActivity:
            return "Show the activity timeline only when events exist."
        case .viewFiles:
            return "Open file context for the current project without fabricating files."
        case .addNote:
            return "Prepare note capture for the relevant project."
        case .addTask:
            return "Prepare task creation for the relevant project."
        case .editProject:
            return "Show editable project details for the relevant project."
        case .createFile:
            return "Prepare local file creation for the relevant project."
        case .generatePDF:
            return "Prepare a PDF generation flow."
        case .generateMindMap:
            return "Prepare a mind map generation flow."
        case .connectIntegration:
            return "Prepare an integration connection flow."
        case .unknown:
            return "Ask a clarifying question when the request is not understood."
        }
    }
}
