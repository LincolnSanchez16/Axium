//
//  ProjectWorkspaceView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import SwiftUI

struct ProjectWorkspaceView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var memoryStore: MemoryStore
    let projectId: UUID?
    let initialFocusMode: FocusedWorkspaceMode
    let messages: [ConversationMessage]
    let turn: AssistantTurn
    @Binding var prompt: String
    let assistantState: AssistantState
    let onSubmit: () -> Void
    let onSuggestionSelected: (SuggestedReply) -> Void
    let onCreateProject: () -> Void
    let onViewProjects: () -> Void
    let onOpenProject: (Project) -> Void
    let onReturnToLanding: () -> Void

    @StateObject private var moduleDisplayManager: ModuleDisplayManager
    @State private var noteBody = ""
    @State private var taskTitle = ""
    @State private var isStashAnimating = false

    init(
        projectStore: ProjectStore,
        memoryStore: MemoryStore,
        projectId: UUID?,
        initialFocusMode: FocusedWorkspaceMode = .conversation,
        messages: [ConversationMessage],
        turn: AssistantTurn,
        prompt: Binding<String>,
        assistantState: AssistantState,
        onSubmit: @escaping () -> Void,
        onSuggestionSelected: @escaping (SuggestedReply) -> Void,
        onCreateProject: @escaping () -> Void,
        onViewProjects: @escaping () -> Void,
        onOpenProject: @escaping (Project) -> Void,
        onReturnToLanding: @escaping () -> Void
    ) {
        self.projectStore = projectStore
        self.memoryStore = memoryStore
        self.projectId = projectId
        self.initialFocusMode = initialFocusMode
        self.messages = messages
        self.turn = turn
        _prompt = prompt
        self.assistantState = assistantState
        self.onSubmit = onSubmit
        self.onSuggestionSelected = onSuggestionSelected
        self.onCreateProject = onCreateProject
        self.onViewProjects = onViewProjects
        self.onOpenProject = onOpenProject
        self.onReturnToLanding = onReturnToLanding
        _moduleDisplayManager = StateObject(wrappedValue: ModuleDisplayManager(initialMode: initialFocusMode))
    }

    var body: some View {
        let project = projectStore.project(id: projectId)

        GeometryReader { proxy in
            ZStack {
                projectFieldBackground

                centeredOrbStage(project: project, size: proxy.size)

                if let project {
                    floatingPanelLayer(project: project, size: proxy.size)
                }

                VStack {
                    projectTopBar(project: project)
                            .padding(.top, 30)
                            .padding(.horizontal, 30)

                    Spacer()

                    projectCommandDeck(project: project)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 30)
                }

                if let project {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            workspaceStashButton(project: project, size: proxy.size)
                                .padding(.trailing, 30)
                                .padding(.bottom, 30)
                        }
                    }
                    .zIndex(40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                moduleDisplayManager.updateCanvasWidth(proxy.size.width)
            }
            .onChange(of: proxy.size.width) { _, width in
                moduleDisplayManager.updateCanvasWidth(width)
            }
        }
        .onChange(of: initialFocusMode) { _, newValue in
            setFocus(newValue)
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.88), value: moduleDisplayManager.modules)
    }

    private var focusMode: FocusedWorkspaceMode {
        moduleDisplayManager.focusedMode
    }

    private var projectFieldBackground: some View {
        ZStack {
            AxiomColor.workspaceSurface.opacity(0.58)
            RadialGradient(
                colors: [
                    AxiomColor.accent.opacity(0.13),
                    AxiomColor.workspaceSurface.opacity(0.20),
                    .clear
                ],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            LinearGradient(
                colors: [.white.opacity(0.035), .clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private func centeredOrbStage(project: Project?, size: CGSize) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 70)

            OrbContainerView(size: orbSize(for: size), assistantState: .idle)
                .opacity(0.94)
                .transition(.scale.combined(with: .opacity))

            centralAssistantContext(project: project)
                .frame(maxWidth: 560)

            Spacer(minLength: 150)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private func orbSize(for size: CGSize) -> CGFloat {
        min(max(min(size.width, size.height) * 0.36, 260), 360)
    }

    private func centralAssistantContext(project: Project?) -> some View {
        let assistantLine = activeAssistantLine(for: project)

        return VStack(spacing: 10) {
            Text(project?.name ?? "Axium")
                .font(.system(size: project == nil ? 72 : 28, weight: .light, design: .default))
                .tracking(2.2)
                .foregroundStyle(AxiomColor.textPrimary)
                .multilineTextAlignment(.center)

            if let assistantLine {
                Text(assistantLine)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(contextBackground(isVisible: true))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, assistantLine == nil ? 0 : 14)
    }

    private func contextBackground(isVisible: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isVisible ? .black.opacity(0.12) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isVisible ? .white.opacity(0.06) : .clear, lineWidth: 1)
            )
    }

    private func projectTopBar(project: Project?) -> some View {
        HStack(spacing: 12) {
            if let project {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        StatusPillView(title: project.status.displayName, systemImage: "circle.hexagongrid", isActive: true)
                        StatusPillView(title: project.priority.displayName, systemImage: "flag", isActive: project.priority >= .high)
                        if project.category.isEmpty == false {
                            StatusPillView(title: project.category, systemImage: "tag", isActive: false)
                        }
                    }

                    if project.currentObjective.isEmpty == false {
                        Text(project.currentObjective)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AxiomColor.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let project {
                FocusModeRail(
                    selectedMode: focusMode,
                    availableModes: availableModes(for: project),
                    isOpen: moduleDisplayManager.isVisible,
                    isPinned: moduleDisplayManager.isPinned,
                    onSelect: setFocus
                )
                .frame(maxWidth: 660)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.13))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func floatingPanelLayer(project: Project, size: CGSize) -> some View {
        ForEach(moduleDisplayManager.modules.filter { $0.state != .minimized }) { display in
            let defaultSize = CGSize(width: panelWidth(for: display.placement, in: size), height: panelHeight(for: display, in: size))
            let defaultPosition = panelPosition(for: display.placement, in: size)
            let layout = moduleDisplayManager.layout(for: display, defaultPosition: defaultPosition, defaultSize: defaultSize)
            DraggableModuleFrame(
                mode: display.mode,
                layout: layout,
                canvasSize: size,
                onMove: { position in
                    moduleDisplayManager.move(display.mode, to: position, in: size)
                },
                onResize: { moduleSize, position in
                    if let position {
                        moduleDisplayManager.resize(display.mode, to: moduleSize, anchoredAt: position, in: size)
                    } else {
                        moduleDisplayManager.resize(display.mode, to: moduleSize, in: size)
                    }
                },
                onInteractionBegan: {
                    moduleDisplayManager.beginInteractiveLayout()
                },
                onInteractionEnded: {
                    moduleDisplayManager.endInteractiveLayout()
                }
            ) {
                activeFocusPanel(display: display, project: project, size: size)
            }
            .zIndex(layout.zIndex)
                .offset(
                    x: isStashAnimating ? stashButtonCenter(in: size).x - CGFloat(layout.positionX) : 0,
                    y: isStashAnimating ? stashButtonCenter(in: size).y - CGFloat(layout.positionY) : 0
                )
                .scaleEffect(isStashAnimating ? 0.12 : 1)
                .rotationEffect(.degrees(isStashAnimating ? stashRotation(for: display.mode) : 0))
                .opacity(isStashAnimating ? 0.04 : 1)
                .allowsHitTesting(isStashAnimating == false)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .move(edge: transitionEdge(for: display.placement))),
                    removal: .opacity.combined(with: .scale(scale: 0.94))
                ))
        }
    }

    @ViewBuilder
    private func activeFocusPanel(display: WorkspaceModuleDisplay, project: Project, size: CGSize) -> some View {
        FloatingProjectModuleShell(
            mode: display.mode,
            placement: display.placement,
            isPinned: display.isPinned,
            isFocused: display.mode == focusMode,
            onPin: { moduleDisplayManager.togglePin(display.mode) },
            onClose: { moduleDisplayManager.close(display.mode) }
        ) {
            focusPane(for: display.mode, project: project)
        }
        .id(display.mode)
    }

    private func projectCommandDeck(project: Project?) -> some View {
        VStack(spacing: 10) {
            CommandInputView(
                prompt: $prompt,
                assistantState: assistantState,
                placeholder: project.map { "Command \($0.name) through Axium..." } ?? "Ask Axium what to build, open, summarize, or route...",
                compact: false,
                leadingSystemImage: "sidebar.left",
                leadingHelp: "Projects",
                leadingMenu: {
                    ProjectSwitcherPopoverView(
                        projectStore: projectStore,
                        currentProjectId: project?.id,
                        onCreateProject: onCreateProject,
                        onViewProjects: onViewProjects,
                        onOpenProject: onOpenProject
                    )
                },
                onSubmit: onSubmit
            )
            .frame(maxWidth: 660)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.black.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.055), lineWidth: 1))
        )
    }

    private func activeAssistantLine(for project: Project?) -> String? {
        if assistantState == .thinking {
            return "Thinking..."
        }

        if let latestAssistant = messages.last(where: { $0.speaker == .assistant })?.text,
           latestAssistant.isEmpty == false {
            return latestAssistant
        }

        guard let project else { return nil }

        if project.currentObjective.isEmpty == false {
            return "Current focus: \(project.currentObjective)"
        }

        if project.description.isEmpty == false {
            return "This project has a goal. It still needs a current objective."
        }

        return "This project is open. Tell Axium what to focus on first."
    }

    @ViewBuilder
    private func focusPane(for mode: FocusedWorkspaceMode, project: Project) -> some View {
        switch mode {
        case .conversation:
            EmptyView()
        case .projectOverview:
            compactOverview(project)
        case .notes:
            compactNotes(project)
        case .tasks:
            compactTasks(project)
        case .metrics:
            compactMetrics(project)
        case .files:
            compactFiles(project)
        case .activity:
            compactActivity(project)
        case .integrations:
            compactIntegrations(project)
        case .memory:
            compactMemory(project)
        case .editProject:
            ProjectFocusEditPane(project: project, projectStore: projectStore)
        }
    }

    private func compactOverview(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(project.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .lineLimit(1)

            if project.description.isEmpty == false {
                Text(project.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineLimit(3)
            }

            if project.currentObjective.isEmpty == false {
                CompactInfoRow(title: "Objective", detail: project.currentObjective, systemImage: "target")
            }

            HStack(spacing: 7) {
                StatusPillView(title: project.status.displayName, systemImage: "circle.hexagongrid", isActive: true)
                StatusPillView(title: project.priority.displayName, systemImage: "flag", isActive: project.priority >= .high)
            }

            if project.openQuestions.isEmpty == false {
                CompactInfoRow(title: "Open questions", detail: "\(project.openQuestions.count) waiting", systemImage: "questionmark.circle")
            }
        }
    }

    private func compactNotes(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Tell Axium what to remember...", text: $noteBody, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .lineLimit(2)
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.05)))

                Button {
                    guard noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                    projectStore.addNote(title: "Project note", body: noteBody, to: project.id)
                    noteBody = ""
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
            }

            if project.notes.isEmpty {
                CompactInfoRow(title: "No notes yet", detail: "Capture context when it matters.", systemImage: "note.text")
            } else {
                ForEach(project.notes.sorted { $0.updatedAt > $1.updatedAt }.prefix(4)) { note in
                    CompactInfoRow(title: note.title, detail: note.body, systemImage: note.pinned ? "pin.fill" : "note.text")
                }
            }
        }
    }

    private func compactTasks(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Add a next action...", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.05)))

                Button {
                    guard taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                    projectStore.addTask(title: taskTitle, to: project.id)
                    taskTitle = ""
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
            }

            let activeTasks = project.tasks.filter { $0.status != .done }.sorted { $0.priority > $1.priority }
            if activeTasks.isEmpty {
                CompactInfoRow(title: "No active tasks", detail: "Add one when the next move is clear.", systemImage: "checklist")
            } else {
                ForEach(activeTasks.prefix(5)) { task in
                    HStack(spacing: 8) {
                        Button {
                            projectStore.completeTask(taskId: task.id, projectId: project.id)
                        } label: {
                            Image(systemName: "circle")
                                .foregroundStyle(AxiomColor.textMuted)
                        }
                        .buttonStyle(.plain)

                        CompactInfoRow(title: task.title, detail: task.priority.displayName, systemImage: "flag")
                    }
                }
            }
        }
    }

    private func compactMetrics(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if project.metrics.isEmpty {
                CompactInfoRow(title: "No metrics connected", detail: "Connect Stripe or add manual numbers later.", systemImage: "chart.xyaxis.line")
            } else {
                ForEach(project.metrics.prefix(5)) { metric in
                    CompactInfoRow(title: metric.name, detail: "\(metric.value) \(metric.unit) • \(metric.source)", systemImage: "number")
                }
            }
        }
    }

    private func compactFiles(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            if project.files.isEmpty {
                CompactInfoRow(title: "No files attached", detail: "Real local artifacts will appear here.", systemImage: "doc")
            } else {
                ForEach(project.files.prefix(5)) { file in
                    CompactInfoRow(title: file.name, detail: file.description ?? file.path, systemImage: "doc.text")
                }
            }
        }
    }

    private func compactActivity(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if project.activityEvents.isEmpty {
                CompactInfoRow(title: "No recent activity", detail: "Activity appears as you work.", systemImage: "clock")
            } else {
                ForEach(project.activityEvents.sorted { $0.timestamp > $1.timestamp }.prefix(4)) { event in
                    CompactInfoRow(title: event.title, detail: ProjectFormatters.relativeString(from: event.timestamp), systemImage: event.type.systemImage)
                }
            }
        }
    }

    private func compactIntegrations(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ProjectIntegration.Provider.allCases.prefix(5), id: \.self) { provider in
                HStack {
                    CompactInfoRow(title: provider.displayName, detail: "Not connected", systemImage: "link")
                    Spacer()
                    Button("Later") {
                        projectStore.addIntegrationPlaceholder(provider: provider, to: project.id)
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .buttonStyle(.plain)
                    .foregroundStyle(AxiomColor.accentText)
                }
            }
        }
    }

    private func compactMemory(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let memories = memoryStore.projectContext(projectId: project.id) + project.memoryItems
            if memories.isEmpty {
                CompactInfoRow(title: "Memory is empty", detail: "Axium will learn only from reviewable context.", systemImage: "brain")
            } else {
                ForEach(memories.prefix(4)) { memory in
                    CompactInfoRow(title: memory.category, detail: memory.content, systemImage: "brain")
                }
            }

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    MemoryMiniAction(title: "Remember", systemImage: "plus.circle")
                    MemoryMiniAction(title: "Save to Project", systemImage: "folder.badge.plus")
                }
                HStack(spacing: 7) {
                    MemoryMiniAction(title: "Mark Preference", systemImage: "slider.horizontal.3")
                    MemoryMiniAction(title: "Add Context", systemImage: "text.badge.plus")
                }
            }
        }
    }

    private func workspaceStashButton(project: Project, size: CGSize) -> some View {
        let hasStash = moduleDisplayManager.hasStashedWorkspace(for: project.id)

        return Button {
            toggleWorkspaceStash(for: project, in: size)
        } label: {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.28))
                    .background(.ultraThinMaterial.opacity(0.42), in: Circle())
                    .overlay(Circle().stroke(AxiomColor.accent.opacity(hasStash ? 0.3 : 0.16), lineWidth: 1))
                    .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)

                Image(systemName: hasStash ? "folder.badge.plus" : "folder.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(hasStash ? AxiomColor.accentText : AxiomColor.textPrimary)
                    .scaleEffect(isStashAnimating ? 0.92 : 1)

                Image(systemName: hasStash ? "arrow.up" : "arrow.down")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(AxiomColor.workspaceSurface)
                    .offset(x: 4, y: 2)
            }
            .frame(width: 58, height: 58)
            .overlay {
                Circle()
                    .stroke(AxiomColor.accent.opacity(isStashAnimating ? 0.35 : 0), lineWidth: 1)
                    .scaleEffect(isStashAnimating ? 1.35 : 1)
                    .opacity(isStashAnimating ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isStashAnimating)
        .scaleEffect(isStashAnimating ? 1.08 : 1)
        .help(hasStash ? "Restore project view" : "Autosave and stash project view")
    }

    private func toggleWorkspaceStash(for project: Project, in size: CGSize) {
        if moduleDisplayManager.hasStashedWorkspace(for: project.id) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                if let snapshot = moduleDisplayManager.restoreStashedWorkspace(projectId: project.id) {
                    noteBody = snapshot.noteDraft
                    taskTitle = snapshot.taskDraft
                }
            }
            return
        }

        projectStore.saveNow()
        memoryStore.saveNow()

        withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
            isStashAnimating = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                moduleDisplayManager.stashWorkspace(projectId: project.id, noteDraft: noteBody, taskDraft: taskTitle)
                isStashAnimating = false
            }
        }
    }

    private func stashButtonCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width - 59, y: size.height - 59)
    }

    private func stashRotation(for mode: FocusedWorkspaceMode) -> Double {
        switch mode {
        case .notes, .metrics, .memory:
            return -7
        case .tasks, .files, .activity:
            return 6
        case .integrations, .projectOverview, .editProject:
            return 4
        case .conversation:
            return 0
        }
    }

    private func setFocus(_ mode: FocusedWorkspaceMode) {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.88)) {
            moduleDisplayManager.open(mode)
        }
    }

    private func availableModes(for project: Project) -> [FocusedWorkspaceMode] {
        [.notes, .tasks, .metrics, .files, .activity, .integrations, .memory, .projectOverview, .editProject]
    }

    private func panelWidth(for placement: WorkspaceModulePlacement, in size: CGSize) -> CGFloat {
        switch placement {
        case .bottomSide:
            return min(620, max(440, size.width * 0.44))
        case .sideExpanded:
            return min(460, max(340, size.width * 0.34))
        default:
            return min(380, max(270, size.width * 0.28))
        }
    }

    private func panelHeight(for display: WorkspaceModuleDisplay, in size: CGSize) -> CGFloat {
        if display.mode == .editProject {
            return min(560, max(460, size.height * 0.64))
        }

        let placement = display.placement
        switch placement {
        case .bottomSide:
            return min(360, max(220, size.height * 0.38))
        case .sideExpanded:
            return min(520, max(340, size.height * 0.58))
        default:
            return min(420, max(280, size.height * 0.44))
        }
    }

    private func panelPosition(for placement: WorkspaceModulePlacement, in size: CGSize) -> CGPoint {
        let sideWidth = panelWidth(for: placement, in: size)
        let sideInset = sideWidth / 2 + 30
        let upperY = min(max(218, size.height * 0.29), size.height - 360)
        let lowerY = max(size.height - 300, 300)

        switch placement {
        case .upperLeft:
            return CGPoint(x: sideInset, y: upperY)
        case .lowerLeft:
            return CGPoint(x: sideInset, y: lowerY)
        case .upperRight:
            return CGPoint(x: size.width - sideInset, y: upperY)
        case .lowerRight:
            return CGPoint(x: size.width - sideInset, y: lowerY)
        case .bottomSide:
            return CGPoint(x: size.width / 2, y: max(size.height - 258, 360))
        case .sideExpanded:
            return CGPoint(x: size.width - sideInset, y: size.height / 2)
        }
    }

    private func transitionEdge(for placement: WorkspaceModulePlacement) -> Edge {
        switch placement {
        case .upperLeft, .lowerLeft:
            return .leading
        case .upperRight, .lowerRight, .sideExpanded:
            return .trailing
        case .bottomSide:
            return .bottom
        }
    }
}

