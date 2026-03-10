import Foundation
import ILSShared
import Observation

// MARK: - BookmarkTagsManager

/// Manages bookmark tags with local UserDefaults persistence.
///
/// Default preset tags (``BookmarkTag.allDefaults``) are always available and cannot
/// be removed. Custom tags created by the user are persisted locally as JSON in
/// UserDefaults and may be added, removed, or reordered.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class BookmarkTagsManager {
    static let shared = BookmarkTagsManager()

    // MARK: - Observable State

    /// Custom (user-created) tags in display order.
    private(set) var customTags: [BookmarkTag] = []

    // MARK: - Constants

    private enum StorageKey {
        static let customTags = "bookmark_custom_tags"
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    private init() {
        customTags = loadFromLocal()
    }

    // MARK: - Computed Properties

    /// All available tags: built-in defaults followed by custom tags in display order.
    var allTags: [BookmarkTag] {
        BookmarkTag.allDefaults + customTags
    }

    // MARK: - Queries

    /// Returns the tag with the given ID, or `nil` if not found.
    func tag(id: UUID) -> BookmarkTag? {
        allTags.first { $0.id == id }
    }

    /// Returns tags matching the given array of IDs, in the order they appear in ``allTags``.
    func tags(ids: [String]) -> [BookmarkTag] {
        let idSet = Set(ids)
        return allTags.filter { idSet.contains($0.id.uuidString) }
    }

    // MARK: - Mutations

    /// Adds a new custom tag with the given name and color hex.
    ///
    /// No-ops silently if a tag with the same name already exists (case-insensitive).
    @discardableResult
    func addTag(name: String, colorHex: String) -> BookmarkTag? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let isDuplicate = allTags.contains {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !isDuplicate else { return nil }

        let tag = BookmarkTag(name: trimmed, colorHex: colorHex, isDefault: false)
        customTags.append(tag)
        saveToLocal()

        AppLogger.shared.info(
            "BookmarkTagsManager: tag '\(trimmed)' added",
            category: "bookmarks"
        )

        return tag
    }

    /// Removes the custom tag with the given ID.
    ///
    /// No-ops silently if the ID belongs to a default tag or is not found.
    func removeTag(id: UUID) {
        guard let tag = customTags.first(where: { $0.id == id }) else { return }

        customTags.removeAll { $0.id == id }
        saveToLocal()

        AppLogger.shared.info(
            "BookmarkTagsManager: tag '\(tag.name)' removed",
            category: "bookmarks"
        )
    }

    /// Reorders custom tags using the offsets produced by `ForEach`/`List` with `.onMove`.
    ///
    /// Only affects the custom tags list; default tags are always shown first.
    func moveTags(fromOffsets source: IndexSet, toOffset destination: Int) {
        customTags.move(fromOffsets: source, toOffset: destination)
        saveToLocal()
    }

    /// Updates the name and color of an existing custom tag.
    ///
    /// No-ops silently for default tags or unknown IDs.
    func updateTag(id: UUID, name: String, colorHex: String) {
        guard let index = customTags.firstIndex(where: { $0.id == id }) else { return }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        customTags[index].name = trimmed
        customTags[index].colorHex = colorHex
        saveToLocal()

        AppLogger.shared.info(
            "BookmarkTagsManager: tag '\(trimmed)' updated",
            category: "bookmarks"
        )
    }

    // MARK: - Local Persistence

    private func loadFromLocal() -> [BookmarkTag] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.customTags) else {
            return []
        }
        do {
            return try decoder.decode([BookmarkTag].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "BookmarkTagsManager: failed to decode custom tags: \(error.localizedDescription)",
                category: "bookmarks"
            )
            return []
        }
    }

    private func saveToLocal() {
        do {
            let data = try encoder.encode(customTags)
            UserDefaults.standard.set(data, forKey: StorageKey.customTags)
        } catch {
            AppLogger.shared.warning(
                "BookmarkTagsManager: failed to persist custom tags: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }
}
