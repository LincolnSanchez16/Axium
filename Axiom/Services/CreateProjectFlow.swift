//
//  CreateProjectFlow.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct CreateProjectFlow: ConversationFlow, Equatable {
    enum Step: Int, CaseIterable, Equatable {
        case projectName = 1
        case description
        case category
        case currentObjective
        case priority
        case localWorkspace
        case confirmation
        case completed
    }

    let id = UUID()
    let title = "Create Project"
    private(set) var step: Step = .projectName
    private(set) var collectedData: [String: String] = [:]
    private(set) var isCancelled = false

    var currentStep: Int {
        step.rawValue
    }

    var totalSteps: Int {
        Step.allCases.count
    }

    var prompt: String {
        switch step {
        case .projectName:
            return "Absolutely. What should we call the project?"
        case .description:
            return "Nice. What is the goal of this project?"
        case .category:
            return "Got it. What kind of project is this?"
        case .currentObjective:
            return "What is the next objective for this project?"
        case .priority:
            return "How important is this right now?"
        case .localWorkspace:
            return "Should I prepare a local workspace for it later?"
        case .confirmation:
            return confirmationPrompt
        case .completed:
            return "Done. Your project is ready."
        }
    }

    var isComplete: Bool {
        step == .completed
    }

    var shouldCreateLocalWorkspace: Bool {
        let answer = collectedData["localWorkspace", default: ""].lowercased()
        return ["yes", "yeah", "yep", "create local workspace", "sure", "do it"].contains { answer.contains($0) }
    }

    var projectName: String {
        collectedData["name", default: "Untitled Project"]
    }

    var projectDescription: String {
        collectedData["description", default: ""]
    }

    var projectCategory: String {
        collectedData["category", default: ""]
    }

    var currentObjective: String {
        collectedData["currentObjective", default: ""]
    }

    var projectPriority: ProjectPriority {
        ProjectPriority(rawValue: collectedData["priority", default: ""].lowercased()) ?? .medium
    }

    var openQuestions: [String] {
        var questions: [String] = []
        if projectName.isEmpty || projectName == "Untitled Project" {
            questions.append("What should this project be called?")
        }
        if projectDescription.isEmpty {
            questions.append("What is the project goal?")
        }
        if projectCategory.isEmpty {
            questions.append("What type of project is this?")
        }
        if currentObjective.isEmpty {
            questions.append("What should happen next?")
        }
        return questions
    }

    mutating func advance(with input: String) {
        let cleanInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let flexibleInput = normalizedFallback(cleanInput)

        switch step {
        case .projectName:
            collectedData["name"] = flexibleInput
            step = .description
        case .description:
            collectedData["description"] = flexibleInput
            step = .category
        case .category:
            collectedData["category"] = flexibleInput
            step = .currentObjective
        case .currentObjective:
            collectedData["currentObjective"] = flexibleInput
            step = .priority
        case .priority:
            collectedData["priority"] = normalizedPriority(cleanInput)
            step = .localWorkspace
        case .localWorkspace:
            collectedData["localWorkspace"] = cleanInput.isEmpty ? "Skip for now" : cleanInput
            step = .confirmation
        case .confirmation:
            if isAffirmative(cleanInput) {
                complete()
            } else if isNegative(cleanInput) {
                step = .projectName
            } else {
                collectedData["confirmationNote"] = cleanInput
            }
        case .completed:
            break
        }
    }

    mutating func goBack() {
        guard let previousStep = Step(rawValue: max(1, step.rawValue - 1)) else { return }
        step = previousStep
    }

    mutating func cancel() {
        isCancelled = true
    }

    mutating func complete() {
        step = .completed
    }

    func snapshot() -> ConversationFlowSnapshot {
        ConversationFlowSnapshot(
            title: title,
            currentStep: currentStep,
            totalSteps: totalSteps,
            prompt: prompt,
            collectedData: collectedData,
            isComplete: isComplete
        )
    }

    func suggestions() -> [SuggestedReply] {
        switch step {
        case .projectName:
            return [
                SuggestedReply("Axium Calculator"),
                SuggestedReply("Skip for now", payload: "I don't know")
            ]
        case .description:
            return [
                SuggestedReply("AI-powered calculator hardware."),
                SuggestedReply("Leave blank", payload: "I don't know")
            ]
        case .category:
            return [
                SuggestedReply("Hardware"),
                SuggestedReply("App"),
                SuggestedReply("Research")
            ]
        case .currentObjective:
            return [
                SuggestedReply("Define first milestone"),
                SuggestedReply("Leave blank", payload: "I don't know")
            ]
        case .priority:
            return [
                SuggestedReply("High"),
                SuggestedReply("Medium"),
                SuggestedReply("Low")
            ]
        case .localWorkspace:
            return [
                SuggestedReply("Create local workspace", payload: "Yes"),
                SuggestedReply("Skip for now", payload: "No")
            ]
        case .confirmation:
            return [
                SuggestedReply("Confirm"),
                SuggestedReply("Start over", payload: "No")
            ]
        case .completed:
            return [
                SuggestedReply("Show projects"),
                SuggestedReply("Add notes")
            ]
        }
    }

    private var confirmationPrompt: String {
        let workspaceText = shouldCreateLocalWorkspace ? "I will mark it for a local workspace." : "I will keep it in local memory for now."
        let objectiveText = currentObjective.isEmpty ? "No current objective yet." : "Objective: \(currentObjective)."
        return "Here is what I have: \(projectName). \(projectDescription.isEmpty ? "No description yet." : projectDescription) Category: \(projectCategory.isEmpty ? "Unsorted" : projectCategory). \(objectiveText) Priority: \(projectPriority.displayName). \(workspaceText) Should I create it?"
    }

    private func normalizedFallback(_ input: String) -> String {
        let lowercased = input.lowercased()
        if input.isEmpty || lowercased == "i don't know" || lowercased == "idk" || lowercased == "not sure" {
            return ""
        }

        return input
    }

    private func isAffirmative(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        return ["yes", "yeah", "yep", "confirm", "do it", "create it", "sure"].contains { lowercased.contains($0) }
    }

    private func isNegative(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        return ["no", "start over", "restart", "not yet"].contains { lowercased.contains($0) }
    }

    private func normalizedPriority(_ input: String) -> String {
        let lowercased = input.lowercased()
        if lowercased.contains("urgent") { return ProjectPriority.urgent.rawValue }
        if lowercased.contains("high") { return ProjectPriority.high.rawValue }
        if lowercased.contains("low") { return ProjectPriority.low.rawValue }
        return ProjectPriority.medium.rawValue
    }
}
