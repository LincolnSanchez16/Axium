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

        if let personalMemoryDecision = personalMemoryDecision(for: normalized, context: context, extractedContext: extractedContext) {
            return personalMemoryDecision
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

    private func personalMemoryDecision(for input: String, context: AIIntentContext, extractedContext: [String: String]) -> AssistantDecision? {
        var extractedContext = extractedContext

        if let name = extractPreferredName(from: input) {
            extractedContext["memoryType"] = "preferredName"
            extractedContext["preferredName"] = name
            let response = input.contains("call me")
                ? "Got it. I’ll call you \(name)."
                : "Got it. I’ll remember your name is \(name)."

            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .saveMemory,
                selectedTool: "GlobalConversationMemoryStore",
                confidence: 0.94,
                shouldSaveMemory: true,
                suggestedModules: ["memory"],
                assistantResponse: response,
                extractedContext: extractedContext
            )
        }

        if asksToStoreKnownName(input) {
            if let knownName = knownPreferredName(from: context.userProfileSummary) {
                extractedContext["memoryType"] = "preferredName"
                extractedContext["preferredName"] = knownName
                return AssistantDecision(
                    reasoningLevel: .lightweight,
                    responseStrategy: .saveMemory,
                    selectedTool: "GlobalConversationMemoryStore",
                    confidence: 0.9,
                    shouldSaveMemory: true,
                    suggestedModules: ["memory"],
                    assistantResponse: "Got it. I’ll remember your name is \(knownName).",
                    extractedContext: extractedContext
                )
            }

            extractedContext["memoryType"] = "preferredName"
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .askClarification,
                selectedTool: "GlobalConversationMemoryStore",
                confidence: 0.9,
                shouldSaveMemory: false,
                shouldAskClarification: true,
                suggestedModules: ["clarification"],
                assistantResponse: "What name should I remember?",
                extractedContext: extractedContext,
                followUpQuestion: "What name should I remember?"
            )
        }

        if let preference = extractPreference(from: input) {
            extractedContext["memoryType"] = "preference"
            extractedContext["preference"] = preference
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .saveMemory,
                selectedTool: "GlobalConversationMemoryStore",
                confidence: 0.88,
                shouldSaveMemory: true,
                suggestedModules: ["memory"],
                assistantResponse: "Got it. I’ll remember that you prefer \(preference).",
                extractedContext: extractedContext
            )
        }

        if isMemorySignal(input) {
            extractedContext["memoryType"] = "general"
            return AssistantDecision(
                reasoningLevel: .lightweight,
                responseStrategy: .saveMemory,
                selectedTool: "GlobalConversationMemoryStore",
                confidence: 0.84,
                shouldSaveMemory: true,
                suggestedModules: ["memory"],
                assistantResponse: "Got it. I’ll keep that as reviewable local context.",
                extractedContext: extractedContext
            )
        }

        return nil
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
            "calendar", "schedule", "save note"
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
        input == "save this" || input == "save that" || input == "save it"
    }

    private func isMemorySignal(_ input: String) -> Bool {
        containsAny(input, phrases: [
            "my name is", "call me", "remember my name", "store my name",
            "remember that", "remember this", "for future reference",
            "i like", "i prefer", "i hate", "i don't like",
            "i dont like", "do not", "don't", "means", "preference"
        ])
    }

    private func extractPreferredName(from input: String) -> String? {
        let markers = ["remember my name is ", "my name is ", "call me "]
        for marker in markers {
            guard let range = input.range(of: marker) else { continue }
            let rawName = input[range.upperBound...]
                .split { $0 == "." || $0 == "," || $0 == "\n" }
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let rawName, rawName.isEmpty == false else { continue }
            let name = rawName
                .split(separator: " ")
                .prefix(3)
                .joined(separator: " ")
            if name.count <= 40 {
                return name.capitalized
            }
        }
        return nil
    }

    private func asksToStoreKnownName(_ input: String) -> Bool {
        containsAny(input, phrases: ["store my name", "remember my name", "name for future reference"])
    }

    private func knownPreferredName(from summary: String) -> String? {
        let marker = "preferred name: "
        let lowerSummary = summary.lowercased()
        guard let range = lowerSummary.range(of: marker) else { return nil }
        let suffix = lowerSummary[range.upperBound...]
        let name = suffix
            .split { $0 == "\n" || $0 == "," || $0 == ";" }
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        return name?.isEmpty == false ? name?.capitalized : nil
    }

    private func extractPreference(from input: String) -> String? {
        let markers = ["remember that i like ", "remember that i prefer ", "i prefer ", "i like "]
        for marker in markers {
            guard let range = input.range(of: marker) else { continue }
            return cleanedPreference(from: input[range.upperBound...])
        }

        let dislikeMarkers = ["remember that i hate ", "i hate ", "i don't like ", "i dont like "]
        for marker in dislikeMarkers {
            guard let range = input.range(of: marker),
                  let disliked = cleanedPreference(from: input[range.upperBound...])
            else { continue }
            return "avoiding \(disliked)"
        }

        return nil
    }

    private func cleanedPreference(from substring: Substring) -> String? {
        let preference = substring
            .split { $0 == "." || $0 == "," || $0 == "\n" }
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preference, preference.isEmpty == false else { return nil }
        return String(preference.prefix(90))
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
