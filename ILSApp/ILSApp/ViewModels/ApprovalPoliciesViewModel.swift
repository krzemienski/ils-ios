import Foundation
import Observation
import ILSShared

// MARK: - ApprovalPoliciesViewModel

/// ViewModel for the Approval Policies management screen.
///
/// Bridges the `/approval-policies` backend endpoints to the SwiftUI layer,
/// maintaining a local cache of policies that is refreshed after each mutation.
///
/// Follows the same actor-bridge pattern as ``AuditTrailViewModel`` (inherits
/// ``BaseViewModel``) and communicates with the backend via ``APIClient``.
@MainActor
@Observable
class ApprovalPoliciesViewModel: BaseViewModel {

    // MARK: - State

    /// All loaded approval policies, ordered by priority ascending.
    var policies: [ApprovalPolicy] = []

    /// Total number of policies on the server (before pagination).
    var totalCount: Int = 0

    /// Number of currently enabled policies on the server.
    var enabledCount: Int = 0

    /// Whether additional pages of results are available.
    var hasMore: Bool = false

    /// Available built-in policy templates.
    var templates: [PolicyTemplateResponse] = []

    /// Local search text applied to ``filteredPolicies``.
    var searchText: String = ""

    // MARK: - Computed

    /// Policies filtered by the local ``searchText``.
    ///
    /// When ``searchText`` is empty, returns all ``policies``.
    /// Matches are case-insensitive against name and description.
    var filteredPolicies: [ApprovalPolicy] {
        guard !searchText.isEmpty else { return policies }
        let query = searchText.lowercased()
        return policies.filter { policy in
            policy.name.lowercased().contains(query)
                || (policy.description?.lowercased().contains(query) ?? false)
        }
    }

    /// Policies that are currently active.
    var enabledPolicies: [ApprovalPolicy] {
        policies.filter { $0.isEnabled }
    }

    /// Global policies (scope == .global).
    var globalPolicies: [ApprovalPolicy] {
        policies.filter { $0.scope == .global }
    }

    /// Project-scoped policies (scope == .project).
    var projectPolicies: [ApprovalPolicy] {
        policies.filter { $0.scope == .project }
    }

    // MARK: - Init

    override init() {
        super.init()
        Task { await loadPolicies() }
    }

    // MARK: - Load Operations

    /// Fetch the list of approval policies from the backend, replacing any existing data.
    ///
    /// Optionally filters by project name and/or enabled state.
    ///
    /// - Parameters:
    ///   - projectName: Optional project name filter.
    ///   - isEnabled: Optional enabled state filter.
    func loadPolicies(projectName: String? = nil, isEnabled: Bool? = nil) async {
        guard let client else { return }
        isLoading = true
        error = nil

        var path = "/approval-policies"
        var queryParams: [String] = []
        if let projectName {
            queryParams.append("projectName=\(projectName)")
        }
        if let isEnabled {
            queryParams.append("isEnabled=\(isEnabled)")
        }
        if !queryParams.isEmpty {
            path += "?" + queryParams.joined(separator: "&")
        }

        do {
            let response: APIResponse<ApprovalPolicyListResponse> = try await client.get(path)
            if let data = response.data {
                policies = data.policies
                totalCount = data.totalCount
                enabledCount = data.enabledCount
                hasMore = data.hasMore
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load approval policies: \(error.localizedDescription)",
                category: "approval-policies"
            )
        }

        isLoading = false
    }

    /// Fetch the list of built-in policy templates from the backend.
    func loadTemplates() async {
        guard let client else { return }

        do {
            let response: APIResponse<ListPolicyTemplatesResponse> = try await client.get(
                "/approval-policies/templates"
            )
            if let data = response.data {
                templates = data.templates
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load policy templates: \(error.localizedDescription)",
                category: "approval-policies"
            )
        }
    }

    // MARK: - CRUD Operations

