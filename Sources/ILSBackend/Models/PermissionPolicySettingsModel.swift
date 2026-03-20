import Fluent
import Vapor
import ILSShared

/// Fluent model for persisting permission policy settings (e.g., default-deny mode).
///
/// Each row represents settings for a given scope: a specific project when
/// ``projectId`` is set, or global settings when ``projectId`` is nil.
/// There should be at most one record per (projectId) scope; the controller
/// enforces this via upsert logic.
final class PermissionPolicySettingsModel: Model, Content, @unchecked Sendable {
    static let schema = "permission_policy_settings"

    @ID(key: .id)
    var id: UUID?

    /// Optional project UUID. When nil this record applies globally.
    @OptionalField(key: "project_id")
    var projectId: UUID?

    /// When true, unmatched permission requests are auto-denied.
    @Field(key: "default_deny")
    var defaultDeny: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        projectId: UUID? = nil,
        defaultDeny: Bool = false
    ) {
        self.id = id
        self.projectId = projectId
        self.defaultDeny = defaultDeny
    }

    /// Convert to shared ``PermissionPolicySettings`` type.
    func toShared() -> PermissionPolicySettings {
        PermissionPolicySettings(
            id: id ?? UUID(),
            projectId: projectId,
            defaultDeny: defaultDeny,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
