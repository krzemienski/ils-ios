import Foundation

// MARK: - Permission Policy Settings

/// Configuration for the permission policy engine — per-project or global.
///
/// When ``defaultDeny`` is `true`, any permission request that is not matched by an
/// explicit `allow` rule is automatically denied without prompting the user.
/// When `false` (the default), unmatched requests fall through to the normal
/// interactive approval flow.
public struct PermissionPolicySettings: Codable, Sendable, Equatable {
    /// Unique identifier for this settings record.
    public let id: UUID
    /// Optional project UUID. When nil this record applies globally.
    public var projectId: UUID?
    /// When true, unmatched permission requests are auto-denied.
    public var defaultDeny: Bool
    /// When the settings record was created.
    public let createdAt: Date
    /// When the settings record was last updated.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        defaultDeny: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.defaultDeny = defaultDeny
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
