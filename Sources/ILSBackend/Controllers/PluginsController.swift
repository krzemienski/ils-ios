import Vapor
import ILSShared

/// Controller for Claude Code plugin management operations.
///
/// Manages plugin installation, configuration, and lifecycle from Claude Code marketplaces.
/// Plugins extend Claude with additional commands, agents, and integrations.
///
/// Routes:
/// - `GET /plugins`: List installed plugins
/// - `GET /plugins/search`: Search installed plugins by name/description
/// - `GET /plugins/marketplace`: List available plugin marketplaces
/// - `POST /plugins/marketplaces`: Register a new plugin marketplace
/// - `POST /plugins/install`: Install a plugin via git clone
/// - `GET /plugins/github-search`: Search GitHub for plugin.json repositories
/// - `POST /plugins/:name/enable`: Enable a plugin
/// - `POST /plugins/:name/disable`: Disable a plugin
/// - `DELETE /plugins/:name`: Uninstall a plugin
struct PluginsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let plugins = routes.grouped("plugins")

        plugins.get(use: list)
        plugins.get("search", use: search)
        plugins.get("github-search", use: githubSearch)
        plugins.get("marketplace", use: marketplace)
        plugins.post("marketplaces", use: addMarketplace)
        plugins.post("install", use: install)
        plugins.post(":name", "enable", use: enable)
        plugins.post(":name", "disable", use: disable)
        plugins.delete(":name", use: uninstall)
    }

    /// List all installed plugins.
    ///
    /// Reads from `~/.claude/plugins/installed_plugins.json` and `~/.claude/settings.json`
    /// to build a list of installed plugins with their enabled status, commands, and agents.
    ///
    /// Query parameters:
    /// - `refresh`: If "true", bypasses the file system cache
    /// - `page`: Page number (1-based, default 1)
    /// - `limit`: Items per page (default 50, max 200)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of Plugin objects
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        let bypassCache = req.query[Bool.self, at: "refresh"] ?? false

        let plugins = try await fileSystem.listPlugins(bypassCache: bypassCache)

        // Apply pagination
        let pagination = PaginationParams(from: req)
        let result = pagination.apply(to: plugins)

        return APIResponse(
            success: true,
            data: ListResponse(items: result.items, total: result.pagination.total)
        )
    }

    /// List available plugin marketplaces.
    ///
    /// Returns official marketplaces (e.g., anthropics/claude-code) plus any custom
    /// marketplaces registered via `extraKnownMarketplaces` in user config.
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with array of PluginMarketplace objects
    @Sendable
    func marketplace(req: Request) async throws -> APIResponse<[PluginMarketplace]> {
        // Read known marketplaces from config
        let config = try? fileSystem.readConfig(scope: .user)
        var marketplaces: [PluginMarketplace] = []

        // Add official marketplace
        marketplaces.append(PluginMarketplace(
            name: "claude-plugins-official",
            source: "anthropics/claude-code",
            plugins: [
                PluginInfo(name: "github", description: "GitHub integration"),
                PluginInfo(name: "jira", description: "Jira integration"),
                PluginInfo(name: "linear", description: "Linear integration")
            ]
        ))

        // Add custom marketplaces
        if let extra = config?.content.extraKnownMarketplaces {
            for (name, source) in extra {
                marketplaces.append(PluginMarketplace(
                    name: name,
                    source: source
                ))
            }
        }

        return APIResponse(
            success: true,
            data: marketplaces
        )
    }

    /// Search installed plugins by name or description.
    ///
    /// Query parameters:
    /// - `q`: Search query (required, case-insensitive)
    /// - `refresh`: If "true", bypasses the file system cache
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with filtered list of Plugin objects
    @Sendable
    func search(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Query parameter 'q' is required")
        }

        let bypassCache = req.query[Bool.self, at: "refresh"] ?? false
        let lowercasedQuery = query.lowercased()

        // Get all installed plugins from cache and filter
        let allPlugins = try await fileSystem.listPlugins(bypassCache: bypassCache)
        let filtered = allPlugins.filter { plugin in
            plugin.name.lowercased().contains(lowercasedQuery) ||
            (plugin.description?.lowercased().contains(lowercasedQuery) ?? false)
        }

        return APIResponse(
            success: true,
            data: ListResponse(items: filtered)
        )
    }

    /// Search GitHub for plugin repositories containing plugin.json files.
    ///
    /// Query parameters:
    /// - `q`: Search query (required)
    /// - `page`: Page number (default 1)
    /// - `per_page`: Results per page (default 20)
    ///
    /// - Parameter req: Vapor Request
    /// - Returns: APIResponse with list of GitHubSearchResult objects
    @Sendable
    func githubSearch(req: Request) async throws -> APIResponse<ListResponse<GitHubSearchResult>> {
        guard let query = req.query[String.self, at: "q"], !query.isEmpty else {
            throw Abort(.badRequest, reason: "Query parameter 'q' is required")
        }

        let page = req.query[Int.self, at: "page"] ?? 1
        let perPage = req.query[Int.self, at: "per_page"] ?? 20

        let results = try await req.application.githubService.searchPlugins(query: query, page: page, perPage: perPage)

        return APIResponse(
            success: true,
            data: ListResponse(items: results)
        )
    }

    /// Register a new custom plugin marketplace.
    ///
    /// Adds the marketplace to `extraKnownMarketplaces` in user config.
    ///
    /// - Parameter req: Vapor Request with AddMarketplaceRequest body
    /// - Returns: APIResponse with registered Marketplace
    @Sendable
    func addMarketplace(req: Request) async throws -> APIResponse<Marketplace> {
        let input = try req.content.decode(AddMarketplaceRequest.self)

        // Validate repo format (owner/repo)
        let parts = input.repo.split(separator: "/")
        guard parts.count == 2 else {
            throw Abort(.badRequest, reason: "Repository must be in 'owner/repo' format")
        }

        // Add to config's extraKnownMarketplaces
        var config = (try? fileSystem.readConfig(scope: .user))?.content ?? ClaudeConfig()
        var marketplaces = config.extraKnownMarketplaces ?? [:]
        marketplaces[input.repo] = input.source
        config.extraKnownMarketplaces = marketplaces

        _ = try fileSystem.writeConfig(scope: .user, content: config)

        let marketplace = Marketplace(
            name: String(parts[1]),
            source: input.source,
            repo: input.repo
        )

        return APIResponse(
            success: true,
            data: marketplace
        )
    }

    /// Install a plugin from a GitHub repository via git clone.
    ///
    /// Clones the repository to `~/.claude/plugins/{pluginName}` and updates
    /// `installed_plugins.json` with installation metadata.
    ///
    /// - Parameter req: Vapor Request with InstallPluginRequest body
    /// - Returns: APIResponse with installed Plugin
    @Sendable
    func install(req: Request) async throws -> APIResponse<Plugin> {
        let input = try req.content.decode(InstallPluginRequest.self)
        let fm = FileManager.default

        // Validate plugin name to prevent path traversal
        try PathSanitizer.validateComponent(input.pluginName)
        try PathSanitizer.validateStringLength(input.pluginName, maxLength: 255, fieldName: "pluginName")
        try PathSanitizer.validateStringLength(input.marketplace, maxLength: 500, fieldName: "marketplace")

        let pluginsDir = "\(fileSystem.claudeDirectory)/plugins"
        let targetDir = "\(pluginsDir)/\(input.pluginName)"

        // Ensure plugins directory exists
        try fm.createDirectory(atPath: pluginsDir, withIntermediateDirectories: true)

        // Remove existing if present (retry/update case)
        if fm.fileExists(atPath: targetDir) {
            try fm.removeItem(atPath: targetDir)
        }

        // Build git clone URL from marketplace source
        let repoURL = "https://github.com/\(input.marketplace).git"

        // Run git clone on a background queue to avoid blocking NIO event loop
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = ["clone", "--depth", "1", repoURL, targetDir]

                let errorPipe = Pipe()
                process.standardError = errorPipe
                process.standardOutput = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown git error"
                        continuation.resume(throwing: Abort(.internalServerError, reason: "git clone failed: \(errorMsg)"))
                    } else {
                        continuation.resume()
                    }
                } catch {
                    continuation.resume(throwing: Abort(.internalServerError, reason: "Failed to run git: \(error.localizedDescription)"))
                }
            }
        }

        // Update installed_plugins.json
        let installedPath = "\(pluginsDir)/installed_plugins.json"
        var pluginsJson: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: installedPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            pluginsJson = json
        }

        var pluginsDict = pluginsJson["plugins"] as? [String: Any] ?? [:]
        let pluginKey = "\(input.pluginName)@\(input.marketplace)"
        let now = ISO8601DateFormatter().string(from: Date())
        pluginsDict[pluginKey] = [[
            "installPath": targetDir,
            "version": "1.0.0",
            "installedAt": now,
            "lastUpdated": now
        ]]
        pluginsJson["plugins"] = pluginsDict

        let jsonData = try JSONSerialization.data(withJSONObject: pluginsJson, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: URL(fileURLWithPath: installedPath))

        // Invalidate cache so the new plugin shows up
        await fileSystem.invalidatePluginsCache()

        // Read plugin manifest for description
        var description: String?
        for manifestName in [".claude-plugin/plugin.json", "plugin.json", "package.json"] {
            let path = "\(targetDir)/\(manifestName)"
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                description = manifest["description"] as? String
                break
            }
        }

        let plugin = Plugin(
            name: input.pluginName,
            description: description,
            marketplace: input.marketplace,
            isInstalled: true,
            isEnabled: true,
            version: "1.0.0",
            path: targetDir
        )

        return APIResponse(
            success: true,
            data: plugin
        )
    }

    /// Enable a plugin.
    ///
    /// Sets the plugin's enabled status to true in user config.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with EnabledResponse
    @Sendable
    func enable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        // Update settings
        var config = (try? fileSystem.readConfig(scope: .user))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = true
        config.enabledPlugins = enabled

        _ = try fileSystem.writeConfig(scope: .user, content: config)

        // Invalidate cache so enabled status change is reflected
        await fileSystem.invalidatePluginsCache()

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: true)
        )
    }

    /// Disable a plugin.
    ///
    /// Sets the plugin's enabled status to false in user config.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with EnabledResponse
    @Sendable
    func disable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        // Update settings
        var config = (try? fileSystem.readConfig(scope: .user))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = false
        config.enabledPlugins = enabled

        _ = try fileSystem.writeConfig(scope: .user, content: config)

        // Invalidate cache so enabled status change is reflected
        await fileSystem.invalidatePluginsCache()

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: false)
        )
    }

    /// Uninstall a plugin by removing its directory.
    ///
    /// Removes `~/.claude/plugins/{name}` from the filesystem.
    ///
    /// - Parameter req: Vapor Request with name parameter
    /// - Returns: APIResponse with deletion confirmation
    @Sendable
    func uninstall(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        // Validate name to prevent path traversal
        try PathSanitizer.validateComponent(name)

        let pluginPath = "\(fileSystem.claudeDirectory)/plugins/\(name)"
        let fm = FileManager.default

        if fm.fileExists(atPath: pluginPath) {
            try fm.removeItem(atPath: pluginPath)
        }

        // Invalidate cache so the removed plugin is no longer returned
        await fileSystem.invalidatePluginsCache()

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }
}