private enum ModuleResizeCorner {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var widthSign: CGFloat {
        switch self {
        case .topLeading, .bottomLeading:
            return -1
        case .topTrailing, .bottomTrailing:
            return 1
        }
    }

    var heightSign: CGFloat {
        switch self {
        case .topLeading, .topTrailing:
            return -1
        case .bottomLeading, .bottomTrailing:
            return 1
        }
    }
}

private struct InvisibleResizeCorner: View {
    var size: CGFloat = 22

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .help("Resize module")
    }
}

private struct DraggableModuleFrame<Content: View>: View {
    let mode: FocusedWorkspaceMode
    let layout: ModuleLayoutState
    let canvasSize: CGSize
    let onMove: (CGPoint) -> Void
    let onResize: (CGSize, CGPoint?) -> Void
    let onInteractionBegan: () -> Void
    let onInteractionEnded: () -> Void
    @ViewBuilder let content: Content

    @State private var dragOrigin: CGPoint?
    @State private var resizeOrigin: CGSize?
    @State private var resizePositionOrigin: CGPoint?
    @State private var livePosition: CGPoint?
    @State private var liveSize: CGSize?
    @State private var isResizing = false

    var body: some View {
        content
            .frame(width: renderedSize.width, height: renderedSize.height)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .gesture(moveGesture, including: .gesture)
            .overlay(alignment: .topLeading) {
                InvisibleResizeCorner()
                    .offset(x: -8, y: -8)
                    .gesture(resizeGesture(corner: .topLeading))
            }
            .overlay(alignment: .topTrailing) {
                InvisibleResizeCorner(size: 18)
                    .offset(x: 10, y: -10)
                    .gesture(resizeGesture(corner: .topTrailing))
            }
            .overlay(alignment: .bottomLeading) {
                InvisibleResizeCorner()
                    .offset(x: -8, y: 8)
                    .gesture(resizeGesture(corner: .bottomLeading))
            }
            .overlay(alignment: .bottomTrailing) {
                InvisibleResizeCorner()
                    .offset(x: 8, y: 8)
                    .gesture(resizeGesture(corner: .bottomTrailing))
            }
            .position(renderedPosition)
            .transaction { transaction in
                if dragOrigin != nil || resizeOrigin != nil {
                    transaction.animation = nil
                }
            }
            .help("\(mode.displayName) module")
    }

