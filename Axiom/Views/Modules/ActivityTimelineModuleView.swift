//
//  ActivityTimelineModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct ActivityTimelineModuleView: View {
    let events: [ActivityEvent]

    var body: some View {
        ModuleCard(title: "Activity Timeline", systemImage: "clock.arrow.circlepath") {
            if events.isEmpty {
                EmptyStateModuleView(
                    title: "No activity data yet.",
                    message: "Activity will appear as you work on projects.",
                    systemImage: "clock.arrow.circlepath",
                    compact: true
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.type.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AxiomColor.accent)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(AxiomColor.accent.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(event.title)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(AxiomColor.textPrimary)

                                    Spacer(minLength: 8)

                                    Text(ProjectFormatters.relativeString(from: event.timestamp))
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(AxiomColor.textMuted)
                                }

                                if event.details.isEmpty == false {
                                    Text(event.details)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundStyle(AxiomColor.textSecondary)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
