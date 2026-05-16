//
//  AssistantRuntimeResult.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct AssistantRuntimeResult {
    let userMessage: String
    let action: AssistantRuntimeAction
    let assistantResponse: String?
    let decision: AssistantDecision
}

enum AssistantRuntimeAction {
    case routeAIIntent(AIIntentResult)
    case routeDeterministicIntent(AssistantIntent, fallbackNotice: String?)
    case showConversationReply(String)
    case showConversationError(String)
}
