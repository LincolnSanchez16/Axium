//
//  GraphsModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct GraphsModuleView: View {
    let metrics: [ProjectMetric]
    let activityEvents: [ActivityEvent]

    var body: some View {
        ModuleCard(title: "Graphs", systemImage: "chart.bar.xaxis") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                GraphPlaceholderView(
                    title: metrics.isEmpty ? "No revenue data connected yet." : "Metric graph ready",
                    message: metrics.isEmpty ? "Connect Stripe or add manual revenue to view growth." : "A chart can render here from real metric history.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )

                GraphPlaceholderView(
                    title: activityEvents.isEmpty ? "No activity data yet." : "Activity graph ready",
                    message: activityEvents.isEmpty ? "Activity will appear as you work on projects." : "A chart can render here from real activity events.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
        }
    }
}

private struct GraphPlaceholderView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)

            Spacer(minLength: 10)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)

            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .foregroundStyle(.white.opacity(0.10))
                )
        )
    }
}
