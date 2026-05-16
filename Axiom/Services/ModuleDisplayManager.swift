//
//  ModuleDisplayManager.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation
import Combine
import CoreGraphics

enum WorkspaceModulePlacement: String, CaseIterable, Equatable, Codable {
    case upperLeft
    case lowerLeft
    case upperRight
    case lowerRight
    case bottomSide
    case sideExpanded
}

enum WorkspaceModuleDisplayState: String, Equatable, Codable {
    case temporary
    case pinned
    case minimized
    case focused
}

struct WorkspaceModuleDisplay: Identifiable, Equatable, Codable {
    var id: FocusedWorkspaceMode { mode }
    var mode: FocusedWorkspaceMode
    var placement: WorkspaceModulePlacement
    var state: WorkspaceModuleDisplayState
    var openedAt: Date
    var lastFocusedAt: Date

    var isPinned: Bool {
        state == .pinned
    }
}

@MainActor
final class ModuleDisplayManager: ObservableObject {
    @Published private(set) var modules: [WorkspaceModuleDisplay]
    @Published private(set) var focusedMode: FocusedWorkspaceMode
    @Published private(set) var layoutSnapshot: ModuleLayoutSnapshot {
        didSet { persistLayoutIfNeeded() }
    }
    @Published private(set) var stashLibrary: ProjectWorkspaceStashLibrary
    private var canvasWidth: CGFloat
    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false
    private var isLayoutInteractionActive = false

    init(initialMode: FocusedWorkspaceMode = .conversation, persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        self.modules = []
        self.focusedMode = .conversation
        self.layoutSnapshot = resolvedPersistence.load(ModuleLayoutSnapshot.self, from: .moduleLayout, fallback: ModuleLayoutSnapshot())
        self.stashLibrary = resolvedPersistence.load(ProjectWorkspaceStashLibrary.self, from: .projectWorkspaceStashes, fallback: ProjectWorkspaceStashLibrary())
        self.canvasWidth = 1440
        isPersistenceReady = true
        if initialMode != .conversation {
            open(initialMode)
        }
    }

    func updateCanvasWidth(_ width: CGFloat) {
        guard abs(canvasWidth - width) > 1 else { return }
        canvasWidth = width
        rebalance()
    }

    func open(_ mode: FocusedWorkspaceMode) {
        if mode == .conversation {
            focusedMode = .conversation
            collapseTemporaryModules()
            return
        }

        focusedMode = mode

        if let index = modules.firstIndex(where: { $0.mode == mode }) {
            modules[index].state = modules[index].isPinned ? .pinned : .focused
            modules[index].lastFocusedAt = Date()
        } else {
            modules.append(
                WorkspaceModuleDisplay(
                    mode: mode,
                    placement: preferredPlacement(for: mode),
                    state: .focused,
                    openedAt: Date(),
                    lastFocusedAt: Date()
                )
            )
        }

        syncLayoutVisibility(for: mode, isVisible: true)
        updateLayout(for: mode) { layout in
            layout.isPinned = modules.first(where: { $0.mode == mode })?.isPinned ?? false
            layout.zIndex = 12
            layout.lastOpenedAt = Date()
        }
        rebalance()
    }

    func close(_ mode: FocusedWorkspaceMode) {
        modules.removeAll { $0.mode == mode }
        syncLayoutVisibility(for: mode, isVisible: false)
        if focusedMode == mode {
            focusedMode = modules.sorted { $0.lastFocusedAt > $1.lastFocusedAt }.first?.mode ?? .conversation
        }
        rebalance()
    }

    func togglePin(_ mode: FocusedWorkspaceMode) {
        guard let index = modules.firstIndex(where: { $0.mode == mode }) else { return }
        modules[index].state = modules[index].isPinned ? .temporary : .pinned
        modules[index].lastFocusedAt = Date()
        let isPinned = modules[index].isPinned
        updateLayout(for: mode) { layout in
            layout.isPinned = isPinned
        }
        rebalance()
    }

    func isPinned(_ mode: FocusedWorkspaceMode) -> Bool {
        modules.first(where: { $0.mode == mode })?.isPinned ?? false
    }

    func isVisible(_ mode: FocusedWorkspaceMode) -> Bool {
        modules.contains { $0.mode == mode && $0.state != .minimized }
    }

    func display(for mode: FocusedWorkspaceMode) -> WorkspaceModuleDisplay? {
        modules.first { $0.mode == mode }
    }

    func visibleModules() -> [WorkspaceModuleDisplay] {
        rebalance()
        return modules
            .filter { $0.state != .minimized }
            .sorted { lhs, rhs in
                placementRank(lhs.placement) == placementRank(rhs.placement)
                    ? lhs.lastFocusedAt > rhs.lastFocusedAt
                    : placementRank(lhs.placement) < placementRank(rhs.placement)
            }
    }

