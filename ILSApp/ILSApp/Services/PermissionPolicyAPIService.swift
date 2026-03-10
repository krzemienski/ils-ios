import Foundation
import ILSShared

// MARK: - PermissionPolicyAPIService

/// Network service for managing permission policy rules via the ILS backend.
///
/// Provides CRUD operations for permission policies and settings,
/// communicating with the `/api/v1/permission-policies` endpoint family.
///
/// All methods are async and throw on network or decoding failures.
/// Callers are responsible for presenting errors to the user.
struct PermissionPolicyAPIService {

    // MARK: - Policies

    /// Fetches all permission policies, optionally scoped to a project.
    ///
    /// - Parameters:
    ///   - projectId: When provided, only returns policies for this project plus global policies.
    ///     When nil, returns all policies.
    ///   - apiClient: The API client used to perform the network request.
    /// - Returns: A list response containing the matching permission policies.
    /// - Throws: `APIError` on network or decoding failure.
    func fetchPolicies(
        projectId: UUID? = nil,
        apiClient: APIClient
    ) async throws -> ListPermissionPoliciesResponse {
        var path = "/permission-policies"
        if let projectId {
            path += "?projectId=\(projectId.uuidString.lowercased())"
        }
        let response: APIResponse<ListPermissionPoliciesResponse> = try await apiClient.get(path)
        return response.data ?? ListPermissionPoliciesResponse(items: [], total: 0)
    }

    /// Creates a new permission policy rule on the backend.
    ///
    /// - Parameters:
    ///   - request: The policy definition to create.
    ///   - apiClient: The API client used to perform the network request.
    /// - Returns: The newly created policy as returned by the server.
    /// - Throws: `APIError` on network or decoding failure.
    func createPolicy(
        _ request: CreatePermissionPolicyRequest,
        apiClient: APIClient
    ) async throws -> PermissionPolicyResponse {
        let response: APIResponse<PermissionPolicyResponse> = try await apiClient.post(
            "/permission-policies",
            body: request
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    /// Updates an existing permission policy rule.
    ///
    /// - Parameters:
    ///   - request: Partial update payload — only non-nil fields are applied.
    ///   - id: The UUID of the policy to update.
    ///   - apiClient: The API client used to perform the network request.
    /// - Returns: The updated policy as returned by the server.
    /// - Throws: `APIError` on network or decoding failure.
    func updatePolicy(
        _ request: UpdatePermissionPolicyRequest,
        id: UUID,
        apiClient: APIClient
    ) async throws -> PermissionPolicyResponse {
        let response: APIResponse<PermissionPolicyResponse> = try await apiClient.put(
            "/permission-policies/\(id.uuidString.lowercased())",
            body: request
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    /// Deletes a permission policy rule by its ID.
    ///
    /// - Parameters:
    ///   - id: The UUID of the policy to delete.
    ///   - apiClient: The API client used to perform the network request.
    /// - Throws: `APIError` on network or decoding failure.
    func deletePolicy(id: UUID, apiClient: APIClient) async throws {
        let _: APIResponse<DeletedResponse> = try await apiClient.delete(
            "/permission-policies/\(id.uuidString.lowercased())"
        )
        AppLogger.shared.info(
            "Permission policy deleted: \(id)",
            category: "permissions"
        )
    }

    /// Reorders permission policies by submitting a new priority order.
    ///
    /// The backend assigns priorities based on position in the array
    /// (index 0 receives the highest priority, i.e., lowest numeric value).
    ///
    /// - Parameters:
    ///   - request: Ordered list of policy IDs representing the desired evaluation order.
    ///   - apiClient: The API client used to perform the network request.
    /// - Throws: `APIError` on network or decoding failure.
    func reorderPolicies(
        _ request: ReorderPermissionPoliciesRequest,
        apiClient: APIClient
    ) async throws {
        let _: APIResponse<ListPermissionPoliciesResponse> = try await apiClient.post(
            "/permission-policies/reorder",
            body: request
        )
    }

    // MARK: - Settings

    /// Fetches the permission policy settings, optionally scoped to a project.
    ///
    /// - Parameters:
    ///   - projectId: When provided, fetches project-scoped settings.
    ///     When nil, fetches global settings.
    ///   - apiClient: The API client used to perform the network request.
    /// - Returns: The current permission policy settings.
    /// - Throws: `APIError` on network or decoding failure.
    func fetchSettings(
        projectId: UUID? = nil,
        apiClient: APIClient
    ) async throws -> PermissionPolicySettingsResponse {
        var path = "/permission-policies/settings"
        if let projectId {
            path += "?projectId=\(projectId.uuidString.lowercased())"
        }
        let response: APIResponse<PermissionPolicySettingsResponse> = try await apiClient.get(path)
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }

    /// Updates the permission policy settings.
    ///
    /// - Parameters:
    ///   - request: Partial update payload — only non-nil fields are applied.
    ///   - projectId: When provided, updates project-scoped settings.
    ///     When nil, updates global settings.
    ///   - apiClient: The API client used to perform the network request.
    /// - Returns: The updated settings as returned by the server.
    /// - Throws: `APIError` on network or decoding failure.
    func updateSettings(
        _ request: UpdatePermissionPolicySettingsRequest,
        projectId: UUID? = nil,
        apiClient: APIClient
    ) async throws -> PermissionPolicySettingsResponse {
        var path = "/permission-policies/settings"
        if let projectId {
            path += "?projectId=\(projectId.uuidString.lowercased())"
        }
        let response: APIResponse<PermissionPolicySettingsResponse> = try await apiClient.put(
            path,
            body: request
        )
        guard let data = response.data else {
            throw APIError.invalidResponse
        }
        return data
    }
}
