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
final class SpeechRecognitionService: NSObject, ObservableObject {
    enum SpeechRecognitionServiceError: LocalizedError {
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

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceWorkItem: DispatchWorkItem?
    private var latestTranscript = ""
    private var activeRecognitionID: UUID?

    var isAvailable: Bool {
        speechRecognizer?.isAvailable == true
    }

    func requestPermissions() async throws {
        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            throw SpeechRecognitionServiceError.speechRecognitionDenied
        }

        let microphoneAllowed = await requestMicrophoneAuthorization()
        guard microphoneAllowed else {
            throw SpeechRecognitionServiceError.microphoneDenied
        }

        guard isAvailable else {
            throw SpeechRecognitionServiceError.recognizerUnavailable
        }
    }

    func startListening() throws {
        guard isAvailable else {
            throw SpeechRecognitionServiceError.recognizerUnavailable
        }

        stopListening()
        latestTranscript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        let recognitionID = UUID()
        activeRecognitionID = recognitionID

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw SpeechRecognitionServiceError.audioInputUnavailable
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
        silenceWorkItem?.cancel()
        silenceWorkItem = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        activeRecognitionID = nil
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult) {
        let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard transcript.isEmpty == false else { return }

        latestTranscript = transcript
        onPartialTranscript?(transcript)

        silenceWorkItem?.cancel()
        let delay: TimeInterval = result.isFinal ? 0.15 : 1.05
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.submitLatestTranscript()
            }
        }
        silenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func submitLatestTranscript() {
        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard transcript.isEmpty == false else { return }
        latestTranscript = ""
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        onFinalTranscript?(transcript)
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
