import Foundation

// MARK: - Permission Policy Action

/// Decision to apply when a permission policy rule matches.
public enum PermissionPolicyAction: String, Codable, Sendable, CaseIterable {
    /// Allow the tool use without prompting the user.
    case allow = "allow"
    /// Deny the tool use without prompting the user.
    case deny = "deny"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized PermissionPolicyAction: '\(raw)'. Expected: allow, deny"
                )
            )
        }
        self = value
    }
}

// MARK: - Permission Policy

/// A rule that automatically allows or denies Claude Code tool-use permission requests.
///
/// Policies are evaluated in priority order (lower number = higher priority). The first
/// matching policy determines the outcome. A policy matches when all non-nil criteria
/// fields match the incoming permission request.
///
/// Matching criteria:
/// - **toolName**: Exact match against the requesting tool's name.
/// - **pathGlob**: Glob pattern matched against path arguments in the tool input.
/// - **commandPrefix**: Prefix match against command arguments in the tool input.
/// - **mcpServer**: Exact match against the MCP server name for MCP tool requests.
///
/// Multiple criteria are combined with AND logic — all specified fields must match.
public struct PermissionPolicy: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the policy.
    public let id: UUID
    /// User-defined name for the policy.
    public var name: String
    /// Tool name to match (e.g., "Bash", "Read", "Write"). If nil, matches any tool.
    public var toolName: String?
    /// Glob pattern to match against path arguments (e.g., "/tmp/**", "~/projects/*").
    /// If nil, no path filtering is applied.
    public var pathGlob: String?
    /// Prefix to match against command arguments (e.g., "git ", "npm run").
    /// If nil, no command filtering is applied.
    public var commandPrefix: String?
    /// MCP server name to match for MCP tool requests. If nil, matches any server.
    public var mcpServer: String?
    /// Action to take when this policy matches: allow or deny.
    public var action: PermissionPolicyAction
    /// Optional project UUID to scope this policy to a specific project.
    /// If nil, the policy applies globally across all projects.
    public var projectId: UUID?
    /// Whether this policy is currently active and evaluated.
    public var isEnabled: Bool
    /// Evaluation order — lower numbers are evaluated first.
    public var priority: Int
    /// Optional human-readable explanation of why this policy exists.
    public var note: String?
    /// When the policy was created.
    public let createdAt: Date
    /// Last time the policy was modified.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        toolName: String? = nil,
        pathGlob: String? = nil,
        commandPrefix: String? = nil,
        mcpServer: String? = nil,
        action: PermissionPolicyAction,
        projectId: UUID? = nil,
        isEnabled: Bool = true,
        priority: Int = 100,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(!name.isEmpty, "PermissionPolicy name must not be empty")
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
}
