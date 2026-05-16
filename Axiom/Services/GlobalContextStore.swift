//
//  GlobalContextStore.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation
import Combine

@MainActor
final class GlobalContextStore: ObservableObject {
    @Published private(set) var snapshot: GlobalContextSnapshot {
        didSet { persistIfNeeded() }
    }

    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false

    init(persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        snapshot = resolvedPersistence.load(GlobalContextSnapshot.self, from: .globalContext, fallback: GlobalContextSnapshot())
        isPersistenceReady = true
    }

    var notes: [GlobalNote] { snapshot.notes }
    var tasks: [GlobalTask] { snapshot.tasks }
    var reminders: [GlobalReminder] { snapshot.reminders }
    var calendarItems: [GlobalCalendarItem] { snapshot.calendarItems }
    var workingContext: UnsavedWorkingContext { snapshot.workingContext }

    func addNote(title: String, body: String, tags: [String] = [], source: String = "Manual") {
        snapshot.notes.append(GlobalNote(title: title, body: body, tags: tags, source: source))
    }

    func updateNote(_ note: GlobalNote) {
        guard let index = snapshot.notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        snapshot.notes[index] = updated
    }

    func deleteNote(id: UUID) {
        snapshot.notes.removeAll { $0.id == id }
    }

    func addTask(title: String, details: String = "", priority: ProjectPriority = .medium, dueDate: Date? = nil) {
        snapshot.tasks.append(GlobalTask(title: title, details: details, priority: priority, dueDate: dueDate))
    }

    func updateTask(_ task: GlobalTask) {
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.updatedAt = Date()
        snapshot.tasks[index] = updated
    }

    func completeTask(id: UUID) {
        guard let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { return }
        snapshot.tasks[index].status = .done
        snapshot.tasks[index].completedAt = Date()
        snapshot.tasks[index].updatedAt = Date()
    }

    func addReminder(title: String, details: String = "", remindAt: Date? = nil, source: String = "Manual") {
        snapshot.reminders.append(GlobalReminder(title: title, details: details, remindAt: remindAt, source: source))
    }

    func addCalendarItem(title: String, details: String = "", startDate: Date, endDate: Date? = nil, location: String? = nil, source: String = "Manual") {
        snapshot.calendarItems.append(GlobalCalendarItem(title: title, details: details, startDate: startDate, endDate: endDate, location: location, source: source))
    }

    func addMemory(_ item: MemoryItem) {
        snapshot.globalMemory.append(item)
    }

    func createConversationSession(title: String, messages: [ConversationMessage], summary: String? = nil, extractedItems: [String] = []) -> GlobalConversationSession {
        let session = GlobalConversationSession(title: title, messages: messages, summary: summary, extractedItems: extractedItems)
        snapshot.conversationSessions.append(session)
        return session
    }

    func updateWorkingContext(with message: ConversationMessage) {
        snapshot.workingContext.recentMessages.append(message)
        if snapshot.workingContext.recentMessages.count > 40 {
            snapshot.workingContext.recentMessages.removeFirst(snapshot.workingContext.recentMessages.count - 40)
        }
        snapshot.workingContext.updatedAt = Date()
    }

    func saveCurrentSessionToNewProject(name: String, projectStore: ProjectStore) -> Project {
        let messages = snapshot.workingContext.recentMessages
        let transcript = messages.map { "\($0.speaker.rawValue): \($0.text)" }.joined(separator: "\n")
        let project = projectStore.createProject(
            name: name,
            description: snapshot.workingContext.currentTopic ?? "",
            currentObjective: "Review saved conversation",
            conversationMessages: messages
        )
        projectStore.addNote(title: "Saved conversation", body: transcript.isEmpty ? "Conversation transcript placeholder." : transcript, to: project.id, source: "Global conversation")
        snapshot.conversationSessions.append(
            GlobalConversationSession(title: name, messages: messages, summary: "Saved into project \(name).", savedToProjectId: project.id, extractedItems: snapshot.workingContext.extractedIdeas + snapshot.workingContext.extractedTasks)
        )
        return project
    }

    func saveCurrentSessionToExistingProject(projectId: UUID, projectStore: ProjectStore) {
        let transcript = snapshot.workingContext.recentMessages.map { "\($0.speaker.rawValue): \($0.text)" }.joined(separator: "\n")
        projectStore.addNote(title: "Saved conversation", body: transcript.isEmpty ? "Conversation transcript placeholder." : transcript, to: projectId, source: "Global conversation")
    }

    func globalBriefingData() -> (highPriorityTasks: [GlobalTask], dueSoonTasks: [GlobalTask], reminders: [GlobalReminder]) {
        (highPriorityTasks(), dueSoonTasks(), snapshot.reminders.filter { $0.status == .pending })
    }

    func highPriorityTasks() -> [GlobalTask] {
        snapshot.tasks.filter { $0.status != .done && $0.priority >= .high }
    }

    func dueSoonTasks(now: Date = Date()) -> [GlobalTask] {
        let horizon = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        return snapshot.tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return task.status != .done && dueDate <= horizon
        }
    }

    private func persistIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(snapshot, to: .globalContext)
    }
}
