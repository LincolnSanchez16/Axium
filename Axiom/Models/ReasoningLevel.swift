//
//  ReasoningLevel.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

enum ReasoningLevel: String, CaseIterable, Equatable, Codable {
    case instant
    case lightweight
    case contextual
    case deep
    case cloudRequired

    var needsVisibleThinking: Bool {
        switch self {
        case .instant:
            return false
        case .lightweight, .contextual, .deep, .cloudRequired:
            return true
        }
    }
}
