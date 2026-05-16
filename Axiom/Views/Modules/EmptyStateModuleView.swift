//
//  EmptyStateModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct EmptyStateModuleView: View {
    let title: String
    let message: String
    let systemImage: String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 20 : 26, weight: .semibold))
                .foregroundStyle(AxiomColor.accent)
                .frame(width: compact ? 38 : 46, height: compact ? 38 : 46)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AxiomColor.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: compact ? 15 : 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Text(message)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AxiomColor.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 0 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if compact == false {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.035))
                }
            }
        )
    }
}
