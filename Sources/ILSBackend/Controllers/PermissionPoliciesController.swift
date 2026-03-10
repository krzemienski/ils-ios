import Vapor
import Fluent
import ILSShared

/// Controller for permission policy rule management operations.
///
/// Routes:
/// - `GET /permission-policies`: List all permission policies with optional filters
/// - `POST /permission-policies`: Create a new permission policy
/// - `GET /permission-policies/evaluate`: Test-evaluate a hypothetical permission request
/// - `POST /permission-policies/reorder`: Reorder policies by updating their priorities
/// - `GET /permission-policies/settings`: Get permission policy settings (default-deny mode)
/// - `PUT /permission-policies/settings`: Update permission policy settings
/// - `GET /permission-policies/:id`: Get a specific permission policy
/// - `PUT /permission-policies/:id`: Update a permission policy
/// - `DELETE /permission-policies/:id`: Delete a permission policy
struct PermissionPoliciesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let policies = routes.grouped("permission-policies")

        policies.get(use: list)
        policies.post(use: create)
        policies.get("evaluate", use: evaluate)
        policies.post("reorder", use: reorder)
        policies.get("settings", use: getSettings)
        policies.put("settings", use: updateSettings)
        policies.get(":id", use: get)
        policies.put(":id", use: update)
        policies.delete(":id", use: deletePolicy)
    }

    /// List all permission policies with optional filters.
    ///
    /// Query parameters:
    /// - `projectId`: Filter to policies for a specific project (UUID)
    /// - `isEnabled`: Filter to enabled/disabled policies (true/false)
    /// - `action`: Filter to policies with a specific action (allow/deny)
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListPermissionPoliciesResponse> {
        let projectId = req.query[UUID.self, at: "projectId"]
        let isEnabled = req.query[Bool.self, at: "isEnabled"]
        let action = req.query[String.self, at: "action"]

        // Build query with filters first, then sorts. Applying filters before sorts
        // avoids a Fluent/SQLite issue where ORDER BY on an optional @Timestamp field
        // without a preceding WHERE clause returns 0 rows.
        let query = PermissionPolicyModel.query(on: req.db)

        if let projectId = projectId {
            query.filter(\.$projectId == projectId)
        }

        if let isEnabled = isEnabled {
            query.filter(\.$isEnabled == isEnabled)
        }

        if let action = action {
            query.filter(\.$action == action)
        }

        let models = try await query
            .sort(\.$priority, .ascending)
            .sort(\.$createdAt, .ascending)
            .all()
        let items = models.map { PermissionPolicyResponse(from: $0.toShared()) }

        return APIResponse(
            success: true,
            data: ListPermissionPoliciesResponse(
                items: items,
                total: items.count
            )
        )
    }

    /// Create a new permission policy.
    /// - Parameter req: Vapor Request with CreatePermissionPolicyRequest body
    /// - Returns: APIResponse with created PermissionPolicyResponse
    @Sendable
    func create(req: Request) async throws -> APIResponse<PermissionPolicyResponse> {
        let input = try req.content.decode(CreatePermissionPolicyRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.toolName, maxLength: 255, fieldName: "toolName")
        try PathSanitizer.validateOptionalStringLength(input.pathGlob, maxLength: 500, fieldName: "pathGlob")
        try PathSanitizer.validateOptionalStringLength(input.commandPrefix, maxLength: 500, fieldName: "commandPrefix")
        try PathSanitizer.validateOptionalStringLength(input.mcpServer, maxLength: 255, fieldName: "mcpServer")
        try PathSanitizer.validateOptionalStringLength(input.note, maxLength: 1000, fieldName: "note")

        let model = PermissionPolicyModel(
            name: input.name,
            toolName: input.toolName,
            pathGlob: input.pathGlob,
            commandPrefix: input.commandPrefix,
            mcpServer: input.mcpServer,
            action: input.action,
            projectId: input.projectId,
            isEnabled: input.isEnabled,
            priority: input.priority,
            note: input.note
        )

        try await model.save(on: req.db)

        let response = PermissionPolicyResponse(from: model.toShared())
        return APIResponse(success: true, data: response)
    }

    /// Get a specific permission policy by ID.
    /// - Parameter req: Vapor Request with :id parameter
    /// - Returns: APIResponse with PermissionPolicyResponse
    @Sendable
    func get(req: Request) async throws -> APIResponse<PermissionPolicyResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid policy ID")
        }

        guard let model = try await PermissionPolicyModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Permission policy not found")
        }

        let response = PermissionPolicyResponse(from: model.toShared())
        return APIResponse(success: true, data: response)
    }

    /// Update an existing permission policy.
    /// - Parameter req: Vapor Request with :id parameter and UpdatePermissionPolicyRequest body
    /// - Returns: APIResponse with updated PermissionPolicyResponse
    @Sendable
    func update(req: Request) async throws -> APIResponse<PermissionPolicyResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid policy ID")
        }

        guard let model = try await PermissionPolicyModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Permission policy not found")
        }

        let input = try req.content.decode(UpdatePermissionPolicyRequest.self)

        if let name = input.name {
            try PathSanitizer.validateOptionalStringLength(name, maxLength: 255, fieldName: "name")
            model.name = name
        }

        if let toolName = input.toolName {
            try PathSanitizer.validateOptionalStringLength(toolName, maxLength: 255, fieldName: "toolName")
            model.toolName = toolName
        }

        if let pathGlob = input.pathGlob {
            try PathSanitizer.validateOptionalStringLength(pathGlob, maxLength: 500, fieldName: "pathGlob")
            model.pathGlob = pathGlob
        }

        if let commandPrefix = input.commandPrefix {
            try PathSanitizer.validateOptionalStringLength(commandPrefix, maxLength: 500, fieldName: "commandPrefix")
            model.commandPrefix = commandPrefix
        }

        if let mcpServer = input.mcpServer {
            try PathSanitizer.validateOptionalStringLength(mcpServer, maxLength: 255, fieldName: "mcpServer")
            model.mcpServer = mcpServer
        }

        if let action = input.action {
            model.action = action.rawValue
        }

        if let isEnabled = input.isEnabled {
            model.isEnabled = isEnabled
        }

        if let priority = input.priority {
            model.priority = priority
        }

        if let note = input.note {
            try PathSanitizer.validateOptionalStringLength(note, maxLength: 1000, fieldName: "note")
            model.note = note
        }

        try await model.save(on: req.db)

        let response = PermissionPolicyResponse(from: model.toShared())
        return APIResponse(success: true, data: response)
    }

    /// Delete a permission policy.
    /// - Parameter req: Vapor Request with :id parameter
    /// - Returns: APIResponse with success message
    @Sendable
    func deletePolicy(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid policy ID")
        }

        guard let model = try await PermissionPolicyModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Permission policy not found")
        }

        try await model.delete(on: req.db)

        return APIResponse(success: true, data: DeletedResponse())
    }

    /// Reorder permission policies by assigning new priorities based on the provided order.
    ///
    /// - Parameter req: Vapor Request with ReorderPermissionPoliciesRequest body
    /// - Returns: APIResponse with updated list of PermissionPolicyResponse
    @Sendable
    func reorder(req: Request) async throws -> APIResponse<ListPermissionPoliciesResponse> {
        let input = try req.content.decode(ReorderPermissionPoliciesRequest.self)

        // Fetch all referenced models in one query
        let models = try await PermissionPolicyModel.query(on: req.db)
            .filter(\.$id ~~ input.orderedIds)
            .all()

        // Build a lookup map for fast access
        let modelMap = Dictionary(uniqueKeysWithValues: models.compactMap { model -> (UUID, PermissionPolicyModel)? in
            guard let id = model.id else { return nil }
            return (id, model)
        })

        // Assign priorities: index 0 = priority 1 (highest), ascending from there
        try await req.db.transaction { db in
            for (index, policyId) in input.orderedIds.enumerated() {
                guard let model = modelMap[policyId] else {
                    throw Abort(.badRequest, reason: "Permission policy not found: \(policyId)")
                }
                model.priority = index + 1
                try await model.save(on: db)
            }
        }

        // Return updated ordered list — sort by priority only; createdAt sort is omitted
        // to avoid a Fluent/SQLite issue with optional @Timestamp ORDER BY without WHERE.
        let updatedModels = try await PermissionPolicyModel.query(on: req.db)
            .sort(\.$priority, .ascending)
            .all()

        let items = updatedModels.map { PermissionPolicyResponse(from: $0.toShared()) }

        return APIResponse(
            success: true,
            data: ListPermissionPoliciesResponse(
                items: items,
                total: items.count
            )
        )
    }

    /// Test-evaluate a hypothetical permission request against the current policy set.
    ///
    /// Query parameters:
    /// - `toolName`: The tool name to test (e.g., "Bash", "Read")
    /// - `path`: A path argument to test against pathGlob policies
    /// - `command`: A command argument to test against commandPrefix policies
    /// - `mcpServer`: An MCP server name to test
    /// - `projectId`: Optional project UUID for scoped evaluation
    ///
    /// Returns the first matching policy and the resulting action, or nil if no policy matches.
    @Sendable
    func evaluate(req: Request) async throws -> APIResponse<PolicyEvaluationResult> {
        let toolName = req.query[String.self, at: "toolName"]
        let path = req.query[String.self, at: "path"]
        let command = req.query[String.self, at: "command"]
        let mcpServer = req.query[String.self, at: "mcpServer"]
        let projectId = req.query[UUID.self, at: "projectId"]

        // Fetch enabled policies ordered by priority
        let models = try await PermissionPolicyModel.query(on: req.db)
            .filter(\.$isEnabled == true)
            .sort(\.$priority, .ascending)
            .sort(\.$createdAt, .ascending)
            .all()

        let policies = models.map { $0.toShared() }

        // Find first matching policy
        let matchedPolicy = policies.first { policy in
            // Scope check: global policies match all; project policies match only their project
            if let policyProjectId = policy.projectId {
                guard policyProjectId == projectId else { return false }
            }

            // Tool name check
            if let policyTool = policy.toolName, let requestTool = toolName {
                guard policyTool.lowercased() == requestTool.lowercased() else { return false }
            } else if policy.toolName != nil && toolName == nil {
                return false
            }

            // Path glob check
            if let glob = policy.pathGlob, let requestPath = path {
                guard matchesGlob(pattern: glob, path: requestPath) else { return false }
            } else if policy.pathGlob != nil && path == nil {
                return false
            }

            // Command prefix check
            if let prefix = policy.commandPrefix, let requestCommand = command {
                guard requestCommand.hasPrefix(prefix) else { return false }
            } else if policy.commandPrefix != nil && command == nil {
                return false
            }

            // MCP server check
            if let policyMCP = policy.mcpServer, let requestMCP = mcpServer {
                guard policyMCP == requestMCP else { return false }
            } else if policy.mcpServer != nil && mcpServer == nil {
                return false
            }

            return true
        }

        let result = PolicyEvaluationResult(
            matched: matchedPolicy != nil,
            action: matchedPolicy.map { $0.action.rawValue },
            matchedPolicy: matchedPolicy.map { PermissionPolicyResponse(from: $0) }
        )

        return APIResponse(success: true, data: result)
    }

    // MARK: - Settings

    /// Get permission policy settings for a given scope.
    ///
    /// Query parameters:
    /// - `projectId`: Optional project UUID; omit for global settings.
    ///
    /// If no settings record exists for the requested scope a default record
    /// (defaultDeny = false) is returned without persisting it.
    @Sendable
    func getSettings(req: Request) async throws -> APIResponse<PermissionPolicySettingsResponse> {
        let projectId = req.query[UUID.self, at: "projectId"]

        let model = try await findOrDefaultSettings(projectId: projectId, db: req.db)
        let response = PermissionPolicySettingsResponse(from: model.toShared())
        return APIResponse(success: true, data: response)
    }

    /// Update permission policy settings for a given scope.
    ///
    /// Query parameters:
    /// - `projectId`: Optional project UUID; omit for global settings.
    ///
    /// Body: ``UpdatePermissionPolicySettingsRequest``
    ///
    /// If no settings record exists for the scope one is created (upsert).
    @Sendable
    func updateSettings(req: Request) async throws -> APIResponse<PermissionPolicySettingsResponse> {
        let projectId = req.query[UUID.self, at: "projectId"]
        let input = try req.content.decode(UpdatePermissionPolicySettingsRequest.self)

        // Fetch existing or build a new model for this scope
        var query = PermissionPolicySettingsModel.query(on: req.db)
        if let projectId = projectId {
            query = query.filter(\.$projectId == projectId)
        } else {
            query = query.filter(\.$projectId == nil)
        }

        let existing = try await query.first()
        let model: PermissionPolicySettingsModel

        if let existing = existing {
            model = existing
        } else {
            model = PermissionPolicySettingsModel(projectId: projectId)
        }

        if let defaultDeny = input.defaultDeny {
            model.defaultDeny = defaultDeny
        }

        try await model.save(on: req.db)

        let response = PermissionPolicySettingsResponse(from: model.toShared())
        return APIResponse(success: true, data: response)
    }

    // MARK: - Private Helpers

    /// Fetch the settings model for the given scope, returning an unsaved default when absent.
    private func findOrDefaultSettings(projectId: UUID?, db: Database) async throws -> PermissionPolicySettingsModel {
        var query = PermissionPolicySettingsModel.query(on: db)
        if let projectId = projectId {
            query = query.filter(\.$projectId == projectId)
        } else {
            query = query.filter(\.$projectId == nil)
        }

        if let existing = try await query.first() {
            return existing
        }

        // Return a transient default — caller decides whether to persist it.
        return PermissionPolicySettingsModel(projectId: projectId, defaultDeny: false)
    }


    /// Simple glob pattern matcher supporting `*` (any chars within path segment) and `**` (any chars including `/`).
    private func matchesGlob(pattern: String, path: String) -> Bool {
        return globMatch(pattern: pattern[pattern.startIndex...], path: path[path.startIndex...])
    }

    private func globMatch(pattern: Substring, path: Substring) -> Bool {
        var p = pattern
        var s = path

        while !p.isEmpty {
            if p.hasPrefix("**") {
                let rest = p.dropFirst(2)
                // Try matching rest at every position in s
                var idx = s.startIndex
                while true {
                    if globMatch(pattern: rest, path: s[idx...]) { return true }
                    if idx == s.endIndex { break }
                    s.formIndex(after: &idx)
                }
                return false
            } else if p.first == "*" {
                let rest = p.dropFirst()
                // Match zero or more non-'/' chars
                var idx = s.startIndex
                while true {
                    if globMatch(pattern: rest, path: s[idx...]) { return true }
                    if idx == s.endIndex || s[idx] == "/" { break }
                    s.formIndex(after: &idx)
                }
                return false
            } else if p.first == "?" {
                guard !s.isEmpty, s.first != "/" else { return false }
                p = p.dropFirst()
                s = s.dropFirst()
            } else {
                guard !s.isEmpty, p.first == s.first else { return false }
                p = p.dropFirst()
                s = s.dropFirst()
            }
        }

        return s.isEmpty
    }
}

// MARK: - Policy Evaluation Result

/// Result of evaluating a hypothetical permission request against the policy set.
struct PolicyEvaluationResult: Content {
    /// Whether any enabled policy matched the request.
    let matched: Bool
    /// The action the matching policy would apply: "allow" or "deny". Nil if no match.
    let action: String?
    /// The full matched policy, or nil if no policy matched.
    let matchedPolicy: PermissionPolicyResponse?
}
