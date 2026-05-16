//
//  OllamaService.swift
//  Axiom
//
//  Created by Lincoln Sanchez on 5/14/26.
//

import Foundation

struct OllamaService {
    private let endpoint = URL(string: "http://localhost:11434/api/chat")!
    private let model = "qwen2.5-coder:7b"

    func chat(messages: [OllamaChatMessage]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 18
        request.httpBody = try JSONEncoder().encode(
            OllamaChatRequest(
                model: model,
                messages: messages,
                stream: false
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8)
            throw OllamaServiceError.server(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let content = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard content.isEmpty == false else {
            throw OllamaServiceError.emptyResponse
        }

        return content
    }
}

struct OllamaChatMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaChatMessage]
    let stream: Bool
}

private struct OllamaChatResponse: Decodable {
    let message: OllamaChatMessage
}

enum OllamaServiceError: LocalizedError {
    case invalidResponse
    case emptyResponse
    case server(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Ollama returned an invalid response."
        case .emptyResponse:
            return "Ollama returned an empty response."
        case .server(let statusCode, let message):
            if let message, message.isEmpty == false {
                return "Ollama returned HTTP \(statusCode): \(message)"
            }

            return "Ollama returned HTTP \(statusCode)."
        }
    }
}
