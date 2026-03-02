import Foundation

/// Represents a favorited skill, optionally grouped into a named collection.
///
/// SkillFavorites are persisted locally and synced across devices via
/// CloudKit private database. Conflict resolution uses ``modifiedAt`` with
/// a last-write-wins strategy. ``skillName`` matches ``Skill.name`` and is
/// used to resolve the associated skill at runtime.
public struct SkillFavorite: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this favorite record.
    public let id: UUID
    /// The name of the favorited skill (matches ``Skill.name``).
    public var skillName: String
    /// Optional collection name for grouping favorites (e.g. "Daily Use", "Refactoring").
    public var collectionName: String?
    /// When this favorite was first created.
    public let addedAt: Date
    /// When this favorite was last modified (used for conflict resolution).
    public var modifiedAt: Date

    /// Creates a new skill favorite.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - skillName: The name of the skill to favorite. Must not be empty.
    ///   - collectionName: Optional collection name for grouping.
    ///   - addedAt: Creation timestamp (defaults to now).
    ///   - modifiedAt: Last-modified timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        skillName: String,
        collectionName: String? = nil,
        addedAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        precondition(!skillName.isEmpty, "SkillFavorite skillName must not be empty")
        self.id = id
        self.skillName = skillName
        self.collectionName = collectionName
        self.addedAt = addedAt
        self.modifiedAt = modifiedAt
    }

    public static func == (lhs: SkillFavorite, rhs: SkillFavorite) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
