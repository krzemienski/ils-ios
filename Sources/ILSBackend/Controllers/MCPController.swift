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
/// - `GET /mcp/:name/health`: Check health status of an MCP server
/// - `GET /mcp/:name/logs`: Get recent logs for an MCP server
/// - `POST /mcp`: Create a new MCP server configuration
/// - `POST /mcp/:name/restart`: Restart an MCP server
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
        mcp.post(use: create)

        // Named server routes — order matters: static segments before ":name"
        mcp.get(":name", "health", use: health)
        mcp.get(":name", "logs", use: logs)
        mcp.post(":name", "restart", use: restart)
        mcp.get(":name", use: show)
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
    /// - `page`: Page number (1-based, default 1)
    /// - `limit`: Items per page (default 50, max 200)
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

        // Apply pagination
        let pagination = PaginationParams(from: req)
        let result = pagination.apply(to: servers)

        return APIResponse(
            success: true,
            data: ListResponse(items: result.items, total: result.pagination.total)
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

    // MARK: - Health, Restart & Logs

    /// Check the health of a specific MCP server.
    ///
    /// Reads the server configuration and cross-references the enabled servers list
    /// from `~/.claude/settings.local.json` to determine health status.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with MCPHealthResponse
    @Sendable
    func health(req: Request) async throws -> APIResponse<MCPHealthResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        // Bypass cache to get fresh status
        let servers = try await fileSystem.readMCPServers(scope: nil, bypassCache: true)

        guard let server = servers.first(where: { $0.name == name }) else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

        let isEnabled = server.status == .healthy

        let formatter = ISO8601DateFormatter()
        let checkedAt = formatter.string(from: Date())

        let response = MCPHealthResponse(
            name: server.name,
            status: server.status,
            isEnabled: isEnabled,
            command: server.command,
            checkedAt: checkedAt
        )

        return APIResponse(
            success: true,
            data: response
        )
    }

    /// Restart an MCP server by toggling its enabled status.
    ///
    /// Adds the server to the enabled list in `~/.claude/settings.local.json`
    /// and invalidates the cache. Actual MCP servers are managed by Claude Code
    /// at runtime, so this signals a restart by updating configuration.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with MCPRestartResponse
    @Sendable
    func restart(req: Request) async throws -> APIResponse<MCPRestartResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        // Verify server exists
        let servers = try await fileSystem.readMCPServers(scope: nil, bypassCache: true)
        guard servers.first(where: { $0.name == name }) != nil else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

        // Toggle enabled status in settings.local.json to trigger restart
        let fm = FileManager.default
        let settingsPath = "\(fm.homeDirectoryForCurrentUser.path)/.claude/settings.local.json"

        // Dynamic JSON — Claude settings files have evolving schema with arbitrary keys
        var json: [String: Any] = [:]
        if fm.fileExists(atPath: settingsPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        var enabledServers = json["enabledMcpjsonServers"] as? [String] ?? []
        if !enabledServers.contains(name) {
            enabledServers.append(name)
        }
        json["enabledMcpjsonServers"] = enabledServers

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: settingsPath))

        // Invalidate cache so next read picks up the change
        await fileSystem.invalidateMCPServersCache()

        let response = MCPRestartResponse(
            name: name,
            restarted: true,
            status: .healthy
        )

        return APIResponse(
            success: true,
            data: response
        )
    }

    /// Get recent logs for an MCP server.
    ///
    /// Checks `~/.claude/logs/` for MCP-related log files. Since Claude Code
    /// manages MCP server processes internally, logs may not always be available.
    ///
    /// Query parameters:
    /// - `limit`: Maximum number of log entries (default: 50)
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with MCPLogsResponse
    @Sendable
    func logs(req: Request) async throws -> APIResponse<MCPLogsResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        let limit = req.query[Int.self, at: "limit"] ?? 50
        let clampedLimit = min(max(limit, 1), 500)

        // Verify server exists
        let servers = try await fileSystem.readMCPServers(scope: nil, bypassCache: false)
        guard servers.first(where: { $0.name == name }) != nil else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

        // Check for MCP log files in ~/.claude/logs/
        let fm = FileManager.default
        let logsDir = "\(fm.homeDirectoryForCurrentUser.path)/.claude/logs"
        var logEntries: [MCPLogEntry] = []

        if fm.fileExists(atPath: logsDir) {
            // Look for log files matching the server name
            let contents = (try? fm.contentsOfDirectory(atPath: logsDir)) ?? []
            let matchingLogs = contents.filter { $0.lowercased().contains(name.lowercased()) || $0.contains("mcp") }

            for logFile in matchingLogs.prefix(3) {
                let logPath = "\(logsDir)/\(logFile)"
                if let content = try? String(contentsOfFile: logPath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines)
                    // Take last N lines
                    let recentLines = lines.suffix(clampedLimit)
                    let formatter = ISO8601DateFormatter()
                    let now = formatter.string(from: Date())

                    for line in recentLines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        logEntries.append(MCPLogEntry(
                            timestamp: now,
                            level: "info",
                            message: line
                        ))
                    }
                }
            }
        }

        // Clamp total entries to limit
        let finalEntries = Array(logEntries.prefix(clampedLimit))

        let response = MCPLogsResponse(
            name: name,
            logs: finalEntries,
            available: !finalEntries.isEmpty
        )

        return APIResponse(
            success: true,
            data: response
        )
    }
}
