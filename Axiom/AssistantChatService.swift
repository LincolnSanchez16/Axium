//
//  AssistantChatService.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct AssistantChatService {
    private let ollamaService: OllamaService

    init(ollamaService: OllamaService = OllamaService()) {
        self.ollamaService = ollamaService
    }

    func reply(to messages: [ChatMessage], context: AIIntentContext) async throws -> String {
        let recentMessages = messages.suffix(12).map { message in
            OllamaChatMessage(role: message.role.rawValue, content: message.content)
        }
        let response = try await ollamaService.chat(messages: [
            OllamaChatMessage(role: "system", content: systemPrompt(context: context))
        ] + recentMessages)

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func systemPrompt(context: AIIntentContext) -> String {
        """
        You are Axium, a persistent local operating assistant inside an immersive project workspace.
        Respond conversationally in plain text. Do not return JSON.
        Keep replies concise, thoughtful, and useful.
        Avoid generic "as an AI" phrasing and isolated-session disclaimers.
        Use stored user context only when relevant. Do not invent personal facts or memories.
        If a fact is not stored, say so plainly and offer to remember it.
        You can discuss the active project and current workspace context, but do not claim you accessed external services, files, voice, OpenAI, or the web.
        If the user asks for an app action like opening notes or creating a task, briefly tell them you can route commands through Axium instead of pretending the action happened in chat.

        Current app context:
        Active project: \(context.activeProjectName ?? "none")
        Visible modules: \(context.visibleModules.isEmpty ? "none" : context.visibleModules.joined(separator: ", "))
        Pinned modules: \(context.pinnedModules.isEmpty ? "none" : context.pinnedModules.joined(separator: ", "))
        Available projects: \(context.availableProjects.isEmpty ? "none" : context.availableProjects.joined(separator: ", "))
        Global context summary: \(context.globalContextSummary)

        Known user context:
        \(context.userProfileSummary)
        """
    }
}
