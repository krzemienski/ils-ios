import Foundation
import CloudKit
import ILSShared

/// CloudKit service for CRUD operations on synced models
actor CloudKitService {
    private let container: CKContainer
    private let database: CKDatabase
    private let zone: CKRecordZone

    init(containerIdentifier: String? = nil) {
        if let identifier = containerIdentifier {
            self.container = CKContainer(identifier: identifier)
        } else {
            self.container = CKContainer.default()
        }

        self.database = container.privateCloudDatabase

        // Use custom zone for atomic operations and proper sync
        let zoneID = CKRecordZone.ID(zoneName: "ILSAppZone", ownerName: CKCurrentUserDefaultName)
        self.zone = CKRecordZone(zoneID: zoneID)
    }

    // MARK: - Zone Setup

    /// Ensures the custom zone exists, creating it if necessary
    func setupZone() async throws {
        do {
            _ = try await database.recordZone(for: zone.zoneID)
        } catch {
            // Zone doesn't exist, create it
            do {
                _ = try await database.save(zone)
            } catch let ckError as CKError {
                // If zone already exists, that's fine
                if ckError.code != .serverRecordChanged {
                    throw CloudKitServiceError.zoneCreationFailed(ckError)
                }
            }
        }
    }

    // MARK: - CRUD Operations

    /// Saves a record to CloudKit (create or update)
    /// - Parameter record: The CKRecord to save
    /// - Returns: The saved CKRecord with server-generated fields
    func save(_ record: CKRecord) async throws -> CKRecord {
        do {
            let savedRecord = try await database.save(record)
            return savedRecord
        } catch let ckError as CKError {
            throw mapCloudKitError(ckError)
        }
    }

    /// Saves multiple records in a batch operation
    /// - Parameter records: Array of CKRecords to save
    /// - Returns: Array of saved CKRecords
    func saveAll(_ records: [CKRecord]) async throws -> [CKRecord] {
        guard !records.isEmpty else { return [] }

        do {
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated

            return try await withCheckedThrowingContinuation { continuation in
                var savedRecords: [CKRecord] = []

                operation.perRecordSaveBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        savedRecords.append(record)
                    case .failure:
                        break
                    }
                }

                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: savedRecords)
                    case .failure(let error):
                        continuation.resume(throwing: self.mapCloudKitError(error as? CKError ?? CKError(.unknownItem)))
                    }
                }

                database.add(operation)
            }
        }
    }

    /// Fetches a record by its ID
    /// - Parameter recordID: The CKRecord.ID to fetch
    /// - Returns: The fetched CKRecord
    func fetch(_ recordID: CKRecord.ID) async throws -> CKRecord {
        do {
            let record = try await database.record(for: recordID)
            return record
        } catch let ckError as CKError {
            throw mapCloudKitError(ckError)
        }
    }

    /// Fetches multiple records by their IDs
    /// - Parameter recordIDs: Array of CKRecord.IDs to fetch
    /// - Returns: Dictionary mapping record IDs to fetched records
    func fetchAll(_ recordIDs: [CKRecord.ID]) async throws -> [CKRecord.ID: CKRecord] {
        guard !recordIDs.isEmpty else { return [:] }

        do {
            let results = try await database.records(for: recordIDs)
            var records: [CKRecord.ID: CKRecord] = [:]

            for (recordID, result) in results {
                if case .success(let record) = result {
                    records[recordID] = record
                }
            }

            return records
        } catch let ckError as CKError {
            throw mapCloudKitError(ckError)
        }
    }

    /// Deletes a record by its ID
    /// - Parameter recordID: The CKRecord.ID to delete
    func delete(_ recordID: CKRecord.ID) async throws {
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch let ckError as CKError {
            throw mapCloudKitError(ckError)
        }
    }

    /// Deletes multiple records in a batch operation
    /// - Parameter recordIDs: Array of CKRecord.IDs to delete
    func deleteAll(_ recordIDs: [CKRecord.ID]) async throws {
        guard !recordIDs.isEmpty else { return }

        do {
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
            operation.qualityOfService = .userInitiated

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: self.mapCloudKitError(error as? CKError ?? CKError(.unknownItem)))
                    }
                }

                database.add(operation)
            }
        }
    }

    // MARK: - Query Operations

    /// Queries for records of a specific type
    /// - Parameters:
    ///   - recordType: The CloudKit record type name
    ///   - predicate: Optional NSPredicate for filtering (defaults to all records)
    ///   - sortDescriptors: Optional array of NSSortDescriptors for ordering
    ///   - limit: Maximum number of records to fetch (defaults to 100)
    /// - Returns: Array of matching CKRecords
    func query(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        sortDescriptors: [NSSortDescriptor]? = nil,
        limit: Int = 100
    ) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zone.zoneID, resultsLimit: limit)

            var records: [CKRecord] = []
            for (_, result) in results {
                if case .success(let record) = result {
                    records.append(record)
                }
            }

            return records
        } catch let ckError as CKError {
            throw mapCloudKitError(ckError)
        }
    }

    /// Queries all records of a specific type
    /// - Parameter recordType: The CloudKit record type name
    /// - Returns: Array of all matching CKRecords
    func queryAll(recordType: String) async throws -> [CKRecord] {
        return try await query(recordType: recordType, limit: CKQueryOperation.maximumResults)
    }

    // MARK: - Generic CloudKitSyncable Operations

    /// Saves a CloudKitSyncable model to CloudKit
    /// - Parameter model: The model conforming to CloudKitSyncable
    /// - Returns: The saved CKRecord
    func save<T: CloudKitSyncable>(_ model: T) async throws -> CKRecord {
        let record = model.toCKRecord(zoneID: zone.zoneID)
        return try await save(record)
    }

    /// Fetches all records of a specific CloudKitSyncable type
    /// - Parameter type: The CloudKitSyncable type to fetch
    /// - Returns: Array of model instances
    func fetchAll<T: CloudKitSyncable>(ofType type: T.Type) async throws -> [T] {
        let records = try await queryAll(recordType: T.recordType)

        var models: [T] = []
        for record in records {
            do {
                let model = try T(from: record)
                models.append(model)
            } catch {
                // Log error but continue processing other records
                continue
            }
        }

        return models
    }

    // MARK: - Session Operations

    /// Saves a session to CloudKit
    /// - Parameter session: The ChatSession to save
    /// - Returns: The saved CKRecord
    func saveSession(_ session: ChatSession) async throws -> CKRecord {
        return try await save(session)
    }

    /// Fetches all sessions from CloudKit
    /// - Returns: Array of ChatSession objects
    func fetchSessions() async throws -> [ChatSession] {
        return try await fetchAll(ofType: ChatSession.self)
    }

    /// Deletes a session from CloudKit
    /// - Parameter sessionId: The UUID of the session to delete
    func deleteSession(_ sessionId: UUID) async throws {
        let recordID = CKRecord.ID(
            recordName: sessionId.uuidString,
            zoneID: zone.zoneID
        )
        try await delete(recordID)
    }

    // MARK: - Template Operations

    /// Saves a template to CloudKit
    /// - Parameter template: The Template to save
    /// - Returns: The saved CKRecord
    func saveTemplate(_ template: Template) async throws -> CKRecord {
        return try await save(template)
    }

    /// Fetches all templates from CloudKit
    /// - Returns: Array of Template objects
    func fetchTemplates() async throws -> [Template] {
        return try await fetchAll(ofType: Template.self)
    }

    /// Deletes a template from CloudKit
    /// - Parameter templateId: The UUID of the template to delete
    func deleteTemplate(_ templateId: UUID) async throws {
        let recordID = CKRecord.ID(
            recordName: templateId.uuidString,
            zoneID: zone.zoneID
        )
        try await delete(recordID)
    }

    // MARK: - Snippet Operations

    /// Saves a snippet to CloudKit
    /// - Parameter snippet: The Snippet to save
    /// - Returns: The saved CKRecord
    func saveSnippet(_ snippet: Snippet) async throws -> CKRecord {
        return try await save(snippet)
    }

    /// Fetches all snippets from CloudKit
    /// - Returns: Array of Snippet objects
    func fetchSnippets() async throws -> [Snippet] {
        return try await fetchAll(ofType: Snippet.self)
    }

    /// Deletes a snippet from CloudKit
    /// - Parameter snippetId: The UUID of the snippet to delete
    func deleteSnippet(_ snippetId: UUID) async throws {
        let recordID = CKRecord.ID(
            recordName: snippetId.uuidString,
            zoneID: zone.zoneID
        )
        try await delete(recordID)
    }

    // MARK: - Account Status

    /// Checks if iCloud is available and user is signed in
    /// - Returns: True if CloudKit is available, false otherwise
    func checkAccountStatus() async throws -> Bool {
        let status = try await container.accountStatus()

        switch status {
        case .available:
            return true
        case .noAccount:
            throw CloudKitServiceError.noiCloudAccount
        case .restricted:
            throw CloudKitServiceError.iCloudRestricted
        case .couldNotDetermine:
            throw CloudKitServiceError.accountStatusUnknown
        case .temporarilyUnavailable:
            throw CloudKitServiceError.temporarilyUnavailable
        @unknown default:
            throw CloudKitServiceError.accountStatusUnknown
        }
    }

    // MARK: - Error Mapping

    private func mapCloudKitError(_ error: CKError?) -> CloudKitServiceError {
        guard let ckError = error else {
            return .unknownError
        }

        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .notAuthenticated:
            return .notAuthenticated
        case .permissionFailure:
            return .permissionDenied
        case .quotaExceeded:
            return .quotaExceeded
        case .zoneNotFound:
            return .zoneNotFound
        case .serverRecordChanged:
            return .conflictDetected(ckError)
        case .unknownItem:
            return .recordNotFound
        case .partialFailure:
            return .partialFailure(ckError)
        default:
            return .operationFailed(ckError)
        }
    }
}

