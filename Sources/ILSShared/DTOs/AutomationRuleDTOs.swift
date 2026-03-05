import Foundation

// MARK: - Create Automation Rule Request

/// Request payload for creating a new automation rule.
public struct CreateAutomationRuleRequest: Codable, Sendable {
    /// User-defined name for the rule.
    public let name: String
    /// Optional description of what the rule does.
    public let description: String?
    /// Event type that triggers this rule.
    public let triggerType: RuleTriggerType
    /// Optional conditions that must be met for the action to execute.
    public let conditions: [RuleCondition]
    /// Action to execute when triggered.
    public let actionType: RuleActionType
    /// Configuration for the action.
    public let actionConfig: RuleActionConfig
    /// Whether the rule should be enabled immediately.
    public let isEnabled: Bool
    /// Optional session ID to scope the rule.
    public let sessionId: UUID?
    /// Optional project name to scope the rule.
    public let projectName: String?

    public init(
        name: String,
        description: String? = nil,
        triggerType: RuleTriggerType,
        conditions: [RuleCondition] = [],
        actionType: RuleActionType,
        actionConfig: RuleActionConfig = RuleActionConfig(),
        isEnabled: Bool = true,
        sessionId: UUID? = nil,
        projectName: String? = nil
    ) {
        precondition(!name.isEmpty, "CreateAutomationRuleRequest name must not be empty")
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.conditions = conditions
        self.actionType = actionType
        self.actionConfig = actionConfig
        self.isEnabled = isEnabled
        self.sessionId = sessionId
        self.projectName = projectName
    }
}

// MARK: - Update Automation Rule Request

/// Request payload for updating an existing automation rule.
public struct UpdateAutomationRuleRequest: Codable, Sendable {
    /// Updated name for the rule.
    public let name: String?
    /// Updated description.
    public let description: String?
    /// Updated trigger type.
    public let triggerType: RuleTriggerType?
    /// Updated conditions.
    public let conditions: [RuleCondition]?
    /// Updated action type.
    public let actionType: RuleActionType?
    /// Updated action configuration.
    public let actionConfig: RuleActionConfig?
    /// Updated enabled status.
    public let isEnabled: Bool?
    /// Updated session ID.
    public let sessionId: UUID?
    /// Updated project name.
    public let projectName: String?

    public init(
        name: String? = nil,
        description: String? = nil,
        triggerType: RuleTriggerType? = nil,
        conditions: [RuleCondition]? = nil,
        actionType: RuleActionType? = nil,
        actionConfig: RuleActionConfig? = nil,
        isEnabled: Bool? = nil,
        sessionId: UUID? = nil,
        projectName: String? = nil
    ) {
        if let name { precondition(!name.isEmpty, "UpdateAutomationRuleRequest name must not be empty") }
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.conditions = conditions
        self.actionType = actionType
        self.actionConfig = actionConfig
        self.isEnabled = isEnabled
        self.sessionId = sessionId
        self.projectName = projectName
    }
}

// MARK: - Automation Rule Response

/// Response containing a single automation rule.
public struct AutomationRuleResponse: Codable, Sendable {
    /// The automation rule.
    public let rule: AutomationRule

    public init(rule: AutomationRule) {
        self.rule = rule
    }
}

// MARK: - List Automation Rules Response

/// Response containing a list of automation rules.
public struct ListAutomationRulesResponse: Codable, Sendable {
    /// Array of automation rules.
    public let rules: [AutomationRule]
    /// Total number of rules (before filtering).
    public let totalCount: Int

    public init(rules: [AutomationRule], totalCount: Int) {
        precondition(totalCount >= 0, "ListAutomationRulesResponse totalCount must be non-negative")
        self.rules = rules
        self.totalCount = totalCount
    }
}

// MARK: - Rule Execution History Response

/// Response containing execution history for a rule.
public struct RuleExecutionHistoryResponse: Codable, Sendable {
    /// Array of execution log entries, ordered by executedAt descending.
    public let executions: [RuleExecutionLog]
    /// Total number of executions for this rule.
    public let totalCount: Int

    public init(executions: [RuleExecutionLog], totalCount: Int) {
        precondition(totalCount >= 0, "RuleExecutionHistoryResponse totalCount must be non-negative")
        self.executions = executions
        self.totalCount = totalCount
    }
}

// MARK: - Rule Template

/// Pre-built rule template for common automation scenarios.
public struct RuleTemplate: Codable, Sendable, Identifiable {
    /// Unique identifier for the template.
    public let id: String
    /// Display name for the template.
    public let name: String
    /// Description of what the template does.
    public let description: String
    /// Trigger type for this template.
    public let triggerType: RuleTriggerType
    /// Pre-configured conditions.
    public let conditions: [RuleCondition]
    /// Action type for this template.
    public let actionType: RuleActionType
    /// Pre-configured action config.
    public let actionConfig: RuleActionConfig

    public init(
        id: String,
        name: String,
        description: String,
        triggerType: RuleTriggerType,
        conditions: [RuleCondition] = [],
        actionType: RuleActionType,
        actionConfig: RuleActionConfig = RuleActionConfig()
    ) {
        precondition(!id.isEmpty, "RuleTemplate id must not be empty")
        precondition(!name.isEmpty, "RuleTemplate name must not be empty")
        precondition(!description.isEmpty, "RuleTemplate description must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.conditions = conditions
        self.actionType = actionType
        self.actionConfig = actionConfig
    }
}

// MARK: - List Rule Templates Response

/// Response containing pre-built rule templates.
public struct ListRuleTemplatesResponse: Codable, Sendable {
    /// Array of available templates.
    public let templates: [RuleTemplate]

    public init(templates: [RuleTemplate]) {
        self.templates = templates
    }
}
