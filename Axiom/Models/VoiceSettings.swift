//
//  VoiceSettings.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

enum VoiceMode: String, CaseIterable, Equatable, Codable, Identifiable {
    case passive
    case interactive
    case ambient

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .passive:
            return "Passive"
        case .interactive:
            return "Interactive"
        case .ambient:
            return "Ambient"
        }
    }
}

enum VoiceSensitivity: String, CaseIterable, Equatable, Codable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}

enum TTSProviderType: String, CaseIterable, Equatable, Codable, Identifiable {
    case apple
    case piper
    case futureCloud

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple:
            return "Apple"
        case .piper:
            return "Piper"
        case .futureCloud:
            return "Cloud"
        }
    }
}

struct VoiceSettings: Equatable, Codable {
    var selectedMode: VoiceMode
    var isInterruptionEnabled: Bool
    var showsLiveTranscript: Bool
    var isSessionMuted: Bool
    var autoSpeaksResponses: Bool
    var isSpeechOutputMuted: Bool
    var sensitivity: VoiceSensitivity
    var ttsProviderType: TTSProviderType

    enum CodingKeys: String, CodingKey {
        case selectedMode
        case isInterruptionEnabled
        case showsLiveTranscript
        case isSessionMuted
        case autoSpeaksResponses
        case isSpeechOutputMuted
        case sensitivity
        case ttsProviderType
    }

    init(
        selectedMode: VoiceMode = .interactive,
        isInterruptionEnabled: Bool = true,
        showsLiveTranscript: Bool = true,
        isSessionMuted: Bool = false,
        autoSpeaksResponses: Bool = true,
        isSpeechOutputMuted: Bool = false,
        sensitivity: VoiceSensitivity = .medium,
        ttsProviderType: TTSProviderType = .piper
    ) {
        self.selectedMode = selectedMode
        self.isInterruptionEnabled = isInterruptionEnabled
        self.showsLiveTranscript = showsLiveTranscript
        self.isSessionMuted = isSessionMuted
        self.autoSpeaksResponses = autoSpeaksResponses
        self.isSpeechOutputMuted = isSpeechOutputMuted
        self.sensitivity = sensitivity
        self.ttsProviderType = ttsProviderType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedMode = try container.decodeIfPresent(VoiceMode.self, forKey: .selectedMode) ?? .interactive
        isInterruptionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isInterruptionEnabled) ?? true
        showsLiveTranscript = try container.decodeIfPresent(Bool.self, forKey: .showsLiveTranscript) ?? true
        isSessionMuted = try container.decodeIfPresent(Bool.self, forKey: .isSessionMuted) ?? false
        autoSpeaksResponses = try container.decodeIfPresent(Bool.self, forKey: .autoSpeaksResponses) ?? true
        isSpeechOutputMuted = try container.decodeIfPresent(Bool.self, forKey: .isSpeechOutputMuted) ?? false
        sensitivity = try container.decodeIfPresent(VoiceSensitivity.self, forKey: .sensitivity) ?? .medium
        ttsProviderType = try container.decodeIfPresent(TTSProviderType.self, forKey: .ttsProviderType) ?? .piper
    }
}