// MARK: - Error Types

enum CloudKitServiceError: Error, LocalizedError {
    case noiCloudAccount
    case iCloudRestricted
    case accountStatusUnknown
    case temporarilyUnavailable
    case notAuthenticated
    case permissionDenied
    case networkUnavailable
    case quotaExceeded
    case zoneNotFound
    case zoneCreationFailed(Error)
    case recordNotFound
    case conflictDetected(Error)
    case partialFailure(Error)
    case operationFailed(Error)
    case unknownError

    var errorDescription: String? {
        switch self {
        case .noiCloudAccount:
            return "iCloud account not found. Please sign in to iCloud in Settings."
        case .iCloudRestricted:
            return "iCloud access is restricted on this device."
        case .accountStatusUnknown:
            return "Unable to determine iCloud account status."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Please try again later."
        case .notAuthenticated:
            return "Not authenticated with iCloud. Please sign in."
        case .permissionDenied:
            return "Permission denied. Please check iCloud permissions in Settings."
        case .networkUnavailable:
            return "Network unavailable. Please check your internet connection."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Please free up space."
        case .zoneNotFound:
            return "CloudKit zone not found. Please try syncing again."
        case .zoneCreationFailed(let error):
            return "Failed to create CloudKit zone: \(error.localizedDescription)"
        case .recordNotFound:
            return "Record not found in CloudKit."
        case .conflictDetected(let error):
            return "Sync conflict detected: \(error.localizedDescription)"
        case .partialFailure(let error):
            return "Some operations failed: \(error.localizedDescription)"
        case .operationFailed(let error):
            return "CloudKit operation failed: \(error.localizedDescription)"
        case .unknownError:
            return "An unknown error occurred."
        }
    }

    var isRetriable: Bool {
        switch self {
        case .networkUnavailable, .temporarilyUnavailable, .quotaExceeded:
            return true
        case .operationFailed, .partialFailure:
            return true
        case .noiCloudAccount, .iCloudRestricted, .notAuthenticated, .permissionDenied:
            return false
        case .accountStatusUnknown, .zoneNotFound, .zoneCreationFailed, .recordNotFound:
            return false
        case .conflictDetected:
            return false // Conflicts need special handling
        case .unknownError:
            return false
        }
    }
}
