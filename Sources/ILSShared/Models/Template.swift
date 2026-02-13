import Foundation
import CloudKit

/// Represents a reusable prompt template
public struct Template: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var content: String
    public var description: String?
    public var category: String?
    public let createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        content: String,
        description: String? = nil,
        category: String? = nil,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.description = description
        self.category = category
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

// MARK: - CloudKitSyncable Conformance

extension Template: CloudKitSyncable {
    public static var recordType: String {
        return "Template"
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
        record["category"] = category
        record["createdAt"] = createdAt
        record["lastUsedAt"] = lastUsedAt

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

        // Extract optional fields
        let description = record["description"] as? String
        let category = record["category"] as? String
        let lastUsedAt = record["lastUsedAt"] as? Date

        // Initialize the model
        self.init(
            id: id,
            name: name,
            content: content,
            description: description,
            category: category,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
}
