import Foundation
import CloudKit

/// Session status enumeration
public enum SessionStatus: String, Codable, Sendable {
    case active
    case completed
    case cancelled
    case error
}

/// Source of the session (ILS-created or discovered from Claude Code)
public enum SessionSource: String, Codable, Sendable {
    case ils
    case external
}

/// Permission mode for Claude Code execution
public enum PermissionMode: String, Codable, Sendable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case plan = "plan"
    case bypassPermissions = "bypassPermissions"
}

/// Represents a chat session with Claude Code
public struct ChatSession: Codable, Identifiable, Sendable {
    public let id: UUID
    public var claudeSessionId: String?
    public var name: String?
    public var projectId: UUID?
    public var projectName: String?
    public var model: String
    public var permissionMode: PermissionMode
    public var status: SessionStatus
    public var messageCount: Int
    public var totalCostUSD: Double?
    public var source: SessionSource
    public var forkedFrom: UUID?
    public let createdAt: Date
    public var lastActiveAt: Date

    public init(
        id: UUID = UUID(),
        claudeSessionId: String? = nil,
        name: String? = nil,
        projectId: UUID? = nil,
        projectName: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        status: SessionStatus = .active,
        messageCount: Int = 0,
        totalCostUSD: Double? = nil,
        source: SessionSource = .ils,
        forkedFrom: UUID? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectId = projectId
        self.projectName = projectName
        self.model = model
        self.permissionMode = permissionMode
        self.status = status
        self.messageCount = messageCount
        self.totalCostUSD = totalCostUSD
        self.source = source
        self.forkedFrom = forkedFrom
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
}

/// External session discovered from Claude Code storage
public struct ExternalSession: Codable, Sendable {
    public let claudeSessionId: String
    public var name: String?
    public let projectPath: String?
    public let source: SessionSource
    public let lastActiveAt: Date?

    public init(
        claudeSessionId: String,
        name: String? = nil,
        projectPath: String? = nil,
        source: SessionSource = .external,
        lastActiveAt: Date? = nil
    ) {
        self.claudeSessionId = claudeSessionId
        self.name = name
        self.projectPath = projectPath
        self.source = source
        self.lastActiveAt = lastActiveAt
    }
}

// MARK: - CloudKitSyncable Conformance

extension ChatSession: CloudKitSyncable {
    public static var recordType: String {
        return "ChatSession"
    }

    public var recordName: String {
        return id.uuidString
    }

    public func toCKRecord(zoneID: CKRecordZone.ID?) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID ?? CKRecordZone.default().zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)

        // Store all properties
        record["claudeSessionId"] = claudeSessionId
        record["name"] = name
        record["projectId"] = projectId?.uuidString
        record["projectName"] = projectName
        record["model"] = model
        record["permissionMode"] = permissionMode.rawValue
        record["status"] = status.rawValue
        record["messageCount"] = messageCount
        record["totalCostUSD"] = totalCostUSD
        record["source"] = source.rawValue
        record["forkedFrom"] = forkedFrom?.uuidString
        record["createdAt"] = createdAt
        record["lastActiveAt"] = lastActiveAt

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
        guard let model = record["model"] as? String else {
            throw CloudKitSyncError.missingRequiredField("model")
        }

        guard let permissionModeRaw = record["permissionMode"] as? String,
              let permissionMode = PermissionMode(rawValue: permissionModeRaw) else {
            throw CloudKitSyncError.missingRequiredField("permissionMode")
        }

        guard let statusRaw = record["status"] as? String,
              let status = SessionStatus(rawValue: statusRaw) else {
            throw CloudKitSyncError.missingRequiredField("status")
        }

        guard let messageCount = record["messageCount"] as? Int else {
            throw CloudKitSyncError.missingRequiredField("messageCount")
        }

        guard let sourceRaw = record["source"] as? String,
              let source = SessionSource(rawValue: sourceRaw) else {
            throw CloudKitSyncError.missingRequiredField("source")
        }

        guard let createdAt = record["createdAt"] as? Date else {
            throw CloudKitSyncError.missingRequiredField("createdAt")
        }

        guard let lastActiveAt = record["lastActiveAt"] as? Date else {
            throw CloudKitSyncError.missingRequiredField("lastActiveAt")
        }

        // Extract optional fields
        let claudeSessionId = record["claudeSessionId"] as? String
        let name = record["name"] as? String
        let projectId = (record["projectId"] as? String).flatMap { UUID(uuidString: $0) }
        let projectName = record["projectName"] as? String
        let totalCostUSD = record["totalCostUSD"] as? Double
        let forkedFrom = (record["forkedFrom"] as? String).flatMap { UUID(uuidString: $0) }

        // Initialize the struct
        self.init(
            id: id,
            claudeSessionId: claudeSessionId,
            name: name,
            projectId: projectId,
            projectName: projectName,
            model: model,
            permissionMode: permissionMode,
            status: status,
            messageCount: messageCount,
            totalCostUSD: totalCostUSD,
            source: source,
            forkedFrom: forkedFrom,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt
        )
    }
}
