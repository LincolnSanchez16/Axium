//
//  VoiceSessionManager.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Combine
import Foundation

enum VoiceSessionState: String, Equatable {
    case inactive
    case requestingPermission
    case listening
    case transcribing
    case thinking
    case speaking
    case interrupted
    case error
}

@MainActor
final class VoiceSessionManager: ObservableObject {
    @Published private(set) var state: VoiceSessionState = .inactive
    @Published private(set) var liveTranscript = ""
    @Published private(set) var errorMessage: String?
    @Published var isMuted = false

    private let speechRecognitionService: SpeechRecognitionService
    private let speechSynthesisService: SpeechSynthesisService
    private var onFinalTranscript: ((String) -> Void)?
    private var lastSpokenText = ""
    private var lastSubmittedTranscript = ""
    private var isSessionActive = false
    private var isHandlingBargeIn = false

    init() {
        self.speechRecognitionService = SpeechRecognitionService()
        self.speechSynthesisService = SpeechSynthesisService()
        configureCallbacks()
    }

    init(
        speechRecognitionService: SpeechRecognitionService,
        speechSynthesisService: SpeechSynthesisService
    ) {
        self.speechRecognitionService = speechRecognitionService
        self.speechSynthesisService = speechSynthesisService
        configureCallbacks()
    }

    var isActive: Bool {
        isSessionActive
    }

    var statusText: String {
        if isMuted { return "Voice muted" }

        switch state {
        case .inactive:
            return "Voice inactive"
        case .requestingPermission:
            return "Permission needed"
        case .listening:
            return "Listening"
        case .transcribing:
            return "Transcribing"
        case .thinking:
            return "Thinking"
        case .speaking:
            return "Speaking"
        case .interrupted:
            return "Interrupted"
        case .error:
            return errorMessage ?? "Mic unavailable"
        }
    }

    func startSession(onFinalTranscript: @escaping (String) -> Void) async {
        self.onFinalTranscript = onFinalTranscript
        isSessionActive = true
        isMuted = false
        errorMessage = nil
        state = .requestingPermission

        do {
            try await speechRecognitionService.requestPermissions()
            try startListening()
        } catch {
            state = .error
            errorMessage = error.localizedDescription
            isSessionActive = false
        }
    }

    func stopSession() {
        isSessionActive = false
        liveTranscript = ""
        lastSpokenText = ""
        lastSubmittedTranscript = ""
        speechSynthesisService.stopSpeaking()
        speechRecognitionService.stopListening()
        state = .inactive
    }

    func restartListening() {
        guard isSessionActive, isMuted == false else { return }
        speechSynthesisService.stopSpeaking()
        do {
            try startListening()
        } catch {
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            speechSynthesisService.stopSpeaking()
            speechRecognitionService.stopListening()
            state = .inactive
        } else if isSessionActive {
            restartListening()
        }
    }

    func markThinking() {
        guard isSessionActive, isMuted == false else { return }
        state = .thinking
    }

    func speak(_ response: String) {
        guard isSessionActive, isMuted == false else { return }

        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanResponse.isEmpty == false else {
            restartListening()
            return
        }

        lastSpokenText = cleanResponse
        liveTranscript = ""
        isHandlingBargeIn = false

        do {
            try startListening(setState: false)
        } catch {
            // Speech can still be spoken if barge-in listening is unavailable.
        }

        state = .speaking
        speechSynthesisService.speak(cleanResponse)
    }

    private func configureCallbacks() {
        speechRecognitionService.onPartialTranscript = { [weak self] transcript in
            self?.handlePartialTranscript(transcript)
        }

        speechRecognitionService.onFinalTranscript = { [weak self] transcript in
            self?.handleFinalTranscript(transcript)
        }

        speechRecognitionService.onError = { [weak self] message in
            guard let self, self.isSessionActive else { return }
            self.state = .error
            self.errorMessage = message
        }

        speechSynthesisService.onSpeechFinished = { [weak self] in
            guard let self, self.isSessionActive, self.isMuted == false else { return }
            if self.isHandlingBargeIn {
                return
            }
            self.restartListening()
        }

        speechSynthesisService.onSpeechCancelled = { [weak self] in
            guard let self, self.isSessionActive, self.isMuted == false else { return }
            if self.isHandlingBargeIn {
                self.state = .interrupted
            }
        }
    }

    private func startListening(setState: Bool = true) throws {
        try speechRecognitionService.startListening()
        if setState {
            liveTranscript = ""
            state = .listening
        }
    }

    private func handlePartialTranscript(_ transcript: String) {
        guard isSessionActive, isMuted == false else { return }
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTranscript.isEmpty == false else { return }

        if state == .speaking {
            guard isLikelySelfSpeech(cleanTranscript) == false else { return }
            isHandlingBargeIn = true
            speechSynthesisService.stopSpeaking()
            state = .interrupted
        }

        liveTranscript = cleanTranscript
        if state == .listening || state == .interrupted {
            state = .transcribing
        }
    }

    private func handleFinalTranscript(_ transcript: String) {
        guard isSessionActive, isMuted == false else { return }
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTranscript.isEmpty == false else { return }

        if isLikelySelfSpeech(cleanTranscript), state == .speaking || state == .interrupted {
            liveTranscript = ""
            return
        }

        guard cleanTranscript.caseInsensitiveCompare(lastSubmittedTranscript) != .orderedSame else {
            return
        }

        lastSubmittedTranscript = cleanTranscript
        liveTranscript = cleanTranscript
        speechRecognitionService.stopListening()
        speechSynthesisService.stopSpeaking()
        state = .thinking
        onFinalTranscript?(cleanTranscript)
    }

    private func isLikelySelfSpeech(_ transcript: String) -> Bool {
        let spoken = normalized(lastSpokenText)
        let heard = normalized(transcript)
        guard spoken.isEmpty == false, heard.count > 8 else { return false }
        return spoken.contains(heard) || heard.contains(spoken.prefix(min(spoken.count, 80)))
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .split(separator: " ")
            .joined(separator: " ")
    }
}
