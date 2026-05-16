//
//  GlobalConversationMemoryStore.swift
//  Axium
//
//  Created by Codex on 5/16/26.
//

import Foundation
import Combine

struct GlobalConversationMemorySnapshot: Equatable, Codable {
    var userProfile: UserProfileContext = UserProfileContext()
    var candidates: [ConversationMemoryCandidate] = []
    var preferences: [GlobalConversationPreference] = []
    var patterns: [ConversationPattern] = []
    var recentConversations: [GlobalConversationSession] = []
    var unresolvedDiscussions: [String] = []
    var recentlyReferencedProjects: [String] = []
    var unfinishedThoughts: [String] = []
    var updatedAt: Date = Date()
}

@MainActor
final class GlobalConversationMemoryStore: ObservableObject {
    @Published private(set) var snapshot: GlobalConversationMemorySnapshot {
        didSet { persistIfNeeded() }
    }

    private let persistence: AxiumPersistenceController
    private var isPersistenceReady = false

    init(persistence: AxiumPersistenceController? = nil) {
        let resolvedPersistence = persistence ?? AxiumPersistenceController()
        self.persistence = resolvedPersistence
        var loadedSnapshot = resolvedPersistence.load(GlobalConversationMemorySnapshot.self, from: .conversationMemory, fallback: GlobalConversationMemorySnapshot())
        let loadedProfile = resolvedPersistence.load(UserProfileContext.self, from: .userProfile, fallback: loadedSnapshot.userProfile)
        loadedSnapshot.userProfile = loadedProfile
        snapshot = loadedSnapshot
        isPersistenceReady = true
    }

    var userProfile: UserProfileContext { snapshot.userProfile }

    func observeUserMessage(_ message: String, activeProjectName: String?, availableProjectNames: [String]) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanMessage.isEmpty == false else { return }

        var extractedCandidates = extractCandidates(from: cleanMessage, availableProjectNames: availableProjectNames)
        for index in extractedCandidates.indices where shouldAutoApprove(extractedCandidates[index]) {
            extractedCandidates[index].approved = true
            applyApprovedCandidate(extractedCandidates[index])
        }

