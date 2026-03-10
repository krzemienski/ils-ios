import Foundation

/// Represents a bookmarked message within a Claude Code session, optionally marking
/// it as a key moment for later reference.
///
/// MessageBookmarks are persisted locally and synced across devices via
/// CloudKit private database. Conflict resolution uses ``modifiedAt`` with
/// a last-write-wins strategy.
public struct MessageBookmark: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this bookmark record.
    public let id: UUID
    /// The ID of the bookmarked message.
    public var messageId: String
    /// The ID of the session containing the bookmarked message.
    public var sessionId: UUID
    /// Display name of the session at time of bookmarking.
    public var sessionName: String?
    /// Snippet or full content of the bookmarked message.
    public var messageContent: String?
    /// Role of the message author (e.g. "user", "assistant").
    public var messageRole: String?
    /// Optional free-form note about this bookmark.
    public var note: String?
    /// User-assigned tags for organizing bookmarks.
    public var tags: [String]
    /// When this bookmark was first created.
    public let createdAt: Date
    /// When this bookmark was last modified (used for conflict resolution).
    public var modifiedAt: Date

    /// Creates a new message bookmark.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - messageId: The ID of the message to bookmark.
    ///   - sessionId: The ID of the session containing the message.
    ///   - sessionName: Display name of the session.
    ///   - messageContent: Snippet or full content of the message.
    ///   - messageRole: Role of the message author.
    ///   - note: Optional free-form note.
    ///   - tags: Tags for organizing bookmarks.
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - modifiedAt: Last-modified timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        messageId: String,
        sessionId: UUID,
        sessionName: String? = nil,
        messageContent: String? = nil,
        messageRole: String? = nil,
        note: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.messageId = messageId
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.messageContent = messageContent
        self.messageRole = messageRole
        self.note = note
        self.tags = tags
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func == (lhs: MessageBookmark, rhs: MessageBookmark) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
