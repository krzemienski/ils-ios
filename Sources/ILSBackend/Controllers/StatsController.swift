import Vapor
import Fluent
import ILSShared

struct StatsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        routes.get("stats", use: stats)
        routes.get("settings", use: settings)
    }

    /// GET /stats - Get overall statistics from real Claude config files
    @Sendable
    func stats(req: Request) async throws -> APIResponse<StatsResponse> {
        let fm = FileManager.default

        // Count projects from ~/.claude/projects/
        var projectCount = 0
        var totalSessions = 0
        let projectsPath = fileSystem.claudeProjectsPath
        if fm.fileExists(atPath: projectsPath),
           let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) {
            projectCount = projectDirs.filter { dir in
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: "\(projectsPath)/\(dir)", isDirectory: &isDir) && isDir.boolValue
            }.count

            // Count total sessions across all projects
            for projectDir in projectDirs {
                let sessionsIndexPath = "\(projectsPath)/\(projectDir)/sessions-index.json"
                if let data = try? Data(contentsOf: URL(fileURLWithPath: sessionsIndexPath)),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let entries = json["entries"] as? [[String: Any]] {
                    totalSessions += entries.count
                }
            }
        }

        // Count skills (use cached data for performance)
        let skills = try await fileSystem.listSkills()
        let activeSkills = skills.filter { $0.isActive }.count

        // Count MCP servers (use cached data for performance)
        let mcpServers = try await fileSystem.readMCPServers()
        let healthyServers = mcpServers.filter { $0.status == .healthy }.count

        // Count plugins from installed_plugins.json
        var totalPlugins = 0
        var enabledCount = 0
        let installedPluginsPath = "\(fileSystem.claudeDirectory)/plugins/installed_plugins.json"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: installedPluginsPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let plugins = json["plugins"] as? [String: Any] {
            totalPlugins = plugins.count
        }

        // Get enabled count from settings.json
        let config = try? fileSystem.readConfig(scope: "user")
        let enabledPlugins = config?.content.enabledPlugins ?? [:]
        enabledCount = enabledPlugins.values.filter { $0 }.count

        return APIResponse(
            success: true,
            data: StatsResponse(
                projects: CountStat(total: projectCount),
                sessions: SessionStat(total: totalSessions, active: 0),
                skills: CountStat(total: skills.count, active: activeSkills),
                mcpServers: MCPStat(total: mcpServers.count, healthy: healthyServers),
                plugins: PluginStat(total: totalPlugins, enabled: enabledCount)
            )
        )
    }

    /// GET /settings - Get raw settings from ~/.claude/settings.json
    @Sendable
    func settings(req: Request) async throws -> APIResponse<ClaudeConfig> {
        let config = try fileSystem.readConfig(scope: "user")
        return APIResponse(
            success: true,
            data: config.content
        )
    }
}
