//
//  DynamicWorkspaceView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI
import Combine

struct DynamicWorkspaceView: View {
    let turn: AssistantTurn
    let messages: [ConversationMessage]
    let activeFlowSnapshot: ConversationFlowSnapshot?
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var memoryStore: MemoryStore
    @Binding var prompt: String
    let assistantState: AssistantState
    let onSubmit: () -> Void
    let onSuggestionSelected: (SuggestedReply) -> Void
    let onCreateProject: () -> Void
    let onViewProjects: () -> Void
    let onOpenProject: (Project) -> Void
    let onReturnToLanding: () -> Void

    var body: some View {
        Group {
            if turn.modules.contains(where: { $0.kind == .projectWorkspace }),
               let projectId = turn.focusedProjectId ?? turn.focusedProject?.id {
                ProjectWorkspaceView(
                    projectStore: projectStore,
                    memoryStore: memoryStore,
                    projectId: projectId,
                    initialFocusMode: turn.focusedMode,
                    messages: conversationMessages,
                    turn: turn,
                    prompt: $prompt,
                    assistantState: assistantState,
                    onSubmit: onSubmit,
                    onSuggestionSelected: onSuggestionSelected,
                    onCreateProject: onCreateProject,
                    onViewProjects: onViewProjects,
                    onOpenProject: onOpenProject,
                    onReturnToLanding: onReturnToLanding
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                VStack(spacing: 18) {
                    commandHeader

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .center, spacing: 16) {
                            AssistantConversationView(
                                messages: conversationMessages,
                                isThinking: assistantState == .thinking,
                                flowSnapshot: activeFlowSnapshot,
                                onSuggestionSelected: onSuggestionSelected
                            )
                            .frame(maxWidth: 860)

                            ForEach(visibleModules) { module in
                                moduleView(for: module)
                                    .frame(maxWidth: moduleMaxWidth(for: module))
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.985)),
                                        removal: .opacity.combined(with: .scale(scale: 0.985))
                                    ))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(AxiomColor.workspaceSurface.opacity(0.58))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: turn.id)
    }

    private var commandHeader: some View {
        HStack(spacing: 14) {
            OrbContainerView(size: 78, assistantState: assistantState)
                .transition(.scale.combined(with: .opacity))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                StatusPillView(title: "Command-driven", systemImage: "waveform", isActive: true)
                StatusPillView(title: turn.intent.displayName, systemImage: "point.topleft.down.curvedto.point.bottomright.up", isActive: true)
                if let activeFlowSnapshot {
                    StatusPillView(title: activeFlowSnapshot.title, systemImage: "arrow.triangle.turn.up.right.diamond", isActive: true)
                }
                }

                CommandInputView(
                    prompt: $prompt,
                    assistantState: assistantState,
                    placeholder: "Ask Axium what to open, create, summarize, or route...",
                    compact: true,
                    onSubmit: onSubmit
                )
                .frame(maxWidth: 660)
            }

            Spacer()

