import Fluent
import Vapor

/// Fluent model for persisting approval policy rules that govern agent action authorization.
final class ApprovalPolicyModel: Model, Content, @unchecked Sendable {
    static let schema = "approval_policies"

    @ID(key: .id)
    var id: UUID?

    /// Human-readable name for this policy (e.g., "Block destructive git commands").
    @Field(key: "name")
    var name: String

    /// Optional reference to a policy template that created this policy.
    @OptionalField(key: "template_id")
    var templateId: String?

    /// The type of action this policy governs (e.g., "always_ask", "allowlist", "path_scope", "high_risk").
    @Field(key: "action_type")
    var actionType: String

    /// JSON-encoded array of tool names this policy applies to (e.g., ["Bash", "Write"]).
    @Field(key: "tool_names")
    var toolNames: String

    /// JSON-encoded array of file path glob patterns for scope (e.g., ["src/**/*.swift", "*.config"]).
    @Field(key: "path_globs")
    var pathGlobs: String

    /// JSON-encoded array of risk levels this policy matches (e.g., ["high", "critical"]).
    @Field(key: "risk_levels")
    var riskLevels: String

    /// Project identifier this policy is scoped to, or nil for global policies.
    @OptionalField(key: "project_id")
    var projectId: String?

    /// Whether this policy is currently active.
    @Field(key: "is_enabled")
    var isEnabled: Bool

    /// Evaluation priority — lower numbers are evaluated first.
    @Field(key: "priority")
    var priority: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        templateId: String? = nil,
        actionType: String,
        toolNames: [String] = [],
        pathGlobs: [String] = [],
        riskLevels: [String] = [],
        projectId: String? = nil,
        isEnabled: Bool = true,
        priority: Int = 100
    ) {
        self.id = id
        self.name = name
        self.templateId = templateId
        self.actionType = actionType
        self.toolNames = Self.encodeJSONArray(toolNames)
        self.pathGlobs = Self.encodeJSONArray(pathGlobs)
        self.riskLevels = Self.encodeJSONArray(riskLevels)
        self.projectId = projectId
        self.isEnabled = isEnabled
        self.priority = priority
    }

    // MARK: - JSON Array Helpers

    /// Encode a string array to a JSON string for storage.
    static func encodeJSONArray(_ array: [String]) -> String {
        let data = (try? JSONEncoder().encode(array)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Decode a JSON string back to a string array.
    static func decodeJSONArray(_ json: String) -> [String] {
        let data = json.data(using: .utf8) ?? Data()
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Parsed tool names from the JSON-encoded field.
    var parsedToolNames: [String] {
        Self.decodeJSONArray(toolNames)
    }

    /// Parsed path globs from the JSON-encoded field.
    var parsedPathGlobs: [String] {
        Self.decodeJSONArray(pathGlobs)
    }

    /// Parsed risk levels from the JSON-encoded field.
    var parsedRiskLevels: [String] {
        Self.decodeJSONArray(riskLevels)
    }
}
