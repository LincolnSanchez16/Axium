//
//  CloudReasoningManager.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct CloudReasoningRequest: Equatable {
    var input: String
    var decision: AssistantDecision
    var contextSummary: String
}

struct CloudReasoningManager {
    func placeholderResponse(for request: CloudReasoningRequest) -> String {
        if request.decision.assistantResponse.isEmpty == false {
            return request.decision.assistantResponse
        }

        return "This likely needs deeper/cloud reasoning. I can prepare the escalation path, but cloud intelligence is not connected yet."
    }
}
