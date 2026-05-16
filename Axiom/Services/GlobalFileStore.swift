//
//  GlobalFileStore.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation
import Combine

@MainActor
final class GlobalFileStore: ObservableObject {
    @Published private(set) var files: [GlobalFileItem] {
        didSet { persistIfNeeded() }
    }

    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false

    init(persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        files = resolvedPersistence.load([GlobalFileItem].self, from: .globalFiles, fallback: [])
        isPersistenceReady = true
    }

    func addFile(_ file: GlobalFileItem) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
        } else {
            files.append(file)
        }
    }

    func searchGlobalFiles(_ query: String) -> [GlobalFileItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedQuery.isEmpty == false else { return globallyVisibleFiles() }
        return globallyVisibleFiles().filter { file in
            file.name.lowercased().contains(normalizedQuery)
                || file.searchableText.lowercased().contains(normalizedQuery)
                || (file.description ?? "").lowercased().contains(normalizedQuery)
                || file.tags.contains { $0.lowercased().contains(normalizedQuery) }
        }
    }

    func attachFileToProject(fileId: UUID, projectId: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileId }) else { return }
        if files[index].relatedProjectIds.contains(projectId) == false {
            files[index].relatedProjectIds.append(projectId)
        }
        files[index].updatedAt = Date()
    }

    func markFilePrivate(fileId: UUID, projectId: UUID?) {
        guard let index = files.firstIndex(where: { $0.id == fileId }) else { return }
        files[index].isPrivateToProject = true
        files[index].globalVisibility = .privateToProject
        if let projectId, files[index].relatedProjectIds.contains(projectId) == false {
            files[index].relatedProjectIds.append(projectId)
        }
        files[index].updatedAt = Date()
    }

    func retrieveRecentFiles(limit: Int = 10) -> [GlobalFileItem] {
        globallyVisibleFiles()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    func retrieveFilesByApproximateDate(_ date: Date, toleranceDays: Int = 7) -> [GlobalFileItem] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -toleranceDays, to: date) ?? date
        let end = calendar.date(byAdding: .day, value: toleranceDays, to: date) ?? date
        return globallyVisibleFiles().filter { file in
            file.createdAt >= start && file.createdAt <= end
        }
    }

    func files(for projectId: UUID, includePrivate: Bool = true) -> [GlobalFileItem] {
        files.filter { file in
            file.relatedProjectIds.contains(projectId) && (includePrivate || file.isPrivateToProject == false)
        }
    }

    private func globallyVisibleFiles() -> [GlobalFileItem] {
        files.filter { $0.globalVisibility == .global && $0.isPrivateToProject == false }
    }

    private func persistIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(files, to: .globalFiles)
    }

    // Future retrieval path:
    // Metadata search -> OCR/searchable text -> embeddings/vector recall -> LLM reranking.
    // This will support references like "that photo from last week" without rigid filenames.
}
