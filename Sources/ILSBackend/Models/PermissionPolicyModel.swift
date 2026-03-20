import Fluent
import Vapor
import ILSShared

/// Fluent model for persisting permission policy rules.
final class PermissionPolicyModel: Model, Content, @unchecked Sendable {
    static let schema = "permission_policies"

    @ID(key: .id)
    var id: UUID?

    /// User-defined name for the policy.
    @Field(key: "name")
    var name: String

    /// Tool name to match (e.g., "Bash", "Read", "Write"). If nil, matches any tool.
    @OptionalField(key: "tool_name")
    var toolName: String?

    /// Glob pattern to match against path arguments. If nil, no path filtering is applied.
    @OptionalField(key: "path_glob")
    var pathGlob: String?

    /// Prefix to match against command arguments. If nil, no command filtering is applied.
    @OptionalField(key: "command_prefix")
    var commandPrefix: String?

    /// MCP server name to match for MCP tool requests. If nil, matches any server.
    @OptionalField(key: "mcp_server")
    var mcpServer: String?

    /// Action to take when this policy matches: "allow" or "deny".
    @Field(key: "action")
    var action: String

    /// Optional project UUID to scope this policy to a specific project.
    @OptionalField(key: "project_id")
    var projectId: UUID?

    /// Whether this policy is currently active and evaluated.
    @Field(key: "is_enabled")
    var isEnabled: Bool

    /// Evaluation order — lower numbers are evaluated first.
    @Field(key: "priority")
    var priority: Int

    /// Optional human-readable explanation of why this policy exists.
    @OptionalField(key: "note")
    var note: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        mcpServer: String? = nil,
        action: PermissionPolicyAction,
        projectId: UUID? = nil,
        isEnabled: Bool = true,
        priority: Int = 100,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.mcpServer = mcpServer
        self.action = action.rawValue
        self.projectId = projectId
        self.isEnabled = isEnabled
        self.priority = priority
        self.note = note
    }

    /// Convert to shared PermissionPolicy type.
    func toShared() -> PermissionPolicy {
        PermissionPolicy(
            id: id ?? UUID(),
            name: name,
            toolName: toolName,
            pathGlob: pathGlob,
            commandPrefix: commandPrefix,
            mcpServer: mcpServer,
            action: PermissionPolicyAction(rawValue: action) ?? .allow,
            projectId: projectId,
            isEnabled: isEnabled,
            priority: priority,
            note: note,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    /// Create from shared PermissionPolicy type.
    static func from(_ policy: PermissionPolicy) -> PermissionPolicyModel {
        PermissionPolicyModel(
            id: policy.id,
            name: policy.name,
            toolName: policy.toolName,
            pathGlob: policy.pathGlob,
            commandPrefix: policy.commandPrefix,
            mcpServer: policy.mcpServer,
            action: policy.action,
            projectId: policy.projectId,
            isEnabled: policy.isEnabled,
            priority: policy.priority,
            note: policy.note
        )
    }
}