    func layout(for display: WorkspaceModuleDisplay, defaultPosition: CGPoint, defaultSize: CGSize) -> ModuleLayoutState {
        if let existing = layoutSnapshot.layouts.first(where: { $0.moduleId == display.mode.rawValue }) {
            return clamped(existing, fallbackPosition: defaultPosition, fallbackSize: defaultSize)
        }

        let layout = ModuleLayoutState(
            moduleId: display.mode.rawValue,
            positionX: defaultPosition.x,
            positionY: defaultPosition.y,
            width: defaultSize.width,
            height: defaultSize.height,
            isPinned: display.isPinned,
            isVisible: display.state != .minimized,
            zIndex: display.mode == focusedMode ? 8 : 5,
            lastOpenedAt: display.lastFocusedAt
        )
        upsert(layout)
        return layout
    }

    func move(_ mode: FocusedWorkspaceMode, to position: CGPoint, in canvasSize: CGSize) {
        updateLayout(for: mode) { layout in
            let halfWidth = layout.width / 2
            let halfHeight = layout.height / 2
            layout.positionX = min(max(position.x, halfWidth + 16), max(halfWidth + 16, canvasSize.width - halfWidth - 16))
            layout.positionY = min(max(position.y, halfHeight + 16), max(halfHeight + 16, canvasSize.height - halfHeight - 16))
            layout.lastOpenedAt = Date()
        }
    }

    func resize(_ mode: FocusedWorkspaceMode, to size: CGSize, in canvasSize: CGSize) {
        updateLayout(for: mode) { layout in
            layout.width = min(max(size.width, 260), max(280, canvasSize.width - 48))
            layout.height = min(max(size.height, 180), max(220, canvasSize.height - 96))
            layout.lastOpenedAt = Date()
        }
    }

    func resize(_ mode: FocusedWorkspaceMode, to size: CGSize, anchoredAt position: CGPoint, in canvasSize: CGSize) {
        updateLayout(for: mode) { layout in
            let resolvedWidth = min(max(size.width, 260), max(280, canvasSize.width - 48))
            let resolvedHeight = min(max(size.height, 180), max(220, canvasSize.height - 96))
            let halfWidth = resolvedWidth / 2
            let halfHeight = resolvedHeight / 2

            layout.width = resolvedWidth
            layout.height = resolvedHeight
            layout.positionX = min(max(position.x, halfWidth + 16), max(halfWidth + 16, canvasSize.width - halfWidth - 16))
            layout.positionY = min(max(position.y, halfHeight + 16), max(halfHeight + 16, canvasSize.height - halfHeight - 16))
            layout.lastOpenedAt = Date()
        }
    }

    func beginInteractiveLayout() {
        isLayoutInteractionActive = true
    }

    func endInteractiveLayout() {
        isLayoutInteractionActive = false
        persistLayoutIfNeeded()
    }

    func hasStashedWorkspace(for projectId: UUID?) -> Bool {
        guard let projectId else { return false }
        return stashLibrary.snapshot(for: projectId) != nil
    }

    func stashWorkspace(projectId: UUID?, noteDraft: String = "", taskDraft: String = "") {
        guard let projectId else { return }
        let openModuleIds = Set(modules.map { moduleId(for: $0.mode) })
        let snapshot = ProjectWorkspaceStashSnapshot(
            projectId: projectId,
            modules: modules,
            focusedMode: focusedMode,
            layoutSnapshot: layoutSnapshot,
            noteDraft: noteDraft,
            taskDraft: taskDraft,
            stashedAt: Date()
        )

        stashLibrary.upsert(snapshot)
        persistStashesIfNeeded()

        modules.removeAll()
        focusedMode = .conversation
        layoutSnapshot.layouts = layoutSnapshot.layouts.map { layout in
            var updated = layout
            if openModuleIds.contains(layout.moduleId) {
                updated.isVisible = false
            }
            return updated
        }
    }

    @discardableResult
    func restoreStashedWorkspace(projectId: UUID?) -> ProjectWorkspaceStashSnapshot? {
        guard let projectId, let snapshot = stashLibrary.snapshot(for: projectId) else { return nil }
        layoutSnapshot = snapshot.layoutSnapshot
        modules = snapshot.modules
        focusedMode = snapshot.focusedMode
        stashLibrary.remove(projectId: projectId)
        persistStashesIfNeeded()
        rebalance()
        persistLayoutIfNeeded()
        return snapshot
    }

    private func collapseTemporaryModules() {
        modules.removeAll { $0.isPinned == false }
        layoutSnapshot.layouts = layoutSnapshot.layouts.map { layout in
            var updated = layout
            if modules.contains(where: { $0.mode.rawValue == layout.moduleId }) == false && updated.isPinned == false {
                updated.isVisible = false
            }
            return updated
        }
    }

    private func rebalance() {
        assignPlacements()

        let limit = maxVisibleModules(for: canvasWidth)
        while modules.filter({ $0.state != .minimized }).count > limit {
            guard let collapseIndex = modules
                .enumerated()
                .filter({ $0.element.isPinned == false && $0.element.mode != focusedMode && $0.element.state != .minimized })
                .sorted(by: { $0.element.openedAt < $1.element.openedAt })
                .first?
                .offset
            else {
                break
            }
            modules[collapseIndex].state = .minimized
            syncLayoutVisibility(for: modules[collapseIndex].mode, isVisible: false)
        }

        if let focusedIndex = modules.firstIndex(where: { $0.mode == focusedMode && $0.state == .minimized }) {
            modules[focusedIndex].state = .focused
        }
    }

