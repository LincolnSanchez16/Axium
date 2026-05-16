//
//  MemoryModuleView.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import SwiftUI

struct MemoryModuleView: View {
    @ObservedObject var memoryStore: MemoryStore
    var project: Project?

    var body: some View {
        ModuleCard(title: "Memory", systemImage: "brain.head.profile") {
            VStack(alignment: .leading, spacing: 12) {
                if memories.isEmpty {
                    EmptyStateModuleView(
                        title: "Memory is empty for now.",
                        message: "Axium will gradually learn your workflows, projects, and preferences over time. You will be able to review, edit, or delete memories before this becomes persistent.",
                        systemImage: "brain",
                        compact: true
                    )
                } else {
                    ForEach(memories) { memory in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(memory.category)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.accentText)

                                Spacer()

                                Text(memory.confidence.displayName)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.textMuted)
                            }

                            Text(memory.content)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        MemoryActionChip(title: "Remember", systemImage: "plus.circle")
                        MemoryActionChip(title: "Save to Project", systemImage: "folder.badge.plus")
                    }

                    HStack(spacing: 8) {
                        MemoryActionChip(title: "Mark Preference", systemImage: "slider.horizontal.3")
                        MemoryActionChip(title: "Add Context", systemImage: "text.badge.plus")
                    }
                }
            }
        }
    }

    private var memories: [MemoryItem] {
        if let project {
            return memoryStore.projectContext(projectId: project.id) + project.memoryItems
        }

        return memoryStore.globalPreferences()
    }
}

private struct MemoryActionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(AxiomColor.textMuted)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.045)))
            .help("Memory management placeholder")
    }
}
