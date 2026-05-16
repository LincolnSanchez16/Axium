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
    struct VoiceTuning {
        var rate: Float = 0.44
        var pitchMultiplier: Float = 0.97
        var volume: Float = 0.9
    }

    @Published private(set) var isSpeaking = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onSpeechCancelled: (() -> Void)?

    private let tuning = VoiceTuning()
    private let synthesizer = AVSpeechSynthesizer()
    private lazy var selectedVoice: AVSpeechSynthesisVoice? = chooseBestVoice()

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
        utterance.voice = selectedVoice
        utterance.rate = tuning.rate
        utterance.pitchMultiplier = tuning.pitchMultiplier
        utterance.volume = tuning.volume
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func chooseBestVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let selected = voices
            .filter { $0.language.hasPrefix("en") }
            .sorted { voiceScore($0) > voiceScore($1) }
            .first
            ?? AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en")

        if let selected {
            print("Axium voice selected: \(selected.name), language: \(selected.language), quality: \(qualityDescription(selected.quality))")
        } else {
            print("Axium voice selected: system default")
        }

        return selected
    }

    private func voiceScore(_ voice: AVSpeechSynthesisVoice) -> Int {
        var score = 0

        if voice.language == "en-GB" {
            score += 1_000
        } else if voice.language.hasPrefix("en-GB") {
            score += 900
        } else if voice.language.hasPrefix("en") {
            score += 400
        }

        score += qualityScore(voice.quality) * 100

        switch voice.gender {
        case .male:
            score += 40
        case .unspecified:
            score += 25
        case .female:
            score += 10
        @unknown default:
            score += 0
        }

        let lowerName = voice.name.lowercased()
        if lowerName.contains("enhanced") || lowerName.contains("premium") {
            score += 30
        }
        if lowerName.contains("daniel") || lowerName.contains("oliver") || lowerName.contains("arthur") {
            score += 20
        }

        return score
    }

    private func qualityScore(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:
            return 3
        case .enhanced:
            return 2
        case .default:
            return 1
        @unknown default:
            return 0
        }
    }

    private func qualityDescription(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium:
            return "premium"
        case .enhanced:
            return "enhanced"
        case .default:
            return "default"
        @unknown default:
            return "unknown"
        }
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
