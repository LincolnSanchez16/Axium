//
//  ResponseStrategy.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

enum ResponseStrategy: String, CaseIterable, Equatable, Codable {
    case immediateAction
    case conversationalReply
    case askClarification
    case toolExecution
    case saveMemory
    case suggestProject
    case escalateToCloud
    case deferredReasoning
    case hybrid
}
