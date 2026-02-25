import Vapor
import Fluent
import ILSShared

/// Controller for session template management operations.
///
/// Routes:
/// - `GET /templates`: List all templates (built-in defaults + user-created DB rows)
/// - `POST /templates`: Create a new user-defined template
/// - `GET /templates/:id`: Get a specific template by ID
/// - `PUT /templates/:id`: Update a user-defined template
/// - `DELETE /templates/:id`: Delete a user-defined template
/// - `POST /templates/bulk-delete`: Bulk-delete templates by ID array
struct TemplatesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let templates = routes.grouped("templates")

        templates.get(use: index)
        templates.post(use: create)
        templates.post("bulk-delete", use: bulkDelete)
        templates.get(":id", use: show)
        templates.put(":id", use: update)
        templates.delete(":id", use: deleteTemplate)
    }

    // MARK: - Helpers

    /// The set of built-in template UUIDs (used to guard mutation/deletion).
    private static let builtInIDs: Set<UUID> = Set(SessionTemplate.defaults.map { $0.id })

    private func isBuiltIn(_ id: UUID) -> Bool {
        Self.builtInIDs.contains(id)
    }

    // MARK: - Routes

    /// List all templates: built-in defaults merged with user DB templates.
    /// Supports `?search=` query parameter for case-insensitive name filtering.
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<SessionTemplate>> {
        let searchTerm = req.query[String.self, at: "search"]?.lowercased()

        // Fetch user templates from DB
        let dbModels = try await TemplateModel.query(on: req.db)
            .sort(\.$createdAt, .ascending)
            .all()

        var all: [SessionTemplate] = SessionTemplate.defaults + dbModels.map { $0.toShared() }

        if let search = searchTerm, !search.isEmpty {
            all = all.filter {
                $0.name.lowercased().contains(search) ||
                $0.description.lowercased().contains(search)
            }
        }

        return APIResponse(success: true, data: ListResponse(items: all))
    }

    /// Get a specific template by ID. Checks built-in templates first, then DB.
    @Sendable
    func show(req: Request) async throws -> APIResponse<SessionTemplate> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        // Check built-in templates first
        if let builtin = SessionTemplate.defaults.first(where: { $0.id == id }) {
            return APIResponse(success: true, data: builtin)
        }

        // Fall back to DB
        guard let template = try await TemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        return APIResponse(success: true, data: template.toShared())
    }

    /// Create a new user-defined template.
    @Sendable
    func create(req: Request) async throws -> APIResponse<SessionTemplate> {
        let input = try req.content.decode(CreateTemplateRequest.self)

        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 2000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.systemPrompt, maxLength: 100_000, fieldName: "systemPrompt")

        let template = TemplateModel(
            name: input.name,
            description: input.description ?? "",
            model: input.model,
            permissionMode: input.permissionMode.rawValue,
            systemPrompt: input.systemPrompt ?? "",
            maxBudgetUSD: input.maxBudgetUSD,
            maxTurns: input.maxTurns,
            isFavorite: input.isFavorite ?? false
        )

        try await template.save(on: req.db)

        return APIResponse(success: true, data: template.toShared())
    }

    /// Update a user-defined template. Returns 403 if the template is built-in.
    @Sendable
    func update(req: Request) async throws -> APIResponse<SessionTemplate> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        if isBuiltIn(id) {
            throw Abort(.forbidden, reason: "Built-in templates cannot be modified")
        }

        guard let template = try await TemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        let input = try req.content.decode(UpdateTemplateRequest.self)

        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 2000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.systemPrompt, maxLength: 100_000, fieldName: "systemPrompt")

        if let name = input.name { template.name = name }
        if let description = input.description { template.description = description }
        if let model = input.model { template.model = model }
        if let permissionMode = input.permissionMode { template.permissionMode = permissionMode.rawValue }
        if let systemPrompt = input.systemPrompt { template.systemPrompt = systemPrompt }
        if let maxBudgetUSD = input.maxBudgetUSD { template.maxBudgetUSD = maxBudgetUSD }
        if let maxTurns = input.maxTurns { template.maxTurns = maxTurns }
        if let isFavorite = input.isFavorite { template.isFavorite = isFavorite }

        try await template.save(on: req.db)

        return APIResponse(success: true, data: template.toShared())
    }

    /// Delete a user-defined template. Returns 403 if the template is built-in.
    @Sendable
    func deleteTemplate(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        if isBuiltIn(id) {
            throw Abort(.forbidden, reason: "Built-in templates cannot be deleted")
        }

        guard let template = try await TemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        try await template.delete(on: req.db)

        return APIResponse(success: true, data: DeletedResponse())
    }

    /// Bulk-delete user-defined templates. Returns 403 if any ID is a built-in template.
    @Sendable
    func bulkDelete(req: Request) async throws -> APIResponse<DeletedResponse> {
        let input = try req.content.decode(BulkDeleteTemplatesRequest.self)

        guard !input.ids.isEmpty else {
            throw Abort(.badRequest, reason: "ids array must not be empty")
        }

        guard input.ids.count <= 100 else {
            throw Abort(.badRequest, reason: "Cannot delete more than 100 templates at once")
        }

        // Reject if any built-in ID is included
        if let builtInID = input.ids.first(where: { isBuiltIn($0) }) {
            throw Abort(.forbidden, reason: "Cannot delete built-in template \(builtInID)")
        }

        try await TemplateModel.query(on: req.db)
            .filter(\.$id ~~ input.ids)
            .delete()

        return APIResponse(success: true, data: DeletedResponse())
    }
}
