import Foundation

// MARK: - Audit Action Type

/// The category of action Claude performed.
public enum AuditActionType: String, Codable, Sendable, CaseIterable {
    /// Claude wrote content to an existing file.
    case fileWrite = "file_write"
    /// Claude created a new file.
    case fileCreate = "file_create"
    /// Claude deleted a file.
    case fileDelete = "file_delete"
    /// Claude executed a shell or bash command.
    case bashCommand = "bash_command"
    /// Claude invoked a tool (non-file, non-bash).
    case toolUse = "tool_use"
    /// A permission request was approved or denied.
    case permissionDecision = "permission_decision"
    /// A previous audit action was rolled back.
    case rollback = "rollback"
}

// MARK: - Rollback Status

/// Whether this audit action has been rolled back.
public enum RollbackStatus: String, Codable, Sendable, CaseIterable {
    /// The action has not been rolled back.
    case notRolledBack = "not_rolled_back"
    /// The action has been rolled back.
    case rolledBack = "rolled_back"
}

// MARK: - Audit Action

/// An immutable record of a single action Claude performed during a session.
///
/// Every file modification, command execution, tool use, and permission decision is
/// captured as an ``AuditAction``. Before/after state is stored for file operations,
/// enabling one-tap rollback of individual or batched actions.
public struct AuditAction: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this audit action.
    public let id: UUID
    /// Identifier of the session that produced this action.
    public let sessionId: String
    /// Human-readable session name, if available.
    public let sessionName: String?
    /// Category of action Claude performed.
    public let actionType: AuditActionType
    /// Human-readable description of the action.
    public let description: String
    /// File path affected by this action, if applicable.
    public let filePath: String?
    /// Command executed, if applicable.
    public let command: String?
    /// Name of the tool invoked, if applicable.
    public let toolName: String?
    /// File content before the action (for file operations).
    public let beforeContent: String?
    /// File content after the action (for file operations).
    public let afterContent: String?
    /// Additional structured metadata as a JSON string.
    public let metadata: String?
    /// Whether this action can be individually rolled back.
    public let isRollbackable: Bool
    /// Current rollback state of this action.
    public var rollbackStatus: RollbackStatus
    /// When this action was rolled back, or nil if not rolled back.
    public var rolledBackAt: Date?
    /// ID of the rollback audit entry that reversed this action.
    public var rollbackAuditId: UUID?
    /// When this action was recorded (UTC).
    public let createdAt: Date

    /// Creates a new audit action record.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - sessionId: ID of the session that generated this action.
    ///   - sessionName: Optional human-readable session name.
    ///   - actionType: Category of action performed.
    ///   - description: Human-readable description.
    ///   - filePath: Affected file path, if applicable.
    ///   - command: Executed command, if applicable.
    ///   - toolName: Invoked tool name, if applicable.
    ///   - beforeContent: Pre-action file content, if applicable.
    ///   - afterContent: Post-action file content, if applicable.
    ///   - metadata: Additional JSON metadata, if any.
    ///   - isRollbackable: Whether this action supports rollback.
    ///   - rollbackStatus: Current rollback state.
    ///   - rolledBackAt: Rollback timestamp, if rolled back.
    ///   - rollbackAuditId: Audit ID of the rollback entry, if rolled back.
    ///   - createdAt: Timestamp of this action (defaults to now).
    public init(
        id: UUID = UUID(),
        sessionId: String,
        sessionName: String? = nil,
        actionType: AuditActionType,
        description: String,
        filePath: String? = nil,
        command: String? = nil,
        toolName: String? = nil,
        beforeContent: String? = nil,
        afterContent: String? = nil,
        metadata: String? = nil,
        isRollbackable: Bool,
        rollbackStatus: RollbackStatus = .notRolledBack,
        rolledBackAt: Date? = nil,
        rollbackAuditId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        precondition(!sessionId.isEmpty, "AuditAction sessionId must not be empty")
        precondition(!description.isEmpty, "AuditAction description must not be empty")
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.actionType = actionType
        self.description = description
        self.filePath = filePath
        self.command = command
        self.toolName = toolName
        self.beforeContent = beforeContent
        self.afterContent = afterContent
        self.metadata = metadata
        self.isRollbackable = isRollbackable
        self.rollbackStatus = rollbackStatus
        self.rolledBackAt = rolledBackAt
        self.rollbackAuditId = rollbackAuditId
        self.createdAt = createdAt
    }

    /// A display-friendly title for the audit action.
    ///
    /// Returns the file path, command, tool name, or falls back to the
    /// action type's human-readable label.
    public var displayTitle: String {
        if let filePath, !filePath.isEmpty {
            return (filePath as NSString).lastPathComponent
        }
        if let command, !command.isEmpty {
            let trimmed = command.trimmingCharacters(in: .whitespaces)
            let preview = String(trimmed.prefix(60))
            return trimmed.count > 60 ? "\(preview)…" : preview
        }
        if let toolName, !toolName.isEmpty {
            return toolName
        }
        switch actionType {
        case .fileWrite:          return "File Write"
        case .fileCreate:         return "File Created"
        case .fileDelete:         return "File Deleted"
        case .bashCommand:        return "Bash Command"
        case .toolUse:            return "Tool Use"
        case .permissionDecision: return "Permission Decision"
        case .rollback:           return "Rollback"
        }
    }

    /// Whether this action is currently eligible for rollback.
    ///
    /// Returns `true` only when the action is marked rollbackable and has
    /// not already been rolled back.
    public var canRollback: Bool {
        isRollbackable && rollbackStatus == .notRolledBack
    }
}
