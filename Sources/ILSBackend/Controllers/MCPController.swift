import Vapor
import ILSShared

/// Controller for MCP (Model Context Protocol) server management.
///
/// Manages MCP server configurations across user, project, and local scopes.
/// MCP servers extend Claude with custom tools and integrations.
///
/// Routes:
/// - `GET /mcp`: List MCP servers (all scopes or filtered by scope)
/// - `GET /mcp/:name`: Get a specific MCP server by name
/// - `POST /mcp`: Create a new MCP server configuration
/// - `PUT /mcp/:name`: Update an existing MCP server
/// - `DELETE /mcp/:name`: Remove an MCP server configuration
struct MCPController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let mcp = routes.grouped("mcp")

        mcp.get(use: list)
        mcp.get(":name", use: show)
        mcp.post(use: create)
        mcp.put(":name", use: update)
        mcp.delete(":name", use: delete)
    }

    /// Get a specific MCP server by name.
    ///
    /// Query parameters:
    /// - `scope`: Filter by configuration scope (user, project, or local)
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with MCPServer
    /// - Throws: Abort(.notFound) if server doesn't exist
    @Sendable
    func show(req: Request) async throws -> APIResponse<MCPServer> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        var scope: MCPScope?
        if let scopeString = req.query[String.self, at: "scope"] {
            scope = MCPScope(rawValue: scopeString)
        }

        let servers = try await fileSystem.readMCPServers(scope: scope, bypassCache: false)

        guard let server = servers.first(where: { $0.name == name }) else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

        return APIResponse(
            success: true,
            data: server
        )
    }

    /// List all MCP servers from configuration files.
    ///
    /// Query parameters:
    /// - `scope`: Filter by configuration scope (user, project, or local)
    /// - `refresh`: If "true", bypasses the cache and reads from disk
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of MCPServer objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<MCPServer>> {
        var scope: MCPScope?
        if let scopeString = req.query[String.self, at: "scope"] {
            scope = MCPScope(rawValue: scopeString)
        }
        let bypassCache = req.query[Bool.self, at: "refresh"] ?? false

        let servers = try await fileSystem.readMCPServers(scope: scope, bypassCache: bypassCache)

        return APIResponse(
            success: true,
            data: ListResponse(items: servers)
        )
    }

    /// Create a new MCP server configuration.
    ///
    /// Adds the server to the specified scope's configuration file.
    ///
    /// - Parameter req: Vapor Request with CreateMCPRequest body
    /// - Returns: APIResponse with created MCPServer
    @Sendable
    func create(req: Request) async throws -> APIResponse<MCPServer> {
        let input = try req.content.decode(CreateMCPRequest.self)

        // Validate input lengths
        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateStringLength(input.command, maxLength: 1000, fieldName: "command")

        let server = MCPServer(
            name: input.name,
            command: input.command,
            args: input.args ?? [],
            env: input.env,
            scope: input.scope ?? .user
        )

        try fileSystem.addMCPServer(server)

        return APIResponse(
            success: true,
            data: server
        )
    }

    /// Update an existing MCP server configuration.
    ///
    /// Removes the old configuration and adds the updated one.
    ///
    /// - Parameter req: Vapor Request with name parameter and CreateMCPRequest body
    /// - Returns: APIResponse with updated MCPServer
    @Sendable
    func update(req: Request) async throws -> APIResponse<MCPServer> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        let input = try req.content.decode(CreateMCPRequest.self)

        // Remove old entry then add updated one
        let scope = input.scope ?? .user
        try? fileSystem.removeMCPServer(name: name, scope: scope)

        let server = MCPServer(
            name: input.name,
            command: input.command,
            args: input.args ?? [],
            env: input.env,
            scope: scope
        )

        try fileSystem.addMCPServer(server)

        // Invalidate cache
        await fileSystem.invalidateMCPServersCache()

        return APIResponse(
            success: true,
            data: server
        )
    }

    /// Remove an MCP server configuration.
    ///
    /// Query parameters:
    /// - `scope`: Configuration scope to remove from (default: user)
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        let scopeString = req.query[String.self, at: "scope"] ?? "user"
        let scope = MCPScope(rawValue: scopeString) ?? .user

        try fileSystem.removeMCPServer(name: name, scope: scope)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }
}
