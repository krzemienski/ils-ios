import Foundation

// MARK: - Session Checkpoint

/// A named snapshot of a session's state at a specific point in time.
///
/// Checkpoints allow users to mark important milestones in a conversation
/// and restore session state to those points. Automatic checkpoints are
/// created by the system at regular intervals or on significant events;
/// manual checkpoints are created explicitly by the user.
public struct SessionCheckpoint: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this checkpoint.
    public let id: UUID
    /// The session this checkpoint belongs to.
    public let sessionId: UUID
    /// User-provided or auto-generated name for the checkpoint.
    public var name: String
    /// When this checkpoint was created.
    public let createdAt: Date
    /// Number of messages in the session at checkpoint time.
    public var messageCount: Int
    /// Whether this checkpoint was created automatically by the system.
    public var isAutomatic: Bool

    /// Creates a new session checkpoint.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - sessionId: The session this checkpoint belongs to.
    ///   - name: Name for the checkpoint.
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - messageCount: Number of messages at checkpoint time.
    ///   - isAutomatic: Whether this was created automatically.
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        name: String,
        createdAt: Date = Date(),
        messageCount: Int = 0,
        isAutomatic: Bool = false
    ) {
        precondition(!name.isEmpty, "SessionCheckpoint name must not be empty")
        precondition(messageCount >= 0, "SessionCheckpoint messageCount must be non-negative")
        self.id = id
        self.sessionId = sessionId
        self.name = name
        self.createdAt = createdAt
        self.messageCount = messageCount
        self.isAutomatic = isAutomatic
    }
}