    private func assignPlacements() {
        var used: Set<WorkspaceModulePlacement> = []
        let orderedModes = modules
            .filter { $0.state != .minimized }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                if lhs.mode == focusedMode { return true }
                if rhs.mode == focusedMode { return false }
                return lhs.lastFocusedAt > rhs.lastFocusedAt
            }
            .map(\.mode)

        for mode in orderedModes {
            guard let index = modules.firstIndex(where: { $0.mode == mode }) else { continue }
            let placement = firstAvailablePlacement(for: mode, used: used)
            modules[index].placement = placement
            used.insert(placement)
            if modules[index].isPinned == false {
                modules[index].state = mode == focusedMode ? .focused : .temporary
            }
        }
    }

    private func firstAvailablePlacement(for mode: FocusedWorkspaceMode, used: Set<WorkspaceModulePlacement>) -> WorkspaceModulePlacement {
        let preferences = placementPreferences(for: mode)
        return preferences.first { used.contains($0) == false } ?? .sideExpanded
    }

    private func preferredPlacement(for mode: FocusedWorkspaceMode) -> WorkspaceModulePlacement {
        placementPreferences(for: mode).first ?? .upperRight
    }

    private func placementPreferences(for mode: FocusedWorkspaceMode) -> [WorkspaceModulePlacement] {
        switch mode {
        case .notes:
            return [.upperLeft, .lowerLeft, .bottomSide]
        case .memory:
            return [.lowerLeft, .upperLeft, .bottomSide]
        case .tasks:
            return [.upperRight, .lowerRight, .bottomSide]
        case .activity:
            return [.lowerRight, .upperRight, .bottomSide]
        case .metrics:
            return [.bottomSide, .lowerRight, .lowerLeft]
        case .files:
            return [.lowerRight, .upperRight, .bottomSide]
        case .integrations:
            return [.bottomSide, .upperRight, .lowerRight]
        case .projectOverview:
            return [.bottomSide, .upperLeft, .upperRight]
        case .editProject:
            return [.upperRight, .bottomSide, .lowerRight]
        case .conversation:
            return []
        }
    }

    private func maxVisibleModules(for canvasWidth: CGFloat) -> Int {
        if canvasWidth < 1120 { return 4 }
        if canvasWidth < 1380 { return 6 }
        return 8
    }

    private func placementRank(_ placement: WorkspaceModulePlacement) -> Int {
        switch placement {
        case .upperLeft: return 0
        case .upperRight: return 1
        case .lowerLeft: return 2
        case .lowerRight: return 3
        case .bottomSide: return 4
        case .sideExpanded: return 5
        }
    }

    private func moduleId(for mode: FocusedWorkspaceMode) -> String {
        mode.rawValue
    }

    private func syncLayoutVisibility(for mode: FocusedWorkspaceMode, isVisible: Bool) {
        updateLayout(for: mode) { layout in
            layout.isVisible = isVisible
            layout.zIndex = mode == focusedMode ? 12 : layout.zIndex
            layout.lastOpenedAt = Date()
        }
    }

    private func updateLayout(for mode: FocusedWorkspaceMode, mutate: (inout ModuleLayoutState) -> Void) {
        let id = moduleId(for: mode)
        var layout = layoutSnapshot.layouts.first(where: { $0.moduleId == id }) ?? ModuleLayoutState(
            moduleId: id,
            positionX: canvasWidth / 2,
            positionY: 320,
            width: 340,
            height: 260
        )
        mutate(&layout)
        upsert(layout)
    }

    private func upsert(_ layout: ModuleLayoutState) {
        if let index = layoutSnapshot.layouts.firstIndex(where: { $0.moduleId == layout.moduleId }) {
            layoutSnapshot.layouts[index] = layout
        } else {
            layoutSnapshot.layouts.append(layout)
        }
    }

    private func clamped(_ layout: ModuleLayoutState, fallbackPosition: CGPoint, fallbackSize: CGSize) -> ModuleLayoutState {
        var output = layout
        if output.width <= 0 { output.width = fallbackSize.width }
        if output.height <= 0 { output.height = fallbackSize.height }
        let halfWidth = output.width / 2
        let halfHeight = output.height / 2
        output.positionX = min(max(output.positionX, halfWidth + 16), max(halfWidth + 16, canvasWidth - halfWidth - 16))
        output.positionY = max(output.positionY, halfHeight + 16)
        return output
    }

    private func persistLayoutIfNeeded() {
        guard isPersistenceReady, isLayoutInteractionActive == false else { return }
        persistence.save(layoutSnapshot, to: .moduleLayout)
    }

    private func persistStashesIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(stashLibrary, to: .projectWorkspaceStashes)
    }

    // Future adaptive workspace hook:
    // Axium should learn which modules the user keeps open together, which modules get pinned,
    // preferred density, and common spatial pairings such as Notes + Tasks or Metrics + Files.
    // That memory can later seed initial placements and overflow behavior without hardcoding it here.
}
