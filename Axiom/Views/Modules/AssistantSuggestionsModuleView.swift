//
//  AssistantSuggestionsModuleView.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import SwiftUI

struct AssistantSuggestionsModuleView: View {
    let suggestions: [String]

    var body: some View {
        ModuleCard(title: "Assistant Suggestions", systemImage: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AxiomColor.accent)
                            .padding(.top, 3)

                        Text(suggestion)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(AxiomColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
