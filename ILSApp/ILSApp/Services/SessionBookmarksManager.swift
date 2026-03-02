import CloudKit
import Foundation
import ILSShared
import Observation

// MARK: - SessionBookmarksManager

/// Manages session bookmarks with local persistence and cross-device CloudKit sync.
///
/// Bookmarks are persisted locally as JSON in UserDefaults and synced to the
/// CloudKit private database. Conflict resolution uses `SessionBookmark.modifiedAt`
/// with last-write-wins semantics.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class SessionBookmarksManager {
    static let shared = SessionBookmarksManager()

    // MARK: - Observable State

    private(set) var bookmarks: [SessionBookmark] = []
    private(set) var bookmarkedSessionIds: Set<UUID> = []
    private(set) var isSyncing = false

    // MARK: - Constants

    private enum StorageKey {
        static let bookmarks = "session_bookmarks"
    }

    private enum CloudKitConfig {
        static let containerIdentifier = "iCloud.com.ils.app"
        static let recordType = "SessionBookmark"
    }

    private enum RecordField {
        static let sessionId = "sessionId"
        static let sessionName = "sessionName"
        static let tags = "tags"
        static let notes = "notes"
        static let createdAt = "createdAt"
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
        bookmarks = loadFromLocal()
        bookmarkedSessionIds = Set(bookmarks.map(\.sessionId))
    }

    // MARK: - Public API

    /// Returns `true` if the given session is bookmarked. O(1) lookup via cached Set.
    func isBookmarked(sessionId: UUID) -> Bool {
        bookmarkedSessionIds.contains(sessionId)
    }

    /// Adds a bookmark for the given session.
    ///
    /// No-ops silently if a bookmark for the session already exists.
    func addBookmark(session: ChatSession) async {
        guard !isBookmarked(sessionId: session.id) else { return }

        let bookmark = SessionBookmark(
            sessionId: session.id,
            sessionName: session.name
        )
        bookmarks.append(bookmark)
        bookmarkedSessionIds.insert(bookmark.sessionId)
        saveToLocal()
        await saveToCloud(bookmark)

        AppLogger.shared.info(
            "Bookmark added for session \(session.id)",
            category: "bookmarks"
        )
    }

    /// Removes the bookmark for the given session ID.
    ///
    /// Also deletes the corresponding record from CloudKit.
    func removeBookmark(sessionId: UUID) async {
        guard let bookmark = bookmarks.first(where: { $0.sessionId == sessionId }) else { return }

        bookmarks.removeAll { $0.sessionId == sessionId }
        bookmarkedSessionIds.remove(sessionId)
        saveToLocal()
        await deleteFromCloud(bookmarkId: bookmark.id)

        AppLogger.shared.info(
            "Bookmark removed for session \(sessionId)",
            category: "bookmarks"
        )
    }

    /// Toggles the bookmark state for the given session.
    func toggleBookmark(session: ChatSession) async {
        if isBookmarked(sessionId: session.id) {
            await removeBookmark(sessionId: session.id)
        } else {
            await addBookmark(session: session)
        }
    }

    // MARK: - CloudKit Sync

    /// Pushes all local bookmarks to CloudKit using a batch save.
    ///
    /// No-ops if a sync is already in progress. Uses `.changedKeys` save policy
    /// so only modified fields are transmitted to reduce bandwidth.
    func syncToCloud() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard !bookmarks.isEmpty else { return }

        let records = bookmarks.map { makeRecord(from: $0) }

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
                "Synced \(successCount)/\(records.count) bookmark(s) to CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to sync bookmarks to CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    /// Pulls bookmarks from CloudKit and merges with local bookmarks.
    ///
    /// Conflict resolution: last-write-wins by `modifiedAt`. Remote bookmarks
    /// with a newer `modifiedAt` replace the local copy; local bookmarks without
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

            var remoteBookmarks: [SessionBookmark] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let bookmark = parseRecord(record) {
                        remoteBookmarks.append(bookmark)
                    }
                case .failure(let error):
                    AppLogger.shared.warning(
                        "Failed to parse CloudKit record: \(error.localizedDescription)",
                        category: "bookmarks"
                    )
                }
            }

            mergeRemote(remoteBookmarks)

            AppLogger.shared.info(
                "Fetched \(remoteBookmarks.count) bookmark(s) from CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to fetch bookmarks from CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    // MARK: - CloudKit Helpers

    private func saveToCloud(_ bookmark: SessionBookmark) async {
        let record = makeRecord(from: bookmark)
        do {
            try await database.save(record)
            AppLogger.shared.info(
                "Bookmark \(bookmark.id) saved to CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to save bookmark \(bookmark.id) to CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    private func deleteFromCloud(bookmarkId: UUID) async {
        let recordID = CKRecord.ID(recordName: bookmarkId.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            AppLogger.shared.info(
                "Bookmark \(bookmarkId) deleted from CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to delete bookmark \(bookmarkId) from CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    private func makeRecord(from bookmark: SessionBookmark) -> CKRecord {
        let recordID = CKRecord.ID(recordName: bookmark.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
        record[RecordField.sessionId] = bookmark.sessionId.uuidString as CKRecordValue
        record[RecordField.sessionName] = bookmark.sessionName as CKRecordValue?
        record[RecordField.tags] = bookmark.tags.joined(separator: ",") as CKRecordValue
        record[RecordField.notes] = bookmark.notes as CKRecordValue?
        record[RecordField.createdAt] = bookmark.createdAt as CKRecordValue
        record[RecordField.modifiedAt] = bookmark.modifiedAt as CKRecordValue
        return record
    }

    private func parseRecord(_ record: CKRecord) -> SessionBookmark? {
        guard
            let sessionIdString = record[RecordField.sessionId] as? String,
            let sessionId = UUID(uuidString: sessionIdString),
            let modifiedAt = record[RecordField.modifiedAt] as? Date
        else { return nil }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let sessionName = record[RecordField.sessionName] as? String
        let tagsString = record[RecordField.tags] as? String ?? ""
        let tags: [String] = tagsString.isEmpty ? [] : tagsString.split(separator: ",").map(String.init)
        let notes = record[RecordField.notes] as? String
        let createdAt = record[RecordField.createdAt] as? Date ?? modifiedAt

        return SessionBookmark(
            id: id,
            sessionId: sessionId,
            sessionName: sessionName,
            tags: tags,
            notes: notes,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - Merge

    /// Merges remote bookmarks into the local set using last-write-wins by `modifiedAt`.
    private func mergeRemote(_ remoteBookmarks: [SessionBookmark]) {
        // Index local bookmarks by sessionId for O(1) lookup
        var mergedBySessionId: [UUID: SessionBookmark] = [:]
        for local in bookmarks {
            mergedBySessionId[local.sessionId] = local
        }

        // Apply remote: last-write-wins
        for remote in remoteBookmarks {
            if let existing = mergedBySessionId[remote.sessionId] {
                if remote.modifiedAt > existing.modifiedAt {
                    mergedBySessionId[remote.sessionId] = remote
                }
            } else {
                mergedBySessionId[remote.sessionId] = remote
            }
        }

        let merged = mergedBySessionId.values.sorted { $0.createdAt > $1.createdAt }
        bookmarks = merged
        bookmarkedSessionIds = Set(merged.map(\.sessionId))
        saveToLocal()
    }

    // MARK: - Local Persistence

    private func loadFromLocal() -> [SessionBookmark] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.bookmarks) else {
            return []
        }
        do {
            return try decoder.decode([SessionBookmark].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "Failed to decode local bookmarks: \(error.localizedDescription)",
                category: "bookmarks"
            )
            return []
        }
    }

    private func saveToLocal() {
        do {
            let data = try encoder.encode(bookmarks)
            UserDefaults.standard.set(data, forKey: StorageKey.bookmarks)
        } catch {
            AppLogger.shared.warning(
                "Failed to encode bookmarks for local storage: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }
}
