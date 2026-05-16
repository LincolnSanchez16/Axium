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
    @Published private(set) var settings: VoiceSettings {
        didSet { persistSettingsIfNeeded() }
    }

    private let speechRecognitionProvider: any SpeechRecognitionProvider
    private let speechSynthesisService: SpeechSynthesisService
    private let persistence: AxiumPersistenceController
    private var onFinalTranscript: ((String) -> Void)?
    private var lastSpokenText = ""
    private var lastSubmittedTranscript = ""
    private var isSessionActive = false
    private var isHandlingBargeIn = false
    private var recoveryAttempts = 0
    private var isPersistenceReady = false

    init() {
        let persistence = AxiumPersistenceController()
        let loadedSettings = persistence.load(VoiceSettings.self, from: .voiceSettings, fallback: VoiceSettings())
        self.persistence = persistence
        self.settings = loadedSettings
        self.speechRecognitionProvider = AppleSpeechRecognitionProvider()
        self.speechSynthesisService = SpeechSynthesisService(preferredProviderType: loadedSettings.ttsProviderType)
        isPersistenceReady = true
        configureCallbacks()
    }

    init(
        speechRecognitionProvider: any SpeechRecognitionProvider,
        speechSynthesisService: SpeechSynthesisService,
        persistence: AxiumPersistenceController
    ) {
        self.persistence = persistence
        self.settings = persistence.load(VoiceSettings.self, from: .voiceSettings, fallback: VoiceSettings())
        self.speechRecognitionProvider = speechRecognitionProvider
        self.speechSynthesisService = speechSynthesisService
        isPersistenceReady = true
        configureCallbacks()
    }

    var isActive: Bool {
        isSessionActive
    }

    var isMuted: Bool {
        settings.isSessionMuted
    }

    var statusText: String {
        if settings.isSessionMuted { return "Voice muted" }

        switch state {
        case .inactive:
            return settings.selectedMode == .passive ? "Passive" : "Voice inactive"
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

    func startSession(onFinalTranscript: @escaping (String) -> Void, manualActivation: Bool = false) async {
        self.onFinalTranscript = onFinalTranscript
        isSessionActive = true
        errorMessage = nil
        state = .requestingPermission

        if settings.isSessionMuted || (settings.selectedMode == .passive && manualActivation == false) {
            state = .inactive
            return
        }

        do {
            try await speechRecognitionProvider.requestPermissions()
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
        speechRecognitionProvider.stopListening()
        state = .inactive
    }

    func restartListening() {
        restartListening(manualActivation: true)
    }

    func restartListening(manualActivation: Bool) {
        guard isSessionActive, settings.isSessionMuted == false else { return }
        guard settings.selectedMode != .passive || manualActivation else {
            state = .inactive
            return
        }

        speechSynthesisService.stopSpeaking()
        do {
            try startListening()
            recoveryAttempts = 0
        } catch {
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    func toggleMute() {
        settings.isSessionMuted.toggle()
        if settings.isSessionMuted {
            speechSynthesisService.stopSpeaking()
            speechRecognitionProvider.stopListening()
            state = .inactive
        } else if isSessionActive {
            restartListening(manualActivation: settings.selectedMode != .passive)
        }
    }

    func updateMode(_ mode: VoiceMode) {
        settings.selectedMode = mode
        guard isSessionActive, settings.isSessionMuted == false else { return }

        switch mode {
        case .passive:
            speechRecognitionProvider.stopListening()
            state = .inactive
        case .interactive, .ambient:
            restartListening(manualActivation: true)
        }
    }

    func setInterruptionEnabled(_ isEnabled: Bool) {
        settings.isInterruptionEnabled = isEnabled
    }

    func setLiveTranscriptVisible(_ isVisible: Bool) {
        settings.showsLiveTranscript = isVisible
        if isVisible == false {
            liveTranscript = ""
        }
    }

    func setAutoSpeakResponses(_ isEnabled: Bool) {
        settings.autoSpeaksResponses = isEnabled
    }

    func setSpeechOutputMuted(_ isMuted: Bool) {
        settings.isSpeechOutputMuted = isMuted
        if isMuted {
            speechSynthesisService.stopSpeaking()
        }
    }

    func updateSensitivity(_ sensitivity: VoiceSensitivity) {
        settings.sensitivity = sensitivity
    }

    func updateTTSProviderType(_ providerType: TTSProviderType) {
        settings.ttsProviderType = providerType
        speechSynthesisService.updatePreferredProvider(providerType)
    }

    func markThinking() {
        guard isSessionActive, settings.isSessionMuted == false else { return }
        state = .thinking
    }

    func speak(_ response: String) {
        guard isSessionActive, settings.isSessionMuted == false else { return }

        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanResponse.isEmpty == false else {
            resumeListeningAfterResponse()
            return
        }

        guard settings.autoSpeaksResponses, settings.isSpeechOutputMuted == false else {
            resumeListeningAfterResponse()
            return
        }

        lastSpokenText = cleanResponse
        liveTranscript = ""
        isHandlingBargeIn = false

        if settings.isInterruptionEnabled {
            do {
                try startListening(setState: false)
            } catch {
                // Speech can still be spoken if barge-in listening is unavailable.
            }
        } else {
            speechRecognitionProvider.stopListening()
        }

        state = .speaking
        speechSynthesisService.speak(cleanResponse)
    }

    private func configureCallbacks() {
        speechRecognitionProvider.onPartialTranscript = { [weak self] transcript in
            self?.handlePartialTranscript(transcript)
        }

        speechRecognitionProvider.onFinalTranscript = { [weak self] transcript in
            self?.handleFinalTranscript(transcript)
        }

        speechRecognitionProvider.onError = { [weak self] message in
            guard let self, self.isSessionActive else { return }
            self.state = .error
            self.errorMessage = message
            self.recoverListeningIfNeeded()
        }

        speechSynthesisService.onSpeechFinished = { [weak self] in
            guard let self, self.isSessionActive, self.settings.isSessionMuted == false else { return }
            if self.isHandlingBargeIn {
                return
            }
            self.resumeListeningAfterResponse()
        }

        speechSynthesisService.onSpeechCancelled = { [weak self] in
            guard let self, self.isSessionActive, self.settings.isSessionMuted == false else { return }
            if self.isHandlingBargeIn {
                self.state = .interrupted
            }
        }
    }

    private func startListening(setState: Bool = true) throws {
        try speechRecognitionProvider.startListening()
        if setState {
            liveTranscript = ""
            state = .listening
        }
    }

    private func handlePartialTranscript(_ transcript: String) {
        guard isSessionActive, settings.isSessionMuted == false else { return }
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTranscript.isEmpty == false else { return }

        if state == .speaking {
            guard settings.isInterruptionEnabled else { return }
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
        guard isSessionActive, settings.isSessionMuted == false else { return }
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
        speechRecognitionProvider.stopListening()
        speechSynthesisService.stopSpeaking()
        state = .thinking
        onFinalTranscript?(cleanTranscript)
    }

    private func resumeListeningAfterResponse() {
        switch settings.selectedMode {
        case .passive:
            speechRecognitionProvider.stopListening()
            state = .inactive
        case .interactive, .ambient:
            restartListening(manualActivation: false)
        }
    }

    private func recoverListeningIfNeeded() {
        guard settings.selectedMode == .ambient,
              settings.isSessionMuted == false,
              isSessionActive,
              recoveryAttempts < 2
        else { return }

        recoveryAttempts += 1
        Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 700_000_000)
            } catch {
                return
            }

            await MainActor.run {
                self?.restartListening(manualActivation: false)
            }
        }
    }

    private func persistSettingsIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(settings, to: .voiceSettings)
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
