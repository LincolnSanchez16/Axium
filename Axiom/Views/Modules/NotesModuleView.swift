//
//  NotesModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct NotesModuleView: View {
    let notes: [ProjectNote]

    var body: some View {
        ModuleCard(title: "Notes", systemImage: "note.text") {
            if notes.isEmpty {
                EmptyStateModuleView(
                    title: "No notes yet.",
                    message: "Ask Axium to remember something after a project exists.",
                    systemImage: "note.text.badge.plus",
                    compact: true
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textPrimary)

                            Text(note.body)
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }
            }
        }
    }
}
