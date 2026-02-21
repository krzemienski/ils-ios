import Vapor
import Fluent
import ILSShared
import Foundation

/// Controller for custom theme management operations.
///
/// Routes:
/// - `GET /themes`: List all custom themes (paginated)
/// - `POST /themes`: Create a new custom theme
/// - `GET /themes/:id`: Get a single custom theme by ID
/// - `PUT /themes/:id`: Update an existing custom theme
/// - `DELETE /themes/:id`: Delete a custom theme
struct ThemesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let themes = routes.grouped("themes")

        themes.get(use: index)
        themes.post(use: create)
        themes.get(":id", use: show)
        themes.put(":id", use: update)
        themes.delete(":id", use: delete)
    }

    /// List all custom themes, sorted by most recently updated.
    ///
    /// Supports pagination via query parameters:
    /// - `page`: Page number (1-based, default 1)
    /// - `limit`: Items per page (default 50, max 200)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with paginated list of CustomTheme objects
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<CustomTheme>> {
        let themes = try await ThemeModel.query(on: req.db)
            .sort(\.$updatedAt, .descending)
            .all()

        let customThemes = themes.map { $0.toShared() }

        // Apply pagination
        let pagination = PaginationParams(from: req)
        let result = pagination.apply(to: customThemes)

        return APIResponse(
            success: true,
            data: ListResponse(items: result.items, total: result.pagination.total)
        )
    }

    /// Create a new custom theme with the provided colors, typography, and layout properties.
    ///
    /// - Parameter req: Vapor Request with CreateCustomThemeRequest body
    /// - Returns: APIResponse with the newly created CustomTheme
    @Sendable
    func create(req: Request) async throws -> APIResponse<CustomTheme> {
        let input = try req.content.decode(CreateCustomThemeRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.author, maxLength: 255, fieldName: "author")
        try PathSanitizer.validateOptionalStringLength(input.version, maxLength: 64, fieldName: "version")

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

    /// Get a single custom theme by its UUID.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter
    /// - Returns: APIResponse with the matching CustomTheme
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

    /// Update an existing custom theme; only provided fields are changed.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter and UpdateCustomThemeRequest body
    /// - Returns: APIResponse with the updated CustomTheme
    @Sendable
    func update(req: Request) async throws -> APIResponse<CustomTheme> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid theme ID")
        }

        guard let theme = try await ThemeModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Theme not found")
        }

        let input = try req.content.decode(UpdateCustomThemeRequest.self)

        // Validate input lengths
        try PathSanitizer.validateOptionalStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateOptionalStringLength(input.description, maxLength: 1000, fieldName: "description")
        try PathSanitizer.validateOptionalStringLength(input.author, maxLength: 255, fieldName: "author")
        try PathSanitizer.validateOptionalStringLength(input.version, maxLength: 64, fieldName: "version")

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

    /// Delete a custom theme by its UUID.
    ///
    /// - Parameter req: Vapor Request with `id` route parameter
    /// - Returns: APIResponse with DeletedResponse confirming deletion
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
