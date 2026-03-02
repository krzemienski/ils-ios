import Foundation

// MARK: - Checkpoint

/// A saved snapshot of a session's message state at a point in time.
///
/// Checkpoints store the list of message IDs present at the time of creation
/// rather than duplicating message content, keeping storage efficient. Restoring
/// a checkpoint deletes any messages that are not in ``snapshotMessageIds``.
public struct Checkpoint: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for this checkpoint.
    public let id: UUID
    /// ID of the session this checkpoint belongs to.
    public let sessionId: UUID
    /// Optional user-provided label for the checkpoint.
    public var label: String?
    /// Number of messages in the session at checkpoint time.
    public var messageCount: Int
    /// Ordered list of message IDs present at checkpoint time.
    ///
    /// Stored as a JSON string in the database; decoded as `[UUID]` in Swift.
    public var snapshotMessageIds: [UUID]
    /// Whether this checkpoint was created automatically by the system.
    public var isAuto: Bool
    /// When the checkpoint was created.
    public let createdAt: Date

    /// Creates a new checkpoint.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - sessionId: ID of the parent session.
    ///   - label: Optional user-provided label.
    ///   - messageCount: Number of messages at checkpoint time.
    ///   - snapshotMessageIds: Ordered list of message IDs in the snapshot.
    ///   - isAuto: Whether this was auto-created by the system.
    ///   - createdAt: Creation timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        label: String? = nil,
        messageCount: Int,
        snapshotMessageIds: [UUID],
        isAuto: Bool,
        createdAt: Date = Date()
    ) {
        precondition(messageCount >= 0, "Checkpoint messageCount must be non-negative")
        self.id = id
        self.sessionId = sessionId
        self.label = label
        self.messageCount = messageCount
        self.snapshotMessageIds = snapshotMessageIds
        self.isAuto = isAuto
        self.createdAt = createdAt
    }

    /// A display-friendly title for the checkpoint.
    ///
    /// Returns the user-provided label when available; otherwise returns
    /// "Auto Checkpoint" or "Manual Checkpoint" depending on ``isAuto``.
    public var displayTitle: String {
        if let label, !label.isEmpty {
            return label
        }
        return isAuto ? "Auto Checkpoint" : "Manual Checkpoint"
    }
}

// MARK: - Request / Response DTOs

/// Request body for creating a new checkpoint.
public struct CreateCheckpointRequest: Codable, Sendable {
    /// Optional user-provided label for the checkpoint.
    public let label: String?
    /// Whether this checkpoint is being created automatically by the system.
    public let isAuto: Bool

    /// Creates a checkpoint creation request.
    /// - Parameters:
    ///   - label: Optional display label.
    ///   - isAuto: `true` if the system is creating this automatically.
    public init(label: String? = nil, isAuto: Bool) {
        self.label = label
        self.isAuto = isAuto
    }
}

/// Response returned after restoring a session to a checkpoint.
public struct RestoreCheckpointResponse: Codable, Sendable {
    /// Number of messages that remain in the session after the restore.
    public let restoredMessageCount: Int

    /// Creates a restore response.
    /// - Parameter restoredMessageCount: Number of messages remaining post-restore.
    public init(restoredMessageCount: Int) {
        self.restoredMessageCount = restoredMessageCount
    }
}
