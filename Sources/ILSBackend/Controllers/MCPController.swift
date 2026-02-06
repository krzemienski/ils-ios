import Vapor
import ILSShared

struct MCPController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let mcp = routes.grouped("mcp")

        mcp.get(use: list)
        mcp.get(":name", use: show)
        mcp.post(use: create)
        mcp.put(":name", use: update)
        mcp.delete(":name", use: delete)
    }

    /// GET /mcp/:name - Get a single MCP server by name
    /// Query params: ?scope=user|project
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

    /// GET /mcp - List all MCP servers
    /// Query params: ?scope=user|project, ?refresh=true to bypass cache
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

    /// POST /mcp - Add a new MCP server
    @Sendable
    func create(req: Request) async throws -> APIResponse<MCPServer> {
        let input = try req.content.decode(CreateMCPRequest.self)

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

    /// PUT /mcp/:name - Update an existing MCP server
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

    /// DELETE /mcp/:name - Remove an MCP server
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
