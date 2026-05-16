//
//  AIIntentInterpreter.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct AIIntentInterpreter {
    private let ollamaService: OllamaService
    private let decoder = JSONDecoder()

    init(ollamaService: OllamaService = OllamaService()) {
        self.ollamaService = ollamaService
    }

    func interpret(command: String, context: AIIntentContext) async throws -> AIIntentResult {
        let response = try await ollamaService.chat(messages: [
            OllamaChatMessage(role: "system", content: systemPrompt),
            OllamaChatMessage(role: "user", content: userPrompt(command: command, context: context))
        ])
        let data = try jsonData(from: response)
        return try decoder.decode(AIIntentResult.self, from: data)
    }

    private var systemPrompt: String {
        """
        You are Axium's lightweight local intent interpreter.
        Return ONLY valid JSON. No markdown. No prose outside JSON.
        Do not answer as a chat assistant. Do not perform long reasoning.
        Use persistent user context for routing preferences and slang only. Do not invent facts or memories.
        Choose one supported intent:
        greeting, createProject, openProject, viewProjects, addNote, addTask, showNotes, showTasks, showMetrics, showFiles, showActivity, showIntegrations, saveToProject, addReminder, addCalendarItem, rememberUserInfo, updateUserProfile, savePreference, unknown.
        Use rememberUserInfo, updateUserProfile, or savePreference for personal identity, user preference, slang, or future-reference memory requests.
        Use shouldUseCloudAPI true only when the command needs broad external knowledge, web research, complex strategy, or long-form reasoning.
        Keep assistantResponse to one short UI sentence.
        JSON schema:
        {
          "intent": "openProject",
          "target": "project/module/global/currentProject/unknown",
          "projectName": null,
          "module": null,
          "extractedTitle": null,
          "extractedDetails": null,
          "confidence": 0.0,
          "shouldUseCloudAPI": false,
          "assistantResponse": "Short response."
        }
        """
    }

    private func userPrompt(command: String, context: AIIntentContext) -> String {
        """
        Command:
        \(command)

        Current app context:
        Active project: \(context.activeProjectName ?? "none")
        Visible modules: \(context.visibleModules.isEmpty ? "none" : context.visibleModules.joined(separator: ", "))
        Pinned modules: \(context.pinnedModules.isEmpty ? "none" : context.pinnedModules.joined(separator: ", "))
        Available projects: \(context.availableProjects.isEmpty ? "none" : context.availableProjects.joined(separator: ", "))
        Global context summary: \(context.globalContextSummary)

        Persistent user context:
        \(context.userProfileSummary)

        Return ONLY valid JSON for the command.
        """
    }

    private func jsonData(from response: String) throws -> Data {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}")
        else {
            throw AIIntentInterpreterError.invalidJSON(response)
        }

        let json = String(trimmed[start...end])
        guard let data = json.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else {
            throw AIIntentInterpreterError.invalidJSON(response)
        }

        return data
    }
}

struct AIIntentContext: Equatable {
    let activeProjectName: String?
    let visibleModules: [String]
    let pinnedModules: [String]
    let availableProjects: [String]
    let globalContextSummary: String
    let userProfileSummary: String
}

enum AIIntentInterpreterError: LocalizedError {
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Ollama returned invalid JSON."
        }
    }
}
