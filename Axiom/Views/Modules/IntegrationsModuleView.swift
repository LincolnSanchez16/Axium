//
//  IntegrationsModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct IntegrationsModuleView: View {
    let integrations: [ProjectIntegration]

    var body: some View {
        ModuleCard(title: "Integrations", systemImage: "link") {
            if integrations.isEmpty {
                EmptyStateModuleView(
                    title: "No integrations connected.",
                    message: "Connect Stripe, GitHub, Notion, or another real source before Axium shows synced data.",
                    systemImage: "link.badge.plus",
                    compact: true
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(integrations) { integration in
                        HStack(spacing: 12) {
                            Image(systemName: "link")
                                .foregroundStyle(AxiomColor.accent)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(AxiomColor.accent.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(integration.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AxiomColor.textPrimary)

                                Text(integration.status.displayName)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(AxiomColor.textMuted)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }
            }
        }
    }
}
