import Foundation
import CloudKit

/// Defines the CloudKit schema for ILS models
enum CloudKitSchema {
    // MARK: - Record Types

    enum RecordType {
        static let chatSession = "ChatSession"
        static let template = "Template"
        static let snippet = "Snippet"
    }

    // MARK: - ChatSession Fields

    enum ChatSessionField {
        static let claudeSessionId = "claudeSessionId"
        static let name = "name"
        static let projectId = "projectId"
        static let projectName = "projectName"
        static let model = "model"
        static let permissionMode = "permissionMode"
        static let status = "status"
        static let messageCount = "messageCount"
        static let totalCostUSD = "totalCostUSD"
        static let source = "source"
        static let forkedFrom = "forkedFrom"
        static let createdAt = "createdAt"
        static let lastActiveAt = "lastActiveAt"
    }

    // MARK: - Template Fields

    enum TemplateField {
        static let name = "name"
        static let content = "content"
        static let description = "description"
        static let category = "category"
        static let createdAt = "createdAt"
        static let lastUsedAt = "lastUsedAt"
    }

    // MARK: - Snippet Fields

    enum SnippetField {
        static let name = "name"
        static let content = "content"
        static let description = "description"
        static let language = "language"
        static let category = "category"
        static let createdAt = "createdAt"
        static let lastUsedAt = "lastUsedAt"
    }

    // MARK: - Schema Validation

    /// Validates that a CKRecord conforms to the expected schema for a given record type
    /// - Parameters:
    ///   - record: The CloudKit record to validate
    ///   - recordType: The expected record type
    /// - Returns: True if the record conforms to the schema, false otherwise
    static func validateRecord(_ record: CKRecord, recordType: String) -> Bool {
        guard record.recordType == recordType else {
            return false
        }

        switch recordType {
        case RecordType.chatSession:
            return validateChatSessionRecord(record)
        case RecordType.template:
            return validateTemplateRecord(record)
        case RecordType.snippet:
            return validateSnippetRecord(record)
        default:
            return false
        }
    }

    // MARK: - Private Validation Methods

    private static func validateChatSessionRecord(_ record: CKRecord) -> Bool {
        // Validate required fields
        guard record[ChatSessionField.model] as? String != nil else { return false }
        guard record[ChatSessionField.permissionMode] as? String != nil else { return false }
        guard record[ChatSessionField.status] as? String != nil else { return false }
        guard record[ChatSessionField.messageCount] as? Int != nil else { return false }
        guard record[ChatSessionField.source] as? String != nil else { return false }
        guard record[ChatSessionField.createdAt] as? Date != nil else { return false }
        guard record[ChatSessionField.lastActiveAt] as? Date != nil else { return false }

        return true
    }

    private static func validateTemplateRecord(_ record: CKRecord) -> Bool {
        // Validate required fields
        guard record[TemplateField.name] as? String != nil else { return false }
        guard record[TemplateField.content] as? String != nil else { return false }
        guard record[TemplateField.createdAt] as? Date != nil else { return false }

        return true
    }

    private static func validateSnippetRecord(_ record: CKRecord) -> Bool {
        // Validate required fields
        guard record[SnippetField.name] as? String != nil else { return false }
        guard record[SnippetField.content] as? String != nil else { return false }
        guard record[SnippetField.createdAt] as? Date != nil else { return false }

        return true
    }
}
