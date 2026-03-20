import Foundation
import Fluent
import Vapor
import ILSShared
import Logging

/// In-memory store for approval policies that govern agent action authorization.
///
/// ## Architecture
///
/// Acts as the central authority for approval policy lifecycle:
/// 1. On startup, `loadPolicies(db:)` reads all policies from the database into memory.
/// 2. The iOS client reads policies via the REST API (backed by `allPolicies()` / `policiesForProject()`).
/// 3. Mutations (`addPolicy`, `updatePolicy`, `deletePolicy`) persist to DB and reload the cache.
/// 4. `PolicyEvaluationService` queries this store to evaluate permission requests deterministically.
///
/// ## Built-in Templates
///
/// Three pre-configured templates are available:
/// - **Strict**: Always ask for all tools — maximum safety.
/// - **Balanced**: Auto-approve reads, ask for writes/bash — moderate friction.
/// - **Permissive**: Auto-approve everything except destructive commands — minimum friction.
///
/// ## Concurrency
///
/// Declared as an `actor` so all mutations are automatically serialised — no explicit locking
/// required. Callers must `await` every method.
actor ApprovalPolicyStore {
    /// Shared singleton accessible throughout the backend without dependency injection.
    static let shared = ApprovalPolicyStore()

    /// Structured logger for ApprovalPolicyStore operations.
    private static let logger = Logger(label: "ils.approval-policy-store")

    /// Cached policies keyed by ID for O(1) lookup.
    private var policiesById: [UUID: ApprovalPolicy] = [:]

    /// Cached policies sorted by priority (ascending) for evaluation order.
    private var sortedPolicies: [ApprovalPolicy] = []

    // MARK: - Database Operations

    /// Load all policies from the database into the in-memory cache.
    ///
    /// Call this once on server startup (from `configure.swift`).
    ///
    /// - Parameter db: Fluent `Database` handle to query from.
    func loadPolicies(db: Database) async throws {
        let models = try await ApprovalPolicyModel.query(on: db).all()
        var byId: [UUID: ApprovalPolicy] = [:]
        for model in models {
            guard let id = model.id else { continue }
            let policy = Self.toShared(model: model, id: id)
            byId[id] = policy
        }
        policiesById = byId
        rebuildSortedCache()
        Self.logger.info("Loaded \(policiesById.count) approval policies from database")
    }

    /// Add a new policy, persisting it to the database and updating the cache.
    ///
    /// - Parameters:
    ///   - request: The creation request DTO.
    ///   - db: Fluent `Database` handle for persistence.
    /// - Returns: The newly created `ApprovalPolicy`.
    @discardableResult
    func addPolicy(from request: CreateApprovalPolicyRequest, db: Database) async throws -> ApprovalPolicy {
        let model = ApprovalPolicyModel(
            name: request.name,
            templateId: request.template.rawValue,
            actionType: request.defaultAction.rawValue,
            toolNames: request.toolRules.map(\.toolPattern),
            pathGlobs: request.pathPatterns ?? [],
            riskLevels: (request.confirmationRequiredRiskLevels ?? [.high, .critical]).map(\.rawValue),
            projectId: request.projectName,
            isEnabled: request.isEnabled,
            priority: request.priority ?? 100
        )
        try await model.save(on: db)

        guard let id = model.id else {
            throw Abort(.internalServerError, reason: "Failed to generate ID for new approval policy")
        }

        let policy = ApprovalPolicy(
            id: id,
            name: request.name,
            description: request.description,
            template: request.template,
            scope: request.scope,
            projectName: request.projectName,
            pathPatterns: request.pathPatterns,
            defaultAction: request.defaultAction,
            toolRules: request.toolRules,
            confirmationRequiredRiskLevels: request.confirmationRequiredRiskLevels ?? [.high, .critical],
            isEnabled: request.isEnabled,
            priority: request.priority ?? 100,
            createdAt: model.createdAt ?? Date(),
            updatedAt: model.updatedAt ?? Date()
        )

        policiesById[id] = policy
        rebuildSortedCache()
        Self.logger.info("Added approval policy: \(id) name=\(request.name)")
        return policy
    }

    /// Update an existing policy, persisting changes to the database and refreshing the cache.
    ///
    /// Only non-nil fields in the request are applied.
    ///
    /// - Parameters:
    ///   - id: The UUID of the policy to update.
    ///   - request: The update request DTO with optional fields.
    ///   - db: Fluent `Database` handle for persistence.
    /// - Returns: The updated `ApprovalPolicy`, or `nil` if the ID was not found.
    @discardableResult
    func updatePolicy(id: UUID, from request: UpdateApprovalPolicyRequest, db: Database) async throws -> ApprovalPolicy? {
        guard let model = try await ApprovalPolicyModel.find(id, on: db) else {
            Self.logger.warning("Update called for unknown policy: \(id)")
            return nil
        }

        if let name = request.name { model.name = name }
        if let template = request.template { model.templateId = template.rawValue }
        if let defaultAction = request.defaultAction { model.actionType = defaultAction.rawValue }
        if let toolRules = request.toolRules {
            model.toolNames = ApprovalPolicyModel.encodeJSONArray(toolRules.map(\.toolPattern))
        }
        if let pathPatterns = request.pathPatterns {
            model.pathGlobs = ApprovalPolicyModel.encodeJSONArray(pathPatterns)
        }
        if let riskLevels = request.confirmationRequiredRiskLevels {
            model.riskLevels = ApprovalPolicyModel.encodeJSONArray(riskLevels.map(\.rawValue))
        }
        if let projectName = request.projectName { model.projectId = projectName }
        if let isEnabled = request.isEnabled { model.isEnabled = isEnabled }
        if let priority = request.priority { model.priority = priority }

        try await model.save(on: db)

        let updated = Self.toShared(model: model, id: id)
        policiesById[id] = updated
        rebuildSortedCache()
        Self.logger.info("Updated approval policy: \(id)")
        return updated
    }

    /// Delete a policy from the database and remove it from the cache.
    ///
    /// - Parameters:
    ///   - id: The UUID of the policy to delete.
    ///   - db: Fluent `Database` handle for persistence.
    /// - Returns: `true` if the policy was found and deleted, `false` otherwise.
    @discardableResult
    func deletePolicy(id: UUID, db: Database) async throws -> Bool {
        guard let model = try await ApprovalPolicyModel.find(id, on: db) else {
            Self.logger.warning("Delete called for unknown policy: \(id)")
            return false
        }
        try await model.delete(on: db)
        policiesById.removeValue(forKey: id)
        rebuildSortedCache()
        Self.logger.info("Deleted approval policy: \(id)")
        return true
    }

    // MARK: - Query Methods

    /// Return all cached policies sorted by priority (ascending).
    func allPolicies() -> [ApprovalPolicy] {
        sortedPolicies
    }

    /// Return enabled policies matching a specific project, plus global policies.
    ///
    /// Results are sorted by priority (ascending) for deterministic evaluation order.
    ///
    /// - Parameter projectId: The project identifier to filter by, or `nil` for global-only.
    /// - Returns: Matching enabled policies sorted by priority.
    func policiesForProject(_ projectId: String?) -> [ApprovalPolicy] {
        sortedPolicies.filter { policy in
            guard policy.isEnabled else { return false }
            // Global policies apply everywhere
            if policy.scope == .global { return true }
            // Project-scoped policies match by project name
            if let projectId, policy.projectName == projectId { return true }
            // Path-based policies are evaluated per-request (include them for the engine)
            if policy.scope == .pathBased { return true }
            return false
        }
    }

    /// Find a single policy by its ID.
    ///
    /// - Parameter id: The UUID of the policy to find.
    /// - Returns: The matching `ApprovalPolicy`, or `nil` if not found.
    func policy(id: UUID) -> ApprovalPolicy? {
        policiesById[id]
    }

    // MARK: - Built-in Templates

    /// Pre-configured policy templates for common approval strategies.
    ///
    /// These templates define sensible defaults that users can apply with a single tap.
    static let builtInTemplates: [PolicyTemplateResponse] = [
        PolicyTemplateResponse(
            id: "strict",
            name: "Strict",
            description: "Maximum safety: all tool actions require explicit user approval before execution. No actions are auto-approved.",
            template: .strict,
            defaultAction: .alwaysAsk,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Glob", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Grep", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Write", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Edit", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Bash", action: .alwaysAsk),
            ],
            confirmationRequiredRiskLevels: [.low, .medium, .high, .critical]
        ),
        PolicyTemplateResponse(
            id: "balanced",
            name: "Balanced",
            description: "Moderate safety: read-only operations (Read, Glob, Grep) are auto-approved. Write operations and Bash commands require explicit approval.",
            template: .balanced,
            defaultAction: .alwaysAsk,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .autoApprove),
                PolicyToolRule(toolPattern: "Glob", action: .autoApprove),
                PolicyToolRule(toolPattern: "Grep", action: .autoApprove),
                PolicyToolRule(toolPattern: "Write", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Edit", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Bash", action: .alwaysAsk),
            ],
            confirmationRequiredRiskLevels: [.high, .critical]
        ),
        PolicyTemplateResponse(
            id: "permissive",
            name: "Permissive",
            description: "Minimum friction: most actions are auto-approved. Only destructive commands (delete, force-push, rm) and critical-risk Bash commands require confirmation.",
            template: .permissive,
            defaultAction: .autoApprove,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .autoApprove),
                PolicyToolRule(toolPattern: "Glob", action: .autoApprove),
                PolicyToolRule(toolPattern: "Grep", action: .autoApprove),
                PolicyToolRule(toolPattern: "Write", action: .autoApprove),
                PolicyToolRule(toolPattern: "Edit", action: .autoApprove),
                PolicyToolRule(toolPattern: "Bash", action: .requireConfirmation),
            ],
            confirmationRequiredRiskLevels: [.critical]
        ),
    ]

    // MARK: - Private Helpers

    /// Rebuild the sorted cache from the keyed dictionary.
    private func rebuildSortedCache() {
        sortedPolicies = policiesById.values
            .sorted { $0.priority < $1.priority }
    }

    /// Convert a Fluent model to a shared `ApprovalPolicy` value type.
    private static func toShared(model: ApprovalPolicyModel, id: UUID) -> ApprovalPolicy {
        let toolPatterns = model.parsedToolNames
        let toolRules = toolPatterns.map { pattern in
            PolicyToolRule(toolPattern: pattern, action: PolicyAction(rawValue: model.actionType) ?? .alwaysAsk)
        }
        let riskLevels = model.parsedRiskLevels.compactMap { PermissionRiskLevel(rawValue: $0) }

        return ApprovalPolicy(
            id: id,
            name: model.name,
            template: PolicyTemplate(rawValue: model.templateId ?? "custom") ?? .custom,
            scope: model.projectId != nil ? .project : .global,
            projectName: model.projectId,
            pathPatterns: model.parsedPathGlobs.isEmpty ? nil : model.parsedPathGlobs,
            defaultAction: PolicyAction(rawValue: model.actionType) ?? .alwaysAsk,
            toolRules: toolRules,
            confirmationRequiredRiskLevels: riskLevels.isEmpty ? [.high, .critical] : riskLevels,
            isEnabled: model.isEnabled,
            priority: model.priority,
            createdAt: model.createdAt ?? Date(),
            updatedAt: model.updatedAt ?? Date()
        )
    }
}
