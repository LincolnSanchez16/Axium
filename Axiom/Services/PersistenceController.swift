//
//  PersistenceController.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation

final class AxiumPersistenceController: @unchecked Sendable {
    enum StoreFile: String {
        case projects = "projects.json"
        case memory = "memory.json"
        case globalContext = "globalContext.json"
        case globalFiles = "globalFiles.json"
        case appState = "appState.json"
        case moduleLayout = "moduleLayout.json"
        case projectWorkspaceStashes = "projectWorkspaceStashes.json"
    }

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        directoryURL = baseURL.appendingPathComponent("Axium", isDirectory: true)

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            // Persistence must never crash Axium. Failed writes remain in-memory for this session.
            print("Axium persistence directory error: \(error.localizedDescription)")
        }
    }

    func load<T: Decodable>(_ type: T.Type, from file: StoreFile, fallback: T) -> T {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            return fallback
        } catch {
            print("Axium persistence load error for \(file.rawValue): \(error.localizedDescription)")
            return fallback
        }
    }

    func save<T: Encodable>(_ value: T, to file: StoreFile) {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Axium persistence save error for \(file.rawValue): \(error.localizedDescription)")
        }
    }

    func applicationSupportDirectory() -> URL {
        directoryURL
    }
}
