import Foundation
import Observation
import ILSShared

/// View model for automation rule management.
///
/// Manages automation rule CRUD operations, templates, and execution history.
/// Coordinates with `APIClient` for REST operations and maintains local state for UI.
///
/// ## Topics
/// ### Properties
/// - ``rules`` - Array of automation rules
/// - ``templates`` - Pre-built rule templates
/// - ``isLoading`` - Whether a request is in progress
/// - ``error`` - Current error, if any
///
/// ### Rule Operations
/// - ``loadRules()`` - Fetch all automation rules
/// - ``createRule(_:)`` - Create a new automation rule
/// - ``updateRule(_:request:)`` - Update an existing rule
/// - ``deleteRule(_:)`` - Delete a rule
///
/// ### Templates
/// - ``loadTemplates()`` - Fetch pre-built rule templates
///
/// ### Execution History
/// - ``loadExecutionHistory(ruleId:)`` - Fetch execution history for a rule
@Observable
@MainActor
class AutomationRulesViewModel {
    /// Array of automation rules.
    var rules: [AutomationRule] = []
    /// Pre-built rule templates for common scenarios.
    var templates: [RuleTemplate] = []
    /// Execution history for the currently selected rule.
    var executionHistory: [RuleExecutionLog] = []
    /// Total count of execution logs for the selected rule.
    var executionHistoryCount: Int = 0
    /// Whether a request is currently in progress.
    var isLoading = false
    /// Whether templates are being loaded.
    var isLoadingTemplates = false
    /// Whether execution history is being loaded.
    var isLoadingHistory = false
    /// Current error, if any.
    var error: Error?

    private var apiClient: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.apiClient = client
    }

    // MARK: - Rule CRUD Operations

    /// Load all automation rules from the backend.
    func loadRules() async {
        guard let client = apiClient else {
            error = AutomationRuleError.notConfigured
            return
        }

        isLoading = true
        error = nil

        do {
            let response: ListAutomationRulesResponse = try await client.get("/automation-rules")
            rules = response.rules
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Create a new automation rule.
    /// - Parameter request: The rule creation request containing all rule properties
    /// - Returns: The created automation rule
    @discardableResult
    func createRule(_ request: CreateAutomationRuleRequest) async throws -> AutomationRule {
        guard let client = apiClient else {
            throw AutomationRuleError.notConfigured
        }

        isLoading = true
        error = nil

        do {
            let response: AutomationRuleResponse = try await client.post("/automation-rules", body: request)
            // Add the new rule to the list
            rules.append(response.rule)
            isLoading = false
            return response.rule
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    /// Update an existing automation rule.
    /// - Parameters:
    ///   - ruleId: UUID of the rule to update
    ///   - request: The update request containing fields to modify
    /// - Returns: The updated automation rule
    @discardableResult
    func updateRule(_ ruleId: UUID, request: UpdateAutomationRuleRequest) async throws -> AutomationRule {
        guard let client = apiClient else {
            throw AutomationRuleError.notConfigured
        }

        isLoading = true
        error = nil

        do {
            let response: AutomationRuleResponse = try await client.put("/automation-rules/\(ruleId.uuidString)", body: request)
            // Update the rule in the local list
            if let index = rules.firstIndex(where: { $0.id == ruleId }) {
                rules[index] = response.rule
            }
            isLoading = false
            return response.rule
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    /// Delete an automation rule.
    /// - Parameter ruleId: UUID of the rule to delete
    func deleteRule(_ ruleId: UUID) async throws {
        guard let client = apiClient else {
            throw AutomationRuleError.notConfigured
        }

        isLoading = true
        error = nil

        do {
            struct DeleteResponse: Decodable {
                let success: Bool
            }
            let _: DeleteResponse = try await client.delete("/automation-rules/\(ruleId.uuidString)")
            // Remove the rule from the local list
            rules.removeAll { $0.id == ruleId }
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }

    /// Toggle the enabled state of a rule.
    /// - Parameter ruleId: UUID of the rule to toggle
    func toggleRule(_ ruleId: UUID) async throws {
        guard let rule = rules.first(where: { $0.id == ruleId }) else {
            throw AutomationRuleError.ruleNotFound
        }

        let request = UpdateAutomationRuleRequest(isEnabled: !rule.isEnabled)
        try await updateRule(ruleId, request: request)
    }

    // MARK: - Templates

    /// Load pre-built rule templates from the backend.
    func loadTemplates() async {
        guard let client = apiClient else {
            error = AutomationRuleError.notConfigured
            return
        }

        isLoadingTemplates = true
        error = nil

        do {
            let response: ListRuleTemplatesResponse = try await client.get("/automation-rules/templates")
            templates = response.templates
        } catch {
            self.error = error
        }

        isLoadingTemplates = false
    }

    /// Create a rule from a template.
    /// - Parameter template: The template to use
    /// - Returns: The created automation rule
    @discardableResult
    func createRuleFromTemplate(_ template: RuleTemplate) async throws -> AutomationRule {
        let request = CreateAutomationRuleRequest(
            name: template.name,
            description: template.description,
            triggerType: template.triggerType,
            conditions: template.conditions,
            actionType: template.actionType,
            actionConfig: template.actionConfig
        )
        return try await createRule(request)
    }

    // MARK: - Execution History

    /// Load execution history for a specific rule.
    /// - Parameter ruleId: UUID of the rule
    func loadExecutionHistory(ruleId: UUID) async {
        guard let client = apiClient else {
            error = AutomationRuleError.notConfigured
            return
        }

        isLoadingHistory = true
        error = nil

        do {
            let response: RuleExecutionHistoryResponse = try await client.get("/automation-rules/\(ruleId.uuidString)/executions")
            executionHistory = response.executions
            executionHistoryCount = response.totalCount
        } catch {
            self.error = error
        }

        isLoadingHistory = false
    }

    // MARK: - Filtering & Querying

    /// Get rules filtered by session ID.
    /// - Parameter sessionId: UUID of the session
    /// - Returns: Array of rules scoped to the session or global rules
    func rules(for sessionId: UUID?) -> [AutomationRule] {
        if let sessionId = sessionId {
            return rules.filter { $0.sessionId == sessionId || $0.sessionId == nil }
        }
        return rules.filter { $0.sessionId == nil }
    }

    /// Get rules filtered by project name.
    /// - Parameter projectName: Name of the project
    /// - Returns: Array of rules scoped to the project or global rules
    func rules(forProject projectName: String?) -> [AutomationRule] {
        if let projectName = projectName {
            return rules.filter { $0.projectName == projectName || $0.projectName == nil }
        }
        return rules.filter { $0.projectName == nil }
    }

    /// Get enabled rules only.
    var enabledRules: [AutomationRule] {
        rules.filter { $0.isEnabled }
    }

    /// Get disabled rules only.
    var disabledRules: [AutomationRule] {
        rules.filter { !$0.isEnabled }
    }
}

// MARK: - Error Types

enum AutomationRuleError: Error, LocalizedError {
    case notConfigured
    case ruleNotFound

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AutomationRulesViewModel not configured with APIClient"
        case .ruleNotFound:
            return "Automation rule not found"
        }
    }
}
