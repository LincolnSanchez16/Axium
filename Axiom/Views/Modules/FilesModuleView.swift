//
//  FilesModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct FilesModuleView: View {
    let files: [ProjectFile]

    var body: some View {
        ModuleCard(title: "Files", systemImage: "shippingbox") {
            if files.isEmpty {
                EmptyStateModuleView(
                    title: "No files attached.",
                    message: "Files will appear here after a project creates or imports real local artifacts.",
                    systemImage: "doc",
                    compact: true
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(files) { file in
                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AxiomColor.accent)

                            Text(file.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AxiomColor.textPrimary)

                            Text((file.description ?? file.path).isEmpty ? "No details." : (file.description ?? file.path))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(AxiomColor.textMuted)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.04)))
                    }
                }
            }
        }
    }
}
