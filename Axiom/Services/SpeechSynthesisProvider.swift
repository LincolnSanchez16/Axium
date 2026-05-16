//
//  SpeechSynthesisProvider.swift
//  Axiom
//
//  Created by Codex on 5/16/26.
//

import Foundation

@MainActor
protocol SpeechSynthesisProvider: AnyObject {
    var isSpeaking: Bool { get }
    var onSpeechStarted: (() -> Void)? { get set }
    var onSpeechFinished: (() -> Void)? { get set }
    var onSpeechCancelled: (() -> Void)? { get set }

    func speak(_ text: String)
    func stopSpeaking()
}
