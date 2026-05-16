//
//  TasksModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct TasksModuleView: View {
    let tasks: [ProjectTask]

    var body: some View {
        ModuleCard(title: "Tasks", systemImage: "checklist") {
            if tasks.isEmpty {
                EmptyStateModuleView(
                    title: "No tasks yet.",
                    message: "Tasks will appear after you add them to real projects.",
                    systemImage: "checklist",
                    compact: true
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(tasks) { task in
                        TaskRowView(task: task)
                    }
                }
            }
        }
    }
}

struct TaskRowView: View {
    let task: ProjectTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(task.status == .done ? Color(red: 0.42, green: 0.86, blue: 0.62) : AxiomColor.textMuted)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AxiomColor.textPrimary)

                    Text(task.priority.displayName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(task.priority >= .high ? AxiomColor.accentText : AxiomColor.textMuted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.055)))

                    Spacer(minLength: 0)
                }

                if task.details.isEmpty == false {
                    Text(task.details)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(AxiomColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
    }
}
