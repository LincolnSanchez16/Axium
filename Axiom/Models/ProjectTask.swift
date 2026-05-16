//
//  ProjectTask.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct ProjectTask: Identifiable, Equatable, Codable {
    enum Status: String, CaseIterable, Equatable, Codable {
        case todo
        case inProgress
        case blocked
        case done

        var displayName: String {
            switch self {
            case .todo:
                return "Todo"
            case .inProgress:
                return "In Progress"
            case .blocked:
                return "Blocked"
            case .done:
                return "Done"
            }
        }
    }

    let id: UUID
    var title: String
    var details: String
    var priority: ProjectPriority
    var status: Status
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var relatedProjectId: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        details: String = "",
        priority: ProjectPriority = .medium,
        status: Status = .todo,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        relatedProjectId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.priority = priority
        self.status = status
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.relatedProjectId = relatedProjectId
    }
}
