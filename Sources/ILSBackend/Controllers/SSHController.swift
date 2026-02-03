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

        // SSH-specific operations
        ssh.post("test", use: testConnection)
        ssh.post(":id", "execute", use: executeCommand)
        ssh.get(":id", "claude-version", use: detectClaudeVersion)
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

    // MARK: - SSH Operations

    /// POST /ssh/test - Test SSH connection with credentials
    @Sendable
    func testConnection(req: Request) async throws -> APIResponse<TestConnectionResponse> {
        // Define request structure with credential field
        struct TestConnectionRequestWithCredential: Codable {
            let host: String
            let port: Int
            let username: String
            let authType: SSHAuthType
            let credential: String
        }

        let input = try req.content.decode(TestConnectionRequestWithCredential.self)

        let sshService = SSHService()
        let success = try await sshService.testConnection(
            host: input.host,
            port: input.port,
            username: input.username,
            authType: input.authType,
            credential: input.credential
        )

        return APIResponse(
            success: true,
            data: TestConnectionResponse(success: success)
        )
    }

    /// POST /ssh/:id/execute - Execute remote command on SSH server
    @Sendable
    func executeCommand(req: Request) async throws -> APIResponse<ExecuteRemoteCommandResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid server ID")
        }

        // Define request structure with credential field
        struct ExecuteCommandRequestWithCredential: Codable {
            let command: String
            let credential: String
        }

        let input = try req.content.decode(ExecuteCommandRequestWithCredential.self)

        let sshService = SSHService()
        do {
            let (output, exitCode) = try await sshService.executeCommand(
                serverId: id,
                credential: input.credential,
                command: input.command,
                on: req.db
            )

            return APIResponse(
                success: true,
                data: ExecuteRemoteCommandResponse(
                    output: output,
                    exitCode: exitCode,
                    error: nil
                )
            )
        } catch {
            return APIResponse(
                success: false,
                data: ExecuteRemoteCommandResponse(
                    output: "",
                    exitCode: -1,
                    error: error.localizedDescription
                )
            )
        }
    }

    /// GET /ssh/:id/claude-version - Detect Claude Code CLI version on remote server
    @Sendable
    func detectClaudeVersion(req: Request) async throws -> APIResponse<ClaudeVersionResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid server ID")
        }

        // Credential needs to be passed as query parameter or header for GET request
        // For security, we'll require it in the Authorization header or as a query param
        guard let credential = req.headers.first(name: "X-SSH-Credential") else {
            throw Abort(.badRequest, reason: "Missing X-SSH-Credential header")
        }

        let sshService = SSHService()
        let version = try await sshService.detectClaudeCode(
            serverId: id,
            credential: credential,
            on: req.db
        )

        return APIResponse(
            success: true,
            data: ClaudeVersionResponse(
                version: version,
                installed: version != nil
            )
        )
    }
}

// MARK: - Response Types

struct TestConnectionResponse: Content, Sendable {
    let success: Bool
}

struct ClaudeVersionResponse: Content, Sendable {
    let version: String?
    let installed: Bool
}