    private var renderedPosition: CGPoint {
        livePosition ?? CGPoint(x: layout.positionX, y: layout.positionY)
    }

    private var renderedSize: CGSize {
        liveSize ?? CGSize(width: CGFloat(layout.width), height: CGFloat(layout.height))
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard isResizing == false, resizeOrigin == nil else { return }
                if dragOrigin == nil {
                    onInteractionBegan()
                    dragOrigin = renderedPosition
                }
                guard let dragOrigin else { return }
                let delta = CGSize(
                    width: value.location.x - value.startLocation.x,
                    height: value.location.y - value.startLocation.y
                )
                livePosition = clampedPosition(
                    CGPoint(
                        x: dragOrigin.x + delta.width,
                        y: dragOrigin.y + delta.height
                    ),
                    size: renderedSize
                )
            }
            .onEnded { _ in
                if let livePosition {
                    onMove(livePosition)
                }
                dragOrigin = nil
                onInteractionEnded()
                livePosition = nil
            }
    }

    private func resizeGesture(corner: ModuleResizeCorner) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                isResizing = true
                if resizeOrigin == nil {
                    onInteractionBegan()
                    resizeOrigin = renderedSize
                }
                if resizePositionOrigin == nil {
                    resizePositionOrigin = renderedPosition
                }
                guard let resizeOrigin, let resizePositionOrigin else { return }

                let cursorDelta = CGSize(
                    width: value.location.x - value.startLocation.x,
                    height: value.location.y - value.startLocation.y
                )
                let horizontalDelta = cursorDelta.width * corner.widthSign
                let verticalDelta = cursorDelta.height * corner.heightSign
                let nextWidth = resizeOrigin.width + horizontalDelta
                let nextHeight = resizeOrigin.height + verticalDelta
                let resolvedWidth = min(max(nextWidth, 260), max(280, canvasSize.width - 60))
                let resolvedHeight = min(max(nextHeight, 180), max(220, canvasSize.height - 96))
                let widthChange = resolvedWidth - resizeOrigin.width
                let heightChange = resolvedHeight - resizeOrigin.height
                let nextPosition = CGPoint(
                    x: resizePositionOrigin.x + (widthChange * corner.widthSign / 2),
                    y: resizePositionOrigin.y + (heightChange * corner.heightSign / 2)
                )

                let resolvedSize = CGSize(width: resolvedWidth, height: resolvedHeight)
                liveSize = resolvedSize
                livePosition = clampedPosition(nextPosition, size: resolvedSize)
            }
            .onEnded { _ in
                if let liveSize {
                    onResize(liveSize, livePosition)
                }
                resizeOrigin = nil
                resizePositionOrigin = nil
                isResizing = false
                onInteractionEnded()
                livePosition = nil
                liveSize = nil
            }
    }

    private func clampedPosition(_ position: CGPoint, size: CGSize) -> CGPoint {
        let edgeInset: CGFloat = 30
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        return CGPoint(
            x: min(max(position.x, halfWidth + edgeInset), max(halfWidth + edgeInset, canvasSize.width - halfWidth - edgeInset)),
            y: min(max(position.y, halfHeight + edgeInset), max(halfHeight + edgeInset, canvasSize.height - halfHeight - edgeInset))
        )
    }
}

