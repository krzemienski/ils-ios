import Vapor
import Fluent
import ILSShared
import Foundation

struct SSHController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let ssh = routes.grouped("ssh")

        ssh.get(use: index)
        ssh.post(use: create)
        ssh.get(":id", use: show)
        ssh.put(":id", use: update)
        ssh.delete(":id", use: delete)
    }

    /// GET /ssh - List all SSH servers
    @Sendable
    func index(req: Request) async throws -> APIResponse<ListResponse<SSHServer>> {
        let servers = try await SSHServerModel.query(on: req.db)
            .sort(\.$lastConnectedAt, .descending)
            .sort(\.$createdAt, .descending)
            .all()

        let sharedServers = servers.map { $0.toShared() }

        return APIResponse(
            success: true,
            data: ListResponse(items: sharedServers)
        )
    }

    /// POST /ssh - Create a new SSH server
    @Sendable
    func create(req: Request) async throws -> APIResponse<SSHServer> {
        let input = try req.content.decode(CreateSSHServerRequest.self)

        // Check if server with same host/username already exists
        if let existing = try await SSHServerModel.query(on: req.db)
            .filter(\.$host == input.host)
            .filter(\.$username == input.username)
            .filter(\.$port == input.port)
            .first() {
            // Return existing server instead of error
            return APIResponse(
                success: true,
                data: existing.toShared()
            )
        }

        let server = SSHServerModel(
            name: input.name,
            host: input.host,
            port: input.port,
            username: input.username,
            authType: input.authType,
            description: input.description
        )

        try await server.save(on: req.db)

        return APIResponse(
            success: true,
            data: server.toShared()
        )
    }

    /// GET /ssh/:id - Get a single SSH server by ID
    @Sendable
    func show(req: Request) async throws -> APIResponse<SSHServer> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid server ID")
        }

        guard let server = try await SSHServerModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "SSH server not found")
        }

        return APIResponse(
            success: true,
            data: server.toShared()
        )
    }

    /// PUT /ssh/:id - Update an existing SSH server
    @Sendable
    func update(req: Request) async throws -> APIResponse<SSHServer> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid server ID")
        }

        guard let server = try await SSHServerModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "SSH server not found")
        }

        let input = try req.content.decode(UpdateSSHServerRequest.self)

        // Update only provided fields
        if let name = input.name {
            server.name = name
        }
        if let host = input.host {
            server.host = host
        }
        if let port = input.port {
            server.port = port
        }
        if let username = input.username {
            server.username = username
        }
        if let authType = input.authType {
            server.authType = authType.rawValue
        }
        if let description = input.description {
            server.description = description
        }

        try await server.save(on: req.db)

        return APIResponse(
            success: true,
            data: server.toShared()
        )
    }

    /// DELETE /ssh/:id - Delete an SSH server
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid server ID")
        }

        guard let server = try await SSHServerModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "SSH server not found")
        }

        try await server.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }
}
