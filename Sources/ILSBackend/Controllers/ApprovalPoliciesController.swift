import Vapor
import Fluent
import ILSShared

/// Controller for managing approval policies that govern agent tool-use authorization.
///
/// Routes:
/// - `GET /approval-policies`: List all approval policies
/// - `GET /approval-policies/templates`: List built-in policy templates
/// - `POST /approval-policies`: Create a new approval policy
/// - `PUT /approval-policies/:id`: Update an existing approval policy
/// - `DELETE /approval-policies/:id`: Delete an approval policy
/// - `POST /approval-policies/evaluate`: Test-evaluate a tool request against policies
struct ApprovalPoliciesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let policies = routes.grouped("approval-policies")

        policies.get(use: list)
        policies.get("templates", use: templates)
        policies.post(use: create)
        policies.put(":id", use: update)
        policies.delete(":id", use: deletePolicy)
        policies.post("evaluate", use: evaluate)
    }

    // MARK: - List All Policies

    /// GET /approval-policies
    ///
    /// Returns all approval policies sorted by priority (ascending).
    ///
    /// Query parameters:
    /// - `projectName`: Optional — filter to policies for a specific project (includes global policies)
    /// - `isEnabled`: Optional — filter to enabled/disabled policies (true/false)
    @Sendable
    func list(req: Request) async throws -> APIResponse<ApprovalPolicyListResponse> {
        var policies = await ApprovalPolicyStore.shared.allPolicies()

        if let projectName = req.query[String.self, at: "projectName"] {
            policies = policies.filter { policy in
                policy.scope == .global || policy.projectName == projectName
            }
        }

        if let isEnabled = req.query[Bool.self, at: "isEnabled"] {
            policies = policies.filter { $0.isEnabled == isEnabled }
        }

        let enabledCount = policies.filter(\.isEnabled).count

        return APIResponse(
            success: true,
            data: ApprovalPolicyListResponse(
                policies: policies,
                totalCount: policies.count,
                enabledCount: enabledCount
            )
        )
    }

    // MARK: - List Templates

    /// GET /approval-policies/templates
    ///
    /// Returns the built-in policy templates (strict, balanced, permissive).
    @Sendable
    func templates(req: Request) async throws -> APIResponse<ListPolicyTemplatesResponse> {
        return APIResponse(
            success: true,
            data: ListPolicyTemplatesResponse(
                templates: ApprovalPolicyStore.builtInTemplates
            )
        )
    }

    // MARK: - Create Policy

    /// POST /approval-policies
    ///
    /// Creates a new approval policy and persists it to the database.
    ///
    /// Request body: `CreateApprovalPolicyRequest`
    @Sendable
    func create(req: Request) async throws -> APIResponse<ApprovalPolicy> {
        let input = try req.content.decode(CreateApprovalPolicyRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        if let description = input.description {
            try PathSanitizer.validateOptionalStringLength(description, maxLength: 1000, fieldName: "description")
        }
        if let projectName = input.projectName {
            try PathSanitizer.validateOptionalStringLength(projectName, maxLength: 255, fieldName: "projectName")
        }

        let policy = try await ApprovalPolicyStore.shared.addPolicy(from: input, db: req.db)

        req.logger.info("Created approval policy: \(policy.id) name=\(policy.name)")

        return APIResponse(success: true, data: policy)
    }

    // MARK: - Update Policy

    /// PUT /approval-policies/:id
    ///
    /// Updates an existing approval policy. Only non-nil fields in the request body are applied.
    ///
    /// Request body: `UpdateApprovalPolicyRequest`
    @Sendable
    func update(req: Request) async throws -> APIResponse<ApprovalPolicy> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid policy ID")
        }

        let input = try req.content.decode(UpdateApprovalPolicyRequest.self)

        // Validate input lengths
        if let name = input.name {
            try PathSanitizer.validateOptionalStringLength(name, maxLength: 255, fieldName: "name")
        }
        if let description = input.description {
            try PathSanitizer.validateOptionalStringLength(description, maxLength: 1000, fieldName: "description")
        }
        if let projectName = input.projectName {
            try PathSanitizer.validateOptionalStringLength(projectName, maxLength: 255, fieldName: "projectName")
        }

        guard let updated = try await ApprovalPolicyStore.shared.updatePolicy(id: id, from: input, db: req.db) else {
            throw Abort(.notFound, reason: "Approval policy not found")
        }

        req.logger.info("Updated approval policy: \(id)")

        return APIResponse(success: true, data: updated)
    }

    // MARK: - Delete Policy

    /// DELETE /approval-policies/:id
    ///
    /// Deletes an approval policy from the database and cache.
    @Sendable
    func deletePolicy(req: Request) async throws -> APIResponse<AcknowledgedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid policy ID")
        }

        let deleted = try await ApprovalPolicyStore.shared.deletePolicy(id: id, db: req.db)

        guard deleted else {
            throw Abort(.notFound, reason: "Approval policy not found")
        }

        req.logger.info("Deleted approval policy: \(id)")

        return APIResponse(success: true, data: AcknowledgedResponse())
    }

    // MARK: - Evaluate (Test)

    /// POST /approval-policies/evaluate
    ///
    /// Test-evaluates a tool request against the configured approval policies.
    /// Useful for previewing what action would be taken without actually executing a tool.
    ///
    /// Request body: `PolicyEvaluateRequest` with toolName, toolInput, riskLevel, and optional projectName.
    @Sendable
    func evaluate(req: Request) async throws -> APIResponse<PolicyEvaluationResult> {
        let input = try req.content.decode(PolicyEvaluateRequest.self)

        let result = await PolicyEvaluationService.shared.evaluate(
            toolName: input.toolName,
            toolInput: input.toolInput,
            riskLevel: input.riskLevel,
            projectId: input.projectName
        )

        req.logger.info("Policy evaluation: tool=\(input.toolName) action=\(result.action.rawValue)")

        return APIResponse(success: true, data: result)
    }
}

// MARK: - Evaluate Request DTO

/// Request payload for test-evaluating a tool request against approval policies.
struct PolicyEvaluateRequest: Content, Sendable {
    /// The name of the tool to evaluate (e.g., "Bash", "Write", "Edit").
    let toolName: String
    /// Tool input parameters (may contain file paths for path-based matching).
    let toolInput: AnyCodable
    /// The assessed risk level for this operation.
    let riskLevel: PermissionRiskLevel
    /// Optional project name for project-scoped policy matching.
    let projectName: String?
}