        mergeCandidates(extractedCandidates)
        updatePatterns(from: cleanMessage)
        updateSessionContinuity(from: cleanMessage, activeProjectName: activeProjectName, availableProjectNames: availableProjectNames)
        trimSnapshot()
        snapshot.updatedAt = Date()
    }

    func observeAssistantMessage(_ message: String) {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanMessage.isEmpty == false else { return }

        let lower = cleanMessage.lowercased()
        var capturedContinuity = false
        if lower.hasPrefix("which ") || lower.hasPrefix("what ") || lower.contains("one more detail") {
            appendUnique(String(cleanMessage.prefix(180)), to: &snapshot.unresolvedDiscussions)
            capturedContinuity = true
        }

        if lower.contains("come back to") || lower.contains("later") || lower.contains("unfinished") {
            appendUnique(String(cleanMessage.prefix(180)), to: &snapshot.unfinishedThoughts)
            capturedContinuity = true
        }

        guard capturedContinuity else { return }
        trimSnapshot()
        snapshot.updatedAt = Date()
    }

    func approveCandidate(id: UUID) {
        guard let index = snapshot.candidates.firstIndex(where: { $0.id == id }) else { return }
        snapshot.candidates[index].approved = true
        snapshot.candidates[index].rejected = false
        applyApprovedCandidate(snapshot.candidates[index])
        snapshot.updatedAt = Date()
    }

    func rejectCandidate(id: UUID) {
        guard let index = snapshot.candidates.firstIndex(where: { $0.id == id }) else { return }
        snapshot.candidates[index].approved = false
        snapshot.candidates[index].rejected = true
        snapshot.updatedAt = Date()
    }

    func deleteCandidate(id: UUID) {
        snapshot.candidates.removeAll { $0.id == id }
        snapshot.updatedAt = Date()
    }

    func setPreferenceEnabled(id: UUID, enabled: Bool) {
        guard let index = snapshot.preferences.firstIndex(where: { $0.id == id }) else { return }
        snapshot.preferences[index].enabled = enabled
        snapshot.preferences[index].updatedAt = Date()
        snapshot.updatedAt = Date()
    }

    func deletePattern(id: UUID) {
        snapshot.patterns.removeAll { $0.id == id }
        snapshot.updatedAt = Date()
    }

    func replaceUserProfile(_ userProfile: UserProfileContext) {
        snapshot.userProfile = userProfile
        snapshot.updatedAt = Date()
    }

    func rememberPreferredName(_ name: String, sourceMessage: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanName.isEmpty == false else { return }

        let candidate = ConversationMemoryCandidate(
            sourceMessage: sourceMessage,
            extractedMeaning: "User prefers to be called \(cleanName).",
            confidence: 0.96,
            category: .preferredName,
            approved: true
        )
        mergeCandidates([candidate])
        applyApprovedCandidate(candidate)
        snapshot.updatedAt = Date()
    }

    func rememberPreference(_ preference: String, sourceMessage: String) {
        let cleanPreference = preference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPreference.isEmpty == false else { return }

        let candidate = ConversationMemoryCandidate(
            sourceMessage: sourceMessage,
            extractedMeaning: "Prefers \(cleanPreference).",
            confidence: 0.9,
            category: .responsePreference,
            approved: true
        )
        mergeCandidates([candidate])
        applyApprovedCandidate(candidate)
        snapshot.updatedAt = Date()
    }

    func compactPromptSummary(maxLines: Int = 12) -> String {
        var lines = snapshot.userProfile.compactSummaryLines

        let enabledPreferenceLines = snapshot.preferences
            .filter(\.enabled)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map { "preference: \($0.value)" }
        lines.append(contentsOf: enabledPreferenceLines)

        let approvedPatterns = snapshot.patterns
            .filter { $0.approved && $0.rejected == false }
            .sorted { $0.occurrences > $1.occurrences }
            .prefix(5)
            .map { pattern in
                if let meaning = pattern.meaning, meaning.isEmpty == false {
                    return "pattern: \(pattern.phrase) = \(meaning)"
                }
                return "pattern: \(pattern.phrase)"
            }
        lines.append(contentsOf: approvedPatterns)

        if snapshot.unresolvedDiscussions.isEmpty == false {
            lines.append("unresolved discussions: \(snapshot.unresolvedDiscussions.prefix(3).joined(separator: "; "))")
        }

        if snapshot.unfinishedThoughts.isEmpty == false {
            lines.append("unfinished thoughts: \(snapshot.unfinishedThoughts.prefix(3).joined(separator: "; "))")
        }

        return lines.isEmpty
            ? "No approved persistent user profile context yet."
            : lines.prefix(maxLines).map { "- \($0)" }.joined(separator: "\n")
    }

    private func extractCandidates(from message: String, availableProjectNames: [String]) -> [ConversationMemoryCandidate] {
        let lower = message.lowercased()
        var candidates: [ConversationMemoryCandidate] = []

        if let name = extractPreferredName(from: message) {
            candidates.append(candidate(message, "User prefers to be called \(name).", 0.92, .preferredName))
        }

        if lower.contains("don't yes-man") || lower.contains("do not yes-man") || lower.contains("hate yes-man") || lower.contains("no yes-man") {
            candidates.append(candidate(message, "Prefers honest critique over yes-man responses.", 0.94, .assistantBehaviorPreference))
        }

        if lower.contains("generic ai disclaimer") || lower.contains("as an ai") {
            candidates.append(candidate(message, "Dislikes generic AI disclaimers unless necessary.", 0.88, .dislikedBehavior))
        }

        if lower.contains("direct technical honesty") || lower.contains("be direct") || lower.contains("tell me straight") {
            candidates.append(candidate(message, "Prefers direct technical honesty.", 0.88, .responsePreference))
        }

        if lower.contains("direct answers") {
            candidates.append(candidate(message, "Prefers direct answers.", 0.9, .responsePreference))
        }

        if let statedPreference = extractStatedPreference(from: message) {
            candidates.append(candidate(message, "Prefers \(statedPreference).", 0.88, .responsePreference))
        }

        if let statedDislike = extractStatedDislike(from: message) {
            candidates.append(candidate(message, "Dislikes \(statedDislike).", 0.88, .dislikedBehavior))
        }

        if lower.contains("conversation-first") || lower.contains("conversation first") {
            candidates.append(candidate(message, "Prefers conversation-first workflows.", 0.9, .workflowPreference))
        }

        if lower.contains("projects are save containers") || lower.contains("projects are optional") {
            candidates.append(candidate(message, "Projects are optional save containers, not mandatory contexts.", 0.9, .preferredProjectBehavior))
        }

        if lower.contains("premium ui") || lower.contains("dark premium") || lower.contains("premium blue") {
            candidates.append(candidate(message, "Prefers dark, premium, polished UI direction.", 0.84, .preferredUIStyle))
        }

        if let slangMapping = extractSlangMapping(from: message) {
            candidates.append(candidate(message, "User slang: \(slangMapping.term) means \(slangMapping.meaning).", 0.88, .slangMapping))
        } else if lower.contains("buns") {
            candidates.append(candidate(message, "User slang: buns means low quality.", 0.9, .slangMapping))
        }

        if lower.contains("bro") {
            candidates.append(candidate(message, "User commonly uses casual phrase: bro.", 0.72, .commonPhrase))
        }

        if lower.contains("that sucks") || lower.contains("this sucks") {
            candidates.append(candidate(message, "User uses direct negative quality feedback.", 0.72, .interactionPattern))
        }

        for projectName in availableProjectNames where lower.contains(projectName.lowercased()) {
            candidates.append(candidate(message, "Recently referenced project: \(projectName).", 0.78, .projectReference))
        }

        if lower.contains("researching ") || lower.contains("working on ") || lower.contains("focused on ") {
            let focus = String(message.prefix(120))
            candidates.append(candidate(message, "Possible active focus area: \(focus)", 0.62, .activeFocusArea))
        }

        return candidates
    }

    private func candidate(_ source: String, _ meaning: String, _ confidence: Double, _ category: ConversationMemoryCandidate.Category) -> ConversationMemoryCandidate {
        ConversationMemoryCandidate(
            sourceMessage: source,
            extractedMeaning: meaning,
            confidence: confidence,
            category: category
        )
    }

    private func shouldAutoApprove(_ candidate: ConversationMemoryCandidate) -> Bool {
        switch candidate.category {
        case .preferredName, .preferredTone, .assistantBehaviorPreference, .responsePreference, .workflowPreference, .preferredProjectBehavior, .preferredUIStyle, .slangMapping, .dislikedBehavior:
            return candidate.confidence >= 0.84
        case .commonPhrase, .projectReference, .activeFocusArea, .interactionPattern:
            return false
        }
    }

    private func applyApprovedCandidate(_ candidate: ConversationMemoryCandidate) {
        switch candidate.category {
        case .preferredName:
            snapshot.userProfile.preferredName = candidate.extractedMeaning
                .replacingOccurrences(of: "User prefers to be called ", with: "")
                .replacingOccurrences(of: ".", with: "")
        case .preferredTone:
            snapshot.userProfile.preferredTone = candidate.extractedMeaning
        case .workflowPreference:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.interactionPatterns)
            snapshot.userProfile.preferredWorkflowStyle = candidate.extractedMeaning
            addPreference(.workflow, candidate: candidate)
        case .assistantBehaviorPreference:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.assistantBehaviorPreferences)
            addPreference(.assistantBehavior, candidate: candidate)
        case .responsePreference:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.responsePreferences)
            addPreference(.responseStyle, candidate: candidate)
        case .dislikedBehavior:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.dislikedBehaviors)
            addPreference(.dislikedBehavior, candidate: candidate)
        case .preferredUIStyle:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.preferredUIStyle)
            addPreference(.uiStyle, candidate: candidate)
        case .preferredProjectBehavior:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.preferredProjectBehavior)
            addPreference(.projectBehavior, candidate: candidate)
        case .slangMapping:
            if let mapping = parseSlangMeaning(from: candidate.extractedMeaning) {
                snapshot.userProfile.aliases[mapping.term] = mapping.meaning
            }
        case .commonPhrase:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.commonPhrases)
        case .projectReference:
            let projectName = candidate.extractedMeaning.replacingOccurrences(of: "Recently referenced project: ", with: "").replacingOccurrences(of: ".", with: "")
            appendUnique(projectName, to: &snapshot.userProfile.knownProjects)
            appendUnique(projectName, to: &snapshot.recentlyReferencedProjects)
        case .activeFocusArea:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.activeFocusAreas)
        case .interactionPattern:
            appendUnique(candidate.extractedMeaning, to: &snapshot.userProfile.interactionPatterns)
        }

        snapshot.userProfile.updatedAt = Date()
    }

    private func addPreference(_ category: GlobalConversationPreference.Category, candidate: ConversationMemoryCandidate) {
        if let index = snapshot.preferences.firstIndex(where: { $0.category == category && $0.value == candidate.extractedMeaning }) {
            snapshot.preferences[index].updatedAt = Date()
            snapshot.preferences[index].confidence = max(snapshot.preferences[index].confidence, candidate.confidence)
            return
        }

        snapshot.preferences.append(
            GlobalConversationPreference(
                category: category,
                value: candidate.extractedMeaning,
                sourceMessage: candidate.sourceMessage,
                confidence: candidate.confidence
            )
        )
    }

    private func updatePatterns(from message: String) {
        let lower = message.lowercased()
        let watchedPhrases = [
            ("bro", ConversationPattern.Category.repeatedPhrase, nil),
            ("buns", ConversationPattern.Category.slang, "low quality"),
            ("that sucks", ConversationPattern.Category.correction, "direct negative feedback"),
            ("don't yes-man", ConversationPattern.Category.correction, "prefers honest critique"),
            ("conversation-first", ConversationPattern.Category.workflow, "prefers conversation-first workflows"),
            ("premium ui", ConversationPattern.Category.workflow, "prefers polished premium UI")
        ]

        for (phrase, category, meaning) in watchedPhrases where lower.contains(phrase) {
            upsertPattern(phrase: phrase, meaning: meaning, category: category, autoApproveAfter: category == .slang ? 1 : 2)
        }
    }

    private func updateSessionContinuity(from message: String, activeProjectName: String?, availableProjectNames: [String]) {
        let lower = message.lowercased()
        if lower.contains("?") || lower.contains("think about") || lower.contains("research") {
            appendUnique(String(message.prefix(180)), to: &snapshot.unresolvedDiscussions)
        }

        if lower.contains("earlier") || lower.contains("later") || lower.contains("come back to") || lower.contains("unfinished") {
            appendUnique(String(message.prefix(180)), to: &snapshot.unfinishedThoughts)
        }

        for projectName in availableProjectNames where lower.contains(projectName.lowercased()) {
            appendUnique(projectName, to: &snapshot.recentlyReferencedProjects)
            appendUnique(projectName, to: &snapshot.userProfile.knownProjects)
        }

        if let activeProjectName,
           lower.contains("this project") || lower.contains("current project") || lower.contains("active project") {
            appendUnique(activeProjectName, to: &snapshot.recentlyReferencedProjects)
            appendUnique(activeProjectName, to: &snapshot.userProfile.knownProjects)
        }
    }

    private func upsertPattern(phrase: String, meaning: String?, category: ConversationPattern.Category, autoApproveAfter: Int) {
        if let index = snapshot.patterns.firstIndex(where: { $0.phrase == phrase && $0.category == category }) {
            snapshot.patterns[index].occurrences += 1
            snapshot.patterns[index].lastSeenAt = Date()
            if snapshot.patterns[index].occurrences >= autoApproveAfter {
                snapshot.patterns[index].approved = true
            }
            return
        }

        snapshot.patterns.append(
            ConversationPattern(
                phrase: phrase,
                meaning: meaning,
                category: category,
                approved: autoApproveAfter <= 1
            )
        )
    }

    private func mergeCandidates(_ candidates: [ConversationMemoryCandidate]) {
        for candidate in candidates {
            let exists = snapshot.candidates.contains {
                $0.category == candidate.category && $0.extractedMeaning == candidate.extractedMeaning
            }
            if exists == false {
                snapshot.candidates.append(candidate)
            }
        }
    }

    private func extractPreferredName(from message: String) -> String? {
        let lower = message.lowercased()
        let markers = ["my name is ", "call me ", "i'm ", "i am "]
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            let suffix = lower[range.upperBound...]
            let candidate = suffix
                .split { $0 == "." || $0 == "," || $0 == "\n" }
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let candidate, candidate.count <= 40, candidate.split(separator: " ").count <= 3 {
                return candidate.capitalized
            }
        }
        return nil
    }

    private func extractSlangMapping(from message: String) -> (term: String, meaning: String)? {
        let lower = message.lowercased()
        for marker in [" means ", " = "] {
            guard let range = lower.range(of: marker) else { continue }
            let rawTerm = lower[..<range.lowerBound]
                .split { $0 == "." || $0 == "," || $0 == "\n" || $0 == ":" }
                .last
                .map(String.init)?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            let rawMeaning = lower[range.upperBound...]
                .split { $0 == "." || $0 == "," || $0 == "\n" }
                .first
                .map(String.init)?
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

            guard let term = rawTerm?.lowercased(),
                  let meaning = rawMeaning?.lowercased(),
                  term.isEmpty == false,
                  meaning.isEmpty == false,
                  term.count <= 32,
                  meaning.count <= 80
            else { continue }

            return (term, meaning)
        }
        return nil
    }

    private func extractStatedPreference(from message: String) -> String? {
        let lower = message.lowercased()
        let markers = ["remember that i like ", "remember that i prefer ", "i like ", "i prefer "]
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            return extractShortValue(from: lower[range.upperBound...])
        }
        return nil
    }

    private func extractStatedDislike(from message: String) -> String? {
        let lower = message.lowercased()
        let markers = ["remember that i hate ", "remember that i don't like ", "remember that i dont like ", "i hate ", "i don't like ", "i dont like "]
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            return extractShortValue(from: lower[range.upperBound...])
        }
        return nil
    }

    private func extractShortValue(from substring: Substring) -> String? {
        let value = substring
            .split { $0 == "." || $0 == "," || $0 == "\n" }
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, value.isEmpty == false else { return nil }
        return String(value.prefix(90))
    }

    private func parseSlangMeaning(from meaning: String) -> (term: String, meaning: String)? {
        let prefix = "User slang: "
        let suffix = "."
        let clean = meaning
            .replacingOccurrences(of: prefix, with: "")
            .replacingOccurrences(of: suffix, with: "")
        guard let range = clean.lowercased().range(of: " means ") else { return nil }
        let term = clean[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let mappedMeaning = clean[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard term.isEmpty == false, mappedMeaning.isEmpty == false else { return nil }
        return (term, mappedMeaning)
    }

    private func appendUnique(_ value: String, to array: inout [String], limit: Int = 24) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false else { return }
        array.removeAll { $0.caseInsensitiveCompare(clean) == .orderedSame }
        array.insert(clean, at: 0)
        array = Array(array.prefix(limit))
    }

    private func trimSnapshot() {
        snapshot.candidates = Array(snapshot.candidates.sorted { $0.createdAt > $1.createdAt }.prefix(160))
        snapshot.preferences = Array(snapshot.preferences.sorted { $0.updatedAt > $1.updatedAt }.prefix(80))
        snapshot.patterns = Array(snapshot.patterns.sorted { $0.lastSeenAt > $1.lastSeenAt }.prefix(80))
        snapshot.recentConversations = Array(snapshot.recentConversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(20))
        snapshot.unresolvedDiscussions = Array(snapshot.unresolvedDiscussions.prefix(12))
        snapshot.recentlyReferencedProjects = Array(snapshot.recentlyReferencedProjects.prefix(12))
        snapshot.unfinishedThoughts = Array(snapshot.unfinishedThoughts.prefix(12))
    }

    private func persistIfNeeded() {
        guard isPersistenceReady else { return }
        persistence.save(snapshot, to: .conversationMemory)
        persistence.save(snapshot.userProfile, to: .userProfile)
    }
}