private extension Array where Element == FocusedWorkspaceMode {
    mutating func insert(_ mode: FocusedWorkspaceMode, after existingMode: FocusedWorkspaceMode) {
        guard contains(mode) == false else { return }
        if let index = firstIndex(of: existingMode) {
            insert(mode, at: index + 1)
        } else {
            append(mode)
        }
    }
}

struct FocusedProjectHeaderView: View {
    let project: Project
    let focusMode: FocusedWorkspaceMode
    let onFocus: (FocusedWorkspaceMode) -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StatusPillView(title: project.status.displayName, systemImage: "circle.hexagongrid", isActive: true)
                    StatusPillView(title: project.priority.displayName, systemImage: "flag", isActive: project.priority >= .high)
                    StatusPillView(title: focusMode.displayName, systemImage: focusMode.systemImage, isActive: true)
                }

                VStack(spacing: 6) {
                    Text(project.name)
                        .font(.system(size: 24, weight: .medium, design: .default))
                        .tracking(1.1)
                        .foregroundStyle(AxiomColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(contextLine)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                FocusQuickAction(title: "Show notes", mode: .notes, onFocus: onFocus)
                FocusQuickAction(title: "Show tasks", mode: .tasks, onFocus: onFocus)
                FocusQuickAction(title: "Overview", mode: .projectOverview, onFocus: onFocus)
                FocusQuickAction(title: "Back to conversation", mode: .conversation, onFocus: onFocus)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(CardBackground())
    }

    private var contextLine: String {
        let objective = project.currentObjective.isEmpty ? project.description : project.currentObjective
        let fallback = "No current objective yet. Ask Axium to help define the next move."
        let updated = "Updated \(ProjectFormatters.relativeString(from: project.updatedAt))"
        let category = project.category.isEmpty ? "Unsorted" : project.category
        return "\(objective.isEmpty ? fallback : objective) • \(category) • \(updated)"
    }
}

