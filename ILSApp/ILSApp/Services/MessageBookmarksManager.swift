import CloudKit
import Foundation
import ILSShared
import Observation

// MARK: - MessageBookmarksManager

/// Manages message bookmarks with local persistence and cross-device CloudKit sync.
///
/// Bookmarks are persisted locally as JSON in UserDefaults and synced to the
/// CloudKit private database. Conflict resolution uses `MessageBookmark.modifiedAt`
/// with last-write-wins semantics.
///
/// Uses @Observable for zero-overhead SwiftUI integration.
@MainActor
@Observable
final class MessageBookmarksManager {
    static let shared = MessageBookmarksManager()

    // MARK: - Observable State

    private(set) var bookmarks: [MessageBookmark] = []
    private(set) var bookmarkedMessageIds: Set<String> = []
    private(set) var isSyncing = false

    // MARK: - Constants

    private enum StorageKey {
        static let bookmarks = "message_bookmarks"
    }

    private enum CloudKitConfig {
        static let containerIdentifier = "iCloud.com.ils.app"
        static let recordType = "MessageBookmark"
    }

    private enum RecordField {
        static let messageId = "messageId"
        static let sessionId = "sessionId"
        static let sessionName = "sessionName"
        static let messageContent = "messageContent"
        static let messageRole = "messageRole"
        static let note = "note"
        static let tags = "tags"
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
        bookmarkedMessageIds = Set(bookmarks.map(\.messageId))
    }

    // MARK: - Public API

    /// Returns `true` if the given message is bookmarked. O(1) lookup via cached Set.
    func isBookmarked(messageId: String) -> Bool {
        bookmarkedMessageIds.contains(messageId)
    }

    /// Returns the number of bookmarks for a given session.
    func bookmarkCount(for sessionId: UUID) -> Int {
        bookmarks.filter { $0.sessionId == sessionId }.count
    }

    /// Returns all bookmarks for a given session.
    func bookmarks(for sessionId: UUID) -> [MessageBookmark] {
        bookmarks.filter { $0.sessionId == sessionId }
    }

    /// Adds a bookmark for the given message.
    ///
    /// No-ops silently if a bookmark for the message already exists.
    func addBookmark(
        messageId: String,
        sessionId: UUID,
        sessionName: String? = nil,
        messageContent: String? = nil,
        messageRole: String? = nil,
        note: String? = nil,
        tags: [String] = []
    ) async {
        guard !isBookmarked(messageId: messageId) else { return }

        let bookmark = MessageBookmark(
            messageId: messageId,
            sessionId: sessionId,
            sessionName: sessionName,
            messageContent: messageContent,
            messageRole: messageRole,
            note: note,
            tags: tags
        )
        bookmarks.append(bookmark)
        bookmarkedMessageIds.insert(bookmark.messageId)
        saveToLocal()
        await saveToCloud(bookmark)

        AppLogger.shared.info(
            "Bookmark added for message \(messageId)",
            category: "bookmarks"
        )
    }

    /// Removes the bookmark for the given message ID.
    ///
    /// Also deletes the corresponding record from CloudKit.
    func removeBookmark(messageId: String) async {
        guard let bookmark = bookmarks.first(where: { $0.messageId == messageId }) else { return }

        bookmarks.removeAll { $0.messageId == messageId }
        bookmarkedMessageIds.remove(messageId)
        saveToLocal()
        await deleteFromCloud(bookmarkId: bookmark.id)

        AppLogger.shared.info(
            "Bookmark removed for message \(messageId)",
            category: "bookmarks"
        )
    }

    /// Toggles the bookmark state for the given message.
    func toggleBookmark(
        messageId: String,
        sessionId: UUID,
        sessionName: String? = nil,
        messageContent: String? = nil,
        messageRole: String? = nil
    ) async {
        if isBookmarked(messageId: messageId) {
            await removeBookmark(messageId: messageId)
        } else {
            await addBookmark(
                messageId: messageId,
                sessionId: sessionId,
                sessionName: sessionName,
                messageContent: messageContent,
                messageRole: messageRole
            )
        }
    }

