//
//  ProjectCreationModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct ProjectCreationModuleView: View {
    var body: some View {
        ModuleCard(title: "Create Project", systemImage: "folder.badge.plus") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Project creation is staged.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Text("Axium will ask for a project name, description, priority, and confirmation before adding anything to local memory or the file system.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    ProjectCreationBadge(title: "No files written", systemImage: "lock")
                    ProjectCreationBadge(title: "Local only", systemImage: "externaldrive")
                }
            }
        }
    }
}

private struct ProjectCreationBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(AxiomColor.accentText)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(AxiomColor.accent.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(AxiomColor.accent.opacity(0.24), lineWidth: 1)
                )
        )
    }
}
