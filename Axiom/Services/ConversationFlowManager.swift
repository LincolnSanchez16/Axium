//
//  ConversationFlowManager.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation
import Combine

@MainActor
final class ConversationFlowManager: ObservableObject {
    @Published private(set) var messages: [ConversationMessage]
    @Published private(set) var state: ConversationFlowState = .idle
    @Published private(set) var activeFlowSnapshot: ConversationFlowSnapshot?
    @Published private(set) var latestSuggestions: [SuggestedReply] = []

    private var createProjectFlow: CreateProjectFlow?
    private var recentConversations: [ConversationMessage] = []
    private var preferredProjectReferences: [String: UUID] = [:]
    private var phraseMappings: [String: AssistantIntent.Kind] = [:]
    private var userLanguagePatterns: [String] = []

    init(messages: [ConversationMessage] = []) {
        self.messages = messages
    }

    var isFlowActive: Bool {
        if case .active = state {
            return true
        }
        return false
    }

    func startCreateProjectFlow() -> ConversationFlowResult {
        let flow = CreateProjectFlow()
        createProjectFlow = flow
        state = .active(.createProject)
        activeFlowSnapshot = flow.snapshot()
        latestSuggestions = flow.suggestions()

        let result = ConversationFlowResult(
            assistantMessage: flow.prompt,
            modules: [
                DynamicModule(kind: .projectCreation),
                DynamicModule(kind: .projectSummaryPreview),
                DynamicModule(kind: .workspacePreview)
            ],
            suggestions: latestSuggestions
        )
        appendAssistantMessage(result.assistantMessage, suggestions: result.suggestions)
        return result
    }

    func handleUserMessage(_ input: String, projectStore: ProjectStore) -> ConversationFlowResult? {
        guard case .active(let kind) = state else { return nil }

        appendUserMessage(input)

        switch kind {
        case .createProject:
            return advanceCreateProjectFlow(with: input, projectStore: projectStore)
        case .addTask, .connectIntegration, .generatePDF, .createNote, .createMetric:
            let message = "That guided flow is not built yet, but the flow manager is ready for it."
            appendAssistantMessage(message)
            return ConversationFlowResult(
                assistantMessage: message,
                modules: [DynamicModule(kind: .emptyState, title: "Flow placeholder", message: message)]
            )
        }
    }

    func appendUserMessage(_ text: String) {
        let message = ConversationMessage(speaker: .user, text: text)
        messages.append(message)
        remember(message)
    }

    func appendAssistantMessage(_ text: String, suggestions: [SuggestedReply] = []) {
        let message = ConversationMessage(speaker: .assistant, text: text, suggestions: suggestions)
        messages.append(message)
        latestSuggestions = suggestions
        remember(message)
    }

    func goBack() -> ConversationFlowResult? {
        guard case .active(.createProject) = state, var flow = createProjectFlow else { return nil }
        flow.goBack()
        createProjectFlow = flow
        activeFlowSnapshot = flow.snapshot()
        latestSuggestions = flow.suggestions()
        appendAssistantMessage(flow.prompt, suggestions: latestSuggestions)
        return ConversationFlowResult(
            assistantMessage: flow.prompt,
            modules: createProjectModules(),
            suggestions: latestSuggestions
        )
    }

    func cancel() {
        createProjectFlow?.cancel()
        createProjectFlow = nil
        activeFlowSnapshot = nil
        latestSuggestions = [
            SuggestedReply("Show projects"),
            SuggestedReply("Create project")
        ]
        state = .cancelled
        appendAssistantMessage("No problem. I cancelled that flow.", suggestions: latestSuggestions)
    }

    func reset() {
        createProjectFlow = nil
        activeFlowSnapshot = nil
        latestSuggestions = []
        state = .idle
    }

    private func advanceCreateProjectFlow(with input: String, projectStore: ProjectStore) -> ConversationFlowResult {
        guard var flow = createProjectFlow else {
            return startCreateProjectFlow()
        }

        flow.advance(with: input)
        createProjectFlow = flow
        activeFlowSnapshot = flow.snapshot()

        if flow.isComplete {
            let project = projectStore.createProject(
                name: flow.projectName.isEmpty ? "Untitled Project" : flow.projectName,
                description: flow.projectDescription,
                category: flow.projectCategory,
                currentObjective: flow.currentObjective,
                priority: flow.projectPriority,
                aliases: [flow.projectCategory].filter { $0.isEmpty == false },
                openQuestions: flow.openQuestions,
                conversationMessages: messages
            )
            state = .complete(.createProject)
            latestSuggestions = [
                SuggestedReply("Show projects"),
                SuggestedReply("Add notes"),
                SuggestedReply("What needs work?")
            ]

            let message = flow.shouldCreateLocalWorkspace
                ? "Done. \(project.name) is ready in local memory. Workspace file creation is queued for a future confirmed file action."
                : "Done. \(project.name) is ready in local memory."
            appendAssistantMessage(message, suggestions: latestSuggestions)

            return ConversationFlowResult(
                assistantMessage: message,
                modules: [
                    DynamicModule(kind: .projectWorkspace)
                ],
                suggestions: latestSuggestions,
                createdProject: project,
                focusedProjectId: project.id
            )
        }

        let message = responseForCurrentCreateProjectStep(flow)
        latestSuggestions = flow.suggestions()
        appendAssistantMessage(message, suggestions: latestSuggestions)
        return ConversationFlowResult(
            assistantMessage: message,
            modules: createProjectModules(),
            suggestions: latestSuggestions
        )
    }

    private func responseForCurrentCreateProjectStep(_ flow: CreateProjectFlow) -> String {
        switch flow.currentStep {
        case CreateProjectFlow.Step.description.rawValue where flow.collectedData["name", default: ""].isEmpty:
            return "No worries. We can name it later. What is the goal of this project?"
        case CreateProjectFlow.Step.category.rawValue where flow.collectedData["description", default: ""].isEmpty:
            return "No worries. We can leave the goal blank for now. What kind of project is this?"
        case CreateProjectFlow.Step.currentObjective.rawValue where flow.collectedData["category", default: ""].isEmpty:
            return "No worries. We can leave the type open for now. What is the next objective?"
        case CreateProjectFlow.Step.priority.rawValue where flow.collectedData["currentObjective", default: ""].isEmpty:
            return "No problem. We can decide the next objective later. How important is this project right now?"
        default:
            return flow.prompt
        }
    }

    private func createProjectModules() -> [DynamicModule] {
        [
            DynamicModule(kind: .projectCreation),
            DynamicModule(kind: .projectSummaryPreview),
            DynamicModule(kind: .workspacePreview)
        ]
    }

    private func remember(_ message: ConversationMessage) {
        recentConversations.append(message)
        if recentConversations.count > 24 {
            recentConversations.removeFirst(recentConversations.count - 24)
        }

        if message.speaker == .user {
            userLanguagePatterns.append(message.text)
        }

        // Future LLM integration point:
        // User message -> local context retrieval -> project data retrieval -> LLM interpretation
        // -> intent confidence -> assistant response -> UI action.
        // The placeholders above will become durable memory for recent conversations,
        // preferred project references, phrase mappings, and user language patterns.
        _ = preferredProjectReferences
        _ = phraseMappings
    }
}
