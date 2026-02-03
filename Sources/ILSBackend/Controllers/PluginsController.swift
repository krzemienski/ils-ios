import Vapor
import ILSShared

struct PluginsController: RouteCollection {
    let configService = ClaudeConfigService()

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
        let installedPluginsPath = "\(configService.claudeDirectory)/plugins/installed_plugins.json"
        let settingsPath = configService.userSettingsPath

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
        // Read known marketplaces from config
        let config = try? configService.readConfig(scope: "user")
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
        var config = (try? configService.readConfig(scope: "user"))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = true
        config.enabledPlugins = enabled

        _ = try configService.writeConfig(scope: "user", content: config)

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
        var config = (try? configService.readConfig(scope: "user"))?.content ?? ClaudeConfig()
        var enabled = config.enabledPlugins ?? [:]
        enabled[name] = false
        config.enabledPlugins = enabled

        _ = try configService.writeConfig(scope: "user", content: config)

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

        let pluginPath = "\(configService.claudeDirectory)/plugins/\(name)"
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