            Button(action: onReturnToLanding) {
                Image(systemName: "house")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.055))
                            .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .help("Return to landing")
        }
        .frame(maxWidth: 980)
        .padding(.horizontal, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func moduleView(for module: DynamicModule) -> some View {
        switch module.kind {
        case .briefing:
            BriefingModuleView(
                message: module.message ?? turn.response,
                projectCount: projectStore.projects.count,
                highPriorityTaskCount: projectStore.highPriorityTasks().count
            )
        case .projectLibrary:
            ProjectLibraryModuleView(projects: projectStore.listProjects(), onOpenProject: onOpenProject)
        case .projectWorkspace:
            EmptyStateModuleView(title: "No project selected.", message: "Open a project to enter its workspace.", systemImage: "folder", compact: false)
        case .projectHeader:
            if let project = currentProject {
                ProjectHeaderView(project: project, onEdit: {}, onAddNote: {}, onAddTask: {})
            }
        case .projectOverview:
            ProjectOverviewModuleView(project: currentProject)
        case .notes:
            if let project = currentProject {
                ProjectNotesModuleView(project: project, noteBody: .constant(""), projectStore: projectStore)
            } else {
                NotesModuleView(notes: [])
            }
        case .tasks:
            if let project = currentProject {
                ProjectTasksModuleView(project: project, taskTitle: .constant(""), projectStore: projectStore)
            } else {
                TasksModuleView(tasks: projectStore.allTasks())
            }
        case .priorities:
            PrioritiesModuleView(tasks: projectStore.highPriorityTasks())
        case .metrics:
            MetricsModuleView(metrics: projectStore.metrics(projectId: turn.focusedProjectId))
        case .graphs:
            GraphsModuleView(metrics: projectStore.metrics(projectId: turn.focusedProjectId), activityEvents: projectStore.activityEvents(projectId: turn.focusedProjectId))
        case .activityTimeline:
            ActivityTimelineModuleView(events: projectStore.activityEvents(projectId: turn.focusedProjectId))
        case .files:
            FilesModuleView(files: currentProject?.files ?? projectStore.projects.flatMap(\.files))
        case .integrations:
            if let project = currentProject {
                ProjectIntegrationsModuleView(project: project, projectStore: projectStore)
            } else {
                IntegrationsModuleView(integrations: projectStore.projects.flatMap(\.integrations))
            }
        case .projectMemory:
            ProjectMemoryModuleView(project: currentProjectRequired, memoryStore: memoryStore)
        case .projectDecisions:
            ProjectDecisionsModuleView(project: currentProjectRequired)
        case .projectBlockers:
            ProjectBlockersModuleView(project: currentProjectRequired)
        case .projectOpenQuestions:
            ProjectOpenQuestionsModuleView(project: currentProjectRequired)
        case .projectEdit:
            if let project = currentProject {
                ProjectEditModuleView(project: project, projectStore: projectStore)
            }
        case .addNote:
            if let project = currentProject {
                ProjectNotesModuleView(project: project, noteBody: .constant(""), projectStore: projectStore)
            }
        case .addTask:
            if let project = currentProject {
                ProjectTasksModuleView(project: project, taskTitle: .constant(""), projectStore: projectStore)
            }
        case .assistantSuggestions:
            AssistantSuggestionsModuleView(suggestions: suggestions)
        case .emptyState:
            EmptyStateModuleView(
                title: module.title,
                message: module.message ?? "No local data is available for that request yet.",
                systemImage: "tray"
            )
        case .projectCreation:
            ProjectCreationModuleView()
        case .projectSummaryPreview:
            ProjectSummaryPreviewModuleView(snapshot: activeFlowSnapshot)
        case .workspacePreview:
            WorkspacePreviewModuleView(snapshot: activeFlowSnapshot)
        case .clarification:
            EmptyStateModuleView(
                title: "What should I open?",
                message: module.message ?? turn.response,
                systemImage: "questionmark.bubble"
            )
        }
    }

    private var suggestions: [String] {
        [
            "Create a project to give Axium a real workspace to reason over.",
            "Ask what needs work after tasks exist in local project state.",
            "Connect metrics later before revenue, MRR, ARR, or profit appears."
        ]
    }

    private var visibleModules: [DynamicModule] {
        if let projectWorkspace = turn.modules.first(where: { $0.kind == .projectWorkspace }) {
            return [projectWorkspace]
        }

        if let projectLibrary = turn.modules.first(where: { $0.kind == .projectLibrary }) {
            return [projectLibrary]
        }

        let nonSuggestionModules = turn.modules.filter { $0.kind != .assistantSuggestions }
        if nonSuggestionModules.isEmpty == false {
            return nonSuggestionModules
        }

        return turn.modules
    }

    private func moduleMaxWidth(for module: DynamicModule) -> CGFloat {
        switch module.kind {
        case .projectLibrary:
            return 980
        case .projectWorkspace:
            return 920
        default:
            return 860
        }
    }

    private var conversationMessages: [ConversationMessage] {
        if messages.isEmpty == false {
            return messages
        }

        return [
            ConversationMessage(speaker: .user, text: turn.userMessage),
            ConversationMessage(speaker: .assistant, text: turn.response, suggestions: turn.suggestions)
        ].filter { $0.text.isEmpty == false }
    }

    private var currentProject: Project? {
        projectStore.project(id: turn.focusedProjectId) ?? turn.focusedProject
    }

    private var currentProjectRequired: Project {
        currentProject ?? Project(name: "No Project")
    }
}
