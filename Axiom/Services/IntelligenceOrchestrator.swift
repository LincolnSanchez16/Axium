//
//  IntelligenceOrchestrator.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct IntelligenceOrchestrator {
    func decide(input: String, context: AIIntentContext, recentMessages: [ChatMessage]) -> AssistantDecision {
        let normalized = routingText(from: input)
        var extractedContext = baseExtractedContext(from: context)
        extractedContext["normalizedInput"] = normalized

        if normalized.isEmpty {
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .askClarification,
                confidence: 0.9,
                shouldAskClarification: true,
                assistantResponse: "What should we work on?",
                extractedContext: extractedContext,
                followUpQuestion: "What should we work on?"
            )
        }

        if isAmbiguousSaveRequest(normalized) {
            return AssistantDecision(
                reasoningLevel: .contextual,
                responseStrategy: .askClarification,
                selectedTool: "ContextRouter",
                confidence: 0.86,
                shouldSaveMemory: true,
                shouldAskClarification: true,
                suggestedModules: ["clarification"],
                assistantResponse: "Do you want to save this globally or into a project?",
                extractedContext: extractedContext,
                followUpQuestion: "Do you want to save this globally or into a project?"
            )
        }

        if requiresCloud(normalized) {
            return AssistantDecision(
                reasoningLevel: .cloudRequired,
                responseStrategy: .escalateToCloud,
                selectedTool: "CloudReasoningManager",
                confidence: 0.84,
                shouldSaveMemory: true,
                shouldEscalateToCloud: true,
                suggestedModules: ["briefing"],
                assistantResponse: "This likely needs deeper/cloud reasoning. Cloud intelligence is not connected yet.",
                extractedContext: extractedContext
            )
        }

        if isInstantAction(normalized) {
            return AssistantDecision(
                reasoningLevel: .instant,
                responseStrategy: .immediateAction,
                selectedTool: "AIIntentInterpreter",
                confidence: 0.92,
                shouldSaveMemory: mentionsProjectContext(normalized, context: context),
                suggestedModules: suggestedModules(for: normalized),
                assistantResponse: "",
                extractedContext: extractedContext
            )
        }

        if isLightweightAction(normalized) {
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .toolExecution,
                selectedTool: "AIIntentInterpreter",
                confidence: 0.88,
                shouldSaveMemory: shouldCaptureMemorySignal(normalized, context: context),
                suggestedModules: suggestedModules(for: normalized),
                assistantResponse: "",
                extractedContext: extractedContext
            )
        }

        if isMemorySignal(normalized) {
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .saveMemory,
                selectedTool: "ContextRouter",
                confidence: 0.84,
                shouldSaveMemory: true,
                suggestedModules: ["memory"],
                assistantResponse: "I’ll keep that as reviewable local context.",
                extractedContext: extractedContext
            )
        }

        if isContextualRequest(normalized) {
            return AssistantDecision(
                reasoningLevel: .contextual,
                responseStrategy: .hybrid,
                selectedTool: "AIIntentInterpreter",
                confidence: 0.8,
                shouldSaveMemory: true,
                suggestedModules: suggestedModules(for: normalized),
                assistantResponse: "",
                extractedContext: extractedContext
            )
        }

        if isDeepReasoning(normalized) {
            return AssistantDecision(
                reasoningLevel: .deep,
                responseStrategy: .deferredReasoning,
                selectedTool: "AssistantChatService",
                confidence: 0.78,
                shouldSaveMemory: true,
                suggestedModules: ["briefing"],
                assistantResponse: "",
                extractedContext: extractedContext
            )
        }

        if isConversational(normalized) {
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .conversationalReply,
                selectedTool: "AssistantChatService",
                confidence: 0.82,
                shouldSaveMemory: shouldCaptureMemorySignal(normalized, context: context),
                suggestedModules: ["conversation"],
                assistantResponse: "",
                extractedContext: extractedContext
            )
        }

        return AssistantDecision(
            reasoningLevel: .lightweight,
            responseStrategy: .conversationalReply,
            selectedTool: "AssistantChatService",
            confidence: 0.62,
            shouldSaveMemory: shouldCaptureMemorySignal(normalized, context: context),
            suggestedModules: ["conversation"],
            assistantResponse: "",
            extractedContext: extractedContext
        )
    }

    private func baseExtractedContext(from context: AIIntentContext) -> [String: String] {
        [
            "activeProject": context.activeProjectName ?? "none",
            "visibleModules": context.visibleModules.joined(separator: ", "),
            "pinnedModules": context.pinnedModules.joined(separator: ", "),
            "availableProjects": context.availableProjects.joined(separator: ", ")
        ]
    }

    private func routingText(from input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let salutations = ["hey axium,", "hey axium", "hi axium,", "hi axium", "axium,", "axium"]
        for salutation in salutations where text.hasPrefix(salutation) {
            text.removeFirst(salutation.count)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func isInstantAction(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "open notes", "show notes", "view notes",
            "open tasks", "show tasks", "view tasks",
            "open files", "show files", "view files",
            "show metrics", "show activity", "show integrations",
            "show projects", "view projects", "list projects", "project library",
            "open project", "pull up project", "show project"
        ]) || input.hasPrefix("open ")
    }

    private func isLightweightAction(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "create project", "new project", "add note", "add task",
            "create task", "new task", "remind me", "add reminder",
            "calendar", "schedule", "remember this", "save note"
        ])
    }

    private func isContextualRequest(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "save this to", "save this as", "save conversation",
            "what needs work", "priorities", "where should this go",
            "which project", "this project", "current project"
        ])
    }

    private func isDeepReasoning(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "architecture", "architect", "strategy", "technical breakdown",
            "multi-step", "multi step", "design a system", "local ai agents",
            "agent architecture", "roadmap", "deep dive", "think through"
        ])
    }

    private func requiresCloud(_ input: String) -> Bool {
        input.hasPrefix("research ") || containsAny(input, phrases: [
            "web research", "search the web", "look up", "latest",
            "current news", "internet", "external knowledge",
            "large code generation", "generate an entire app",
            "future multimodal", "market research"
        ])
    }

    private func isConversational(_ input: String) -> Bool {
        input.hasSuffix("?") || containsAny(input, phrases: [
            "what do you think", "what are your thoughts", "how do you feel",
            "help me think", "talk through", "brainstorm", "explain",
            "why do", "why is", "should i", "can you help me understand"
        ])
    }

    private func isAmbiguousSaveRequest(_ input: String) -> Bool {
        input == "save this" || input == "save that" || input == "remember this" || input == "save it"
    }

    private func isMemorySignal(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "remember that", "remember this", "i prefer", "i like",
            "i hate", "do not", "don't", "call me", "my name is",
            "means", "preference"
        ])
    }

    private func shouldCaptureMemorySignal(_ input: String, context: AIIntentContext) -> Bool {
        isMemorySignal(input) || mentionsProjectContext(input, context: context) || input.contains("research") || input.contains("earlier")
    }

    private func mentionsProjectContext(_ input: String, context: AIIntentContext) -> Bool {
        if input.contains("this project") || input.contains("current project") || input.contains("active project") {
            return context.activeProjectName != nil
        }

        return context.availableProjects.contains { projectName in
            input.contains(projectName.lowercased())
        }
    }

    private func suggestedModules(for input: String) -> [String] {
        if input.contains("note") { return ["notes"] }
        if input.contains("task") || input.contains("todo") { return ["tasks"] }
        if input.contains("file") { return ["files"] }
        if input.contains("metric") { return ["metrics"] }
        if input.contains("activity") { return ["activity"] }
        if input.contains("project") { return ["projectWorkspace"] }
        return []
    }

    private func containsAny(_ input: String, phrases: [String]) -> Bool {
        phrases.contains { input.contains($0) }
    }
}
