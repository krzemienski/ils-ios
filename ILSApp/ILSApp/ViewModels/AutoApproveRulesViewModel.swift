import Foundation
import Observation
import ILSShared

// MARK: - AutoApproveRulesViewModel

/// ViewModel for the Auto-Approve Rules management screen.
///
/// Bridges `AutoApproveService` (actor, local cache + offline support) and
/// `PermissionPolicyAPIService` (direct backend access) to the SwiftUI layer.
///
/// CRUD mutations flow through `AutoApproveService`, which applies optimistic local
/// updates and best-effort backend sync. Direct backend access via `PermissionPolicyAPIService`
/// is used for explicit refresh, reordering, and settings management (default-deny).
///
/// Call `configure(client:)` once the active `APIClient` is known so that backend
/// operations can be performed. Before `configure(client:)` is called, all operations
/// fall back to the local `AutoApproveService` cache gracefully.
@MainActor
@Observable
class AutoApproveRulesViewModel {

    // MARK: - Observable State

    /// All auto-approve rules, mirrored from `AutoApproveService`.
    var rules: [AutoApproveRule] = []

    /// True while a local CRUD mutation is in progress.
    var isLoading = false

    /// Non-nil when a CRUD mutation fails; cleared before each new operation.
    var error: String?

    // MARK: - Backend Sync State

    /// Whether default-deny mode is currently enabled (fetched from backend).
    var defaultDenyEnabled: Bool = false

    /// True while a backend fetch (refresh or settings load) is in progress.
    var isLoadingFromBackend: Bool = false

    /// Non-nil when a backend sync operation fails; cleared before each new sync.
    var syncError: String?

    // MARK: - Private

    private var apiClient: APIClient?
    private let apiService = PermissionPolicyAPIService()

    // MARK: - Init

    init() {
        Task { await loadRules() }
    }

    // MARK: - Configuration

    /// Provides the API client required for direct backend operations.
    ///
    /// Call this once `AppState` (or an equivalent coordinator) has an active
    /// connection. If not called, CRUD operations still work via `AutoApproveService`'s
    /// local cache, but backend-only features (refresh, reorder, settings) are no-ops.
    func configure(client: APIClient) {
        apiClient = client
    }

    // MARK: - Computed Sections

    /// Rules that apply across all projects (projectId == nil).
    var globalRules: [AutoApproveRule] {
        rules.filter { $0.projectId == nil }
    }

    /// Rules scoped to a specific project (projectId != nil).
    var projectRules: [AutoApproveRule] {
        rules.filter { $0.projectId != nil }
    }

    // MARK: - Local Load

    /// Refresh the local rules cache from `AutoApproveService`.
    func loadRules() async {
        rules = await AutoApproveService.shared.allRules
    }

    // MARK: - Backend Refresh

    /// Fetches the latest rules and settings directly from the backend.
    ///
    /// Sets `isLoadingFromBackend` during the request and stores any failure in
    /// `syncError`. On failure, the existing local cache remains unchanged.
    func refreshFromBackend() async {
        guard let client = apiClient else {
            await loadRules()
            return
        }

        isLoadingFromBackend = true
        syncError = nil
        defer { isLoadingFromBackend = false }

        do {
            async let policiesTask = apiService.fetchPolicies(apiClient: client)
            async let settingsTask = apiService.fetchSettings(apiClient: client)

            let (policiesResponse, settings) = try await (policiesTask, settingsTask)
            rules = policiesResponse.items.map { AutoApproveRule(from: $0) }
            defaultDenyEnabled = settings.defaultDeny
        } catch {
            syncError = error.localizedDescription
            await loadRules()
            AppLogger.shared.error(
                "Backend sync failed: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Settings

    /// Toggles the default-deny setting with an optimistic local update.
    ///
    /// Reverts the toggle and stores the failure in `syncError` if the backend
    /// call fails. Silently no-ops when no API client is configured.
    func toggleDefaultDeny() async {
        guard let client = apiClient else { return }

        let previous = defaultDenyEnabled
        defaultDenyEnabled.toggle()
        syncError = nil

        do {
            let request = UpdatePermissionPolicySettingsRequest(defaultDeny: defaultDenyEnabled)
            let updated = try await apiService.updateSettings(request, apiClient: client)
            defaultDenyEnabled = updated.defaultDeny
        } catch {
            defaultDenyEnabled = previous
            syncError = error.localizedDescription
            AppLogger.shared.error(
                "Failed to update default-deny setting: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - Reorder

    /// Persists a new rule evaluation order to the backend.
    ///
    /// Applies the reordered list optimistically to `rules` immediately.
    /// Reverts and stores the failure in `syncError` if the backend call fails.
    ///
    /// - Parameter reorderedRules: Rules in the desired evaluation order
    ///   (index 0 = highest priority).
    func reorderRules(_ reorderedRules: [AutoApproveRule]) async {
        guard let client = apiClient, !reorderedRules.isEmpty else { return }

        let previous = rules
        rules = reorderedRules
        syncError = nil

        do {
            let request = ReorderPermissionPoliciesRequest(orderedIds: reorderedRules.map(\.id))
            try await apiService.reorderPolicies(request, apiClient: client)
        } catch {
            rules = previous
            syncError = error.localizedDescription
            AppLogger.shared.error(
                "Failed to reorder rules: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    // MARK: - CRUD Operations

    /// Add a new rule.
    ///
    /// Applies an optimistic local insert immediately. Reverts on failure.
    ///
    /// - Parameters:
    ///   - rule: The rule to persist.
    ///   - allowDestructive: Pass `true` if the caller has already confirmed the rule
    ///     targets a destructive operation. Defaults to `false`.
    func addRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        // Optimistic insert
        rules.append(rule)

        do {
            try await AutoApproveService.shared.addRule(rule, allowDestructive: allowDestructive)
            await loadRules()
        } catch {
            // Revert optimistic insert
            rules.removeAll { $0.id == rule.id }
            self.error = error.localizedDescription
            AppLogger.shared.error(
                "Failed to add auto-approve rule: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    /// Update an existing rule.
    ///
    /// Applies the update optimistically. Reverts on failure.
    ///
    /// - Parameters:
    ///   - rule: The updated rule (must carry the same `id` as the persisted rule).
    ///   - allowDestructive: Pass `true` if the caller has confirmed a destructive update.
    func updateRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        // Optimistic update
        let previous = rules
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        }

        do {
            try await AutoApproveService.shared.updateRule(rule, allowDestructive: allowDestructive)
            await loadRules()
        } catch {
            // Revert optimistic update
            rules = previous
            self.error = error.localizedDescription
            AppLogger.shared.error(
                "Failed to update auto-approve rule: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    /// Toggle the `isEnabled` flag on an existing rule.
    func toggleEnabled(_ rule: AutoApproveRule) async {
        var updated = rule
        updated.isEnabled.toggle()
        await updateRule(updated)
    }

    /// Delete rules at the specified offsets within a given section array.
    ///
    /// Removes the matching entries from `rules` optimistically before awaiting
    /// the service calls.
    ///
    /// - Parameters:
    ///   - offsets: Index set of items to remove within `section`.
    ///   - section: The ordered array from which the offsets are taken
    ///     (e.g. `globalRules` or `projectRules`).
    func deleteRules(atOffsets offsets: IndexSet, in section: [AutoApproveRule]) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        let toDelete = offsets.map { section[$0] }

        // Optimistic removal
        let ids = Set(toDelete.map(\.id))
        rules.removeAll { ids.contains($0.id) }

        for rule in toDelete {
            await AutoApproveService.shared.deleteRule(id: rule.id)
        }

        await loadRules()
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
}
