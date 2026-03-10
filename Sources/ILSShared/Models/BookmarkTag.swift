import Foundation

/// Represents a tag that can be applied to message bookmarks for organization.
///
/// BookmarkTags are persisted locally and synced across devices via
/// CloudKit private database. Default tags are provided out-of-the-box
/// and can be identified via ``isDefault``.
public struct BookmarkTag: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this tag record.
    public let id: UUID
    /// Display name of the tag.
    public var name: String
    /// Hex color string for the tag (e.g. ``"#FF5733"``).
    public var colorHex: String
    /// Whether this is a built-in default tag provided by the app.
    public var isDefault: Bool
    /// When this tag was first created.
    public let createdAt: Date

    /// Creates a new bookmark tag.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name of the tag.
    ///   - colorHex: Hex color string for the tag.
    ///   - isDefault: Whether this is a built-in default tag.
    ///   - createdAt: Creation timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    public static func == (lhs: BookmarkTag, rhs: BookmarkTag) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Default Tags

public extension BookmarkTag {
    /// Pre-defined tag for bookmarking code solutions.
    static let codeSolution = BookmarkTag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Code Solution",
        colorHex: "#34C759",
        isDefault: true
    )

    /// Pre-defined tag for bookmarking architectural decisions and patterns.
    static let architecture = BookmarkTag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Architecture",
        colorHex: "#007AFF",
        isDefault: true
    )

    /// Pre-defined tag for bookmarking bug fix discussions.
    static let bugFix = BookmarkTag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Bug Fix",
        colorHex: "#FF3B30",
        isDefault: true
    )

    /// Pre-defined tag for bookmarking configuration-related messages.
    static let configuration = BookmarkTag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Configuration",
        colorHex: "#FF9500",
        isDefault: true
    )

    /// Pre-defined tag for bookmarking key decisions.
    static let decision = BookmarkTag(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        name: "Decision",
        colorHex: "#AF52DE",
        isDefault: true
    )

    /// All built-in default tags in display order.
    static let allDefaults: [BookmarkTag] = [
        .codeSolution,
        .architecture,
        .bugFix,
        .configuration,
        .decision
    ]
}
