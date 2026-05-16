//
//  AssistantConversationView.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import SwiftUI

struct AssistantConversationView: View {
    let messages: [ConversationMessage]
    let isThinking: Bool
    let flowSnapshot: ConversationFlowSnapshot?
    let onSuggestionSelected: (SuggestedReply) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let flowSnapshot {
                FlowProgressView(snapshot: flowSnapshot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(messages) { message in
                    ConversationBubbleView(
                        message: message,
                        isLatestAssistantMessage: message.id == latestAssistantMessageId,
                        onSuggestionSelected: onSuggestionSelected
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                }

                if isThinking {
                    AssistantThinkingView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground())
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: messages)
        .animation(.easeInOut(duration: 0.22), value: isThinking)
    }

    private var latestAssistantMessageId: UUID? {
        messages.last(where: { $0.speaker == .assistant })?.id
    }
}

private struct ConversationBubbleView: View {
    let message: ConversationMessage
    let isLatestAssistantMessage: Bool
    let onSuggestionSelected: (SuggestedReply) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.speaker == .assistant {
                AssistantMark()
            }

            VStack(alignment: message.speaker == .user ? .trailing : .leading, spacing: 10) {
                Text(message.text)
                    .font(.system(size: message.speaker == .assistant ? 15 : 14, weight: .regular, design: .rounded))
                    .foregroundStyle(message.speaker == .assistant ? AxiomColor.textPrimary : AxiomColor.textSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, message.speaker == .assistant ? 0 : 14)
                    .padding(.vertical, message.speaker == .assistant ? 0 : 10)
                    .background(
                        Group {
                            if message.speaker == .user {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.white.opacity(0.055))
                            }
                        }
                    )

                if isLatestAssistantMessage {
                    SuggestedRepliesView(suggestions: message.suggestions, onSelect: onSuggestionSelected)
                }
            }
            .frame(maxWidth: 680, alignment: message.speaker == .user ? .trailing : .leading)

            if message.speaker == .user {
                Spacer(minLength: 80)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.speaker == .user ? .trailing : .leading)
    }
}

private struct AssistantMark: View {
    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AxiomColor.accent)
            .frame(width: 30, height: 30)
            .background(Circle().fill(AxiomColor.accent.opacity(0.13)))
    }
}

private struct AssistantThinkingView: View {
    var body: some View {
        HStack(spacing: 12) {
            AssistantMark()

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AxiomColor.accent.opacity(0.7))
                        .frame(width: 5, height: 5)
                        .opacity(index == 1 ? 0.55 : 0.9)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.045)))
        }
    }
}

private struct FlowProgressView: View {
    let snapshot: ConversationFlowSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textPrimary)

                Spacer()

                Text("Step \(snapshot.currentStep) of \(snapshot.totalSteps)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.06))

                    Capsule()
                        .fill(AxiomColor.accent.opacity(0.7))
                        .frame(width: max(8, proxy.size.width * snapshot.progress))
                }
            }
            .frame(height: 6)

            if snapshot.collectedData.isEmpty == false {
                Text(snapshot.collectedData.keys.sorted().joined(separator: " / "))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AxiomColor.textMuted)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.04)))
    }
}
