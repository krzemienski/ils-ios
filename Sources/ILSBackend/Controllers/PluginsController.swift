import Vapor
import ILSShared

struct PluginsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        let plugins = routes.grouped("plugins")

        plugins.get(use: list)
        plugins.get("marketplace", use: marketplace)
        plugins.post("install", use: install)
        plugins.post(":name", "enable", use: enable)
        plugins.post(":name", "disable", use: disable)
        plugins.delete(":name", use: uninstall)
    }

    /// GET /plugins - List installed plugins
    /// Reads from ~/.claude/plugins/installed_plugins.json and ~/.claude/settings.json
    @Sendable
    func list(req: Request) async throws -> APIResponse<ListResponse<Plugin>> {
        let fm = FileManager.default
        let installedPluginsPath = "\(fileSystem.claudeDirectory)/plugins/installed_plugins.json"
        let settingsPath = fileSystem.userSettingsPath

        var plugins: [Plugin] = []

        // Read enabled status from settings.json
        var enabledPlugins: [String: Bool] = [:]
        if fm.fileExists(atPath: settingsPath),
           let settingsData = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let settingsJson = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
           let enabled = settingsJson["enabledPlugins"] as? [String: Bool] {
            enabledPlugins = enabled
        }

        // Read installed plugins from installed_plugins.json
        guard fm.fileExists(atPath: installedPluginsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: installedPluginsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pluginsDict = json["plugins"] as? [String: Any] else {
            return APIResponse(
                success: true,
                data: ListResponse(items: plugins)
            )
        }

        // Parse each plugin entry
        for (pluginKey, value) in pluginsDict {
            // pluginKey format: "plugin-name@marketplace"
            guard let installsArray = value as? [[String: Any]],
                  let latestInstall = installsArray.first else {
                continue
            }

            // Parse plugin key to get name and marketplace
            let parts = pluginKey.split(separator: "@", maxSplits: 1)
            let pluginName = String(parts.first ?? Substring(pluginKey))
            let marketplace = parts.count > 1 ? String(parts[1]) : nil

            // Extract install info
            let installPath = latestInstall["installPath"] as? String
            let version = latestInstall["version"] as? String
            // Note: installedAt and lastUpdated available but not currently used
            _ = latestInstall["installedAt"] as? String
            _ = latestInstall["lastUpdated"] as? String

            // Check enabled status (default to true if not specified)
            let isEnabled = enabledPlugins[pluginKey] ?? true

            // Try to read plugin manifest for description, commands, agents
            var description: String?
            var commands: [String] = []
            var agents: [String] = []

            if let path = installPath {
                // Try to read plugin.json or manifest
                let manifestPath = "\(path)/.claude-plugin/plugin.json"
                let altManifestPath = "\(path)/plugin.json"

                if let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
                   let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] {
                    description = manifest["description"] as? String
                } else if let manifestData = try? Data(contentsOf: URL(fileURLWithPath: altManifestPath)),
                          let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] {
                    description = manifest["description"] as? String
                }

                // Check for commands directory
                let commandsPath = "\(path)/commands"
                if let cmdContents = try? fm.contentsOfDirectory(atPath: commandsPath) {
                    commands = cmdContents.filter { $0.hasSuffix(".md") }
                        .map { "/\(pluginName):\($0.replacingOccurrences(of: ".md", with: ""))" }
                }

                // Check for agents directory
                let agentsPath = "\(path)/agents"
                if let agentContents = try? fm.contentsOfDirectory(atPath: agentsPath) {
                    agents = agentContents.filter { $0.hasSuffix(".md") }
                        .map { $0.replacingOccurrences(of: ".md", with: "") }
                }
            }

            plugins.append(Plugin(
                name: pluginName,
                description: description,
                marketplace: marketplace,
                isInstalled: true,
                isEnabled: isEnabled,
                version: version,
                commands: commands.isEmpty ? nil : commands,
                agents: agents.isEmpty ? nil : agents,
                path: installPath
            ))
        }

        // Sort by name for consistent ordering
        plugins.sort { $0.name.lowercased() < $1.name.lowercased() }

        return APIResponse(
            success: true,
            data: ListResponse(items: plugins)
        )
    }

    /// GET /plugins/marketplace - List available plugins from marketplaces
    @Sendable
    func marketplace(req: Request) async throws -> APIResponse<[PluginMarketplace]> {
        // Extract query parameters
        let searchQuery = req.query[String.self, at: "search"]?.lowercased()
        let tagFilter = req.query[String.self, at: "tag"]?.lowercased()

        // Read known marketplaces from config
        let config = try? fileSystem.readConfig(scope: "user")
        var marketplaces: [PluginMarketplace] = []

        // Add official marketplace with richer plugin data
        var officialPlugins = [
            PluginInfo(
                name: "github",
                description: "GitHub integration for managing issues, PRs, and repositories",
                author: "Anthropic",
                installCount: 1250,
                rating: 4.8,
                reviewCount: 89,
                tags: ["version-control", "collaboration", "popular"],
                version: "1.2.0",
                screenshots: [
                    "https://example.com/screenshots/github-1.png",
                    "https://example.com/screenshots/github-2.png"
                ]
            ),
            PluginInfo(
                name: "jira",
                description: "Jira integration for project management and issue tracking",
                author: "Anthropic",
                installCount: 890,
                rating: 4.5,
                reviewCount: 67,
                tags: ["project-management", "collaboration"],
                version: "1.1.5",
                screenshots: [
                    "https://example.com/screenshots/jira-1.png"
                ]
            ),
            PluginInfo(
                name: "linear",
                description: "Linear integration for streamlined issue tracking and project management",
                author: "Anthropic",
                installCount: 645,
                rating: 4.7,
                reviewCount: 52,
                tags: ["project-management", "issue-tracking"],
                version: "1.0.8",
                screenshots: [
                    "https://example.com/screenshots/linear-1.png",
                    "https://example.com/screenshots/linear-2.png"
                ]
            )
        ]

        // Apply filters
        officialPlugins = filterPlugins(officialPlugins, search: searchQuery, tag: tagFilter)

        marketplaces.append(PluginMarketplace(
            name: "claude-plugins-official",
            source: "anthropics/claude-code",
            plugins: officialPlugins
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

    /// Helper function to filter plugins based on search and tag parameters
    private func filterPlugins(_ plugins: [PluginInfo], search: String?, tag: String?) -> [PluginInfo] {
        var filtered = plugins

        // Apply search filter (matches name or description)
        if let searchQuery = search, !searchQuery.isEmpty {
            filtered = filtered.filter { plugin in
                plugin.name.lowercased().contains(searchQuery) ||
                (plugin.description?.lowercased().contains(searchQuery) ?? false)
            }
        }

        // Apply tag filter
        if let tagQuery = tag, !tagQuery.isEmpty {
            filtered = filtered.filter { plugin in
                plugin.tags?.contains { $0.lowercased() == tagQuery } ?? false
            }
        }

        return filtered
    }

    /// POST /plugins/install - Install a plugin
    @Sendable
    func install(req: Request) async throws -> APIResponse<Plugin> {
        let input = try req.content.decode(InstallPluginRequest.self)

        // In a real implementation, this would clone from the marketplace
        // For now, return a placeholder
        let plugin = Plugin(
            name: input.pluginName,
            marketplace: input.marketplace,
            isInstalled: true,
            isEnabled: true
        )

        return APIResponse(
            success: true,
            data: plugin
        )
    }

    /// POST /plugins/:name/enable - Enable a plugin
    @Sendable
    func enable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        // Update settings
        var config = (try? fileSystem.readConfig(scope: "user"))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = true
        config.enabledPlugins = enabled

        _ = try fileSystem.writeConfig(scope: "user", content: config)

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: true)
        )
    }

    /// POST /plugins/:name/disable - Disable a plugin
    @Sendable
    func disable(req: Request) async throws -> APIResponse<EnabledResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        // Update settings
        var config = (try? fileSystem.readConfig(scope: "user"))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = false
        config.enabledPlugins = enabled

        _ = try fileSystem.writeConfig(scope: "user", content: config)

        return APIResponse(
            success: true,
            data: EnabledResponse(enabled: false)
        )
    }

    /// DELETE /plugins/:name - Uninstall a plugin
    @Sendable
    func uninstall(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let name = req.parameters.get("name") else {
            throw Abort(.badRequest, reason: "Invalid plugin name")
        }

        let pluginPath = "\(fileSystem.claudeDirectory)/plugins/\(name)"
        let fm = FileManager.default

        if fm.fileExists(atPath: pluginPath) {
            try fm.removeItem(atPath: pluginPath)
        }

        return APIResponse(
            success: true,
            data: DeletedResponse()
        )
    }
}
