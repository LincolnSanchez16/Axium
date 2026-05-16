//
//  ProjectLibraryModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct ProjectLibraryModuleView: View {
    let projects: [Project]
    var onOpenProject: (Project) -> Void = { _ in }

    var body: some View {
        ModuleCard(title: "Project Library", systemImage: "square.grid.2x2") {
            if projects.isEmpty {
                EmptyStateModuleView(
                    title: "No projects yet.",
                    message: "Ask Axium to create a new project when you are ready.",
                    systemImage: "folder.badge.plus",
                    compact: true
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(projects) { project in
                        ProjectLibraryCard(project: project, onOpenProject: onOpenProject)
                    }
                }
            }
        }
    }
}

private struct ProjectLibraryCard: View {
    let project: Project
    let onOpenProject: (Project) -> Void

    var body: some View {
        Button {
            onOpenProject(project)
        } label: {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AxiomColor.accent)

                Spacer()

                Text(project.priority.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.accentText)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .lineLimit(2)

                Text(project.description.isEmpty ? "No description yet." : project.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineLimit(3)
            }

            HStack {
                Text(project.category.isEmpty ? "Unsorted" : project.category)
                Text("\(project.tasks.count) tasks")
                Text("\(project.notes.count) notes")
                Spacer()
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(AxiomColor.textMuted)

            HStack {
                Text(project.status.displayName)
                Spacer()
                Text("Updated \(ProjectFormatters.relativeString(from: project.updatedAt))")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AxiomColor.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }
}
