import Foundation
import Observation

// MARK: - DocumentationService

/// Provides in-app Claude Code reference documentation with full-text search,
/// category filtering, UserDefaults-backed bookmarks, and context-sensitive help.
///
/// All content is compiled-in from ``DocArticle.allArticles`` — no network calls
/// are made and the documentation is fully available offline.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class DocumentationService {
    static let shared = DocumentationService()

    // MARK: - Observable State

    /// The complete compiled-in article library.
    private(set) var allArticles: [DocArticle] = DocArticle.allArticles

    /// Article IDs that the user has bookmarked, persisted in UserDefaults.
    private(set) var bookmarkIDs: Set<String> = []

    // MARK: - Constants

    private enum StorageKey {
        static let bookmarks = "doc_bookmark_ids"
    }

    // MARK: - Init

    private init() {
        bookmarkIDs = loadBookmarks()
    }

    // MARK: - Search

    /// Returns articles whose title, summary, or tags contain `query` (case-insensitive).
    ///
    /// Returns all articles when `query` is empty or whitespace-only.
    func search(_ query: String) -> [DocArticle] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return allArticles }

        return allArticles.filter { article in
            article.title.localizedCaseInsensitiveContains(trimmed)
                || article.summary.localizedCaseInsensitiveContains(trimmed)
                || article.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    // MARK: - Category Filtering

    /// Returns all articles belonging to the given category.
    func articles(for category: DocCategory) -> [DocArticle] {
        allArticles.filter { $0.category == category }
    }

    // MARK: - Bookmarks

    /// Returns all bookmarked articles in their original `allArticles` order.
    var bookmarkedArticles: [DocArticle] {
        allArticles.filter { bookmarkIDs.contains($0.id) }
    }

    /// Returns `true` if the article with the given ID is bookmarked.
    func isBookmarked(_ articleID: String) -> Bool {
        bookmarkIDs.contains(articleID)
    }

    /// Toggles the bookmark state for the given article ID.
    func toggleBookmark(_ articleID: String) {
        if bookmarkIDs.contains(articleID) {
            bookmarkIDs.remove(articleID)
            AppLogger.shared.info(
                "Documentation bookmark removed: '\(articleID)'",
                category: "documentation"
            )
        } else {
            bookmarkIDs.insert(articleID)
            AppLogger.shared.info(
                "Documentation bookmark added: '\(articleID)'",
                category: "documentation"
            )
        }
        saveBookmarks()
    }

    // MARK: - Context-Sensitive Help

    /// Returns up to 5 articles most relevant to the given context hint.
    ///
    /// Matching is performed against article tags and the category raw value.
    /// Pass a screen name, feature slug, or keyword as `hint` (e.g. `"mcp"`,
    /// `"slash_commands"`, `"permissions"`).
    func articlesForContext(_ hint: String) -> [DocArticle] {
        let normalized = hint.localizedLowercase.replacingOccurrences(of: "_", with: " ")
        guard !normalized.isEmpty else { return [] }

        let matched = allArticles.filter { article in
            article.tags.contains { $0.localizedCaseInsensitiveContains(normalized) }
                || article.category.rawValue.localizedCaseInsensitiveContains(normalized)
        }

        return Array(matched.prefix(5))
    }

    // MARK: - UserDefaults Persistence

    private func loadBookmarks() -> Set<String> {
        guard let array = UserDefaults.standard.array(forKey: StorageKey.bookmarks) as? [String] else {
            return []
        }
        return Set(array)
    }

    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarkIDs), forKey: StorageKey.bookmarks)
    }
}
