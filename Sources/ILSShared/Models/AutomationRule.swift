import Foundation

// MARK: - Trigger Type

/// Event type that can initiate an automation rule.
public enum RuleTriggerType: String, Codable, Sendable, CaseIterable {
    /// Triggered when a session completes successfully.
    case sessionComplete = "session_complete"
    /// Triggered when an error occurs in a session.
    case errorOccurred = "error_occurred"
    /// Triggered when a session has been idle for a specified duration.
    case idleTimeout = "idle_timeout"
    /// Triggered when session cost exceeds a threshold.
    case costThreshold = "cost_threshold"
    /// Triggered when context usage nears the limit.
    case contextNearLimit = "context_near_limit"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized RuleTriggerType: '\(raw)'. Expected: session_complete, error_occurred, idle_timeout, cost_threshold, context_near_limit"
                )
            )
        }
        self = value
    }
}

// MARK: - Action Type

/// Action that can be executed when a rule is triggered.
public enum RuleActionType: String, Codable, Sendable, CaseIterable {
    /// Send a notification to the user.
    case notify = "notify"
    /// Pause the session.
    case pause = "pause"
    /// Fork the session into a new session.
    case fork = "fork"
    /// Export the session to Markdown or another format.
    case export = "export"
    /// Send an automated message to the session.
    case sendMessage = "send_message"
    /// Switch the session to a different Claude model.
    case switchModel = "switch_model"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized RuleActionType: '\(raw)'. Expected: notify, pause, fork, export, send_message, switch_model"
                )
            )
        }
        self = value
    }
}

// MARK: - Condition Operator

/// Comparison operator for rule conditions.
public enum ConditionOperator: String, Codable, Sendable, CaseIterable {
    /// Greater than comparison.
    case greaterThan = "greater_than"
    /// Less than comparison.
    case lessThan = "less_than"
    /// Equality comparison.
    case equals = "equals"
    /// Contains comparison (for string/array values).
    case contains = "contains"

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unrecognized ConditionOperator: '\(raw)'. Expected: greater_than, less_than, equals, contains"
                )
            )
        }
        self = value
    }
}

// MARK: - Rule Condition

/// A condition that refines when a trigger should fire.
public struct RuleCondition: Codable, Sendable, Hashable {
    /// Field to evaluate (e.g., "error_count", "idle_duration_minutes", "cost_usd").
    public let field: String
    /// Comparison operator.
    public let `operator`: ConditionOperator
    /// Value to compare against (stored as string, interpreted based on field type).
    public let value: String

    public init(field: String, operator: ConditionOperator, value: String) {
        precondition(!field.isEmpty, "RuleCondition field must not be empty")
        precondition(!value.isEmpty, "RuleCondition value must not be empty")
        self.field = field
        self.operator = `operator`
        self.value = value
    }
}

// MARK: - Rule Action Config

/// Configuration for a rule action (e.g., notification message, export format).
public struct RuleActionConfig: Codable, Sendable, Hashable {
    /// Optional notification message for notify actions.
    public let notificationMessage: String?
    /// Optional export format (e.g., "markdown", "json").
    public let exportFormat: String?
    /// Optional model to switch to (e.g., "sonnet", "opus").
    public let targetModel: String?
    /// Optional message content for sendMessage actions.
    public let messageContent: String?

    public init(
        notificationMessage: String? = nil,
        exportFormat: String? = nil,
        targetModel: String? = nil,
        messageContent: String? = nil
    ) {
        self.notificationMessage = notificationMessage
        self.exportFormat = exportFormat
        self.targetModel = targetModel
        self.messageContent = messageContent
    }
}

// MARK: - Automation Rule

/// Represents an IFTTT-style automation rule for session management.
///
/// Rules follow the pattern: **trigger → conditions → action**
/// - **Trigger**: Event that initiates evaluation (e.g., session complete, error occurred)
/// - **Conditions**: Optional refinements (e.g., error_count > 3)
/// - **Action**: What to execute when triggered (e.g., notify, fork, export)
public struct AutomationRule: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the rule.
    public let id: UUID
    /// User-defined name for the rule.
    public var name: String
    /// Optional description of what the rule does.
    public var description: String?
    /// Event type that triggers this rule.
    public var triggerType: RuleTriggerType
    /// Optional conditions that must be met for the action to execute.
    public var conditions: [RuleCondition]
    /// Action to execute when triggered.
    public var actionType: RuleActionType
    /// Configuration for the action (e.g., notification message, export format).
    public var actionConfig: RuleActionConfig
    /// Whether the rule is currently enabled.
    public var isEnabled: Bool
    /// Optional session ID to scope the rule to a specific session.
    /// If nil, the rule applies to all sessions.
    public var sessionId: UUID?
    /// Optional project name to scope the rule to sessions in a specific project.
    public var projectName: String?
    /// When the rule was created.
    public let createdAt: Date
    /// Last time the rule was modified.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        triggerType: RuleTriggerType,
        conditions: [RuleCondition] = [],
        actionType: RuleActionType,
        actionConfig: RuleActionConfig = RuleActionConfig(),
        isEnabled: Bool = true,
        sessionId: UUID? = nil,
        projectName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(!name.isEmpty, "AutomationRule name must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.triggerType = triggerType
        self.conditions = conditions
        self.actionType = actionType
        self.actionConfig = actionConfig
        self.isEnabled = isEnabled
        self.sessionId = sessionId
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
