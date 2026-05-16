//
//  IntentRouter.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct IntentRouter {
    private let languageMemory: UserLanguageMemory

    init(languageMemory: UserLanguageMemory = UserLanguageMemory()) {
        self.languageMemory = languageMemory
    }

    func route(_ input: String) -> AssistantIntent {
        let normalizedInput = normalized(input)

        if let rememberedIntent = languageMemory.mappedIntent(for: normalizedInput) {
            return AssistantIntent(kind: rememberedIntent, confidence: 0.96)
        }

        if matchesAny(normalizedInput, phrases: ["hi", "hello", "hey", "yo", "good morning", "good afternoon"]) {
            return AssistantIntent(kind: .greeting, confidence: 0.95)
        }

        if containsAny(normalizedInput, phrases: ["create a project", "create project", "new project", "start project", "create a new project"]) {
            return AssistantIntent(kind: .createProject, confidence: 0.92)
        }

        if containsAny(normalizedInput, phrases: ["show my projects", "view projects", "list projects", "project library"]) {
            return AssistantIntent(kind: .viewProjects, confidence: 0.9)
        }

        if containsAny(normalizedInput, phrases: ["hide this", "close this", "back to conversation", "return to conversation", "conversation mode"]) {
            return AssistantIntent(kind: .focusConversation, confidence: 0.9)
        }

        if containsAny(normalizedInput, phrases: ["show notes", "view notes", "notes", "open notes"]) {
            return AssistantIntent(kind: .viewNotes, confidence: 0.88)
        }

        if containsAny(normalizedInput, phrases: ["show files", "view files", "open files", "files", "file browser"]) {
            return AssistantIntent(kind: .viewFiles, confidence: 0.88)
        }

        if containsAny(normalizedInput, phrases: ["open project", "pull up project", "show project"]) ||
            normalizedInput.hasPrefix("open ") ||
            normalizedInput.hasPrefix("pull up ") {
            return AssistantIntent(kind: .openProject, confidence: 0.82)
        }

        if containsAny(normalizedInput, phrases: ["what needs work", "what should i work on", "priority tasks", "priorities", "needs work"]) {
            return AssistantIntent(kind: .summarizePriorities, confidence: 0.9)
        }

        if containsAny(normalizedInput, phrases: ["show tasks", "tasks", "to do", "todo", "todos"]) {
            return AssistantIntent(kind: .viewTasks, confidence: 0.88)
        }

        if containsAny(normalizedInput, phrases: ["metrics", "revenue", "money", "mrr", "arr", "profit"]) {
            return AssistantIntent(kind: .viewMetrics, confidence: 0.9)
        }

        if containsAny(normalizedInput, phrases: ["activity", "timeline", "what did i work on"]) {
            return AssistantIntent(kind: .viewActivity, confidence: 0.9)
        }

        if containsAny(normalizedInput, phrases: ["add note", "remember this"]) {
            return AssistantIntent(kind: .addNote, confidence: 0.86)
        }

        if containsAny(normalizedInput, phrases: ["add task", "new task", "create task"]) {
            return AssistantIntent(kind: .addTask, confidence: 0.86)
        }

        if containsAny(normalizedInput, phrases: ["edit project", "update project", "change project"]) {
            return AssistantIntent(kind: .editProject, confidence: 0.84)
        }

        if containsAny(normalizedInput, phrases: ["create file", "make this a file", "new file"]) {
            return AssistantIntent(kind: .createFile, confidence: 0.86)
        }

        if containsAny(normalizedInput, phrases: ["generate pdf", "make a pdf", "export pdf"]) {
            return AssistantIntent(kind: .generatePDF, confidence: 0.86)
        }

        if containsAny(normalizedInput, phrases: ["mind map", "mindmap"]) {
            return AssistantIntent(kind: .generateMindMap, confidence: 0.86)
        }

        if containsAny(normalizedInput, phrases: ["connect", "integration", "stripe", "github", "notion"]) {
            return AssistantIntent(kind: .connectIntegration, confidence: 0.78)
        }

        return AssistantIntent(kind: .unknown, confidence: 0.3)
    }

    private func normalized(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func matchesAny(_ input: String, phrases: [String]) -> Bool {
        phrases.contains(input)
    }

    private func containsAny(_ input: String, phrases: [String]) -> Bool {
        phrases.contains { input.contains($0) }
    }

    // Later this deterministic router will call an LLM and combine project context,
    // learned user language patterns, aliases, and confidence calibration.
}
