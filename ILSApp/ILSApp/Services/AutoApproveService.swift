import Foundation
import ILSShared

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

/// Singleton service for managing auto-approve rules with hybrid persistence.
///
/// Rules are loaded from the backend (via `PermissionPolicyAPIService`) on each
/// `refresh(apiClient:)` call, falling back to a UserDefaults cache for offline support.
/// All mutations update the local in-memory cache immediately and then attempt a
/// best-effort sync to the backend (failures are logged but not surfaced to callers).
///
/// On the first successful backend sync, any rules persisted locally in UserDefaults are
/// automatically migrated to the backend so no data is lost during the upgrade.
///
/// The in-memory cache is always available for fast rule evaluation during polling cycles.
actor AutoApproveService {
    static let shared = AutoApproveService()

    // MARK: - Private State

    private var rules: [AutoApproveRule] = []
    private let defaults = UserDefaults.standard
    private let storageKey = "AutoApproveRules"
    private let migrationCompletedKey = "AutoApproveRulesMigratedToBackend"
    private let apiService = PermissionPolicyAPIService()

    /// Cached API client set on the first successful `refresh(apiClient:)` call.
    /// Retained so that subsequent mutations can sync to the backend without
    /// requiring callers to pass an APIClient on every operation.
    private var apiClient: APIClient?

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

    // MARK: - Backend Sync

    /// Refreshes the rule cache from the backend.
    ///
    /// On the first call, migrates any locally-persisted UserDefaults rules to the backend
    /// before fetching. Subsequent calls simply reload the current backend state.
    ///
    /// Falls back to the existing local cache (UserDefaults) when the backend is unreachable.
    /// The cached `apiClient` is updated so mutations can sync automatically going forward.
    ///
    /// - Parameter apiClient: The API client used for backend communication.
    func refresh(apiClient: APIClient) async {
        self.apiClient = apiClient

        // One-time migration of local rules to backend
        if !defaults.bool(forKey: migrationCompletedKey) {
            await migrateLocalRulesToBackend(apiClient: apiClient)
        }

        // Fetch current rules from backend, fall back to local cache on failure
        do {
            let response = try await apiService.fetchPolicies(apiClient: apiClient)
            rules = response.items.map { AutoApproveRule(from: $0) }
            saveToDefaults()
            AppLogger.shared.info(
                "Auto-approve rules synced from backend: \(rules.count) rule(s)",
                category: "permissions"
            )
        } catch {
            AppLogger.shared.info(
                "Backend sync unavailable, using local cache (\(rules.count) rule(s)): \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Mutations

    /// Add a new auto-approve rule.
    ///
    /// The rule is inserted into the local cache immediately and then synced to the
    /// backend (best-effort). If the backend accepts the rule, the local entry is updated
    /// with the server-assigned ID.
    ///
    /// - Parameters:
    ///   - rule: The rule to persist.
    ///   - allowDestructive: Must be `true` when the rule targets a destructive operation.
    ///     Defaults to `false`; passing `false` for a destructive rule throws an error.
    /// - Throws: `AutoApproveServiceError.destructiveRuleRequiresConfirmation` if `rule.isDestructive`
    ///   is true and `allowDestructive` is false.
    func addRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async throws {
        if rule.isDestructive && !allowDestructive {
            throw AutoApproveServiceError.destructiveRuleRequiresConfirmation
        }
        rules.append(rule)
        saveToDefaults()
        AppLogger.shared.info(
            "Auto-approve rule added: \(rule.id) toolName=\(rule.toolName ?? "*")",
            category: "permissions"
        )

        // Best-effort backend sync
        if let client = apiClient {
            let request = rule.toCreateRequest()
            if let response = try? await apiService.createPolicy(request, apiClient: client) {
                // Replace the temporary local entry with the server-authoritative version
                if let index = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules[index] = AutoApproveRule(from: response)
                    saveToDefaults()
                }
            }
        }
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
    func updateRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async throws {
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

        // Best-effort backend sync
        if let client = apiClient {
            let request = rule.toUpdateRequest()
            if let response = try? await apiService.updatePolicy(request, id: rule.id, apiClient: client) {
                if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                    rules[idx] = AutoApproveRule(from: response)
                    saveToDefaults()
                }
            }
        }
    }

    /// Delete the rule with the given ID.
    ///
    /// If no matching rule exists, the call is a no-op.
    func deleteRule(id: UUID) async {
        let before = rules.count
        rules.removeAll { $0.id == id }
        if rules.count < before {
            saveToDefaults()
            AppLogger.shared.info(
                "Auto-approve rule deleted: \(id)",
                category: "permissions"
            )

            // Best-effort backend sync
            if let client = apiClient {
                try? await apiService.deletePolicy(id: id, apiClient: client)
            }
        }
    }

    /// Delete all rules scoped to the given project.
    func deleteRules(forProject projectId: UUID) async {
        let toDelete = rules.filter { $0.projectId == projectId }
        rules.removeAll { $0.projectId == projectId }
        saveToDefaults()
        AppLogger.shared.info(
            "All auto-approve rules deleted for project \(projectId)",
            category: "permissions"
        )

        // Best-effort backend sync
        if let client = apiClient {
            for rule in toDelete {
                try? await apiService.deletePolicy(id: rule.id, apiClient: client)
            }
        }
    }

    /// Delete all rules (global and project-scoped).
    func deleteAllRules() async {
        let toDelete = rules
        rules.removeAll()
        saveToDefaults()
        AppLogger.shared.info("All auto-approve rules deleted", category: "permissions")

        // Best-effort backend sync
        if let client = apiClient {
            for rule in toDelete {
                try? await apiService.deletePolicy(id: rule.id, apiClient: client)
            }
        }
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

    // MARK: - Private: Migration

    /// Migrates existing UserDefaults-persisted rules to the backend on first launch.
    ///
    /// Called once per installation, guarded by `migrationCompletedKey`. After migration
    /// completes (whether or not all rules transferred successfully), the key is marked
    /// so that the migration is never attempted again.
    private func migrateLocalRulesToBackend(apiClient: APIClient) async {
        defer { defaults.set(true, forKey: migrationCompletedKey) }

        guard !rules.isEmpty else { return }

        var migratedCount = 0
        for rule in rules {
            if (try? await apiService.createPolicy(rule.toCreateRequest(), apiClient: apiClient)) != nil {
                migratedCount += 1
            }
        }
        AppLogger.shared.info(
            "Migrated \(migratedCount)/\(rules.count) auto-approve rule(s) to backend",
            category: "permissions"
        )
    }
}

// MARK: - AutoApproveRule + PermissionPolicyResponse

private extension AutoApproveRule {

    /// Creates a local rule from a backend policy response.
    init(from response: PermissionPolicyResponse) {
        self.init(
            id: response.id,
            toolName: response.toolName,
            pathGlob: response.pathGlob,
            commandPrefix: response.commandPrefix,
            mcpServer: response.mcpServer,
            action: response.action,
            isEnabled: response.isEnabled,
            projectId: response.projectId,
            note: response.note,
            priority: response.priority,
            createdAt: response.createdAt
        )
    }

    /// Builds a `CreatePermissionPolicyRequest` from this rule.
    func toCreateRequest() -> CreatePermissionPolicyRequest {
        let name: String
        if let tool = toolName {
            name = "Auto-approve \(tool)"
        } else if let prefix = commandPrefix {
            name = "Auto-approve: \(prefix)"
        } else {
            name = "Auto-approve all"
        }
        return CreatePermissionPolicyRequest(
            name: name,
            toolName: toolName,
            pathGlob: pathGlob,
            commandPrefix: commandPrefix,
            mcpServer: mcpServer,
            action: action,
            projectId: projectId,
            isEnabled: isEnabled,
            priority: priority,
            note: note
        )
    }

    /// Builds an `UpdatePermissionPolicyRequest` from this rule.
    func toUpdateRequest() -> UpdatePermissionPolicyRequest {
        let name: String
        if let tool = toolName {
            name = "Auto-approve \(tool)"
        } else if let prefix = commandPrefix {
            name = "Auto-approve: \(prefix)"
        } else {
            name = "Auto-approve all"
        }
        return UpdatePermissionPolicyRequest(
            name: name,
            toolName: toolName,
            pathGlob: pathGlob,
            commandPrefix: commandPrefix,
            mcpServer: mcpServer,
            action: action,
            isEnabled: isEnabled,
            priority: priority,
            note: note
        )
    }
}
