import Vapor
import Fluent
import ILSShared

struct TemplatesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let templates = routes.grouped("templates")

        templates.get(use: list)
        templates.post(use: create)
        templates.get(":id", use: get)
        templates.put(":id", use: update)
        templates.delete(":id", use: delete)
        templates.post(":id", "favorite", use: toggleFavorite)
    }

    /// GET /templates - List all templates with optional search
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<SessionTemplate>> {
        var query = SessionTemplateModel.query(on: req.db)

        // Optional search filter
        if let search = req.query[String.self, at: "search"] {
            query = query.group(.or) { group in
                group.filter(\.$name, .custom("ILIKE"), "%\(search)%")
            }
        }

        // Optional favorite filter
        if let isFavorite = req.query[Bool.self, at: "isFavorite"] {
            query = query.filter(\.$isFavorite == isFavorite)
        }

        let templates = try await query
            .sort(\.$isDefault, .descending)
            .sort(\.$isFavorite, .descending)
            .sort(\.$updatedAt, .descending)
            .all()

        let items = templates.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: items)
        )
    }

    /// POST /templates - Create a new template
    @Sendable
    func create(req: Request) async throws -> APIResponse<SessionTemplate> {
        let input = try req.content.decode(CreateTemplateRequest.self)

        let template = SessionTemplateModel(
            name: input.name,
            description: input.description,
            initialPrompt: input.initialPrompt,
            model: input.model ?? "sonnet",
            permissionMode: input.permissionMode ?? .default,
            isFavorite: false,
            isDefault: false,
            tags: input.tags ?? []
        )

        try await template.save(on: req.db)

        return APIResponse(
            success: true,
            data: template.toShared()
        )
    }

    /// GET /templates/:id - Get a single template
    @Sendable
    func get(req: Request) async throws -> APIResponse<SessionTemplate> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        guard let template = try await SessionTemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        return APIResponse(
            success: true,
            data: template.toShared()
        )
    }

    /// PUT /templates/:id - Update a template
    @Sendable
    func update(req: Request) async throws -> APIResponse<SessionTemplate> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        guard let template = try await SessionTemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        // Prevent editing default templates
        if template.isDefault {
            throw Abort(.forbidden, reason: "Cannot edit default templates")
        }

        let input = try req.content.decode(UpdateTemplateRequest.self)

        if let name = input.name {
            template.name = name
        }
        if let description = input.description {
            template.description = description
        }
        if let initialPrompt = input.initialPrompt {
            template.initialPrompt = initialPrompt
        }
        if let model = input.model {
            template.model = model
        }
        if let permissionMode = input.permissionMode {
            template.permissionMode = permissionMode.rawValue
        }
        if let tags = input.tags {
            template.tags = tags
        }
        if let isFavorite = input.isFavorite {
            template.isFavorite = isFavorite
        }

        try await template.save(on: req.db)

        return APIResponse(
            success: true,
            data: template.toShared()
        )
    }

    /// DELETE /templates/:id - Delete a template
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        guard let template = try await SessionTemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        // Prevent deleting default templates
        if template.isDefault {
            throw Abort(.forbidden, reason: "Cannot delete default templates")
        }

        try await template.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }

    /// POST /templates/:id/favorite - Toggle favorite status
    @Sendable
    func toggleFavorite(req: Request) async throws -> APIResponse<SessionTemplate> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid template ID")
        }

        guard let template = try await SessionTemplateModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Template not found")
        }

        template.isFavorite = !template.isFavorite
        try await template.save(on: req.db)

        return APIResponse(
            success: true,
            data: template.toShared()
        )
    }
}
