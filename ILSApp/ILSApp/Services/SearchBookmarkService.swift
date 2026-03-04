import Foundation
import ILSShared

/// Persists bookmarked cross-session search results in UserDefaults.
///
/// Stores up to 100 `SearchBookmark` entries as JSON under the key `ils_searchBookmarks`.
/// When the limit is exceeded, the oldest entries (by `bookmarkedAt`) are removed first.
enum SearchBookmarkService {
    private static let storageKey = "ils_searchBookmarks"
    private static let maxEntries = 100

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    // MARK: - Read

    /// Returns all persisted bookmarks, sorted newest-first.
    static func all() -> [SearchBookmark] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        do {
            return try decoder.decode([SearchBookmark].self, from: data)
        } catch {
            AppLogger.shared.error(
                "SearchBookmarkService: failed to decode bookmarks: \(error.localizedDescription)",
                category: "search"
            )
            return []
        }
    }

    /// Returns `true` if a bookmark for the given message ID exists.
    static func contains(id: UUID) -> Bool {
        all().contains { $0.result.id == id }
    }

    // MARK: - Write

    /// Adds a bookmark for the given search result.
    ///
    /// If a bookmark for the same result ID already exists it is replaced.
    /// Trims the list to `maxEntries`, removing the oldest entries first.
    static func add(_ result: MessageSearchResult) {
        var bookmarks = all().filter { $0.result.id != result.id }
        let bookmark = SearchBookmark(result: result)
        bookmarks.append(bookmark)

        // Enforce max-entries cap by removing oldest first.
        if bookmarks.count > maxEntries {
            bookmarks.sort { $0.bookmarkedAt < $1.bookmarkedAt }
            bookmarks = Array(bookmarks.suffix(maxEntries))
        }

        persist(bookmarks)
    }

    /// Removes the bookmark with the given message result ID.
    static func remove(id: UUID) {
        let updated = all().filter { $0.result.id != id }
        persist(updated)
    }

    /// Removes all persisted bookmarks.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        AppLogger.shared.info("SearchBookmarkService: cleared all bookmarks", category: "search")
    }

    // MARK: - Private

    private static func persist(_ bookmarks: [SearchBookmark]) {
        do {
            let data = try encoder.encode(bookmarks)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            AppLogger.shared.error(
                "SearchBookmarkService: failed to persist bookmarks: \(error.localizedDescription)",
                category: "search"
            )
        }
    }
}