    /// Create a new approval policy on the backend.
    ///
    /// On success, refreshes the local policies list.
    ///
    /// - Parameter request: The policy creation request payload.
    /// - Returns: The created ``ApprovalPolicy``, or `nil` on failure.
    @discardableResult
    func createPolicy(_ request: CreateApprovalPolicyRequest) async -> ApprovalPolicy? {
        guard let client else { return nil }
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let response: APIResponse<ApprovalPolicy> = try await client.post(
                "/approval-policies",
                body: request
            )
            if let policy = response.data {
                await loadPolicies()
                return policy
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to create approval policy: \(error.localizedDescription)",
                category: "approval-policies"
            )
        }

        return nil
    }

    /// Update an existing approval policy on the backend.
    ///
    /// On success, refreshes the local policies list.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the policy to update.
    ///   - request: The policy update request payload.
    /// - Returns: The updated ``ApprovalPolicy``, or `nil` on failure.
    @discardableResult
    func updatePolicy(id: UUID, _ request: UpdateApprovalPolicyRequest) async -> ApprovalPolicy? {
        guard let client else { return nil }
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let response: APIResponse<ApprovalPolicy> = try await client.put(
                "/approval-policies/\(id.uuidString.lowercased())",
                body: request
            )
            if let policy = response.data {
                await loadPolicies()
                return policy
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to update approval policy: \(error.localizedDescription)",
                category: "approval-policies"
            )
        }

        return nil
    }

    /// Delete an approval policy from the backend.
    ///
    /// On success, refreshes the local policies list.
    ///
    /// - Parameter id: The unique identifier of the policy to delete.
    /// - Returns: `true` if the deletion succeeded, `false` otherwise.
    @discardableResult
    func deletePolicy(id: UUID) async -> Bool {
        guard let client else { return false }
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let _: APIResponse<DeletedResponse> = try await client.delete(
                "/approval-policies/\(id.uuidString.lowercased())"
            )
            await loadPolicies()
            return true
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to delete approval policy: \(error.localizedDescription)",
                category: "approval-policies"
            )
        }

        return false
    }

    // MARK: - Convenience Operations

    /// Toggle the `isEnabled` flag on an existing policy.
    ///
    /// - Parameter policy: The policy to toggle.
    func toggleEnabled(_ policy: ApprovalPolicy) async {
        let request = UpdateApprovalPolicyRequest(isEnabled: !policy.isEnabled)
        await updatePolicy(id: policy.id, request)
    }

    /// Apply a built-in template by creating a new policy pre-configured with the
    /// template's defaults.
    ///
    /// - Parameter templateId: The identifier of the template to apply.
    /// - Returns: The created ``ApprovalPolicy``, or `nil` on failure.
    @discardableResult
    func applyTemplate(templateId: String) async -> ApprovalPolicy? {
        guard let template = templates.first(where: { $0.id == templateId }) else {
            self.error = NSError(
                domain: "ApprovalPoliciesViewModel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Template '\(templateId)' not found"]
            )
            AppLogger.shared.error(
                "Template '\(templateId)' not found in loaded templates",
                category: "approval-policies"
            )
            return nil
        }

        let request = CreateApprovalPolicyRequest(
            name: template.name,
            description: template.description,
            template: template.template,
            defaultAction: template.defaultAction,
            toolRules: template.toolRules,
            confirmationRequiredRiskLevels: template.confirmationRequiredRiskLevels
        )

        return await createPolicy(request)
    }

    /// Delete policies at the specified offsets within a given section array.
    ///
    /// Designed for use with `List` `.onDelete` which supplies an `IndexSet`
    /// relative to the currently visible section.
    ///
    /// - Parameters:
    ///   - offsets: Index set of items to remove within `section`.
    ///   - section: The ordered array from which the offsets are taken.
    func deletePolicies(atOffsets offsets: IndexSet, in section: [ApprovalPolicy]) async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        for policy in offsets.map({ section[$0] }) {
            await deletePolicy(id: policy.id)
        }
    }
}