    /// Updates the note and tags on an existing bookmark.
    ///
    /// No-ops silently if no bookmark exists for the given message ID.
    func updateBookmark(messageId: String, note: String?, tags: [String]) async {
        guard let index = bookmarks.firstIndex(where: { $0.messageId == messageId }) else { return }

        var updated = bookmarks[index]
        updated.note = note
        updated.tags = tags
        updated.modifiedAt = Date()
        bookmarks[index] = updated
        saveToLocal()
        await saveToCloud(updated)

        AppLogger.shared.info(
            "Bookmark updated for message \(messageId)",
            category: "bookmarks"
        )
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
                "Synced \(successCount)/\(records.count) message bookmark(s) to CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to sync message bookmarks to CloudKit: \(error.localizedDescription)",
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

            var remoteBookmarks: [MessageBookmark] = []
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
                "Fetched \(remoteBookmarks.count) message bookmark(s) from CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.error(
                "Failed to fetch message bookmarks from CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    // MARK: - CloudKit Helpers

    private func saveToCloud(_ bookmark: MessageBookmark) async {
        let record = makeRecord(from: bookmark)
        do {
            try await database.save(record)
            AppLogger.shared.info(
                "Message bookmark \(bookmark.id) saved to CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to save message bookmark \(bookmark.id) to CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    private func deleteFromCloud(bookmarkId: UUID) async {
        let recordID = CKRecord.ID(recordName: bookmarkId.uuidString)
        do {
            try await database.deleteRecord(withID: recordID)
            AppLogger.shared.info(
                "Message bookmark \(bookmarkId) deleted from CloudKit",
                category: "bookmarks"
            )
        } catch {
            AppLogger.shared.warning(
                "Failed to delete message bookmark \(bookmarkId) from CloudKit: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }

    private func makeRecord(from bookmark: MessageBookmark) -> CKRecord {
        let recordID = CKRecord.ID(recordName: bookmark.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.recordType, recordID: recordID)
        record[RecordField.messageId] = bookmark.messageId as CKRecordValue
        record[RecordField.sessionId] = bookmark.sessionId.uuidString as CKRecordValue
        record[RecordField.sessionName] = bookmark.sessionName as CKRecordValue?
        record[RecordField.messageContent] = bookmark.messageContent as CKRecordValue?
        record[RecordField.messageRole] = bookmark.messageRole as CKRecordValue?
        record[RecordField.note] = bookmark.note as CKRecordValue?
        record[RecordField.tags] = bookmark.tags.joined(separator: ",") as CKRecordValue
        record[RecordField.createdAt] = bookmark.createdAt as CKRecordValue
        record[RecordField.modifiedAt] = bookmark.modifiedAt as CKRecordValue
        return record
    }

    private func parseRecord(_ record: CKRecord) -> MessageBookmark? {
        guard
            let messageId = record[RecordField.messageId] as? String,
            let sessionIdString = record[RecordField.sessionId] as? String,
            let sessionId = UUID(uuidString: sessionIdString),
            let modifiedAt = record[RecordField.modifiedAt] as? Date
        else { return nil }

        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        let sessionName = record[RecordField.sessionName] as? String
        let messageContent = record[RecordField.messageContent] as? String
        let messageRole = record[RecordField.messageRole] as? String
        let note = record[RecordField.note] as? String
        let tagsString = record[RecordField.tags] as? String ?? ""
        let tags: [String] = tagsString.isEmpty ? [] : tagsString.split(separator: ",").map(String.init)
        let createdAt = record[RecordField.createdAt] as? Date ?? modifiedAt

        return MessageBookmark(
            id: id,
            messageId: messageId,
            sessionId: sessionId,
            sessionName: sessionName,
            messageContent: messageContent,
            messageRole: messageRole,
            note: note,
            tags: tags,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }

    // MARK: - Merge

    /// Merges remote bookmarks into the local set using last-write-wins by `modifiedAt`.
    private func mergeRemote(_ remoteBookmarks: [MessageBookmark]) {
        // Index local bookmarks by messageId for O(1) lookup
        var mergedByMessageId: [String: MessageBookmark] = [:]
        for local in bookmarks {
            mergedByMessageId[local.messageId] = local
        }

        // Apply remote: last-write-wins
        for remote in remoteBookmarks {
            if let existing = mergedByMessageId[remote.messageId] {
                if remote.modifiedAt > existing.modifiedAt {
                    mergedByMessageId[remote.messageId] = remote
                }
            } else {
                mergedByMessageId[remote.messageId] = remote
            }
        }

        let merged = mergedByMessageId.values.sorted { $0.createdAt > $1.createdAt }
        bookmarks = merged
        bookmarkedMessageIds = Set(merged.map(\.messageId))
        saveToLocal()
    }

    // MARK: - Local Persistence

    private func loadFromLocal() -> [MessageBookmark] {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.bookmarks) else {
            return []
        }
        do {
            return try decoder.decode([MessageBookmark].self, from: data)
        } catch {
            AppLogger.shared.warning(
                "Failed to decode local message bookmarks: \(error.localizedDescription)",
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
                "Failed to encode message bookmarks for local storage: \(error.localizedDescription)",
                category: "bookmarks"
            )
        }
    }
}
