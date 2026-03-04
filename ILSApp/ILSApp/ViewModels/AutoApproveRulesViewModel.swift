import Foundation
import Observation

// MARK: - AutoApproveRulesViewModel

/// ViewModel for the Auto-Approve Rules management screen.
///
/// Bridges `AutoApproveService` (an actor) to the SwiftUI layer by maintaining a local
/// cache of rules that is refreshed after each mutation.
@MainActor
@Observable
class AutoApproveRulesViewModel {

    // MARK: - Observable State

    /// All auto-approve rules, mirrored from `AutoApproveService`.
    var rules: [AutoApproveRule] = []

    /// True while an async mutation is in progress.
    var isLoading = false

    /// Non-nil when a mutation fails; cleared before each new operation.
    var error: String?

    // MARK: - Init

    init() {
        Task { await loadRules() }
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

    // MARK: - Load

    /// Refresh the local rules cache from the service.
    func loadRules() async {
        rules = await AutoApproveService.shared.allRules
    }

    // MARK: - CRUD Operations

    /// Add a new rule.
    ///
    /// - Parameters:
    ///   - rule: The rule to persist.
    ///   - allowDestructive: Pass `true` if the caller has already confirmed the rule
    ///     targets a destructive operation. Defaults to `false`.
    func addRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AutoApproveService.shared.addRule(rule, allowDestructive: allowDestructive)
            await loadRules()
        } catch {
            self.error = error.localizedDescription
            AppLogger.shared.error(
                "Failed to add auto-approve rule: \(error.localizedDescription)",
                category: "permissions"
            )
        }
    }

    /// Update an existing rule.
    ///
    /// - Parameters:
    ///   - rule: The updated rule (must carry the same `id` as the persisted rule).
    ///   - allowDestructive: Pass `true` if the caller has confirmed a destructive update.
    func updateRule(_ rule: AutoApproveRule, allowDestructive: Bool = false) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await AutoApproveService.shared.updateRule(rule, allowDestructive: allowDestructive)
            await loadRules()
        } catch {
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
    /// Designed for use with `List` `.onDelete` which supplies an `IndexSet` relative to
    /// the currently visible section.
    ///
    /// - Parameters:
    ///   - offsets: Index set of items to remove within `section`.
    ///   - section: The ordered array from which the offsets are taken
    ///     (e.g. `globalRules` or `projectRules`).
    func deleteRules(atOffsets offsets: IndexSet, in section: [AutoApproveRule]) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        for rule in offsets.map({ section[$0] }) {
            await AutoApproveService.shared.deleteRule(id: rule.id)
        }

        await loadRules()
    }
}
