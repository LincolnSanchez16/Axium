//
//  ProjectOverviewModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct ProjectOverviewModuleView: View {
    let project: Project?

    var body: some View {
        ModuleCard(title: "Project Overview", systemImage: "rectangle.and.text.magnifyingglass") {
            if let project {
                VStack(alignment: .leading, spacing: 10) {
                    Text(project.name)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AxiomColor.textPrimary)
                        .lineLimit(1)

                    if project.description.isEmpty == false {
                        Text(project.description)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(AxiomColor.textSecondary)
                            .lineSpacing(3)
                            .lineLimit(3)
                    }

                    if project.currentObjective.isEmpty == false {
                        Text(project.currentObjective)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AxiomColor.accentText)
                            .lineLimit(2)
                    }

                    HStack(spacing: 7) {
                        StatusPillView(title: project.status.displayName, systemImage: "circle.hexagongrid", isActive: true)
                        StatusPillView(title: project.priority.displayName, systemImage: "flag", isActive: project.priority >= .high)
                        if project.category.isEmpty == false {
                            StatusPillView(title: project.category, systemImage: "tag", isActive: false)
                        }
                    }
                }
            } else {
                EmptyStateModuleView(
                    title: "No project selected.",
                    message: "Ask to view projects or open a project by name.",
                    systemImage: "folder",
                    compact: true
                )
            }
        }
    }
}
