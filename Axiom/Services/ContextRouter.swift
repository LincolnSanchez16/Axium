//
//  ContextRouter.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct ContextRoutingResult: Equatable {
    var destination: ContextDestination
    var confidence: Double
    var reason: String
}

@MainActor
struct ContextRouter {
    func route(_ message: String, currentProjectId: UUID?, projectStore: ProjectStore) -> ContextRoutingResult {
        let input = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if input.contains("remind me") || input.contains("reminder") {
            return ContextRoutingResult(destination: .globalReminder, confidence: 0.86, reason: "Reminder language detected.")
        }

        if input.contains("party") || input.contains("meeting") || input.contains("calendar") || input.contains("saturday") {
            return ContextRoutingResult(destination: .globalCalendarItem, confidence: 0.72, reason: "Calendar-like language detected.")
        }

        if input.contains("remember that") || input.contains("i like") || input.contains("preference") {
            return ContextRoutingResult(destination: .globalMemory, confidence: 0.82, reason: "Preference or memory phrase detected.")
        }

        if input.contains("save this to project"), let currentProjectId {
            return ContextRoutingResult(destination: .existingProject(currentProjectId), confidence: 0.84, reason: "Save-to-project phrase with active project.")
        }

        if input.contains("new project") || input.contains("save this as a project") {
            return ContextRoutingResult(destination: .newProject, confidence: 0.8, reason: "New project save phrase detected.")
        }

        if input.contains("task") || input.contains("todo") || input.contains("to do") {
            if let currentProjectId {
                return ContextRoutingResult(destination: .existingProject(currentProjectId), confidence: 0.72, reason: "Task language with active project.")
            }
            return ContextRoutingResult(destination: .globalTask, confidence: 0.72, reason: "Task language without active project.")
        }

        if input.contains("note") || input.contains("save this") {
            if let currentProjectId {
                return ContextRoutingResult(destination: .existingProject(currentProjectId), confidence: 0.68, reason: "Note language with active project.")
            }
            return ContextRoutingResult(destination: .globalNote, confidence: 0.68, reason: "Note language without active project.")
        }

        if let project = projectStore.findProject(in: message) {
            return ContextRoutingResult(destination: .existingProject(project.id), confidence: 0.7, reason: "Existing project name or alias matched.")
        }

        return ContextRoutingResult(destination: .unsavedConversation, confidence: 0.55, reason: "Default to global unsaved working context.")
    }

    // Future route:
    // User message -> global context -> project context -> user language memory -> LLM intent/context
    // interpretation -> confidence -> selected destination/tool. This deterministic router is only a local foundation.
}
