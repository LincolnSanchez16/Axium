//
//  ConversationFlow.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

protocol ConversationFlow {
    var id: UUID { get }
    var title: String { get }
    var currentStep: Int { get }
    var totalSteps: Int { get }
    var prompt: String { get }
    var collectedData: [String: String] { get }
    var isComplete: Bool { get }

    mutating func advance(with input: String)
    mutating func goBack()
    mutating func cancel()
    mutating func complete()
}

enum ConversationFlowKind: Equatable {
    case createProject
    case addTask
    case connectIntegration
    case generatePDF
    case createNote
    case createMetric
}

enum ConversationFlowState: Equatable {
    case idle
    case active(ConversationFlowKind)
    case complete(ConversationFlowKind)
    case cancelled
}

struct ConversationFlowResult: Equatable {
    let assistantMessage: String
    let modules: [DynamicModule]
    let suggestions: [SuggestedReply]
    let createdProject: Project?
    let focusedProjectId: UUID?

    init(
        assistantMessage: String,
        modules: [DynamicModule],
        suggestions: [SuggestedReply] = [],
        createdProject: Project? = nil,
        focusedProjectId: UUID? = nil
    ) {
        self.assistantMessage = assistantMessage
        self.modules = modules
        self.suggestions = suggestions
        self.createdProject = createdProject
        self.focusedProjectId = focusedProjectId ?? createdProject?.id
    }
}
