import Fluent

/// v6.4 — Permission policy tracking.
///
/// Adds `matched_policy_id` (nullable text) to the permissions table.
/// Records the ID of the permission policy that automatically resolved a
/// permission request, enabling audit trails and policy effectiveness analysis.
struct AddPolicyIdToPermissions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("permissions")
            .field("matched_policy_id", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("permissions")
            .deleteField("matched_policy_id")
            .update()
    }
}
