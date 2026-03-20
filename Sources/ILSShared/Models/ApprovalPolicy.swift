import Foundation

// MARK: - Policy Action

/// Determines how a permission request is handled when a policy matches.
public enum PolicyAction: String, Codable, Sendable, CaseIterable {
    /// Always prompt the user for explicit approval.
    case alwaysAsk = "always_ask"
    /// Automatically approve without user interaction.
    case autoApprove = "auto_approve"
    /// Automatically deny without user interaction.
    case autoDeny = "auto_deny"
    /// Require explicit confirmation with additional context shown to the user.
    case requireConfirmation = "require_confirmation"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized PolicyAction: '\(raw)'. Expected: always_ask, auto_approve, auto_deny, require_confirmation"
                )
            )
        }
        self = value
    }
}

// MARK: - Policy Scope

/// Defines the breadth of an approval policy's applicability.
public enum PolicyScope: String, Codable, Sendable, CaseIterable {
    /// Policy applies to all sessions and projects.
    case global = "global"
    /// Policy applies only to sessions within a specific project.
    case project = "project"
    /// Policy applies only to operations on files matching a path pattern.
    case pathBased = "path_based"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized PolicyScope: '\(raw)'. Expected: global, project, path_based"
                )
            )
        }
        self = value
    }
}

// MARK: - Policy Template

/// Built-in policy template identifiers for common configurations.
public enum PolicyTemplate: String, Codable, Sendable, CaseIterable {
    /// Maximum safety: all actions require explicit user approval.
    case strict = "strict"
    /// Moderate safety: low-risk actions auto-approved, high-risk require confirmation.
    case balanced = "balanced"
    /// Minimum friction: most actions auto-approved, only destructive actions require confirmation.
    case permissive = "permissive"
    /// User-defined policy with custom rules.
    case custom = "custom"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized PolicyTemplate: '\(raw)'. Expected: strict, balanced, permissive, custom"
                )
            )
        }
        self = value
    }
}

// MARK: - Denial Reason Code

/// Standardized reason codes for why a permission request was denied or flagged.
public enum DenialReasonCode: String, Codable, Sendable, CaseIterable {
    /// Action violates an active approval policy rule.
    case policyViolation = "policy_violation"
    /// Action falls outside the allowed scope for this session or project.
    case outOfScope = "out_of_scope"
    /// Action is classified as high-risk and blocked by policy.
    case highRiskBlocked = "high_risk_blocked"
    /// Action is destructive (e.g., delete, force-push) and blocked by policy.
    case destructiveBlocked = "destructive_blocked"
    /// User explicitly denied the action.
    case userDenied = "user_denied"
    /// Action targets a path that is not in the allowed path list.
    case pathNotAllowed = "path_not_allowed"
    /// Tool is not in the allowlist for the active policy.
    case toolNotAllowed = "tool_not_allowed"
    /// Action was denied because the request timed out waiting for approval.
    case approvalTimeout = "approval_timeout"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized DenialReasonCode: '\(raw)'. Expected: policy_violation, out_of_scope, high_risk_blocked, destructive_blocked, user_denied, path_not_allowed, tool_not_allowed, approval_timeout"
                )
            )
        }
        self = value
    }
}

// MARK: - Policy Tool Rule

/// A rule within an approval policy that maps a tool name pattern to an action.
public struct PolicyToolRule: Codable, Sendable, Hashable {
    /// Tool name or glob pattern to match (e.g., "Bash", "Write", "Edit").
    public let toolPattern: String
    /// Action to take when this tool is used.
    public let action: PolicyAction
    /// Optional path patterns that further scope this rule (e.g., "src/**/*.swift").
    public let pathPatterns: [String]?

    public init(toolPattern: String, action: PolicyAction, pathPatterns: [String]? = nil) {
        precondition(!toolPattern.isEmpty, "PolicyToolRule toolPattern must not be empty")
        self.toolPattern = toolPattern
        self.action = action
        self.pathPatterns = pathPatterns
    }
}

// MARK: - Approval Policy

/// A deterministic policy that governs how agent tool-use permission requests
/// are evaluated and resolved.
///
/// Policies define rules for specific tools and risk levels, scoped either
/// globally, per-project, or per-path. Built-in templates (strict, balanced,
/// permissive) provide sensible defaults, while custom policies allow
/// fine-grained control.
public struct ApprovalPolicy: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the policy.
    public let id: UUID
    /// User-defined name for the policy.
    public var name: String
    /// Optional description of what the policy enforces.
    public var description: String?
    /// Built-in template this policy is based on, or `.custom` for user-defined.
    public var template: PolicyTemplate
    /// Scope of the policy (global, project, or path-based).
    public var scope: PolicyScope
    /// Project name this policy applies to (required when scope is `.project`).
    public var projectName: String?
    /// Path patterns this policy applies to (required when scope is `.pathBased`).
    public var pathPatterns: [String]?
    /// Default action for tools not covered by specific rules.
    public var defaultAction: PolicyAction
    /// Tool-specific rules that override the default action.
    public var toolRules: [PolicyToolRule]
    /// Risk levels that require explicit confirmation regardless of tool rules.
    public var confirmationRequiredRiskLevels: [PermissionRiskLevel]
    /// Whether the policy is currently active.
    public var isEnabled: Bool
    /// Priority for policy evaluation (lower number = higher priority).
    public var priority: Int
    /// When the policy was created.
    public let createdAt: Date
    /// Last time the policy was modified.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        template: PolicyTemplate = .custom,
        scope: PolicyScope = .global,
        projectName: String? = nil,
        pathPatterns: [String]? = nil,
        defaultAction: PolicyAction = .alwaysAsk,
        toolRules: [PolicyToolRule] = [],
        confirmationRequiredRiskLevels: [PermissionRiskLevel] = [.high, .critical],
        isEnabled: Bool = true,
        priority: Int = 100,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(!name.isEmpty, "ApprovalPolicy name must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.template = template
        self.scope = scope
        self.projectName = projectName
        self.pathPatterns = pathPatterns
        self.defaultAction = defaultAction
        self.toolRules = toolRules
        self.confirmationRequiredRiskLevels = confirmationRequiredRiskLevels
        self.isEnabled = isEnabled
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
