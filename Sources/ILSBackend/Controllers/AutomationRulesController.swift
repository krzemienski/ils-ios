import Vapor
import Fluent
import ILSShared

/// Controller for automation rule management operations.
///
/// Routes:
/// - `GET /automation-rules`: List all automation rules with optional filters
/// - `POST /automation-rules`: Create a new automation rule
/// - `GET /automation-rules/executions`: Get rule execution history with optional filters
/// - `GET /automation-rules/templates`: Get pre-built rule templates
/// - `GET /automation-rules/:id`: Get a specific automation rule
/// - `PUT /automation-rules/:id`: Update an automation rule
/// - `DELETE /automation-rules/:id`: Delete an automation rule
struct AutomationRulesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let rules = routes.grouped("automation-rules")

        rules.get(use: list)
        rules.post(use: create)
        rules.get("executions", use: listExecutions)
        rules.get("templates", use: templates)
        rules.get(":id", use: get)
        rules.put(":id", use: update)
        rules.delete(":id", use: deleteRule)
    }

    /// List all automation rules with optional filters.
    ///
    /// Query parameters:
    /// - `sessionId`: Filter to rules for a specific session
    /// - `projectName`: Filter to rules for a specific project
    /// - `isEnabled`: Filter to enabled/disabled rules (true/false)
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListAutomationRulesResponse> {
        let sessionId = req.query[UUID.self, at: "sessionId"]
        let projectName = req.query[String.self, at: "projectName"]
        let isEnabled = req.query[Bool.self, at: "isEnabled"]

        var query = AutomationRuleModel.query(on: req.db)
            .sort(\.$createdAt, .descending)

        if let sessionId = sessionId {
            query = query.filter(\.$sessionId == sessionId)
        }

        if let projectName = projectName {
            query = query.filter(\.$projectName == projectName)
        }

        if let isEnabled = isEnabled {
            query = query.filter(\.$isEnabled == isEnabled)
        }

        let models = try await query.all()
        let rules = try models.map { try $0.toShared() }

        return APIResponse(
            success: true,
            data: ListAutomationRulesResponse(
                rules: rules,
                totalCount: rules.count
            )
        )
    }

    /// List rule execution history with optional filters.
    ///
    /// Query parameters:
    /// - `ruleId`: Filter to executions for a specific rule
    /// - `sessionId`: Filter to executions for a specific session
    /// - `status`: Filter to executions with a specific status (success/failed/skipped)
    @Sendable
    func listExecutions(req: Request) async throws -> APIResponse<RuleExecutionHistoryResponse> {
        let ruleId = req.query[UUID.self, at: "ruleId"]
        let sessionId = req.query[UUID.self, at: "sessionId"]
        let status = req.query[String.self, at: "status"]

        var query = RuleExecutionLogModel.query(on: req.db)
            .sort(\.$executedAt, .descending)

        if let ruleId = ruleId {
            query = query.filter(\.$ruleId == ruleId)
        }

        if let sessionId = sessionId {
            query = query.filter(\.$sessionId == sessionId)
        }

        if let status = status {
            query = query.filter(\.$status == status)
        }

        let models = try await query.all()
        let executions = try models.map { try $0.toShared() }

        return APIResponse(
            success: true,
            data: RuleExecutionHistoryResponse(
                executions: executions,
                totalCount: executions.count
            )
        )
    }

    /// Create a new automation rule.
    /// - Parameter req: Vapor Request with CreateAutomationRuleRequest body
    /// - Returns: APIResponse with created AutomationRule
    @Sendable
    func create(req: Request) async throws -> APIResponse<AutomationRule> {
        let input = try req.content.decode(CreateAutomationRuleRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.projectName, maxLength: 255, fieldName: "projectName")

        // Validate action config fields
        if let notificationMessage = input.actionConfig.notificationMessage {
            try PathSanitizer.validateOptionalStringLength(notificationMessage, maxLength: 500, fieldName: "notificationMessage")
        }
        if let messageContent = input.actionConfig.messageContent {
            try PathSanitizer.validateOptionalStringLength(messageContent, maxLength: 2000, fieldName: "messageContent")
        }

        // Create model
        let model = AutomationRuleModel(
            name: input.name,
            description: input.description,
            triggerType: input.triggerType,
            conditions: input.conditions,
            actionType: input.actionType,
            actionConfig: input.actionConfig,
            isEnabled: input.isEnabled,
            sessionId: input.sessionId,
            projectName: input.projectName
        )

        try await model.save(on: req.db)

        let rule = try model.toShared()
        return APIResponse(success: true, data: rule)
    }

    /// Get a specific automation rule by ID.
    /// - Parameter req: Vapor Request with :id parameter
    /// - Returns: APIResponse with AutomationRule
    @Sendable
    func get(req: Request) async throws -> APIResponse<AutomationRule> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid rule ID")
        }

        guard let model = try await AutomationRuleModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Automation rule not found")
        }

        let rule = try model.toShared()
        return APIResponse(success: true, data: rule)
    }

    /// Update an existing automation rule.
    /// - Parameter req: Vapor Request with :id parameter and UpdateAutomationRuleRequest body
    /// - Returns: APIResponse with updated AutomationRule
    @Sendable
    func update(req: Request) async throws -> APIResponse<AutomationRule> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid rule ID")
        }

        guard let model = try await AutomationRuleModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Automation rule not found")
        }

        let input = try req.content.decode(UpdateAutomationRuleRequest.self)

        // Validate input lengths
        if let name = input.name {
            try PathSanitizer.validateOptionalStringLength(name, maxLength: 255, fieldName: "name")
            model.name = name
        }

        if let description = input.description {
            try PathSanitizer.validateOptionalStringLength(description, maxLength: 1000, fieldName: "description")
            model.description = description
        }

        if let triggerType = input.triggerType {
            model.triggerType = triggerType.rawValue
        }

        if let conditions = input.conditions {
            model.conditions = AutomationRuleModel.encodeConditions(conditions)
        }

        if let actionType = input.actionType {
            model.actionType = actionType.rawValue
        }

        if let actionConfig = input.actionConfig {
            // Validate action config fields
            if let notificationMessage = actionConfig.notificationMessage {
                try PathSanitizer.validateOptionalStringLength(notificationMessage, maxLength: 500, fieldName: "notificationMessage")
            }
            if let messageContent = actionConfig.messageContent {
                try PathSanitizer.validateOptionalStringLength(messageContent, maxLength: 2000, fieldName: "messageContent")
            }
            model.actionConfig = AutomationRuleModel.encodeActionConfig(actionConfig)
        }

        if let isEnabled = input.isEnabled {
            model.isEnabled = isEnabled
        }

        if let sessionId = input.sessionId {
            model.sessionId = sessionId
        }

        if let projectName = input.projectName {
            try PathSanitizer.validateOptionalStringLength(projectName, maxLength: 255, fieldName: "projectName")
            model.projectName = projectName
        }

        try await model.save(on: req.db)

        let rule = try model.toShared()
        return APIResponse(success: true, data: rule)
    }

    /// Delete an automation rule.
    /// - Parameter req: Vapor Request with :id parameter
    /// - Returns: APIResponse with success message
    @Sendable
    func deleteRule(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid rule ID")
        }

        guard let model = try await AutomationRuleModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Automation rule not found")
        }

        try await model.delete(on: req.db)

        return APIResponse(success: true, data: DeletedResponse())
    }

    /// Get pre-built rule templates for common automation scenarios.
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of RuleTemplate
    @Sendable
    func templates(req: Request) async throws -> APIResponse<ListRuleTemplatesResponse> {
        let templates = [
            RuleTemplate(
                id: "high-cost-alert",
                name: "High Cost Alert",
                description: "Notify when session cost exceeds $5",
                triggerType: .costThreshold,
                conditions: [
                    RuleCondition(field: "cost_usd", operator: .greaterThan, value: "5.0")
                ],
                actionType: .notify,
                actionConfig: RuleActionConfig(
                    notificationMessage: "Session cost exceeded $5"
                )
            ),
            RuleTemplate(
                id: "auto-export-on-complete",
                name: "Auto-Export on Complete",
                description: "Export session to Markdown when it completes successfully",
                triggerType: .sessionComplete,
                conditions: [],
                actionType: .export,
                actionConfig: RuleActionConfig(
                    exportFormat: "markdown"
                )
            ),
            RuleTemplate(
                id: "fork-on-error",
                name: "Fork on Error",
                description: "Fork session when multiple errors occur",
                triggerType: .errorOccurred,
                conditions: [
                    RuleCondition(field: "error_count", operator: .greaterThan, value: "3")
                ],
                actionType: .fork,
                actionConfig: RuleActionConfig()
            ),
            RuleTemplate(
                id: "idle-timeout-notify",
                name: "Idle Timeout Notification",
                description: "Notify when session is idle for 30 minutes",
                triggerType: .idleTimeout,
                conditions: [
                    RuleCondition(field: "idle_duration_minutes", operator: .greaterThan, value: "30")
                ],
                actionType: .notify,
                actionConfig: RuleActionConfig(
                    notificationMessage: "Session has been idle for 30 minutes"
                )
            ),
            RuleTemplate(
                id: "context-limit-warning",
                name: "Context Limit Warning",
                description: "Notify when context usage exceeds 80%",
                triggerType: .contextNearLimit,
                conditions: [
                    RuleCondition(field: "context_percentage", operator: .greaterThan, value: "80")
                ],
                actionType: .notify,
                actionConfig: RuleActionConfig(
                    notificationMessage: "Context usage is nearing the limit"
                )
            )
        ]

        return APIResponse(
            success: true,
            data: ListRuleTemplatesResponse(templates: templates)
        )
    }
}
