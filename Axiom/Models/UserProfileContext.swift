//
//  UserProfileContext.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

struct UserProfileContext: Equatable, Codable {
    var preferredName: String?
    var preferredTone: String?
    var preferredWorkflowStyle: String?
    var commonPhrases: [String]
    var dislikedBehaviors: [String]
    var preferredUIStyle: [String]
    var preferredProjectBehavior: [String]
    var interactionPatterns: [String]
    var responsePreferences: [String]
    var assistantBehaviorPreferences: [String]
    var knownProjects: [String]
    var activeFocusAreas: [String]
    var aliases: [String: String]
    var updatedAt: Date

    init(
        preferredName: String? = nil,
        preferredTone: String? = nil,
        preferredWorkflowStyle: String? = nil,
        commonPhrases: [String] = [],
        dislikedBehaviors: [String] = [],
        preferredUIStyle: [String] = [],
        preferredProjectBehavior: [String] = [],
        interactionPatterns: [String] = [],
        responsePreferences: [String] = [],
        assistantBehaviorPreferences: [String] = [],
        knownProjects: [String] = [],
        activeFocusAreas: [String] = [],
        aliases: [String: String] = [:],
        updatedAt: Date = Date()
    ) {
        self.preferredName = preferredName
        self.preferredTone = preferredTone
        self.preferredWorkflowStyle = preferredWorkflowStyle
        self.commonPhrases = commonPhrases
        self.dislikedBehaviors = dislikedBehaviors
        self.preferredUIStyle = preferredUIStyle
        self.preferredProjectBehavior = preferredProjectBehavior
        self.interactionPatterns = interactionPatterns
        self.responsePreferences = responsePreferences
        self.assistantBehaviorPreferences = assistantBehaviorPreferences
        self.knownProjects = knownProjects
        self.activeFocusAreas = activeFocusAreas
        self.aliases = aliases
        self.updatedAt = updatedAt
    }

    var compactSummaryLines: [String] {
        var lines: [String] = []
        if let preferredName { lines.append("preferred name: \(preferredName)") }
        if let preferredTone { lines.append("preferred tone: \(preferredTone)") }
        if let preferredWorkflowStyle { lines.append("workflow style: \(preferredWorkflowStyle)") }
        lines.append(contentsOf: responsePreferences.prefix(4).map { "response preference: \($0)" })
        lines.append(contentsOf: assistantBehaviorPreferences.prefix(4).map { "assistant behavior: \($0)" })
        lines.append(contentsOf: dislikedBehaviors.prefix(4).map { "dislikes: \($0)" })
        lines.append(contentsOf: preferredUIStyle.prefix(3).map { "UI preference: \($0)" })
        lines.append(contentsOf: preferredProjectBehavior.prefix(3).map { "project behavior: \($0)" })
        lines.append(contentsOf: interactionPatterns.prefix(3).map { "interaction pattern: \($0)" })
        if aliases.isEmpty == false {
            let aliasLines = aliases.sorted { $0.key < $1.key }.prefix(5).map { "\($0.key)=\($0.value)" }
            lines.append("aliases/slang: \(aliasLines.joined(separator: ", "))")
        }
        if knownProjects.isEmpty == false {
            lines.append("known projects: \(knownProjects.prefix(6).joined(separator: ", "))")
        }
        if activeFocusAreas.isEmpty == false {
            lines.append("active focus areas: \(activeFocusAreas.prefix(5).joined(separator: ", "))")
        }
        return lines
    }

    var compactSummary: String {
        let lines = compactSummaryLines
        return lines.isEmpty ? "No approved persistent user profile context yet." : lines.joined(separator: "\n- ")
    }
}
