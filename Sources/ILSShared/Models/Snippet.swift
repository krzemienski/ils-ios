import Foundation
import CloudKit

/// Represents a reusable code snippet
public struct Snippet: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var content: String
    public var description: String?
    public var language: String?
    public var category: String?
    public let createdAt: Date
    public var lastUsedAt: Date?
    public var modificationDate: Date

    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        description: String? = nil,
        language: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        modificationDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.description = description
        self.language = language
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.modificationDate = modificationDate
    }
}

// MARK: - CloudKitSyncable Conformance

extension Snippet: CloudKitSyncable {
    public static var recordType: String {
        return "Snippet"
    }

    public var recordName: String {
        return id.uuidString
    }

    public func toCKRecord(zoneID: CKRecordZone.ID?) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID ?? CKRecordZone.default().zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Store all properties
        record["name"] = name
        record["content"] = content
        record["description"] = description
        record["language"] = language
        record["category"] = category
        record["createdAt"] = createdAt
        record["lastUsedAt"] = lastUsedAt
        record["modificationDate"] = modificationDate

        return record
    }

    public init(from record: CKRecord) throws {
        // Validate record type
        guard record.recordType == Self.recordType else {
            throw CloudKitSyncError.typeMismatch(
                expected: Self.recordType,
                actual: record.recordType
            )
        }

        // Parse record name as UUID
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            throw CloudKitSyncError.invalidRecord
        }

        // Extract required fields
        guard let name = record["name"] as? String else {
            throw CloudKitSyncError.missingRequiredField("name")
        }

        guard let content = record["content"] as? String else {
            throw CloudKitSyncError.missingRequiredField("content")
        }

        guard let createdAt = record["createdAt"] as? Date else {
            throw CloudKitSyncError.missingRequiredField("createdAt")
        }

        guard let modificationDate = record["modificationDate"] as? Date else {
            throw CloudKitSyncError.missingRequiredField("modificationDate")
        }

        // Extract optional fields
        let description = record["description"] as? String
        let language = record["language"] as? String
        let category = record["category"] as? String
        let lastUsedAt = record["lastUsedAt"] as? Date

        // Initialize the model
        self.init(
            id: id,
            name: name,
            content: content,
            description: description,
            language: language,
            category: category,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            modificationDate: modificationDate
        )
    }
}
