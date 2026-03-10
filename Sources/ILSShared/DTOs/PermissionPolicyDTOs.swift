import Foundation

// MARK: - Create Permission Policy Request

/// Request payload for creating a new permission policy rule.
public struct CreatePermissionPolicyRequest: Codable, Sendable {
    /// User-defined name for the policy.
    public let name: String
    /// Tool name to match (e.g., "Bash", "Read", "Write"). If nil, matches any tool.
    public let toolName: String?
    /// Glob pattern to match against path arguments (e.g., "/tmp/**", "~/projects/*").
    /// If nil, no path filtering is applied.
    public let pathGlob: String?
    /// Prefix to match against command arguments (e.g., "git ", "npm run").
    /// If nil, no command filtering is applied.
    public let commandPrefix: String?
    /// MCP server name to match for MCP tool requests. If nil, matches any server.
    public let mcpServer: String?
    /// Action to take when this policy matches: allow or deny.
    public let action: PermissionPolicyAction
    /// Optional project UUID to scope this policy to a specific project.
    /// If nil, the policy applies globally across all projects.
    public let projectId: UUID?
    /// Whether this policy should be active immediately on creation.
    public let isEnabled: Bool
    /// Evaluation order — lower numbers are evaluated first.
    public let priority: Int
    /// Optional human-readable explanation of why this policy exists.
    public let note: String?

    public init(
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
        self.name = name
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.mcpServer = mcpServer
        self.action = action
        self.projectId = projectId
        self.isEnabled = isEnabled
        self.priority = priority
        self.note = note
    }
}

// MARK: - Update Permission Policy Request

/// Request payload for updating an existing permission policy rule.
///
/// All fields are optional; only non-nil values are applied.
public struct UpdatePermissionPolicyRequest: Codable, Sendable {
    /// New user-defined name, or nil to leave unchanged.
    public let name: String?
    /// New tool name pattern, or nil to leave unchanged.
    public let toolName: String?
    /// New path glob pattern, or nil to leave unchanged.
    public let pathGlob: String?
    /// New command prefix, or nil to leave unchanged.
    public let commandPrefix: String?
    /// New MCP server name, or nil to leave unchanged.
    public let mcpServer: String?
    /// New action to apply, or nil to leave unchanged.
    public let action: PermissionPolicyAction?
    /// Enable or disable the policy, or nil to leave unchanged.
    public let isEnabled: Bool?
    /// New priority value, or nil to leave unchanged.
    public let priority: Int?
    /// New explanatory note, or nil to leave unchanged.
    public let note: String?

    public init(
        name: String? = nil,
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        mcpServer: String? = nil,
        action: PermissionPolicyAction? = nil,
        isEnabled: Bool? = nil,
        priority: Int? = nil,
        note: String? = nil
    ) {
        self.name = name
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.mcpServer = mcpServer
        self.action = action
        self.isEnabled = isEnabled
        self.priority = priority
        self.note = note
    }
}

// MARK: - Permission Policy Response

/// Full representation of a permission policy rule returned from the API.
public struct PermissionPolicyResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for the policy.
    public let id: UUID
    /// User-defined name for the policy.
    public let name: String
    /// Tool name to match, or nil to match any tool.
    public let toolName: String?
    /// Glob pattern matched against path arguments, or nil for no path filtering.
    public let pathGlob: String?
    /// Prefix matched against command arguments, or nil for no command filtering.
    public let commandPrefix: String?
    /// MCP server name to match, or nil to match any server.
    public let mcpServer: String?
    /// Action applied when this policy matches: allow or deny.
    public let action: PermissionPolicyAction
    /// Project UUID this policy is scoped to, or nil for global scope.
    public let projectId: UUID?
    /// Whether this policy is currently active and evaluated.
    public let isEnabled: Bool
    /// Evaluation order — lower numbers are evaluated first.
    public let priority: Int
    /// Optional human-readable explanation of why this policy exists.
    public let note: String?
    /// When the policy was created (UTC).
    public let createdAt: Date
    /// Last time the policy was modified (UTC).
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        mcpServer: String? = nil,
        action: PermissionPolicyAction,
        projectId: UUID? = nil,
        isEnabled: Bool,
        priority: Int,
        note: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.toolName = toolName
        self.pathGlob = pathGlob
        self.commandPrefix = commandPrefix
        self.mcpServer = mcpServer
        self.action = action
        self.projectId = projectId
        self.isEnabled = isEnabled
        self.priority = priority
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience initializer that maps from the shared ``PermissionPolicy`` model.
    public init(from policy: PermissionPolicy) {
        self.id = policy.id
        self.name = policy.name
        self.toolName = policy.toolName
        self.pathGlob = policy.pathGlob
        self.commandPrefix = policy.commandPrefix
        self.mcpServer = policy.mcpServer
        self.action = policy.action
        self.projectId = policy.projectId
        self.isEnabled = policy.isEnabled
        self.priority = policy.priority
        self.note = policy.note
        self.createdAt = policy.createdAt
        self.updatedAt = policy.updatedAt
    }
}

// MARK: - List Permission Policies Response

/// Paginated list of permission policy rules.
public struct ListPermissionPoliciesResponse: Codable, Sendable {
    /// Ordered list of policy rules (by priority, then creation date).
    public let items: [PermissionPolicyResponse]
    /// Total number of policies matching the request (before pagination).
    public let total: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        items: [PermissionPolicyResponse],
        total: Int,
        hasMore: Bool = false
    ) {
        precondition(total >= 0, "ListPermissionPoliciesResponse total must be non-negative")
        self.items = items
        self.total = total
        self.hasMore = hasMore
    }
}

// MARK: - Reorder Permission Policies Request

/// Request payload for updating the priority order of multiple permission policies.
///
/// Sends an ordered list of policy IDs; the backend assigns priorities based on
/// the position in the array (index 0 receives the lowest priority value).
public struct ReorderPermissionPoliciesRequest: Codable, Sendable {
    /// Policy IDs in the desired evaluation order (first = highest priority).
    public let orderedIds: [UUID]

    public init(orderedIds: [UUID]) {
        precondition(!orderedIds.isEmpty, "ReorderPermissionPoliciesRequest orderedIds must not be empty")
        self.orderedIds = orderedIds
    }
}