private struct FocusQuickAction: View {
    let title: String
    let mode: FocusedWorkspaceMode
    let onFocus: (FocusedWorkspaceMode) -> Void

    var body: some View {
        Button {
            onFocus(mode)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.accentText)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(AxiomColor.accent.opacity(0.11))
                        .overlay(Capsule().stroke(AxiomColor.accent.opacity(0.18), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CompactInfoRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .lineLimit(1)

                if detail.isEmpty == false {
                    Text(detail)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

private struct MemoryMiniAction: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(AxiomColor.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.045)))
            .help("Memory management placeholder")
    }
}

private struct ProjectFocusEditPane: View {
    let project: Project
    @ObservedObject var projectStore: ProjectStore

    @State private var name: String
    @State private var description: String
    @State private var category: String
    @State private var currentObjective: String
    @State private var status: ProjectStatus
    @State private var priority: ProjectPriority

    init(project: Project, projectStore: ProjectStore) {
        self.project = project
        self.projectStore = projectStore
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description)
        _category = State(initialValue: project.category)
        _currentObjective = State(initialValue: project.currentObjective)
        _status = State(initialValue: project.status)
        _priority = State(initialValue: project.priority)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                InspectorTextField(title: "Name", text: $name)
                InspectorTextField(title: "Description", text: $description, lineLimit: 3)
                InspectorTextField(title: "Type", text: $category)
                InspectorTextField(title: "Objective", text: $currentObjective, lineLimit: 3)
            }

