//
//  PiperSpeechSynthesisProvider.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class PiperSpeechSynthesisProvider: NSObject, ObservableObject, AVAudioPlayerDelegate, SpeechSynthesisProvider {
    struct PiperConfiguration: Equatable {
        var executableURL: URL?
        var modelURL: URL?
        var voiceSpeed: Double = 1.0
        var voiceName: String = "en_GB"

        static func bundledOrInstalled() -> PiperConfiguration {
            let resourceURL = Bundle.main.resourceURL
            let bundledDirectory = resourceURL?.appendingPathComponent("Piper", isDirectory: true)
            let bundledExecutable = bundledDirectory?.appendingPathComponent("piper")
            let bundledModel = findFirstModel(in: bundledDirectory)

            return PiperConfiguration(
                executableURL: executableURL(from: bundledExecutable),
                modelURL: bundledModel,
                voiceSpeed: 1.0,
                voiceName: "en_GB"
            )
        }

        private static func executableURL(from bundledExecutable: URL?) -> URL? {
            if let bundledExecutable,
               FileManager.default.isExecutableFile(atPath: bundledExecutable.path) {
                return bundledExecutable
            }

            let candidates = [
                "/opt/homebrew/bin/piper",
                "/usr/local/bin/piper",
                "/usr/bin/piper"
            ]

            return candidates
                .map(URL.init(fileURLWithPath:))
                .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        }

        private static func findFirstModel(in directory: URL?) -> URL? {
            guard let directory else { return nil }
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            return contents
                .filter { $0.pathExtension == "onnx" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .first { $0.lastPathComponent.lowercased().contains("en_gb") }
                ?? contents.first { $0.pathExtension == "onnx" }
        }
    }

    @Published private(set) var isSpeaking = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onSpeechCancelled: (() -> Void)?
    var onSpeechFailed: ((String) -> Void)?

    private let configuration: PiperConfiguration
    private var generationTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var activeAudioURL: URL?

    override init() {
        self.configuration = PiperConfiguration.bundledOrInstalled()
        super.init()
    }

    init(configuration: PiperConfiguration) {
        self.configuration = configuration
        super.init()
    }

    var isAvailable: Bool {
        configuration.executableURL != nil && configuration.modelURL != nil
    }

    func speak(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanText.isEmpty == false else {
            onSpeechFinished?()
            return
        }

        stopSpeaking()

        guard let executableURL = configuration.executableURL,
              let modelURL = configuration.modelURL
        else {
            onSpeechFailed?("Piper executable or voice model is missing. Expected bundled Resources/Piper/piper and an en_GB .onnx voice model, or a local piper install.")
            return
        }

        let voiceSpeed = configuration.voiceSpeed
        generationTask = Task { [weak self] in
            do {
                let outputURL = try await Self.generateAudio(
                    text: cleanText,
                    executableURL: executableURL,
                    modelURL: modelURL,
                    voiceSpeed: voiceSpeed
                )

                guard Task.isCancelled == false else {
                    try? FileManager.default.removeItem(at: outputURL)
                    return
                }

                self?.playAudio(at: outputURL)
            } catch {
                guard Task.isCancelled == false else { return }
                self?.onSpeechFailed?(error.localizedDescription)
            }
        }
    }

    func stopSpeaking() {
        generationTask?.cancel()
        generationTask = nil

        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlayer = nil
            cleanupActiveAudio()
            isSpeaking = false
            onSpeechCancelled?()
        }
    }

    private func playAudio(at url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            activeAudioURL = url
            isSpeaking = true
            onSpeechStarted?()
            audioPlayer?.play()
        } catch {
            cleanupAudio(at: url)
            onSpeechFailed?(error.localizedDescription)
        }
    }

    private func cleanupActiveAudio() {
        if let activeAudioURL {
            cleanupAudio(at: activeAudioURL)
        }
        activeAudioURL = nil
    }

    private func cleanupAudio(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isSpeaking = false
            audioPlayer = nil
            cleanupActiveAudio()
            onSpeechFinished?()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            isSpeaking = false
            audioPlayer = nil
            cleanupActiveAudio()
            onSpeechFailed?(error?.localizedDescription ?? "Piper audio playback failed.")
        }
    }

    private static func generateAudio(text: String, executableURL: URL, modelURL: URL, voiceSpeed: Double) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("axium-piper-\(UUID().uuidString).wav")

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "--model", modelURL.path,
                "--output_file", outputURL.path,
                "--length_scale", String(format: "%.2f", voiceSpeed)
            ]

            let inputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardError = errorPipe

            try process.run()
            if let data = text.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(data)
            }
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let message = String(data: errorData, encoding: .utf8) ?? "Piper exited with status \(process.terminationStatus)."
                throw PiperSpeechSynthesisProviderError.generationFailed(message)
            }

            guard FileManager.default.fileExists(atPath: outputURL.path) else {
                throw PiperSpeechSynthesisProviderError.outputMissing
            }

            return outputURL
        }.value
    }
}

enum PiperSpeechSynthesisProviderError: LocalizedError {
    case generationFailed(String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return message
        case .outputMissing:
            return "Piper did not generate an audio file."
        }
    }
}

// Piper setup notes:
// Resources/Piper/
// - piper executable
// - en_GB voice model .onnx
// - matching config.json
//
// Future TTS providers can reuse SpeechSynthesisProvider:
// streaming Piper chunks, OpenAI realtime audio, ElevenLabs, local voice personalities,
// emotional tone controls, and low-latency chunk playback.
