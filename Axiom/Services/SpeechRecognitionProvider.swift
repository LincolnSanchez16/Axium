//
//  SpeechRecognitionProvider.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

@MainActor
protocol SpeechRecognitionProvider: AnyObject {
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var isAvailable: Bool { get }

    func requestPermissions() async throws
    func startListening() throws
    func stopListening()
}

// Future WhisperKit setup:
// 1. Add the WhisperKit Swift Package.
// 2. Download/select a local Whisper model appropriate for the Mac.
// 3. Stream microphone audio into this provider.
// 4. Emit partial/final transcripts through SpeechRecognitionProvider callbacks.
// 5. Keep VoiceSessionManager unchanged so Apple Speech and WhisperKit can swap cleanly.
@MainActor
final class WhisperKitSpeechRecognitionProvider: SpeechRecognitionProvider {
    enum WhisperKitSpeechRecognitionProviderError: LocalizedError {
        case notInstalled

        var errorDescription: String? {
            "WhisperKit is not integrated yet."
        }
    }

    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?

    var isAvailable: Bool { false }

    func requestPermissions() async throws {
        throw WhisperKitSpeechRecognitionProviderError.notInstalled
    }

    func startListening() throws {
        throw WhisperKitSpeechRecognitionProviderError.notInstalled
    }

    func stopListening() {}
}
