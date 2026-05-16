//
//  SpeechRecognitionService.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class AppleSpeechRecognitionProvider: NSObject, ObservableObject, SpeechRecognitionProvider {
    struct EndpointingConfiguration: Equatable {
        var minUtteranceLength: Int = 2
        var silenceTimeout: TimeInterval = 1.7
        var maxUtteranceDuration: TimeInterval = 28
        var partialTranscriptDebounce: TimeInterval = 0.22
        var incompletePhraseExtraDelay: TimeInterval = 0.85
    }

    enum AppleSpeechRecognitionProviderError: LocalizedError {
        case microphoneDenied
        case speechRecognitionDenied
        case recognizerUnavailable
        case audioInputUnavailable

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                return "Microphone permission is needed for voice mode."
            case .speechRecognitionDenied:
                return "Speech recognition permission is needed for voice mode."
            case .recognizerUnavailable:
                return "Speech recognition is unavailable right now."
            case .audioInputUnavailable:
                return "No microphone input is available."
            }
        }
    }

    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let endpointing: EndpointingConfiguration
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var endpointTask: Task<Void, Never>?
    private var latestTranscript = ""
    private var lastEmittedPartialTranscript = ""
    private var lastPartialEmitAt: Date?
    private var lastTranscriptUpdateAt: Date?
    private var utteranceStartedAt: Date?
    private var activeRecognitionID: UUID?

    override init() {
        self.endpointing = EndpointingConfiguration()
        super.init()
    }

    init(endpointing: EndpointingConfiguration) {
        self.endpointing = endpointing
        super.init()
    }

    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    func requestPermissions() async throws {
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            throw AppleSpeechRecognitionProviderError.speechRecognitionDenied
        }

        let microphoneAllowed = await requestMicrophoneAuthorization()
        guard microphoneAllowed else {
            throw AppleSpeechRecognitionProviderError.microphoneDenied
        }

        guard isAvailable else {
            throw AppleSpeechRecognitionProviderError.recognizerUnavailable
        }
    }

    func startListening() throws {
        guard isAvailable else {
            throw AppleSpeechRecognitionProviderError.recognizerUnavailable
        }

        stopListening()
        latestTranscript = ""
        lastEmittedPartialTranscript = ""
        lastPartialEmitAt = nil
        lastTranscriptUpdateAt = nil
        utteranceStartedAt = Date()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let recognitionID = UUID()
        activeRecognitionID = recognitionID

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw AppleSpeechRecognitionProviderError.audioInputUnavailable
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                guard self.activeRecognitionID == recognitionID else { return }

                if let result {
                    self.handleRecognitionResult(result)
                }

                if let error {
                    self.onError?(error.localizedDescription)
                    self.stopListening()
                }
            }
        }
    }

    func stopListening() {
        endpointTask?.cancel()
        endpointTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        activeRecognitionID = nil
        lastTranscriptUpdateAt = nil
        utteranceStartedAt = nil
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard transcript.isEmpty == false else { return }

        let transcriptChanged = transcript.caseInsensitiveCompare(latestTranscript) != .orderedSame
        latestTranscript = transcript

        if transcriptChanged {
            lastTranscriptUpdateAt = Date()
            emitPartialTranscriptIfNeeded(transcript)
        }

        scheduleEndpointCheck()
    }

    private func submitLatestTranscript() {
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard transcript.isEmpty == false else { return }

        guard transcript.count >= endpointing.minUtteranceLength else {
            scheduleEndpointCheck(extraDelay: endpointing.incompletePhraseExtraDelay)
            return
        }

        let now = Date()
        let stableFor = now.timeIntervalSince(lastTranscriptUpdateAt ?? now)
        let utteranceDuration = now.timeIntervalSince(utteranceStartedAt ?? now)
        let hitMaxDuration = utteranceDuration >= endpointing.maxUtteranceDuration

        if stableFor < endpointing.silenceTimeout, hitMaxDuration == false {
            scheduleEndpointCheck(extraDelay: endpointing.silenceTimeout - stableFor)
            return
        }

        if seemsSemanticallyIncomplete(transcript), hitMaxDuration == false {
            scheduleEndpointCheck(extraDelay: endpointing.incompletePhraseExtraDelay)
            return
        }

        latestTranscript = ""
        endpointTask?.cancel()
        endpointTask = nil
        onFinalTranscript?(transcript)
    }

    private func emitPartialTranscriptIfNeeded(_ transcript: String) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastPartialEmitAt ?? .distantPast)
        guard transcript.caseInsensitiveCompare(lastEmittedPartialTranscript) != .orderedSame,
              elapsed >= endpointing.partialTranscriptDebounce
        else { return }

        lastEmittedPartialTranscript = transcript
        lastPartialEmitAt = now
        onPartialTranscript?(transcript)
    }

    private func scheduleEndpointCheck(extraDelay: TimeInterval? = nil) {
        endpointTask?.cancel()
        let delay = max(0.05, extraDelay ?? endpointing.silenceTimeout)
        endpointTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }

            await MainActor.run {
                self?.submitLatestTranscript()
            }
        }
    }

    private func seemsSemanticallyIncomplete(_ transcript: String) -> Bool {
        let normalized = transcript
            .lowercased()
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

        let incompleteEndings = [
            "and",
            "or",
            "but",
            "because",
            "so",
            "then",
            "like",
            "i want to",
            "can you",
            "what about"
        ]

        return incompleteEndings.contains { ending in
            normalized == ending || normalized.hasSuffix(" \(ending)")
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

typealias SpeechRecognitionService = AppleSpeechRecognitionProvider
