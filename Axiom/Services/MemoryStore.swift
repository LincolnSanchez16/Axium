//
//  MemoryStore.swift
//  Axium
//
//  Created by Lincoln Sanchez on 5/15/26.
//

import Foundation
import Combine

@MainActor
final class MemoryStore: ObservableObject {
    @Published private(set) var memories: [MemoryItem] {
        didSet { persistIfNeeded() }
    }

    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false

    init(memories: [MemoryItem]? = nil, persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        self.memories = memories ?? resolvedPersistence.load([MemoryItem].self, from: .memory, fallback: [])
        isPersistenceReady = true
    }

    @discardableResult
    func saveMemoryItem(_ item: MemoryItem) -> MemoryItem {
        if let index = memories.firstIndex(where: { $0.id == item.id }) {
            memories[index] = item
            return item
        }

        memories.append(item)
        return item
    }

    @discardableResult
    func saveExplicitMemory(
        _ content: String,
        category: String = "general",
        projectId: UUID? = nil,
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: projectId == nil ? .explicit : .project,
                category: category,
                content: content,
                source: projectId == nil ? .userStated : .projectContext,
                confidence: .high,
                projectId: projectId,
                tags: tags
            )
        )
    }

    @discardableResult
    func saveBehavioralMemory(
        _ content: String,
        category: String = "behavior",
        confidence: MemoryItem.Confidence = .low,
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .behavioral,
                category: category,
                content: content,
                source: .repeatedBehavior,
                confidence: confidence,
                tags: tags
            )
        )
    }

    @discardableResult
    func saveInferredMemory(
        _ content: String,
        category: String = "inferred_pattern",
        confidence: MemoryItem.Confidence = .low,
        projectId: UUID? = nil,
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .inferred,
                category: category,
                content: content,
                source: .inferredPattern,
                confidence: confidence,
                projectId: projectId,
                tags: tags
            )
        )
    }

    @discardableResult
    func saveCorrectionMemory(
        _ content: String,
        category: String = "correction",
        projectId: UUID? = nil,
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .correction,
                category: category,
                content: content,
                source: .correction,
                confidence: .high,
                projectId: projectId,
                tags: tags
            )
        )
    }

    @discardableResult
    func savePreferenceMemory(
        _ content: String,
        category: String = "preference",
        projectId: UUID? = nil,
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .preference,
                category: category,
                content: content,
                source: .userStated,
                confidence: .high,
                projectId: projectId,
                tags: tags
            )
        )
    }

    @discardableResult
    func saveLanguageMemory(
        phrase: String,
        mappedTarget: String,
        category: String = "language_mapping",
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .language,
                category: category,
                content: "\(phrase) -> \(mappedTarget)",
                source: .userStated,
                confidence: .high,
                tags: tags
            )
        )
    }

    @discardableResult
    func saveProjectMemory(
        _ content: String,
        projectId: UUID,
        category: String = "project_context",
        tags: [String] = []
    ) -> MemoryItem {
        saveMemoryItem(
            MemoryItem(
                type: .project,
                category: category,
                content: content,
                source: .projectContext,
                confidence: .medium,
                projectId: projectId,
                tags: tags
            )
        )
    }

    func retrieveRelevantMemories(for context: MemoryRetrievalContext, limit: Int = 8) -> [MemoryItem] {
        let queryTerms = tokenSet(context.userMessage)
        let requestedTags = Set(context.tags.map(normalized))

        let ranked = memories.map { memory -> (MemoryItem, Int) in
            var score = 0
            if memory.projectId == context.projectId, context.projectId != nil { score += 4 }
            if memory.projectId == nil { score += 1 }
            if let intent = context.intent, memory.tags.contains(normalized(intent.rawValue)) { score += 2 }
            if requestedTags.isEmpty == false && requestedTags.isSubset(of: Set(memory.tags.map(normalized))) { score += 2 }
            score += queryTerms.intersection(tokenSet(memory.content)).count
            score += min(memory.usageCount, 4)
            return (memory, score)
        }

        return ranked
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.updatedAt > rhs.0.updatedAt
                }
                return lhs.1 > rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    func searchMemories(_ query: String) -> [MemoryItem] {
        let terms = tokenSet(query)
        guard terms.isEmpty == false else { return memories }
        return memories.filter { memory in
            terms.intersection(tokenSet(memory.content + " " + memory.category + " " + memory.tags.joined(separator: " "))).isEmpty == false
        }
    }

    func saveNow() {
        persistIfNeeded()
    }

    func updateConfidence(memoryId: UUID, confidence: MemoryItem.Confidence) {
        guard let index = memories.firstIndex(where: { $0.id == memoryId }) else { return }
        memories[index].confidence = confidence
        memories[index].updatedAt = Date()
    }

    func trackUsage(memoryId: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == memoryId }) else { return }
        memories[index].usageCount += 1
        memories[index].lastReferencedAt = Date()
        memories[index].updatedAt = Date()
    }

    func associate(memoryId: UUID, projectId: UUID) {
        guard let index = memories.firstIndex(where: { $0.id == memoryId }) else { return }
        memories[index].projectId = projectId
        memories[index].updatedAt = Date()
    }

    func globalPreferences() -> [MemoryItem] {
        memories
            .filter { $0.projectId == nil && ($0.type == .preference || $0.type == .correction) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func projectContext(projectId: UUID) -> [MemoryItem] {
        memories
            .filter { $0.projectId == projectId || ($0.projectId == nil && $0.type == .preference) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func languageMappings() -> [MemoryItem] {
        memories.filter { $0.type == .language }
    }

    func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
    }

    private func tokenSet(_ text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .split { $0.isWhitespace || $0.isPunctuation }
                .map(String.init)
                .filter { $0.count > 2 }
        )
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func persistIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(memories, to: .memory)
    }

    // Future memory pipeline:
    // User message -> retrieve relevant memories -> retrieve project context
    // -> retrieve behavior patterns -> retrieve preferences -> generate enhanced context
    // -> future LLM interpretation. This store remains transparent and editable by design.
}
