import Vapor
import Fluent
import ILSShared

struct StatsController: RouteCollection {
    let fileSystem: FileSystemService

    init(fileSystem: FileSystemService) {
        self.fileSystem = fileSystem
    }

    func boot(routes: RoutesBuilder) throws {
        let stats = routes.grouped("stats")
        stats.get(use: self.stats)
        stats.get("recent", use: recentSessions)

        routes.get("settings", use: settings)

        let server = routes.grouped("server")
        server.get("status", use: serverStatus)
    }

    /// GET /stats - Get overall statistics using same data sources as individual controllers
    @Sendable
    func stats(req: Request) async throws -> APIResponse<StatsResponse> {
        let fm = FileManager.default

        // Count sessions from DATABASE (same as SessionsController)
        let totalSessions = try await SessionModel.query(on: req.db).count()

        // Count projects from FILESYSTEM ~/.claude/projects/ (same as ProjectsController)
        var projectCount = 0
        let homeDir = fm.homeDirectoryForCurrentUser
        let claudeProjectsDir = homeDir.appendingPathComponent(".claude/projects")

        if fm.fileExists(atPath: claudeProjectsDir.path) {
            let projectDirs = try? fm.contentsOfDirectory(
                at: claudeProjectsDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            projectCount = projectDirs?.filter { projectDir in
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    return false
                }
                let sessionsIndexPath = projectDir.appendingPathComponent("sessions-index.json")
                guard fm.fileExists(atPath: sessionsIndexPath.path) else {
                    return false
                }

                // Only count projects with at least one session entry (same as ProjectsController)
                guard let data = try? Data(contentsOf: sessionsIndexPath),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let entries = json["entries"] as? [[String: Any]],
                      !entries.isEmpty else {
                    return false
                }

                return true
            }.count ?? 0
        }

        // Count skills (use cached data for performance)
        let skills = try await fileSystem.listSkills()
        let activeSkills = skills.filter { $0.isActive }.count

        // Count MCP servers (use cached data for performance)
        let mcpServers = try await fileSystem.readMCPServers()
        let healthyServers = mcpServers.filter { $0.status == .healthy }.count

        // Count plugins from FILESYSTEM (same as PluginsController)
        var totalPlugins = 0
        var enabledCount = 0
        let installedPluginsPath = "\(fileSystem.claudeDirectory)/plugins/installed_plugins.json"

        // Read enabled status from settings.json
        let settingsPath = fileSystem.userSettingsPath
        var enabledPlugins: [String: Bool] = [:]
        if fm.fileExists(atPath: settingsPath),
           let settingsData = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let settingsJson = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
           let enabled = settingsJson["enabledPlugins"] as? [String: Bool] {
            enabledPlugins = enabled
        }

        // Read installed plugins
        if fm.fileExists(atPath: installedPluginsPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: installedPluginsPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pluginsDict = json["plugins"] as? [String: Any] {
            totalPlugins = pluginsDict.count

            // Count enabled plugins (default to true if not specified)
            for (pluginKey, _) in pluginsDict {
                let isEnabled = enabledPlugins[pluginKey] ?? true
                if isEnabled {
                    enabledCount += 1
                }
            }
        }

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

    /// GET /stats/recent - Get recent sessions for dashboard timeline
    @Sendable
    func recentSessions(req: Request) async throws -> APIResponse<RecentSessionsResponse> {
        // Query database for the 10 most recently active sessions
        let sessions = try await SessionModel.query(on: req.db)
            .sort(\.$lastActiveAt, .descending)
            .limit(10)
            .all()

        // Convert SessionModel to ChatSession
        let chatSessions = sessions.map { $0.toShared() }

        // Get total count for response
        let totalCount = try await SessionModel.query(on: req.db).count()

        return APIResponse(
            success: true,
            data: RecentSessionsResponse(
                items: chatSessions,
                total: totalCount
            )
        )
    }

    /// GET /server/status - Get remote server connection status
    @Sendable
    func serverStatus(req: Request) async throws -> APIResponse<ServerStatus> {
        let status = try await req.application.sshService.getServerStatus()
        return APIResponse(success: true, data: status)
    }
}
