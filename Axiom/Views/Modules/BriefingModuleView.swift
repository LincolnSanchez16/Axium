//
//  BriefingModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct BriefingModuleView: View {
    let message: String
    let projectCount: Int
    let highPriorityTaskCount: Int

    var body: some View {
        ModuleCard(title: "Briefing", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    BriefingStatView(title: "Projects", value: "\(projectCount)")
                    BriefingStatView(title: "High Priority", value: "\(highPriorityTaskCount)")
                    BriefingStatView(title: "Mode", value: "Local")
                }
            }
        }
    }
}

private struct BriefingStatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(AxiomColor.textPrimary)

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AxiomColor.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
    }
}
