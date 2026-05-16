//
//  SpeechSynthesisService.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechSynthesisService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onSpeechCancelled: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText.isEmpty == false else {
            onSpeechFinished?()
            return
        }

        stopSpeaking()

        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = preferredVoice()
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.98
        utterance.volume = 0.95
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en-GB") }
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("en") }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = true
            onSpeechStarted?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onSpeechFinished?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            onSpeechCancelled?()
        }
    }
}