            Divider()
                .overlay(.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    InspectorPicker(title: "Status", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }

                    InspectorPicker(title: "Priority", selection: $priority) {
                        ForEach(ProjectPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }

                Button {
                    projectStore.updateProjectDetails(
                        projectId: project.id,
                        name: name,
                        description: description,
                        category: category,
                        status: status,
                        priority: priority,
                        currentObjective: currentObjective,
                        tags: project.tags,
                        aliases: project.aliases
                    )
                } label: {
                    Label("Save Changes", systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct InspectorTextField: View {
    let title: String
    @Binding var text: String
    var lineLimit: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted)

            TextField(title, text: $text, axis: lineLimit > 1 ? .vertical : .horizontal)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .lineLimit(1...lineLimit)
                .padding(.horizontal, 11)
                .padding(.vertical, lineLimit > 1 ? 10 : 9)
                .frame(minHeight: lineLimit > 1 ? 58 : 38, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.white.opacity(0.052))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))
                )
        }
    }
}

private struct InspectorPicker<Content: View, Selection: Hashable>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted)

            Picker(title, selection: $selection) {
                content
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProjectHeaderView: View {
    let project: Project
    let onEdit: () -> Void
    let onAddNote: () -> Void
    let onAddTask: () -> Void

    var body: some View {
        FocusedProjectHeaderView(project: project, focusMode: .projectOverview) { mode in
            switch mode {
            case .editProject:
                onEdit()
            case .notes:
                onAddNote()
            case .tasks:
                onAddTask()
            default:
                break
            }
        }
    }
}

private struct FocusModeRail: View {
    let selectedMode: FocusedWorkspaceMode
    let availableModes: [FocusedWorkspaceMode]
    let isOpen: (FocusedWorkspaceMode) -> Bool
    let isPinned: (FocusedWorkspaceMode) -> Bool
    let onSelect: (FocusedWorkspaceMode) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(availableModes, id: \.self) { mode in
                Button {
                    onSelect(mode)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(shortLabel(for: mode))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        if isPinned(mode) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(buttonForeground(for: mode))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(minWidth: mode == .integrations ? 92 : 66)
                    .background(
                        Capsule()
                            .fill(buttonFill(for: mode))
                            .overlay(Capsule().stroke(buttonStroke(for: mode), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .help(mode.contextPrompt)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func shortLabel(for mode: FocusedWorkspaceMode) -> String {
        switch mode {
        case .projectOverview: return "Overview"
        case .editProject: return "Edit"
        default: return mode.displayName
        }
    }

    private func buttonForeground(for mode: FocusedWorkspaceMode) -> Color {
        if mode == selectedMode { return AxiomColor.accentText }
        if isOpen(mode) { return AxiomColor.textPrimary }
        return AxiomColor.textMuted
    }

    private func buttonFill(for mode: FocusedWorkspaceMode) -> Color {
        if mode == selectedMode { return AxiomColor.accent.opacity(0.16) }
        if isOpen(mode) { return .white.opacity(0.075) }
        return .white.opacity(0.035)
    }

    private func buttonStroke(for mode: FocusedWorkspaceMode) -> Color {
        if mode == selectedMode { return AxiomColor.accent.opacity(0.28) }
        if isOpen(mode) { return .white.opacity(0.12) }
        return .white.opacity(0.055)
    }
}

private struct FloatingProjectModuleShell<Content: View>: View {
    let mode: FocusedWorkspaceMode
    let placement: WorkspaceModulePlacement
    let isPinned: Bool
    let isFocused: Bool
    let onPin: () -> Void
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AxiomColor.accent)

                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Spacer(minLength: 0)

                Button(action: onPin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isPinned ? AxiomColor.accentText : AxiomColor.textMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin module" : "Pin module")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AxiomColor.textMuted)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help("Close module")
            }

            ScrollView(showsIndicators: false) {
                content
                    .padding(.bottom, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AxiomColor.cardSurface.opacity(isFocused ? 0.78 : 0.66))
                .background(.ultraThinMaterial.opacity(0.32), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isFocused ? AxiomColor.accent.opacity(0.18) : .white.opacity(0.075), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isFocused ? 0.25 : 0.18), radius: isFocused ? 28 : 20, x: 0, y: 16)
        )
    }
}

private struct ProjectConversationFocusView: View {
    let project: Project
    let onFocus: (FocusedWorkspaceMode) -> Void

    var body: some View {
        ModuleCard(title: "Current Focus", systemImage: "sparkles") {
            VStack(alignment: .center, spacing: 16) {
                Text(projectBrief)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620)

                HStack(spacing: 8) {
                    if project.openQuestions.isEmpty == false {
                        FocusQuickAction(title: "Open questions", mode: .memory, onFocus: onFocus)
                    }
                    if project.tasks.contains(where: { $0.status != .done }) {
                        FocusQuickAction(title: "What needs work?", mode: .tasks, onFocus: onFocus)
                    }
                    FocusQuickAction(title: "Add note", mode: .notes, onFocus: onFocus)
                    FocusQuickAction(title: "Show activity", mode: .activity, onFocus: onFocus)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var projectBrief: String {
        if project.currentObjective.isEmpty == false {
            return "You’re in \(project.name). Current focus: \(project.currentObjective)"
        }

        if project.description.isEmpty == false {
            return "You’re in \(project.name). I know the goal, but this project still needs a current objective."
        }

        return "You’re in \(project.name). This workspace is ready, but it still needs a goal and first next action."
    }
}

struct ProjectEditModuleView: View {
    let project: Project
    @ObservedObject var projectStore: ProjectStore

    @State private var name: String
    @State private var description: String
    @State private var category: String
    @State private var status: ProjectStatus
    @State private var priority: ProjectPriority
    @State private var currentObjective: String
    @State private var tags: String
    @State private var aliases: String

    init(project: Project, projectStore: ProjectStore) {
        self.project = project
        self.projectStore = projectStore
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description)
        _category = State(initialValue: project.category)
        _status = State(initialValue: project.status)
        _priority = State(initialValue: project.priority)
        _currentObjective = State(initialValue: project.currentObjective)
        _tags = State(initialValue: project.tags.joined(separator: ", "))
        _aliases = State(initialValue: project.aliases.joined(separator: ", "))
    }

    var body: some View {
        ModuleCard(title: "Edit Project", systemImage: "slider.horizontal.3") {
            VStack(spacing: 12) {
                ProjectTextField(title: "Name", text: $name)
                ProjectTextField(title: "Description", text: $description)
                ProjectTextField(title: "Type", text: $category)
                ProjectTextField(title: "Current Objective", text: $currentObjective)

                HStack(spacing: 12) {
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(ProjectPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                }

                ProjectTextField(title: "Tags", text: $tags)
                ProjectTextField(title: "Aliases", text: $aliases)

                Button {
                    projectStore.updateProjectDetails(
                        projectId: project.id,
                        name: name,
                        description: description,
                        category: category,
                        status: status,
                        priority: priority,
                        currentObjective: currentObjective,
                        tags: commaList(tags),
                        aliases: commaList(aliases)
                    )
                } label: {
                    Label("Save Project", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func commaList(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
    }
}

private struct ProjectTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted)

            TextField(title, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.045)))
        }
    }
}

struct ProjectNotesModuleView: View {
    let project: Project
    @Binding var noteBody: String
    @ObservedObject var projectStore: ProjectStore

    var body: some View {
        ModuleCard(title: "Notes", systemImage: "note.text") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Tell Axium what to remember...", text: $noteBody, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AxiomColor.textPrimary)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.045)))

                    Button {
                        guard noteBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                        projectStore.addNote(title: "Project note", body: noteBody, to: project.id)
                        noteBody = ""
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if project.notes.isEmpty {
                    EmptyStateModuleView(title: "No notes yet.", message: "Tell Axium what to remember.", systemImage: "note.text.badge.plus", compact: true)
                } else {
                    ForEach(project.notes.sorted { $0.pinned && !$1.pinned || $0.updatedAt > $1.updatedAt }) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(note.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.textPrimary)
                                if note.pinned {
                                    Image(systemName: "pin.fill").foregroundStyle(AxiomColor.accent)
                                }
                                Spacer()
                                Text(ProjectFormatters.relativeString(from: note.updatedAt))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(AxiomColor.textMuted)
                            }
                            Text(note.body)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }
            }
        }
    }
}

struct ProjectTasksModuleView: View {
    let project: Project
    @Binding var taskTitle: String
    @ObservedObject var projectStore: ProjectStore

    var body: some View {
        ModuleCard(title: "Tasks", systemImage: "checklist") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Add a next action...", text: $taskTitle)
                        .textFieldStyle(.plain)
                        .foregroundStyle(AxiomColor.textPrimary)
                        .padding(11)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.045)))

                    Button {
                        guard taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
                        projectStore.addTask(title: taskTitle, to: project.id)
                        taskTitle = ""
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if project.tasks.isEmpty {
                    EmptyStateModuleView(title: "No tasks yet.", message: "Add a task when you know the next move.", systemImage: "checklist", compact: true)
                } else {
                    ForEach(project.tasks.sorted { $0.updatedAt > $1.updatedAt }) { task in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                projectStore.completeTask(taskId: task.id, projectId: project.id)
                            } label: {
                                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.status == .done ? Color.green : AxiomColor.textMuted)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.textPrimary)
                                if task.details.isEmpty == false {
                                    Text(task.details)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundStyle(AxiomColor.textSecondary)
                                }
                            }
                            Spacer()
                            Text(task.priority.displayName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(task.priority >= .high ? AxiomColor.accentText : AxiomColor.textMuted)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }
            }
        }
    }
}

