//
//  AssistantRuntime.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation
import Combine

@MainActor
final class AssistantRuntime: ObservableObject {
    @Published private(set) var chatSession = ConversationSession()

    private let aiIntentInterpreter: AIIntentInterpreter
    private let assistantChatService: AssistantChatService
    private let deterministicIntentRouter: IntentRouter
    private let intelligenceOrchestrator: IntelligenceOrchestrator
    private let cloudReasoningManager: CloudReasoningManager

    init() {
        self.aiIntentInterpreter = AIIntentInterpreter(ollamaService: OllamaService())
        self.assistantChatService = AssistantChatService(ollamaService: OllamaService())
        self.deterministicIntentRouter = IntentRouter(languageMemory: UserLanguageMemory())
        self.intelligenceOrchestrator = IntelligenceOrchestrator()
        self.cloudReasoningManager = CloudReasoningManager()
    }

    init(
        aiIntentInterpreter: AIIntentInterpreter,
        assistantChatService: AssistantChatService,
        deterministicIntentRouter: IntentRouter,
        intelligenceOrchestrator: IntelligenceOrchestrator = IntelligenceOrchestrator(),
        cloudReasoningManager: CloudReasoningManager = CloudReasoningManager()
    ) {
        self.aiIntentInterpreter = aiIntentInterpreter
        self.assistantChatService = assistantChatService
        self.deterministicIntentRouter = deterministicIntentRouter
        self.intelligenceOrchestrator = intelligenceOrchestrator
        self.cloudReasoningManager = cloudReasoningManager
    }

    func handleUserInput(_ input: String, context: AIIntentContext) async -> AssistantRuntimeResult {
        let decision = intelligenceOrchestrator.decide(input: input, context: context, recentMessages: chatSession.messages)

        switch decision.responseStrategy {
        case .askClarification:
            return clarificationResult(input: input, decision: decision)
        case .escalateToCloud:
            return cloudPlaceholderResult(input: input, context: context, decision: decision)
        case .immediateAction, .toolExecution, .saveMemory, .suggestProject:
            return await interpretCommand(input, context: context, decision: decision)
        case .hybrid:
            if decision.selectedTool == "AssistantChatService" {
                return await replyConversationally(to: input, context: context, decision: decision)
            }
            return await interpretCommand(input, context: context, decision: decision)
        case .conversationalReply, .deferredReasoning:
            return await replyConversationally(to: input, context: context, decision: decision)
        }
    }

    private func interpretCommand(_ input: String, context: AIIntentContext, decision: AssistantDecision) async -> AssistantRuntimeResult {
        do {
            let aiResult = try await aiIntentInterpreter.interpret(command: input, context: context)
            return AssistantRuntimeResult(
                userMessage: input,
                action: .routeAIIntent(aiResult),
                assistantResponse: aiResult.assistantResponse,
                decision: decision
            )
        } catch {
            let intent = deterministicIntentRouter.route(input)
            return AssistantRuntimeResult(
                userMessage: input,
                action: .routeDeterministicIntent(intent, fallbackNotice: "Local interpreter unavailable, using deterministic routing."),
                assistantResponse: nil,
                decision: decision
            )
        }
    }

    private func replyConversationally(to input: String, context: AIIntentContext, decision: AssistantDecision) async -> AssistantRuntimeResult {
        chatSession.append(ChatMessage(role: .user, content: input))

        do {
            let response = try await assistantChatService.reply(to: chatSession.messages, context: context)
            let reply = response.isEmpty ? "I’m here, but I didn’t get a usable local response." : response
            chatSession.append(ChatMessage(role: .assistant, content: reply))
            return AssistantRuntimeResult(
                userMessage: input,
                action: .showConversationReply(reply),
                assistantResponse: reply,
                decision: decision
            )
        } catch {
            let response = "I couldn’t reach the local chat runtime. Ollama may be offline, so I kept your message in this session."
            chatSession.append(ChatMessage(role: .assistant, content: response))
            return AssistantRuntimeResult(
                userMessage: input,
                action: .showConversationError(response),
                assistantResponse: response,
                decision: decision
            )
        }
    }

    private func clarificationResult(input: String, decision: AssistantDecision) -> AssistantRuntimeResult {
        let response = decision.followUpQuestion ?? decision.assistantResponse
        chatSession.append(ChatMessage(role: .user, content: input))
        chatSession.append(ChatMessage(role: .assistant, content: response))
        return AssistantRuntimeResult(
            userMessage: input,
            action: .showConversationReply(response),
            assistantResponse: response,
            decision: decision
        )
    }

    private func cloudPlaceholderResult(input: String, context: AIIntentContext, decision: AssistantDecision) -> AssistantRuntimeResult {
        let request = CloudReasoningRequest(
            input: input,
            decision: decision,
            contextSummary: context.globalContextSummary
        )
        let response = cloudReasoningManager.placeholderResponse(for: request)
        chatSession.append(ChatMessage(role: .user, content: input))
        chatSession.append(ChatMessage(role: .assistant, content: response))
        return AssistantRuntimeResult(
            userMessage: input,
            action: .showConversationReply(response),
            assistantResponse: response,
            decision: decision
        )
    }
}
