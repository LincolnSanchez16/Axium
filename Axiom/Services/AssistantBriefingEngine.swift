//
//  AssistantBriefingEngine.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

@MainActor
struct AssistantBriefingEngine {
    func briefing(for projectStore: ProjectStore) -> String {
        briefing(for: projectStore, globalContextStore: nil)
    }

    func briefing(for projectStore: ProjectStore, globalContextStore: GlobalContextStore?) -> String {
        if let globalContextStore {
            let globalData = globalContextStore.globalBriefingData()
            if globalData.highPriorityTasks.isEmpty == false {
                return "Hey. You have \(globalData.highPriorityTasks.count) high-priority global tasks waiting, plus \(projectStore.projects.count) projects in local memory."
            }

            if globalData.reminders.isEmpty == false {
                return "Hey. \(globalData.reminders.count) reminders are waiting in global context. Want to review them or keep building?"
            }

            if globalContextStore.workingContext.recentMessages.isEmpty == false && projectStore.projects.isEmpty {
                return "I'm ready. You can keep talking freely, create a project, add a reminder, or save this thread into a project later."
            }
        }

        let highPriorityTasks = projectStore.highPriorityTasks()
        let needsAttention = projectStore.projectsNeedingAttention()
        let openQuestions = projectStore.projects.reduce(0) { $0 + $1.openQuestions.count }
        let blockers = projectStore.projects.reduce(0) { $0 + $1.blockers.filter { $0.resolvedAt == nil }.count }

        if highPriorityTasks.isEmpty == false {
            let projectCount = Set(highPriorityTasks.compactMap(\.relatedProjectId)).count
            return "Hey. You have \(highPriorityTasks.count) high-priority tasks across \(projectCount) projects. Want the quick brief?"
        }

        if blockers > 0 {
            return "Hey. \(blockers) blockers need attention. Want me to pull up the projects?"
        }

        if needsAttention.isEmpty == false || openQuestions > 0 {
            return "Hey. You have \(projectStore.projects.count) active projects. \(needsAttention.count) need attention, and \(openQuestions) open questions are waiting."
        }

        // Later this can include unread notifications, integration deltas, calendar pressure,
        // and assistant-detected project drift once real sources are connected.
        if projectStore.projects.isEmpty {
            return "Hey. I'm ready. You can talk freely, create a project, add a reminder, or save ideas into a project."
        }

        return "Hey. I found \(projectStore.projects.count) projects in local memory. Want the quick brief, or should I show what needs work?"
    }

    func response(for intent: AssistantIntent, projectStore: ProjectStore) -> String {
        response(for: intent, projectStore: projectStore, globalContextStore: nil)
    }

    func response(for intent: AssistantIntent, projectStore: ProjectStore, globalContextStore: GlobalContextStore?) -> String {
        switch intent.id {
        case .greeting:
            return briefing(for: projectStore, globalContextStore: globalContextStore)
        case .createProject:
            return "I can open a blank project instantly. You can define it through Axium as you work."
        case .viewProjects:
            return projectStore.projects.isEmpty ? "No projects yet. Want to create your first one?" : "Here are the projects I know about."
        case .openProject:
            return "Tell me which project to open, or use one of its aliases."
        case .focusConversation:
            return "Back to the conversation. Tell me what you want to focus on next."
        case .viewNotes:
            return "Opening project notes."
        case .summarizePriorities:
            return projectStore.highPriorityTasks().isEmpty ? "Nothing urgent is marked yet. I can show projects missing next actions or help you add tasks." : "Here is what needs attention first."
        case .viewTasks:
            return projectStore.allTasks().isEmpty ? "No tasks yet. Add a task to a project when you know the next move." : "Here are your current tasks."
        case .viewMetrics:
            return projectStore.metrics().isEmpty ? "No metrics are connected yet." : "Here are the metrics available from local project state."
        case .viewActivity:
            return projectStore.activityEvents().isEmpty ? "No activity has been recorded yet." : "Here is the recent project activity."
        case .viewFiles:
            return "Opening project files. I’ll only show files that exist or are attached."
        case .addNote:
            return "Tell me what to remember. If no project is active, I can keep it in global context."
        case .addTask:
            return "Tell me the task. If no project is active, I can keep it as a global task."
        case .editProject:
            return "Here are the project details you can edit."
        case .createFile:
            return "File creation is staged, but I will ask for details before writing anything."
        case .generatePDF:
            return "PDF generation is not connected yet. I can prepare the flow when local document data exists."
        case .generateMindMap:
            return "Mind map generation is not connected yet. I can prepare the structure from real notes later."
        case .connectIntegration:
            return "Integration setup is ready. Metrics will appear after a real source is connected."
        case .unknown:
            return "I can help with that. Do you want to create a project, open a project, add a task, or review priorities?"
        }
    }
}
