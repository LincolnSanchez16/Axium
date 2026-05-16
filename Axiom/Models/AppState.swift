//
//  AppState.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

struct AxiumAppState: Equatable, Codable {
    enum LaunchMode: String, Equatable, Codable {
        case orbLaunch
        case projectFocus
    }

    var selectedProjectId: UUID?
    var launchMode: LaunchMode
    var activeFocusMode: FocusedWorkspaceMode
    var pinnedModuleIds: [String]
    var visibleModuleIds: [String]
    var recentProjectIds: [UUID]
    var commandHistory: [String]
    var lastOpenedAt: Date
    var hasCompletedLaunchIntro: Bool

    init(
        selectedProjectId: UUID? = nil,
        launchMode: LaunchMode = .orbLaunch,
        activeFocusMode: FocusedWorkspaceMode = .conversation,
        pinnedModuleIds: [String] = [],
        visibleModuleIds: [String] = [],
        recentProjectIds: [UUID] = [],
        commandHistory: [String] = [],
        lastOpenedAt: Date = Date(),
        hasCompletedLaunchIntro: Bool = false
    ) {
        self.selectedProjectId = selectedProjectId
        self.launchMode = launchMode
        self.activeFocusMode = activeFocusMode
        self.pinnedModuleIds = pinnedModuleIds
        self.visibleModuleIds = visibleModuleIds
        self.recentProjectIds = recentProjectIds
        self.commandHistory = commandHistory
        self.lastOpenedAt = lastOpenedAt
        self.hasCompletedLaunchIntro = hasCompletedLaunchIntro
    }
}

struct ModuleLayoutState: Identifiable, Equatable, Codable {
    var id: String { moduleId }
    var moduleId: String
    var positionX: Double
    var positionY: Double
    var width: Double
    var height: Double
    var isPinned: Bool
    var isVisible: Bool
    var zIndex: Double
    var lastOpenedAt: Date

    init(
        moduleId: String,
        positionX: Double,
        positionY: Double,
        width: Double,
        height: Double,
        isPinned: Bool = false,
        isVisible: Bool = true,
        zIndex: Double = 0,
        lastOpenedAt: Date = Date()
    ) {
        self.moduleId = moduleId
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.isPinned = isPinned
        self.isVisible = isVisible
        self.zIndex = zIndex
        self.lastOpenedAt = lastOpenedAt
    }
}

struct ModuleLayoutSnapshot: Equatable, Codable {
    var layouts: [ModuleLayoutState] = []
}

struct ProjectWorkspaceStashSnapshot: Identifiable, Equatable, Codable {
    var id: UUID { projectId }
    var projectId: UUID
    var modules: [WorkspaceModuleDisplay]
    var focusedMode: FocusedWorkspaceMode
    var layoutSnapshot: ModuleLayoutSnapshot
    var noteDraft: String = ""
    var taskDraft: String = ""
    var stashedAt: Date
}

struct ProjectWorkspaceStashLibrary: Equatable, Codable {
    var snapshots: [ProjectWorkspaceStashSnapshot] = []

    func snapshot(for projectId: UUID) -> ProjectWorkspaceStashSnapshot? {
        snapshots.first { $0.projectId == projectId }
    }

    mutating func upsert(_ snapshot: ProjectWorkspaceStashSnapshot) {
        if let index = snapshots.firstIndex(where: { $0.projectId == snapshot.projectId }) {
            snapshots[index] = snapshot
        } else {
            snapshots.append(snapshot)
        }
    }

    mutating func remove(projectId: UUID) {
        snapshots.removeAll { $0.projectId == projectId }
    }
}
