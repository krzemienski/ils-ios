import Foundation

// MARK: - AutoApproveServiceError

/// Errors thrown by AutoApproveService operations.
enum AutoApproveServiceError: Error, LocalizedError {
    /// Attempted to save a destructive rule without explicit confirmation.
    case destructiveRuleRequiresConfirmation

    var errorDescription: String? {
        switch self {
        case .destructiveRuleRequiresConfirmation:
            return "This rule would auto-approve a potentially destructive operation. " +
                   "Pass allowDestructive: true to confirm you intend to create this rule."
        }
    }
}

// MARK: - AutoApproveService

/// Singleton service for managing auto-approve rules with UserDefaults persistence.
///
/// Provides rule CRUD, rule matching for incoming tool invocations, and a safety guard
/// that prevents destructive rules from being created without explicit confirmation.
actor AutoApproveService {
    static let shared = AutoApproveService()

    // MARK: - Private State

    private var rules: [AutoApproveRule] = []
    private let defaults = UserDefaults.standard
    private let storageKey = "AutoApproveRules"

    private init() {
        rules = loadFromDefaults()
    }

    // MARK: - Querying

    /// Returns all stored rules, sorted by creation date (newest first).
    var allRules: [AutoApproveRule] {
        rules.sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns rules scoped to the given project plus all global (projectId == nil) rules.
    ///
    /// - Parameter projectId: The project to filter on. Pass nil to receive only global rules.
    func rules(forProject projectId: UUID?) -> [AutoApproveRule] {
        rules.filter { rule in
            rule.projectId == projectId || rule.projectId == nil
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Matching

    /// Returns the first enabled rule that matches the given tool invocation, or nil if none match.
    ///
    /// Rules scoped to the current project are evaluated before global rules.
    ///
    /// - Parameters:
    ///   - toolName: The tool being invoked (e.g. "Bash", "Read").
    ///   - toolInput: The raw input string for the tool invocation.
    ///   - projectId: The project the invocation belongs to, or nil for no project context.
    func matchingRule(toolName: String, toolInput: String, projectId: UUID?) -> AutoApproveRule? {
        // Prefer project-scoped rules over global ones
        let ordered = rules.sorted { lhs, rhs in
            switch (lhs.projectId, rhs.projectId) {
            case (.some, .none): return true
            case (.none, .some): return false
            default: return lhs.createdAt < rhs.createdAt
            }
        }

        for rule in ordered {
            // Skip rules for a different project
            if let ruleProject = rule.projectId, let currentProject = projectId {
                guard ruleProject == currentProject else { continue }
            } else if rule.projectId != nil && projectId == nil {
                // Rule is scoped to a project but we have no project context — skip
                continue
            }

            if rule.matches(toolName: toolName, toolInput: toolInput) {
                return rule
            }
        }
        return nil
    }

    /// Returns true if any enabled rule matches the given tool invocation.
    ///
    /// - Parameters:
    ///   - toolName: The tool being invoked.
    ///   - toolInput: The raw input string for the tool invocation.
    ///   - projectId: The project the invocation belongs to, or nil for no project context.
    func shouldAutoApprove(toolName: String, toolInput: String, projectId: UUID?) -> Bool {
        matchingRule(toolName: toolName, toolInput: toolInput, projectId: projectId) != nil
    }

    // MARK: - Mutations

    /// Add a new auto-approve rule.
    ///
    /// - Parameters:
    ///   - rule: The rule to persist.
    ///   - allowDestructive: Must be `true` when the rule targets a destructive operation.
    ///     Defaults to `false`; passing `false` for a destructive rule throws an error.
    /// - Throws: `AutoApproveServiceError.destructiveRuleRequiresConfirmation` if `rule.isDestructive`
    ///   is true and `allowDestructive` is false.
    func addRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) throws {
        if rule.isDestructive && !allowDestructive {
            throw AutoApproveServiceError.destructiveRuleRequiresConfirmation
        }
        rules.append(rule)
        saveToDefaults()
        AppLogger.shared.info(
            "Auto-approve rule added: \(rule.id) toolName=\(rule.toolName ?? "*")",
            category: "permissions"
        )
    }

    /// Update an existing rule identified by its ID.
    ///
    /// If no rule with the given ID exists, the call is a no-op.
    ///
    /// - Parameters:
    ///   - rule: The updated rule (must have same `id` as the rule to replace).
    ///   - allowDestructive: Must be `true` when the updated rule targets a destructive operation.
    /// - Throws: `AutoApproveServiceError.destructiveRuleRequiresConfirmation` for unconfirmed
    ///   destructive updates.
    func updateRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) throws {
        if rule.isDestructive && !allowDestructive {
            throw AutoApproveServiceError.destructiveRuleRequiresConfirmation
        }
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
        saveToDefaults()
        AppLogger.shared.info(
            "Auto-approve rule updated: \(rule.id)",
            category: "permissions"
        )
    }

    /// Delete the rule with the given ID.
    ///
    /// If no matching rule exists, the call is a no-op.
    func deleteRule(id: UUID) {
        let before = rules.count
        rules.removeAll { $0.id == id }
        if rules.count < before {
            saveToDefaults()
            AppLogger.shared.info(
                "Auto-approve rule deleted: \(id)",
                category: "permissions"
            )
        }
    }

    /// Delete all rules scoped to the given project.
    func deleteRules(forProject projectId: UUID) {
        rules.removeAll { $0.projectId == projectId }
        saveToDefaults()
        AppLogger.shared.info(
            "All auto-approve rules deleted for project \(projectId)",
            category: "permissions"
        )
    }

    /// Delete all rules (global and project-scoped).
    func deleteAllRules() {
        rules.removeAll()
        saveToDefaults()
        AppLogger.shared.info("All auto-approve rules deleted", category: "permissions")
    }

    // MARK: - Persistence

    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(rules)
            defaults.set(data, forKey: storageKey)
        } catch {
            AppLogger.shared.error(
                "Failed to save auto-approve rules: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    private func loadFromDefaults() -> [AutoApproveRule] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([AutoApproveRule].self, from: data)
        } catch {
            AppLogger.shared.error(
                "Failed to load auto-approve rules: \(error.localizedDescription)",
                category: "permissions"
            )
            return []
        }
    }
}
