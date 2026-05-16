//
//  PrioritiesModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct PrioritiesModuleView: View {
    let tasks: [ProjectTask]

    var body: some View {
        ModuleCard(title: "Priorities", systemImage: "flag") {
            if tasks.isEmpty {
                EmptyStateModuleView(
                    title: "Nothing urgent yet.",
                    message: "High-priority work will appear here after tasks are added to projects.",
                    systemImage: "flag",
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
