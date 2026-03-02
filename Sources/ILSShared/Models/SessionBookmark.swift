import Foundation

/// Represents a bookmarked Claude Code session with optional tags and notes.
///
/// SessionBookmarks are persisted locally and synced across devices via
/// CloudKit private database. Conflict resolution uses ``modifiedAt`` with
/// a last-write-wins strategy.
public struct SessionBookmark: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this bookmark record.
    public let id: UUID
    /// The ID of the bookmarked ``ChatSession``.
    public var sessionId: UUID
    /// Display name of the bookmarked session at time of bookmarking.
    public var sessionName: String?
    /// User-assigned tags for organizing bookmarks.
    public var tags: [String]
    /// Optional free-form notes about the session.
    public var notes: String?
    /// When this bookmark was first created.
    public let createdAt: Date
    /// When this bookmark was last modified (used for conflict resolution).
    public var modifiedAt: Date

    /// Creates a new session bookmark.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - sessionId: The ID of the session to bookmark. Must not be nil.
    ///   - sessionName: Display name of the session.
    ///   - tags: Tags for organizing bookmarks.
    ///   - notes: Optional free-form notes.
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - modifiedAt: Last-modified timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        sessionName: String? = nil,
        tags: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    public static func == (lhs: SessionBookmark, rhs: SessionBookmark) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
