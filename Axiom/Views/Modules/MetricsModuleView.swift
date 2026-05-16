//
//  MetricsModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct MetricsModuleView: View {
    let metrics: [ProjectMetric]

    var body: some View {
        ModuleCard(title: "Metrics", systemImage: "chart.line.uptrend.xyaxis") {
            if metrics.isEmpty {
                EmptyStateModuleView(
                    title: "No metrics connected yet.",
                    message: "Connect Stripe or add manual revenue to view growth.",
                    systemImage: "chart.xyaxis.line",
                    compact: true
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    ForEach(metrics) { metric in
                        MetricTile(metric: metric)
                    }
                }
            }
        }
    }
}

private struct MetricTile: View {
    let metric: ProjectMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metric.category.displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.accentText)

            Text(formattedValue)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(metric.name)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AxiomColor.textSecondary)

            Text("Source: \(metric.source)")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.04)))
    }

    private var formattedValue: String {
        if metric.unit.isEmpty {
            return "\(metric.value)"
        }

        if metric.unit == "$" {
            return "\(metric.unit)\(Int(metric.value))"
        }

        return "\(metric.value) \(metric.unit)"
    }
}
