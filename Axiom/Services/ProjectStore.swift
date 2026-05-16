//
//  ProjectStore.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation
import Combine

@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project] {
        didSet { persistIfNeeded() }
    }

    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false

    init(projects: [Project]? = nil, persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        self.projects = projects ?? resolvedPersistence.load([Project].self, from: .projects, fallback: [])
        isPersistenceReady = true
    }

    @discardableResult
    func createProject(
        name: String,
        description: String = "",
        category: String = "",
        currentObjective: String = "",
        priority: ProjectPriority = .medium,
        aliases: [String] = [],
        tags: [String] = [],
        openQuestions: [String] = [],
        conversationMessages: [ConversationMessage] = []
    ) -> Project {
        let now = Date()
        let id = UUID()
        let cleanName = cleaned(name).isEmpty ? "Untitled Project" : cleaned(name)
        let normalizedAliases = ([cleanName] + aliases).map(normalized).filter { $0.isEmpty == false }
        let projectCreated = ActivityEvent(
            projectId: id,
            title: "Project created",
            details: cleanName,
            type: .projectCreated,
            timestamp: now
        )
        let conversation = ProjectConversation(
            title: "Project creation",
            messages: conversationMessages,
            createdAt: now,
            updatedAt: now,
            projectId: id
        )
        let health = projectHealth(
            description: description,
            currentObjective: currentObjective,
            nextActions: [],
            blockers: [],
            updatedAt: now
        )
        let project = Project(
            id: id,
            name: cleanName,
            description: description,
            category: category,
            status: .planning,
            priority: priority,
            createdAt: now,
            updatedAt: now,
            lastOpenedAt: now,
            summary: description,
            currentObjective: currentObjective,
            activityEvents: [projectCreated],
            conversations: conversationMessages.isEmpty ? [] : [conversation],
            aliases: Array(Set(normalizedAliases)),
            tags: tags,
            projectHealth: health,
            openQuestions: openQuestions,
            nextActions: currentObjective.isEmpty ? [] : [currentObjective]
        )

        projects.append(project)
        return project
    }

    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updatedProject = project
        updatedProject.updatedAt = Date()
        updatedProject.projectHealth = projectHealth(for: updatedProject)
        projects[index] = updatedProject
    }

    func updateProjectDetails(
        projectId: UUID,
        name: String,
        description: String,
        category: String,
        status: ProjectStatus,
        priority: ProjectPriority,
        currentObjective: String,
        tags: [String],
        aliases: [String]
    ) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let now = Date()
        projects[index].name = cleaned(name).isEmpty ? projects[index].name : cleaned(name)
        projects[index].description = description
        projects[index].category = category
        projects[index].status = status
        projects[index].priority = priority
        projects[index].currentObjective = currentObjective
        projects[index].tags = tags
        projects[index].aliases = Array(Set(([projects[index].name] + aliases).map(normalized).filter { $0.isEmpty == false }))
        projects[index].updatedAt = now
        projects[index].projectHealth = projectHealth(for: projects[index])
        addActivityEvent(
            ActivityEvent(projectId: projectId, title: "Project updated", details: "Core project details changed.", type: .assistantAction, timestamp: now),
            updateTimestamp: false
        )
    }

    func archiveProject(id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].status = .archived
        projects[index].updatedAt = Date()
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
    }

    func listProjects(includeArchived: Bool = false) -> [Project] {
        projects
            .filter { includeArchived || $0.status != .archived }
            .sorted { ($0.lastOpenedAt ?? $0.updatedAt) > ($1.lastOpenedAt ?? $1.updatedAt) }
    }

    @discardableResult
    func openProject(id: UUID) -> Project? {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return nil }
        let now = Date()
        projects[index].lastOpenedAt = now
        projects[index].updatedAt = now
        projects[index].activityEvents.append(
            ActivityEvent(projectId: id, title: "Project opened", details: projects[index].name, type: .projectOpened, timestamp: now)
        )
        return projects[index]
    }

    func project(id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func saveNow() {
        persistIfNeeded()
    }

    func findProject(named nameOrAlias: String) -> Project? {
        let needle = normalized(nameOrAlias)
        return projects.first { project in
            normalized(project.name) == needle || project.aliases.map(normalized).contains(needle)
        }
    }

    func findProject(in text: String) -> Project? {
        let haystack = normalized(text)
        return projects
            .sorted { $0.name.count > $1.name.count }
            .first { project in
                haystack.contains(normalized(project.name)) || project.aliases.contains { haystack.contains(normalized($0)) }
            }
    }

    func addNote(title: String, body: String, to projectId: UUID, pinned: Bool = false, source: String = "Manual") {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let now = Date()
        let cleanBody = cleaned(body)
        let note = ProjectNote(
            title: cleaned(title).isEmpty ? "Note" : cleaned(title),
            body: cleanBody,
            createdAt: now,
            updatedAt: now,
            source: source,
            pinned: pinned
        )
        projects[index].notes.append(note)
        projects[index].assistantMemory.append(
            AssistantMemoryItem(content: cleanBody, source: "Project note", confidence: 0.7, createdAt: now, updatedAt: now, projectId: projectId)
        )
        projects[index].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Note added", details: note.title, type: .noteAdded, timestamp: now)
        )
        touchProject(at: index)
    }

    func editNote(_ note: ProjectNote, projectId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let noteIndex = projects[projectIndex].notes.firstIndex(where: { $0.id == note.id })
        else { return }
        var updatedNote = note
        updatedNote.updatedAt = Date()
        projects[projectIndex].notes[noteIndex] = updatedNote
        projects[projectIndex].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Note updated", details: updatedNote.title, type: .noteUpdated)
        )
        touchProject(at: projectIndex)
    }

    func addTask(title: String, details: String = "", priority: ProjectPriority = .medium, to projectId: UUID) {
        let task = ProjectTask(title: title, details: details, priority: priority, relatedProjectId: projectId)
        addTask(task, to: projectId)
    }

    func addTask(_ task: ProjectTask, to projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        let now = Date()
        var scopedTask = task
        scopedTask.relatedProjectId = projectId
        scopedTask.updatedAt = now
        projects[index].tasks.append(scopedTask)
        if scopedTask.status != .done {
            projects[index].nextActions.append(scopedTask.title)
        }
        projects[index].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Task created", details: task.title, type: .taskCreated, timestamp: now)
        )
        touchProject(at: index)
    }

    func updateTask(_ task: ProjectTask, projectId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        var updatedTask = task
        updatedTask.updatedAt = Date()
        projects[projectIndex].tasks[taskIndex] = updatedTask
        touchProject(at: projectIndex)
    }

    func completeTask(taskId: UUID, projectId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId })
        else { return }
        let now = Date()
        projects[projectIndex].tasks[taskIndex].status = .done
        projects[projectIndex].tasks[taskIndex].completedAt = now
        projects[projectIndex].tasks[taskIndex].updatedAt = now
        projects[projectIndex].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Task completed", details: projects[projectIndex].tasks[taskIndex].title, type: .taskCompleted, timestamp: now)
        )
        touchProject(at: projectIndex)
    }

    func addMetric(_ metric: ProjectMetric, to projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].metrics.append(metric)
        projects[index].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Metric updated", details: metric.name, type: .metricUpdated)
        )
        touchProject(at: index)
    }

    func addMemoryItem(_ item: MemoryItem, to projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        var projectMemory = item
        projectMemory.projectId = projectId
        projects[index].memoryItems.append(projectMemory)
        projects[index].assistantMemory.append(
            AssistantMemoryItem(
                content: projectMemory.content,
                source: projectMemory.source.displayName,
                confidence: projectMemory.confidence == .high ? 0.9 : projectMemory.confidence == .medium ? 0.6 : 0.3,
                projectId: projectId
            )
        )
        projects[index].activityEvents.append(
            ActivityEvent(projectId: projectId, title: "Project memory saved", details: projectMemory.content, type: .assistantAction)
        )
        touchProject(at: index)
    }

    func addIntegrationPlaceholder(provider: ProjectIntegration.Provider, to projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        guard projects[index].integrations.contains(where: { $0.provider == provider }) == false else { return }
        projects[index].integrations.append(ProjectIntegration.placeholder(provider: provider, projectId: projectId))
        touchProject(at: index)
    }

    func addActivityEvent(_ event: ActivityEvent, updateTimestamp: Bool = true) {
        guard let projectId = event.projectId,
              let index = projects.firstIndex(where: { $0.id == projectId })
        else { return }
        projects[index].activityEvents.append(event)
        if updateTimestamp {
            touchProject(at: index)
        }
    }

    func highPriorityTasks() -> [ProjectTask] {
        projects
            .flatMap(\.tasks)
            .filter { task in
                (task.priority == .high || task.priority == .urgent) && task.status != .done
            }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.priority > rhs.priority
            }
    }

    func allTasks() -> [ProjectTask] {
        projects.flatMap(\.tasks).sorted { $0.updatedAt > $1.updatedAt }
    }

    func projectsNeedingAttention() -> [Project] {
        projects
            .filter { project in
                project.status != .archived &&
                (project.projectHealth != .healthy || project.priority >= .high || project.blockers.contains { $0.resolvedAt == nil })
            }
            .sorted { $0.priority > $1.priority }
    }

    func metrics(projectId: UUID? = nil) -> [ProjectMetric] {
        projects
            .filter { projectId == nil || $0.id == projectId }
            .flatMap(\.metrics)
            .sorted { $0.timestamp > $1.timestamp }
    }

    func activityEvents(projectId: UUID? = nil) -> [ActivityEvent] {
        projects
            .filter { projectId == nil || $0.id == projectId }
            .flatMap(\.activityEvents)
            .sorted { $0.timestamp > $1.timestamp }
    }

    func recentActivity(limit: Int = 10) -> [ActivityEvent] {
        Array(activityEvents().prefix(limit))
    }

    func projectBriefing(for projectId: UUID) -> String {
        guard let project = project(id: projectId) else { return "I could not find that project." }
        var parts: [String] = []
        parts.append(project.description.isEmpty ? "\(project.name) does not have a project goal yet." : project.description)
        if project.currentObjective.isEmpty == false {
            parts.append("Current objective: \(project.currentObjective).")
        }
        if project.blockers.contains(where: { $0.resolvedAt == nil }) {
            parts.append("There are \(project.blockers.filter { $0.resolvedAt == nil }.count) unresolved blockers.")
        }
        if project.openQuestions.isEmpty == false {
            parts.append("\(project.openQuestions.count) open questions still need answers.")
        }
        if project.tasks.filter({ $0.status != .done }).isEmpty {
            parts.append("There are no active tasks yet.")
        }
        return parts.joined(separator: " ")
    }

    private func touchProject(at index: Int) {
        projects[index].updatedAt = Date()
        projects[index].projectHealth = projectHealth(for: projects[index])
    }

    private func projectHealth(for project: Project) -> ProjectHealth {
        projectHealth(
            description: project.description,
            currentObjective: project.currentObjective,
            nextActions: project.tasks.filter { $0.status != .done }.map(\.title) + project.nextActions,
            blockers: project.blockers,
            updatedAt: project.updatedAt
        )
    }

    private func projectHealth(
        description: String,
        currentObjective: String,
        nextActions: [String],
        blockers: [ProjectBlocker],
        updatedAt: Date
    ) -> ProjectHealth {
        if blockers.contains(where: { $0.resolvedAt == nil }) {
            return .blocked
        }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentObjective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .needsContext
        }
        if nextActions.isEmpty {
            return .needsNextAction
        }
        if Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0 > 14 {
            return .stale
        }
        return .healthy
    }

    private func cleaned(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalized(_ value: String) -> String {
        cleaned(value).lowercased()
    }

    private func persistIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(projects, to: .projects)
    }
}

extension ProjectIntegration {
    static func placeholder(provider: Provider, projectId: UUID? = nil) -> ProjectIntegration {
        ProjectIntegration(
            name: provider.displayName,
            provider: provider,
            status: .notConnected,
            capabilities: provider.defaultCapabilities,
            projectId: projectId
        )
    }
}

extension ProjectIntegration.Provider {
    var defaultCapabilities: [String] {
        switch self {
        case .stripe:
            return ["Revenue", "MRR", "ARR", "Customer metrics", "Growth charts"]
        case .github:
            return ["Commits", "Issues", "Pull requests", "Repo activity"]
        case .gmail:
            return ["Project emails", "Follow-ups", "Briefings"]
        case .calendar:
            return ["Reminders", "Deadlines", "Scheduled work blocks"]
        case .figma:
            return ["Design files", "Comments", "Design activity"]
        case .notion:
            return ["Docs", "Databases", "Knowledge sync"]
        case .googleDrive:
            return ["Docs", "Sheets", "Slides", "Shared files"]
        case .localFiles:
            return ["Local folders", "Documents", "File activity"]
        case .customAPI:
            return ["Custom data", "Automations", "External project state"]
        }
    }
}
