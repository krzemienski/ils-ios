import CloudKit
import Foundation
import ILSShared
import Observation

// MARK: - SkillFavoritesManager

/// Manages skill favorites with local persistence and cross-device CloudKit sync.
///
/// Favorites are persisted locally as JSON in UserDefaults and synced to the
/// CloudKit private database. Conflict resolution uses `SkillFavorite.modifiedAt`
/// with last-write-wins semantics. Favorites can optionally be grouped into named
/// collections (e.g. "Daily Use", "Refactoring").
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class SkillFavoritesManager {
    static let shared = SkillFavoritesManager()

    // MARK: - Observable State

    private(set) var favorites: [SkillFavorite] = []
    private(set) var isSyncing = false

    // MARK: - Constants

    private enum StorageKey {
        static let favorites = "skill_favorites"
    }

    private enum CloudKitConfig {
        static let containerIdentifier = "iCloud.com.ils.app"
        static let recordType = "SkillFavorite"
    }

    private enum RecordField {
        static let skillName = "skillName"
        static let collectionName = "collectionName"
        static let addedAt = "addedAt"
        static let modifiedAt = "modifiedAt"
    }

    // MARK: - Private State

    private var database: CKDatabase {
        CKContainer(identifier: CloudKitConfig.containerIdentifier).privateCloudDatabase
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
        favorites = loadFromLocal()
    }

    // MARK: - Public API

    /// Returns `true` if the skill with the given name is favorited.
    func isFavorite(skillName: String) -> Bool {
        favorites.contains { $0.skillName == skillName }
    }

    /// All distinct collection names currently in use, sorted alphabetically.
    var collectionNames: [String] {
        let names = favorites.compactMap(\.collectionName)
        return Array(Set(names)).sorted()
    }

    /// Returns favorites belonging to the given collection, or all favorites
    /// without a collection when `collectionName` is `nil`.
    func favorites(in collectionName: String?) -> [SkillFavorite] {
        favorites.filter { $0.collectionName == collectionName }
    }

    /// Adds a favorite for the given skill.
    ///
    /// No-ops silently if a favorite for the skill already exists.
    func addFavorite(skill: Skill, collectionName: String? = nil) async {
        guard !isFavorite(skillName: skill.name) else { return }

        let favorite = SkillFavorite(
            skillName: skill.name,
            collectionName: collectionName
        )
        favorites.append(favorite)
        saveToLocal()
        await saveToCloud(favorite)

        AppLogger.shared.info(
            "Favorite added for skill '\(skill.name)'",
            category: "favorites"
        )
    }

    /// Removes the favorite for the given skill name.
    ///
    /// Also deletes the corresponding record from CloudKit.
    func removeFavorite(skillName: String) async {
        guard let favorite = favorites.first(where: { $0.skillName == skillName }) else { return }

        favorites.removeAll { $0.skillName == skillName }
        saveToLocal()
        await deleteFromCloud(favoriteId: favorite.id)

        AppLogger.shared.info(
            "Favorite removed for skill '\(skillName)'",
            category: "favorites"
        )
    }

    /// Toggles the favorite state for the given skill.
    func toggleFavorite(skill: Skill) async {
        if isFavorite(skillName: skill.name) {
            await removeFavorite(skillName: skill.name)
        } else {
            await addFavorite(skill: skill)
        }
    }

    /// Moves a favorite to the specified collection.
    ///
    /// Pass `nil` to remove it from any collection (ungrouped). No-ops if the
    /// favorite is not found.
    func moveFavorite(id: UUID, toCollection collectionName: String?) async {
        guard let index = favorites.firstIndex(where: { $0.id == id }) else { return }
        favorites[index].collectionName = collectionName
        favorites[index].modifiedAt = Date()
        saveToLocal()
        await saveToCloud(favorites[index])

        AppLogger.shared.info(
            "Favorite \(id) moved to collection '\(collectionName ?? "none")'",
            category: "favorites"
        )
    }

    // MARK: - CloudKit Sync

    /// Pushes all local favorites to CloudKit using a batch save.
    ///
    /// No-ops if a sync is already in progress. Uses `.changedKeys` save policy
    /// so only modified fields are transmitted to reduce bandwidth.
    func syncToCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard !favorites.isEmpty else { return }

        let records = favorites.map { makeRecord(from: $0) }

        do {
            let (saveResults, _) = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .changedKeys,
                atomically: false
            )

            let successCount = saveResults.values.filter { result in
                if case .success = result { return true }
                return false
            }.count

            AppLogger.shared.info(
                "Synced \(successCount)/\(records.count) favorite(s) to CloudKit",
                category: "favorites"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to sync favorites to CloudKit: \(error.localizedDescription)",
                category: "favorites"
            )
        }
    }

    /// Pulls favorites from CloudKit and merges with local favorites.
    ///
    /// Conflict resolution: last-write-wins by `modifiedAt`. Remote favorites
    /// with a newer `modifiedAt` replace the local copy; local favorites without
    /// a remote counterpart are preserved.
    func syncFromCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let query = CKQuery(
            recordType: CloudKitConfig.recordType,
            predicate: NSPredicate(value: true)
        )

        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )

            var remoteFavorites: [SkillFavorite] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let favorite = parseRecord(record) {
                        remoteFavorites.append(favorite)
                    }
                case .failure(let error):
                    AppLogger.shared.warning(
                        "Failed to parse CloudKit favorite record: \(error.localizedDescription)",
                        category: "favorites"
                    )
                }
            }

            mergeRemote(remoteFavorites)

            AppLogger.shared.info(
                "Fetched \(remoteFavorites.count) favorite(s) from CloudKit",
                category: "favorites"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to fetch favorites from CloudKit: \(error.localizedDescription)",
                category: "favorites"
            )
        }
    }

    // MARK: - CloudKit Helpers

    private func saveToCloud(_ favorite: SkillFavorite) async {
        let record = makeRecord(from: favorite)
        do {
            try await database.save(record)
            AppLogger.shared.info(
                "Favorite \(favorite.id) saved to CloudKit",
                category: "favorites"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to save favorite \(favorite.id) to CloudKit: \(error.localizedDescription)",
                category: "favorites"
            )
        }
    }

    private func deleteFromCloud(favoriteId: UUID) async {
        let recordID = CKRecord.ID(recordName: favoriteId.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            AppLogger.shared.info(
                "Favorite \(favoriteId) deleted from CloudKit",
                category: "favorites"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to delete favorite \(favoriteId) from CloudKit: \(error.localizedDescription)",
                category: "favorites"
            )
        }
    }

    private func makeRecord(from favorite: SkillFavorite) -> CKRecord {
        let recordID = CKRecord.ID(recordName: favorite.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
        record[RecordField.skillName] = favorite.skillName as CKRecordValue
        record[RecordField.collectionName] = favorite.collectionName as CKRecordValue?
        record[RecordField.addedAt] = favorite.addedAt as CKRecordValue
        record[RecordField.modifiedAt] = favorite.modifiedAt as CKRecordValue
        return record
    }

    private func parseRecord(_ record: CKRecord) -> SkillFavorite? {
        guard
            let skillName = record[RecordField.skillName] as? String,
            !skillName.isEmpty,
            let modifiedAt = record[RecordField.modifiedAt] as? Date
        else { return nil }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let collectionName = record[RecordField.collectionName] as? String
        let addedAt = record[RecordField.addedAt] as? Date ?? modifiedAt

        return SkillFavorite(
            id: id,
            skillName: skillName,
            collectionName: collectionName,
            addedAt: addedAt,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - Merge

    /// Merges remote favorites into the local set using last-write-wins by `modifiedAt`.
    private func mergeRemote(_ remoteFavorites: [SkillFavorite]) {
        // Index local favorites by skillName for O(1) lookup
        var mergedBySkillName: [String: SkillFavorite] = [:]
        for local in favorites {
            mergedBySkillName[local.skillName] = local
        }

        // Apply remote: last-write-wins
        for remote in remoteFavorites {
            if let existing = mergedBySkillName[remote.skillName] {
                if remote.modifiedAt > existing.modifiedAt {
                    mergedBySkillName[remote.skillName] = remote
                }
            } else {
                mergedBySkillName[remote.skillName] = remote
            }
        }

        let merged = mergedBySkillName.values.sorted { $0.addedAt > $1.addedAt }
        favorites = merged
        saveToLocal()
    }

    // MARK: - Local Persistence

    private func loadFromLocal() -> [SkillFavorite] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.favorites) else {
            return []
        }
        do {
            return try decoder.decode([SkillFavorite].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "Failed to decode local skill favorites: \(error.localizedDescription)",
                category: "favorites"
            )
            return []
        }
    }

    private func saveToLocal() {
        do {
            let data = try encoder.encode(favorites)
            UserDefaults.standard.set(data, forKey: StorageKey.favorites)
        } catch {
            AppLogger.shared.warning(
                "Failed to encode skill favorites for local storage: \(error.localizedDescription)",
                category: "favorites"
            )
        }
    }
}
