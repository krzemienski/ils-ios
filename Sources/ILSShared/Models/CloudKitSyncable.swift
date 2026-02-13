import Foundation
import CloudKit

/// Protocol for models that can be synced with CloudKit
public protocol CloudKitSyncable {
    /// The CloudKit record type name (e.g., "ChatSession", "Template")
    static var recordType: String { get }

    /// The unique identifier for this record
    var recordName: String { get }

    /// The creation date for conflict resolution
    var createdAt: Date { get }

    /// Converts the model to a CloudKit record
    /// - Parameter zoneID: The CloudKit zone ID (optional, defaults to default zone)
    /// - Returns: A CKRecord representing this model
    func toCKRecord(zoneID: CKRecordZone.ID?) -> CKRecord

    /// Initializes the model from a CloudKit record
    /// - Parameter record: The CloudKit record to convert from
    /// - Throws: An error if the record cannot be converted
    init(from record: CKRecord) throws
}

extension CloudKitSyncable {
    /// Default implementation uses the default zone if no zone is specified
    public func toCKRecord() -> CKRecord {
        return toCKRecord(zoneID: nil)
    }
}

/// Error types for CloudKit sync operations
public enum CloudKitSyncError: Error {
    case invalidRecord
    case missingRequiredField(String)
    case typeMismatch(expected: String, actual: String)
}