struct ProjectFilesModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Files", systemImage: "shippingbox") {
            if project.files.isEmpty {
                EmptyStateModuleView(title: "No files attached yet.", message: "Files will appear here after a project creates or imports real local artifacts.", systemImage: "doc", compact: true)
            } else {
                ForEach(project.files) { file in
                    SummaryLine(title: file.name, detail: file.description ?? file.path, systemImage: "doc.text")
                }
            }
        }
    }
}

struct ProjectMetricsModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Metrics", systemImage: "chart.line.uptrend.xyaxis") {
            if project.metrics.isEmpty {
                EmptyStateModuleView(title: "No metrics connected yet.", message: "Connect Stripe, add manual numbers, or hide this module.", systemImage: "chart.xyaxis.line", compact: true)
            } else {
                ForEach(project.metrics) { metric in
                    SummaryLine(title: metric.name, detail: "\(metric.value) \(metric.unit) - \(metric.source)", systemImage: "number")
                }
            }
        }
    }
}

struct ProjectGraphsModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Graphs", systemImage: "chart.bar.xaxis") {
            if project.metrics.isEmpty && project.activityEvents.isEmpty {
                EmptyStateModuleView(title: "No graphable data yet.", message: "Add metrics or connect an integration to unlock graphs.", systemImage: "chart.bar", compact: true)
            } else {
                EmptyStateModuleView(title: "Chart-ready data exists.", message: "Swift Charts can render revenue, activity, time worked, tasks, or progress here once a graph type is selected.", systemImage: "chart.line.uptrend.xyaxis", compact: true)
            }
        }
    }
}

