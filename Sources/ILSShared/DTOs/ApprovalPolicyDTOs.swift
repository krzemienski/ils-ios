import Foundation

// MARK: - Approval Policy List Response

/// Paginated list of approval policies for the settings/management views.
public struct ApprovalPolicyListResponse: Codable, Sendable {
    /// Ordered list of approval policies (by priority ascending).
    public let policies: [ApprovalPolicy]
    /// Total number of policies (before pagination).
    public let totalCount: Int
    /// Number of currently enabled policies.
    public let enabledCount: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(
        policies: [ApprovalPolicy],
        totalCount: Int,
        enabledCount: Int,
        hasMore: Bool = false
    ) {
        precondition(totalCount >= 0, "ApprovalPolicyListResponse totalCount must be non-negative")
        precondition(enabledCount >= 0, "ApprovalPolicyListResponse enabledCount must be non-negative")
        self.policies = policies
        self.totalCount = totalCount
        self.enabledCount = enabledCount
        self.hasMore = hasMore
    }
}

// MARK: - Create Approval Policy Request

/// Request payload for creating a new approval policy.
public struct CreateApprovalPolicyRequest: Codable, Sendable {
    /// User-defined name for the policy.
    public let name: String
    /// Optional description of what the policy enforces.
    public let description: String?
    /// Built-in template to base the policy on, or `.custom` for user-defined.
    public let template: PolicyTemplate
    /// Scope of the policy (global, project, or path-based).
    public let scope: PolicyScope
    /// Project name this policy applies to (required when scope is `.project`).
    public let projectName: String?
    /// Path patterns this policy applies to (required when scope is `.pathBased`).
    public let pathPatterns: [String]?
    /// Default action for tools not covered by specific rules.
    public let defaultAction: PolicyAction
    /// Tool-specific rules that override the default action.
    public let toolRules: [PolicyToolRule]
    /// Risk levels that require explicit confirmation regardless of tool rules.
    public let confirmationRequiredRiskLevels: [PermissionRiskLevel]?
    /// Whether the policy should be enabled immediately.
    public let isEnabled: Bool
    /// Priority for policy evaluation (lower number = higher priority).
    public let priority: Int?

    public init(
        name: String,
        description: String? = nil,
        template: PolicyTemplate = .custom,
        scope: PolicyScope = .global,
        projectName: String? = nil,
        pathPatterns: [String]? = nil,
        defaultAction: PolicyAction = .alwaysAsk,
        toolRules: [PolicyToolRule] = [],
        confirmationRequiredRiskLevels: [PermissionRiskLevel]? = nil,
        isEnabled: Bool = true,
        priority: Int? = nil
    ) {
        precondition(!name.isEmpty, "CreateApprovalPolicyRequest name must not be empty")
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
    }
}

// MARK: - Update Approval Policy Request

/// Request payload for updating an existing approval policy.
///
/// All fields are optional; only non-nil values are applied.
public struct UpdateApprovalPolicyRequest: Codable, Sendable {
    /// Updated name for the policy.
    public let name: String?
    /// Updated description.
    public let description: String?
    /// Updated template.
    public let template: PolicyTemplate?
    /// Updated scope.
    public let scope: PolicyScope?
    /// Updated project name.
    public let projectName: String?
    /// Updated path patterns.
    public let pathPatterns: [String]?
    /// Updated default action.
    public let defaultAction: PolicyAction?
    /// Updated tool-specific rules.
    public let toolRules: [PolicyToolRule]?
    /// Updated risk levels requiring confirmation.
    public let confirmationRequiredRiskLevels: [PermissionRiskLevel]?
    /// Updated enabled status.
    public let isEnabled: Bool?
    /// Updated priority.
    public let priority: Int?

    public init(
        name: String? = nil,
        description: String? = nil,
        template: PolicyTemplate? = nil,
        scope: PolicyScope? = nil,
        projectName: String? = nil,
        pathPatterns: [String]? = nil,
        defaultAction: PolicyAction? = nil,
        toolRules: [PolicyToolRule]? = nil,
        confirmationRequiredRiskLevels: [PermissionRiskLevel]? = nil,
        isEnabled: Bool? = nil,
        priority: Int? = nil
    ) {
        if let name { precondition(!name.isEmpty, "UpdateApprovalPolicyRequest name must not be empty") }
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
    }
}

// MARK: - Policy Evaluation Result

/// The outcome of evaluating a permission request against the active approval policies.
///
/// Returned by the policy engine to indicate what action should be taken
/// and which policy (if any) determined the result.
public struct PolicyEvaluationResult: Codable, Sendable {
    /// The action determined by policy evaluation.
    public let action: PolicyAction
    /// Standardized reason code explaining why this action was chosen.
    public let reasonCode: DenialReasonCode?
    /// Identifier of the policy that produced this result, or nil if no policy matched.
    public let policyId: UUID?
    /// Human-readable explanation of why this action was chosen.
    public let explanation: String

    public init(
        action: PolicyAction,
        reasonCode: DenialReasonCode? = nil,
        policyId: UUID? = nil,
        explanation: String
    ) {
        precondition(!explanation.isEmpty, "PolicyEvaluationResult explanation must not be empty")
        self.action = action
        self.reasonCode = reasonCode
        self.policyId = policyId
        self.explanation = explanation
    }
}

// MARK: - Policy Template Response

/// Response describing a built-in policy template with its default configuration.
public struct PolicyTemplateResponse: Codable, Sendable, Identifiable {
    /// Template identifier.
    public let id: String
    /// Display name for the template.
    public let name: String
    /// Description of the template's behavior.
    public let description: String
    /// The template type.
    public let template: PolicyTemplate
    /// Default action for tools not covered by specific rules.
    public let defaultAction: PolicyAction
    /// Pre-configured tool-specific rules.
    public let toolRules: [PolicyToolRule]
    /// Risk levels that require confirmation under this template.
    public let confirmationRequiredRiskLevels: [PermissionRiskLevel]

    public init(
        id: String,
        name: String,
        description: String,
        template: PolicyTemplate,
        defaultAction: PolicyAction,
        toolRules: [PolicyToolRule] = [],
        confirmationRequiredRiskLevels: [PermissionRiskLevel] = []
    ) {
        precondition(!id.isEmpty, "PolicyTemplateResponse id must not be empty")
        precondition(!name.isEmpty, "PolicyTemplateResponse name must not be empty")
        precondition(!description.isEmpty, "PolicyTemplateResponse description must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.template = template
        self.defaultAction = defaultAction
        self.toolRules = toolRules
        self.confirmationRequiredRiskLevels = confirmationRequiredRiskLevels
    }
}

// MARK: - List Policy Templates Response

/// Response containing all available built-in policy templates.
public struct ListPolicyTemplatesResponse: Codable, Sendable {
    /// Array of available policy templates.
    public let templates: [PolicyTemplateResponse]

    public init(templates: [PolicyTemplateResponse]) {
        self.templates = templates
    }
}
