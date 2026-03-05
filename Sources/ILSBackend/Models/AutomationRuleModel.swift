import Fluent
import Vapor
import ILSShared

/// Fluent model for AutomationRule
final class AutomationRuleModel: Model, Content, @unchecked Sendable {
    static let schema = "automation_rules"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "trigger_type")
    var triggerType: String

    @Field(key: "conditions")
    var conditions: String // JSON array stored as string

    @Field(key: "action_type")
    var actionType: String

    @Field(key: "action_config")
    var actionConfig: String // JSON object stored as string

    @Field(key: "is_enabled")
    var isEnabled: Bool

    @OptionalField(key: "session_id")
    var sessionId: UUID?

    @OptionalField(key: "project_name")
    var projectName: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
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
        self.id = id
        self.name = name
        self.description = description
        self.triggerType = triggerType.rawValue
        self.conditions = Self.encodeConditions(conditions)
        self.actionType = actionType.rawValue
        self.actionConfig = Self.encodeActionConfig(actionConfig)
        self.isEnabled = isEnabled
        self.sessionId = sessionId
        self.projectName = projectName
    }

    /// Convert to shared AutomationRule type
    func toShared() throws -> AutomationRule {
        guard let id = id else {
            throw Abort(.internalServerError, reason: "AutomationRule missing ID")
        }

        let triggerTypeEnum = RuleTriggerType(rawValue: triggerType) ?? .sessionComplete
        let actionTypeEnum = RuleActionType(rawValue: actionType) ?? .notify
        let conditionsArray = try Self.decodeConditions(conditions)
        let actionConfigStruct = try Self.decodeActionConfig(actionConfig)

        return AutomationRule(
            id: id,
            name: name,
            description: description,
            triggerType: triggerTypeEnum,
            conditions: conditionsArray,
            actionType: actionTypeEnum,
            actionConfig: actionConfigStruct,
            isEnabled: isEnabled,
            sessionId: sessionId,
            projectName: projectName,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    /// Create from shared AutomationRule type
    static func from(_ rule: AutomationRule) -> AutomationRuleModel {
        AutomationRuleModel(
            id: rule.id,
            name: rule.name,
            description: rule.description,
            triggerType: rule.triggerType,
            conditions: rule.conditions,
            actionType: rule.actionType,
            actionConfig: rule.actionConfig,
            isEnabled: rule.isEnabled,
            sessionId: rule.sessionId,
            projectName: rule.projectName
        )
    }

    // MARK: - JSON Encoding/Decoding Helpers

    private static func encodeConditions(_ conditions: [RuleCondition]) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(conditions),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeConditions(_ json: String) throws -> [RuleCondition] {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8) else {
            return []
        }
        return (try? decoder.decode([RuleCondition].self, from: data)) ?? []
    }

    private static func encodeActionConfig(_ config: RuleActionConfig) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(config),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func decodeActionConfig(_ json: String) throws -> RuleActionConfig {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8) else {
            return RuleActionConfig()
        }
        return (try? decoder.decode(RuleActionConfig.self, from: data)) ?? RuleActionConfig()
    }
}