struct ProjectIntegrationsModuleView: View {
    let project: Project
    @ObservedObject var projectStore: ProjectStore

    var body: some View {
        ModuleCard(title: "Integrations", systemImage: "link") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                ForEach(ProjectIntegration.Provider.allCases, id: \.self) { provider in
                    let existing = project.integrations.first { $0.provider == provider }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(provider.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textPrimary)
                            Spacer()
                            Text(existing?.status.displayName ?? "Not Connected")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textMuted)
                        }

                        Text(provider.defaultCapabilities.joined(separator: ", "))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(AxiomColor.textSecondary)
                            .lineLimit(3)

                        Button("Connect later") {
                            projectStore.addIntegrationPlaceholder(provider: provider, to: project.id)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AxiomColor.accentText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                }
            }
        }
    }
}

struct ProjectActivityTimelineView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Activity", systemImage: "clock.arrow.circlepath") {
            if project.activityEvents.isEmpty {
                EmptyStateModuleView(title: "No recent activity.", message: "Activity will appear as you work on this project.", systemImage: "clock", compact: true)
            } else {
                ForEach(project.activityEvents.sorted { $0.timestamp > $1.timestamp }) { event in
                    SummaryLine(title: event.title, detail: event.details.isEmpty ? ProjectFormatters.relativeString(from: event.timestamp) : event.details, systemImage: event.type.systemImage)
                }
            }
        }
    }
}

struct ProjectMemoryModuleView: View {
    let project: Project
    @ObservedObject var memoryStore: MemoryStore

    var body: some View {
        ModuleCard(title: "Assistant Memory", systemImage: "brain.head.profile") {
            let combinedMemory = project.assistantMemory
            if combinedMemory.isEmpty && project.memoryItems.isEmpty && memoryStore.projectContext(projectId: project.id).isEmpty {
                EmptyStateModuleView(title: "No assistant memory yet.", message: "Later, Axium can save important context here as it learns the project. Memory should stay reviewable, editable, and removable.", systemImage: "brain", compact: true)
            } else {
                ForEach(combinedMemory) { item in
                    SummaryLine(title: item.source, detail: item.content, systemImage: "sparkles")
                }
                ForEach(memoryStore.projectContext(projectId: project.id)) { item in
                    SummaryLine(title: item.category, detail: item.content, systemImage: "brain")
                }
            }
        }
    }
}

struct ProjectDecisionsModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Decisions", systemImage: "checkmark.seal") {
            if project.decisions.isEmpty {
                EmptyStateModuleView(title: "No decisions logged.", message: "Important choices will appear here when you ask Axium to remember them.", systemImage: "checkmark.seal", compact: true)
            } else {
                ForEach(project.decisions) { decision in
                    SummaryLine(title: decision.title, detail: decision.details, systemImage: "checkmark.seal")
                }
            }
        }
    }
}

struct ProjectBlockersModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Blockers", systemImage: "exclamationmark.triangle") {
            let activeBlockers = project.blockers.filter { $0.resolvedAt == nil }
            if activeBlockers.isEmpty {
                EmptyStateModuleView(title: "No blockers.", message: "If something is stuck, tell Axium and it will track it here.", systemImage: "checkmark.circle", compact: true)
            } else {
                ForEach(activeBlockers) { blocker in
                    SummaryLine(title: blocker.title, detail: blocker.details, systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}

struct ProjectOpenQuestionsModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Open Questions", systemImage: "questionmark.bubble") {
            if project.openQuestions.isEmpty {
                EmptyStateModuleView(title: "No open questions.", message: "Missing context from skipped setup answers will appear here.", systemImage: "questionmark.bubble", compact: true)
            } else {
                ForEach(project.openQuestions, id: \.self) { question in
                    SummaryLine(title: question, detail: "Unanswered", systemImage: "questionmark.circle")
                }
            }
        }
    }
}

struct ProjectSuggestionsModuleView: View {
    let project: Project

    var body: some View {
        ModuleCard(title: "Axium Suggestions", systemImage: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    SummaryLine(title: suggestion, detail: "", systemImage: "sparkle")
                }
            }
        }
    }

    private var suggestions: [String] {
        var output: [String] = []
        if project.description.isEmpty {
            output.append("Add a project goal so future briefings know what success means.")
        }
        if project.currentObjective.isEmpty {
            output.append("Set a current objective to make next actions easier.")
        }
        if project.tasks.filter({ $0.status != .done }).isEmpty {
            output.append("Add one next action to keep the project moving.")
        }
        if project.metrics.isEmpty {
            output.append("Metrics are empty. Connect data later only when there is a real source.")
        }
        return output.isEmpty ? ["Project context looks usable. Ask for a brief when you want a summary."] : output
    }
}

private struct SummaryLine: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AxiomColor.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                if detail.isEmpty == false {
                    Text(detail)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.035)))
    }
}
