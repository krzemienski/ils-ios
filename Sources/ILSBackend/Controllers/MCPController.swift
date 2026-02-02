import Vapor
import ILSShared

struct MCPController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let mcp = routes.grouped("mcp")

        mcp.get(use: list)
        mcp.post(use: create)
        mcp.delete(":name", use: delete)
    }

    /// GET /mcp - List all MCP servers
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<MCPServer>> {
        var scope: MCPScope?
        if let scopeString = req.query[String.self, at: "scope"] {
            scope = MCPScope(rawValue: scopeString)
        }

        let servers = try fileSystem.readMCPServers(scope: scope)

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
