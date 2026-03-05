import Vapor
import ILSShared

/// Controller for MCP (Model Context Protocol) server management.
///
/// Manages MCP server configurations across user, project, and local scopes.
/// MCP servers extend Claude with custom tools and integrations.
///
/// Routes:
/// - `GET /mcp`: List MCP servers (all scopes or filtered by scope)
/// - `GET /mcp/search`: Search GitHub for MCP server repositories
/// - `GET /mcp/marketplace`: Browse curated marketplace of popular MCP servers
/// - `GET /mcp/:name`: Get a specific MCP server by name
/// - `GET /mcp/:name/health`: Check health status of an MCP server
/// - `GET /mcp/:name/logs`: Get recent logs for an MCP server
/// - `GET /mcp/presets`: List preset MCP server configurations
/// - `POST /mcp`: Create a new MCP server configuration
/// - `POST /mcp/validate`: Validate an MCP server configuration before applying
/// - `POST /mcp/:name/enable`: Enable an MCP server
/// - `POST /mcp/:name/disable`: Disable an MCP server
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

        // Static routes — must come before ":name" to avoid capture
        mcp.get("search", use: search)
        mcp.get("marketplace", use: marketplace)
        mcp.get("presets", use: presets)
        mcp.post("validate", use: validate)

        // Named server routes — order matters: static segments before ":name"
        mcp.get(":name", "health", use: health)
        mcp.get(":name", "logs", use: logs)
        mcp.post(":name", "enable", use: enable)
        mcp.post(":name", "disable", use: disable)
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

    // MARK: - Marketplace & Search

    /// Search GitHub for MCP server repositories.
    ///
    /// Query parameters:
    /// - `q`: Search query (required)
    /// - `page`: Page number (default 1)
    /// - `per_page`: Results per page (default 20)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of GitHubSearchResult objects
    @Sendable
    func search(req: Request) async throws -> APIResponse<ListResponse<GitHubSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Query parameter 'q' is required")
        }

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per_page"] ?? 20

        let results: [GitHubSearchResult]
        do {
            results = try await req.application.githubService.searchMCPServers(query: query, page: page, perPage: perPage)
        } catch {
            req.logger.warning("GitHub MCP search failed: \(error)")
            results = []
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: results)
        )
    }

    /// Return a curated list of popular MCP servers from the marketplace.
    ///
    /// Returns hardcoded Staff Picks and Popular entries covering the most widely
    /// used MCP servers in the community ecosystem.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of MCPMarketplaceEntry objects
    @Sendable
    func marketplace(req: Request) async throws -> APIResponse<ListResponse<MCPMarketplaceEntry>> {
        let entries: [MCPMarketplaceEntry] = [
            // MARK: Staff Picks
            MCPMarketplaceEntry(
                name: "filesystem",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", "/"],
                requiredEnvVars: [],
                category: "Staff Picks",
                stars: 28000,
                isStaffPick: true,
                isTrending: false,
                tags: ["files", "filesystem", "official"],
                description: "Read, write, and manage files on your local filesystem. Perfect for working with codebases and documents."
            ),
            MCPMarketplaceEntry(
                name: "brave-search",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-brave-search"],
                requiredEnvVars: [
                    MCPEnvVarSpec(key: "BRAVE_API_KEY", description: "Brave Search API key", isRequired: true, placeholder: "BSA...")
                ],
                category: "Staff Picks",
                stars: 28000,
                isStaffPick: true,
                isTrending: true,
                tags: ["search", "web", "official"],
                description: "Web search powered by Brave Search API. Get real-time search results directly in Claude."
            ),
            MCPMarketplaceEntry(
                name: "github",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                requiredEnvVars: [
                    MCPEnvVarSpec(key: "GITHUB_PERSONAL_ACCESS_TOKEN", description: "GitHub Personal Access Token", isRequired: true, placeholder: "ghp_...")
                ],
                category: "Staff Picks",
                stars: 28000,
                isStaffPick: true,
                isTrending: true,
                tags: ["github", "git", "official"],
                description: "Interact with GitHub repositories, issues, pull requests, and code directly from Claude."
            ),
            // MARK: Popular
            MCPMarketplaceEntry(
                name: "postgres",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-postgres"],
                requiredEnvVars: [
                    MCPEnvVarSpec(key: "POSTGRES_CONNECTION_STRING", description: "PostgreSQL connection string", isRequired: true, placeholder: "postgresql://user:pass@localhost/db")
                ],
                category: "Popular",
                stars: 28000,
                isStaffPick: false,
                isTrending: false,
                tags: ["database", "postgres", "sql", "official"],
                description: "Query and manage PostgreSQL databases. Run SQL, explore schemas, and interact with your data."
            ),
            MCPMarketplaceEntry(
                name: "puppeteer",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-puppeteer"],
                requiredEnvVars: [],
                category: "Popular",
                stars: 28000,
                isStaffPick: false,
                isTrending: true,
                tags: ["browser", "automation", "web", "official"],
                description: "Browser automation with Puppeteer. Navigate websites, take screenshots, and interact with web pages."
            ),
            MCPMarketplaceEntry(
                name: "slack",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-slack"],
                requiredEnvVars: [
                    MCPEnvVarSpec(key: "SLACK_BOT_TOKEN", description: "Slack Bot OAuth token", isRequired: true, placeholder: "xoxb-..."),
                    MCPEnvVarSpec(key: "SLACK_TEAM_ID", description: "Slack workspace team ID", isRequired: true, placeholder: "T...")
                ],
                category: "Popular",
                stars: 28000,
                isStaffPick: false,
                isTrending: false,
                tags: ["slack", "messaging", "team", "official"],
                description: "Read and send messages in Slack. List channels, search conversations, and manage your workspace."
            ),
            MCPMarketplaceEntry(
                name: "fetch",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-fetch"],
                requiredEnvVars: [],
                category: "Popular",
                stars: 28000,
                isStaffPick: false,
                isTrending: false,
                tags: ["http", "fetch", "web", "official"],
                description: "Make HTTP requests to any URL. Fetch web pages, call APIs, and retrieve remote content."
            ),
            MCPMarketplaceEntry(
                name: "sequential-thinking",
                repository: "modelcontextprotocol/servers",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-sequential-thinking"],
                requiredEnvVars: [],
                category: "Popular",
                stars: 28000,
                isStaffPick: false,
                isTrending: true,
                tags: ["reasoning", "thinking", "official"],
                description: "Enables dynamic and reflective problem-solving through sequential thought chains."
            ),
        ]

        return APIResponse(
            success: true,
            data: ListResponse(items: entries)
        )
    }

    // MARK: - Enable & Disable

    /// Enable an MCP server by adding it to the enabled list.
    ///
    /// Adds the server name to `enabledMcpjsonServers` in
    /// `~/.claude/settings.local.json`, creating the directory and file
    /// if they do not already exist.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with EnabledResponse (enabled: true)
    @Sendable
    func enable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        // Verify server exists
        let servers = try await fileSystem.readMCPServers(scope: nil, bypassCache: true)
        guard servers.first(where: { $0.name == name }) != nil else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

        let fm = FileManager.default
        let claudeDir = "\(fm.homeDirectoryForCurrentUser.path)/.claude"
        let settingsPath = "\(claudeDir)/settings.local.json"

        // Create ~/.claude/ directory if it doesn't exist (only on enable)
        if !fm.fileExists(atPath: claudeDir) {
            try fm.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
        }

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

        await fileSystem.invalidateMCPServersCache()

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: true)
        )
    }

    /// Disable an MCP server by removing it from the enabled list.
    ///
    /// Removes the server name from `enabledMcpjsonServers` in
    /// `~/.claude/settings.local.json`. Does nothing if the file
    /// does not exist (server was already disabled).
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with EnabledResponse (enabled: false)
    @Sendable
    func disable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid MCP server name")
        }

        // Verify server exists
        let servers = try await fileSystem.readMCPServers(scope: nil, bypassCache: true)
        guard servers.first(where: { $0.name == name }) != nil else {
            throw Abort(.notFound, reason: "MCP server '\(name)' not found")
        }

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
        enabledServers.removeAll { $0 == name }
        json["enabledMcpjsonServers"] = enabledServers

        if fm.fileExists(atPath: settingsPath) {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))
        }

        await fileSystem.invalidateMCPServersCache()

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: false)
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

        let isEnabled = server.isEnabled

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
        if fm.fileExists(atPath: settingsPath) {
            let data: Data
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
            } catch {
                throw Abort(.internalServerError, reason: "Failed to read settings file: \(error.localizedDescription)")
            }
            guard let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Abort(.unprocessableEntity, reason: "Settings file contains invalid JSON")
            }
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

            let isoFormatter = ISO8601DateFormatter()
            let isoFormatterFrac: ISO8601DateFormatter = {
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return f
            }()

            for logFile in matchingLogs.prefix(3) {
                let logPath = "\(logsDir)/\(logFile)"
                if let content = try? String(contentsOfFile: logPath, encoding: .utf8) {
                    let lines = content.components(separatedBy: .newlines)
                    // Take last N lines
                    let recentLines = lines.suffix(clampedLimit)

                    for line in recentLines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Attempt to parse a leading ISO8601 timestamp from the log line.
                        // Common formats: "2026-02-22T10:30:00Z INFO ..." or "[2026-02-22T10:30:00Z] ..."
                        var timestamp = isoFormatter.string(from: Date()) // fallback: now
                        var message = line
                        var level = "info"

                        // Strip optional leading bracket
                        let stripped = line.hasPrefix("[") ? String(line.dropFirst()) : line
                        let parts = stripped.components(separatedBy: .whitespaces)

                        if let first = parts.first {
                            let candidate = first.hasSuffix("]") ? String(first.dropLast()) : first
                            if let parsedDate = isoFormatterFrac.date(from: candidate) ?? isoFormatter.date(from: candidate) {
                                timestamp = isoFormatter.string(from: parsedDate)
                                // Reconstruct message without the leading timestamp token
                                let remaining = parts.dropFirst().joined(separator: " ")
                                message = remaining.isEmpty ? line : remaining
                            }
                        }

                        // Detect log level keyword in message
                        let msgLower = message.lowercased()
                        if msgLower.hasPrefix("error") || msgLower.contains("[error]") {
                            level = "error"
                        } else if msgLower.hasPrefix("warn") || msgLower.contains("[warn]") {
                            level = "warn"
                        } else if msgLower.hasPrefix("debug") || msgLower.contains("[debug]") {
                            level = "debug"
                        }

                        logEntries.append(MCPLogEntry(
                            timestamp: timestamp,
                            level: level,
                            message: message
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

    // MARK: - Validate & Presets

    /// Validate an MCP server configuration before applying it.
    ///
    /// Checks the configuration for errors (blocking) and warnings (non-blocking)
    /// without persisting anything. Useful for pre-flight checks in the UI.
    ///
    /// - Parameter req: Vapor Request with CreateMCPRequest body
    /// - Returns: APIResponse with MCPValidationResult
    @Sendable
    func validate(req: Request) async throws -> APIResponse<MCPValidationResult> {
        let input = try req.content.decode(CreateMCPRequest.self)

        var errors: [String] = []
        var warnings: [String] = []

        // --- Blocking errors ---

        if input.name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Name must not be empty.")
        } else if input.name.count > 255 {
            errors.append("Name must not exceed 255 characters.")
        }

        if input.command.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Command must not be empty.")
        } else if input.command.count > 1000 {
            errors.append("Command must not exceed 1,000 characters.")
        }

        // Check for duplicate name in the target scope
        if errors.isEmpty {
            let targetScope = input.scope
            let existingServers = (try? await fileSystem.readMCPServers(scope: targetScope, bypassCache: true)) ?? []
            if existingServers.contains(where: { $0.name == input.name }) {
                let scopeLabel = targetScope?.rawValue ?? "any scope"
                errors.append("An MCP server named '\(input.name)' already exists in \(scopeLabel).")
            }
        }

        // --- Non-blocking warnings ---

        let knownCommands = ["npx", "node", "python3", "python", "uvx", "deno", "bun"]
        let commandBase = input.command.components(separatedBy: .whitespaces).first ?? input.command
        if !knownCommands.contains(commandBase) {
            warnings.append("'\(commandBase)' is not a commonly used MCP launcher. Verify it is installed and on PATH.")
        }

        if let env = input.env, env.values.contains(where: { $0.isEmpty }) {
            warnings.append("One or more environment variable values are empty. Fill them in before activating the server.")
        }

        let isValid = errors.isEmpty

        return APIResponse(
            success: true,
            data: MCPValidationResult(isValid: isValid, errors: errors, warnings: warnings)
        )
    }

    /// Return a curated list of preset MCP server configurations.
    ///
    /// Presets are template configurations for popular MCP servers that users
    /// can apply with one click. The list is static and updated with each release.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with MCPPresetListResponse
    @Sendable
    func presets(req: Request) async throws -> APIResponse<MCPPresetListResponse> {
        let presets: [MCPPreset] = [
            MCPPreset(
                name: "Filesystem",
                description: "Read and write files on the local filesystem. Pass allowed directories as arguments.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/dir"],
                scope: .user,
                category: .filesystem
            ),
            MCPPreset(
                name: "GitHub",
                description: "Access GitHub repositories, issues, pull requests, and code search.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-github"],
                env: ["GITHUB_PERSONAL_ACCESS_TOKEN": ""],
                scope: .user,
                category: .developer
            ),
            MCPPreset(
                name: "PostgreSQL",
                description: "Connect to a PostgreSQL database and run read-only queries.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
                scope: .project,
                category: .database
            ),
            MCPPreset(
                name: "SQLite",
                description: "Query a local SQLite database file.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", "/path/to/database.db"],
                scope: .project,
                category: .database
            ),
            MCPPreset(
                name: "Brave Search",
                description: "Web search powered by the Brave Search API.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-brave-search"],
                env: ["BRAVE_API_KEY": ""],
                scope: .user,
                category: .web
            ),
            MCPPreset(
                name: "Fetch",
                description: "Fetch web pages and convert them to Markdown for Claude to read.",
                command: "uvx",
                args: ["mcp-server-fetch"],
                scope: .user,
                category: .web
            ),
            MCPPreset(
                name: "Puppeteer",
                description: "Control a headless Chromium browser for screenshots and automation.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-puppeteer"],
                scope: .user,
                category: .web
            ),
            MCPPreset(
                name: "Memory",
                description: "Persistent in-memory key-value store across Claude conversations.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-memory"],
                scope: .user,
                category: .utility
            ),
            MCPPreset(
                name: "Slack",
                description: "Read and send messages in Slack workspaces.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-slack"],
                env: ["SLACK_BOT_TOKEN": "", "SLACK_TEAM_ID": ""],
                scope: .user,
                category: .communication
            ),
            MCPPreset(
                name: "Sequential Thinking",
                description: "Breaks complex tasks into sequential reasoning steps.",
                command: "npx",
                args: ["-y", "@modelcontextprotocol/server-sequential-thinking"],
                scope: .user,
                category: .utility
            ),
        ]

        return APIResponse(
            success: true,
            data: MCPPresetListResponse(presets: presets)
        )
    }
}
