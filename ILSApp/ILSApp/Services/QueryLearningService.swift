import Foundation
import ILSShared
import Observation

// MARK: - QueryLearningService

/// Tracks user query patterns and project access frequency to improve search suggestions.
///
/// Persists data to UserDefaults with the `ils.queryLearning.` key prefix.
/// Storage is kept lightweight: max 50 recent queries and max 20 project name entries.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class QueryLearningService {
    static let shared = QueryLearningService()

    // MARK: - Observable State

    private(set) var recentQueries: [String] = []
    private(set) var successfulQueryPatterns: [String: Int] = [:]
    private(set) var frequentProjectNames: [String: Int] = [:]

    // MARK: - Constants

    private enum StorageKey {
        static let recentQueries = "ils.queryLearning.recentQueries"
        static let successfulQueryPatterns = "ils.queryLearning.successfulQueryPatterns"
        static let frequentProjectNames = "ils.queryLearning.frequentProjectNames"
    }

    private enum Limits {
        static let maxRecentQueries = 50
        static let maxProjectNameEntries = 20
        static let suggestedProjectCount = 5
        static let popularPatternCount = 10
    }

    // MARK: - Init

    private init() {
        recentQueries = loadRecentQueries()
        successfulQueryPatterns = loadDictionary(forKey: StorageKey.successfulQueryPatterns)
        frequentProjectNames = loadDictionary(forKey: StorageKey.frequentProjectNames)
    }

    // MARK: - Public API

    /// Records a search query entered by the user.
    ///
    /// Deduplicates by moving existing entries to the front.
    /// Trims the list to `Limits.maxRecentQueries` after insertion.
    func recordQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentQueries.removeAll { $0 == trimmed }
        recentQueries.insert(trimmed, at: 0)

        if recentQueries.count > Limits.maxRecentQueries {
            recentQueries = Array(recentQueries.prefix(Limits.maxRecentQueries))
        }

        saveRecentQueries()
    }

    /// Records that a session was selected as a result of the given query.
    ///
    /// Increments the success count for the query pattern and, if the session
    /// has an associated project, increments that project's access frequency.
    /// Project name entries are capped at `Limits.maxProjectNameEntries`.
    func recordSessionSelected(forQuery query: String, session: ChatSession) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        successfulQueryPatterns[trimmed, default: 0] += 1
        saveDictionary(successfulQueryPatterns, forKey: StorageKey.successfulQueryPatterns)

        if let projectName = session.projectName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !projectName.isEmpty
        {
            frequentProjectNames[projectName, default: 0] += 1
            trimProjectNames()
            saveDictionary(frequentProjectNames, forKey: StorageKey.frequentProjectNames)
        }
    }

    /// Returns the top project names ordered by access frequency.
    ///
    /// - Returns: Up to `Limits.suggestedProjectCount` project names.
    func suggestedProjectNames() -> [String] {
        Array(
            frequentProjectNames
                .sorted { $0.value > $1.value }
                .prefix(Limits.suggestedProjectCount)
                .map(\.key)
        )
    }

    /// Returns the most frequently successful query patterns.
    ///
    /// - Returns: Up to `Limits.popularPatternCount` query strings.
    func popularPatterns() -> [String] {
        Array(
            successfulQueryPatterns
                .sorted { $0.value > $1.value }
                .prefix(Limits.popularPatternCount)
                .map(\.key)
        )
    }

    // MARK: - Private Helpers

    /// Trims `frequentProjectNames` to at most `Limits.maxProjectNameEntries` entries,
    /// keeping the highest-frequency entries.
    private func trimProjectNames() {
        guard frequentProjectNames.count > Limits.maxProjectNameEntries else { return }
        let trimmed = frequentProjectNames
            .sorted { $0.value > $1.value }
            .prefix(Limits.maxProjectNameEntries)
        frequentProjectNames = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.key, $0.value) })
    }

    // MARK: - Persistence

    private func loadRecentQueries() -> [String] {
        UserDefaults.standard.stringArray(forKey: StorageKey.recentQueries) ?? []
    }

    private func saveRecentQueries() {
        UserDefaults.standard.set(recentQueries, forKey: StorageKey.recentQueries)
    }

    private func loadDictionary(forKey key: String) -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    private func saveDictionary(_ dict: [String: Int], forKey key: String) {
        UserDefaults.standard.set(dict, forKey: key)
    }
}
