//
//  AssistantDecision.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct AssistantDecision: Equatable, Codable {
    var reasoningLevel: ReasoningLevel
    var responseStrategy: ResponseStrategy
    var selectedTool: String?
    var confidence: Double
    var shouldSaveMemory: Bool
    var shouldAskClarification: Bool
    var shouldEscalateToCloud: Bool
    var suggestedModules: [String]
    var assistantResponse: String
    var extractedContext: [String: String]
    var followUpQuestion: String?

    init(
        reasoningLevel: ReasoningLevel,
        responseStrategy: ResponseStrategy,
        selectedTool: String? = nil,
        confidence: Double,
        shouldSaveMemory: Bool = false,
        shouldAskClarification: Bool = false,
        shouldEscalateToCloud: Bool = false,
        suggestedModules: [String] = [],
        assistantResponse: String = "",
        extractedContext: [String: String] = [:],
        followUpQuestion: String? = nil
    ) {
        self.reasoningLevel = reasoningLevel
        self.responseStrategy = responseStrategy
        self.selectedTool = selectedTool
        self.confidence = confidence
        self.shouldSaveMemory = shouldSaveMemory
        self.shouldAskClarification = shouldAskClarification
        self.shouldEscalateToCloud = shouldEscalateToCloud
        self.suggestedModules = suggestedModules
        self.assistantResponse = assistantResponse
        self.extractedContext = extractedContext
        self.followUpQuestion = followUpQuestion
    }
}
