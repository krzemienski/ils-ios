import Vapor
import Fluent
import ILSShared
import Foundation

struct ThemesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let themes = routes.grouped("themes")

        themes.get(use: index)
        themes.post(use: create)
        themes.get(":id", use: show)
        themes.put(":id", use: update)
        themes.delete(":id", use: delete)
    }

    /// GET /themes - List all custom themes
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<CustomTheme>> {
        let themes = try await ThemeModel.query(on: req.db)
            .sort(\.$updatedAt, .descending)
            .all()

        let customThemes = themes.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: customThemes)
        )
    }

    /// POST /themes - Create a new custom theme
    @Sendable
    func create(req: Request) async throws -> APIResponse<CustomTheme> {
        let input = try req.content.decode(CreateCustomThemeRequest.self)

        let theme = ThemeModel(
            name: input.name,
            description: input.description,
            author: input.author,
            version: input.version,
            colors: input.colors,
            typography: input.typography,
            spacing: input.spacing,
            cornerRadius: input.cornerRadius,
            shadows: input.shadows
        )

        try await theme.save(on: req.db)

        return APIResponse(
            success: true,
            data: theme.toShared()
        )
    }

    /// GET /themes/:id - Get a single custom theme by ID
    @Sendable
    func show(req: Request) async throws -> APIResponse<CustomTheme> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid theme ID")
        }

        guard let theme = try await ThemeModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Theme not found")
        }

        return APIResponse(
            success: true,
            data: theme.toShared()
        )
    }

    /// PUT /themes/:id - Update an existing custom theme
    @Sendable
    func update(req: Request) async throws -> APIResponse<CustomTheme> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid theme ID")
        }

        guard let theme = try await ThemeModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Theme not found")
        }

        let input = try req.content.decode(UpdateCustomThemeRequest.self)

        // Update only provided fields
        if let name = input.name {
            theme.name = name
        }
        if let description = input.description {
            theme.description = description
        }
        if let author = input.author {
            theme.author = author
        }
        if let version = input.version {
            theme.version = version
        }
        if let colors = input.colors {
            theme.colors = colors
        }
        if let typography = input.typography {
            theme.typography = typography
        }
        if let spacing = input.spacing {
            theme.spacing = spacing
        }
        if let cornerRadius = input.cornerRadius {
            theme.cornerRadius = cornerRadius
        }
        if let shadows = input.shadows {
            theme.shadows = shadows
        }

        try await theme.save(on: req.db)

        return APIResponse(
            success: true,
            data: theme.toShared()
        )
    }

    /// DELETE /themes/:id - Delete a custom theme
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid theme ID")
        }

        guard let theme = try await ThemeModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Theme not found")
        }

        try await theme.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse(deleted: true)
        )
    }
}
