//
//  UserLanguageMemory.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

final class UserLanguageMemory {
    private var phraseMappings: [String: AssistantIntent.Kind]
    private var projectMappings: [String: UUID]
    private var workflowMappings: [String: String]

    init(
        phraseMappings: [String: AssistantIntent.Kind] = [
            "what needs work": .summarizePriorities,
            "pull up the calculator thing": .openProject,
            "make this a file": .createFile
        ],
        projectMappings: [String: UUID] = [:],
        workflowMappings: [String: String] = [
            "make this a file": "create_note_or_export",
            "save this": "save_to_memory",
            "remember this": "save_explicit_memory"
        ]
    ) {
        self.phraseMappings = phraseMappings
        self.projectMappings = projectMappings
        self.workflowMappings = workflowMappings
    }

    func mappedIntent(for phrase: String) -> AssistantIntent.Kind? {
        phraseMappings[normalized(phrase)]
    }

    func remember(phrase: String, intent: AssistantIntent.Kind) {
        phraseMappings[normalized(phrase)] = intent
    }

    func mappedProjectId(for phrase: String) -> UUID? {
        projectMappings[normalized(phrase)]
    }

    func rememberProjectPhrase(_ phrase: String, projectId: UUID) {
        projectMappings[normalized(phrase)] = projectId
    }

    func mappedWorkflow(for phrase: String) -> String? {
        workflowMappings[normalized(phrase)]
    }

    func rememberWorkflowPhrase(_ phrase: String, workflow: String) {
        workflowMappings[normalized(phrase)] = workflow
    }

    private func normalized(_ phrase: String) -> String {
        phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Future LLM interpretation layer should consult this memory before broader inference:
    // phrase -> intent, phrase -> project, phrase -> workflow. Later this should persist locally
    // and improve from accepted corrections, project aliases, voice transcription quirks,
    // and recurring user language patterns.
}
