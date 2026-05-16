//
//  FlowPreviewModuleViews.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import SwiftUI

struct ProjectSummaryPreviewModuleView: View {
    let snapshot: ConversationFlowSnapshot?

    var body: some View {
        ModuleCard(title: "Project Summary Preview", systemImage: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(title: "Name", value: value(for: "name", fallback: "Waiting for project name"))
                SummaryRow(title: "Goal", value: value(for: "description", fallback: "Waiting for project goal"))
                SummaryRow(title: "Type", value: value(for: "category", fallback: "Waiting for project type"))
                SummaryRow(title: "Workspace", value: value(for: "localWorkspace", fallback: "Not decided yet"))
            }
        }
    }

    private func value(for key: String, fallback: String) -> String {
        guard let value = snapshot?.collectedData[key], value.isEmpty == false else { return fallback }
        return value
    }
}

struct WorkspacePreviewModuleView: View {
    let snapshot: ConversationFlowSnapshot?

    var body: some View {
        ModuleCard(title: "Workspace Preview", systemImage: "rectangle.3.group") {
            VStack(alignment: .leading, spacing: 13) {
                PreviewItem(title: "Project memory", detail: "Name, goal, category, and aliases are stored locally.")
                PreviewItem(title: "Starter files", detail: shouldCreateWorkspace ? "Queued for a future confirmed file action." : "Skipped unless you choose to create a workspace.")
                PreviewItem(title: "Modules", detail: "Axium will reveal notes, tasks, files, activity, and metrics only as real data appears.")
            }
        }
    }

    private var shouldCreateWorkspace: Bool {
        let value = snapshot?.collectedData["localWorkspace", default: ""] ?? ""
        return value.lowercased().contains("yes") || value.lowercased().contains("create")
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.accentText)

            Text(value)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
    }
}

private struct PreviewItem: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Text(detail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
