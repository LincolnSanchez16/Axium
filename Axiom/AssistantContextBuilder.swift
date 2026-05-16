//
//  AssistantContextBuilder.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

@MainActor
struct AssistantContextBuilder {
    func build(
        projectStore: ProjectStore,
        globalContextStore: GlobalContextStore,
        globalConversationMemoryStore: GlobalConversationMemoryStore,
        currentProjectId: UUID?,
        currentTurn: AssistantTurn,
        appState: AxiumAppState
    ) -> AIIntentContext {
        let activeProject = projectStore.project(id: currentProjectId)
        let visibleModules = Array(Set(
            currentTurn.modules.map(\.kind.rawValue)
                + appState.visibleModuleIds
                + (currentTurn.focusedMode == .conversation ? [] : [currentTurn.focusedMode.rawValue])
        )).sorted()
        let pinnedModules = Array(Set(appState.pinnedModuleIds)).sorted()
        let projectNames = projectStore.listProjects().prefix(12).map(\.name)
        let globalSummary = "\(globalContextStore.notes.count) notes, \(globalContextStore.tasks.count) tasks, \(globalContextStore.reminders.count) reminders, \(globalContextStore.calendarItems.count) calendar items."

        return AIIntentContext(
            activeProjectName: activeProject?.name,
            visibleModules: visibleModules,
            pinnedModules: pinnedModules,
            availableProjects: Array(projectNames),
            globalContextSummary: globalSummary,
            userProfileSummary: globalConversationMemoryStore.compactPromptSummary()
        )
    }
}
