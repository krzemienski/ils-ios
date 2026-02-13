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

        // Count sessions from DATABASE + external (unified count, deduped)
        let dbModels = try await SessionModel.query(on: req.db).all()
        let dbSessionCount = dbModels.count
        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions()
        let dbClaudeIdSet = Set(dbModels.compactMap(\.claudeSessionId))
        let uniqueExternalCount = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIdSet.contains(claudeId)
        }.count
        let totalSessions = dbSessionCount + uniqueExternalCount

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

    /// GET /stats/recent - Get recent sessions for dashboard timeline (DB + external merged)
    @Sendable
    func recentSessions(req: Request) async throws -> APIResponse<RecentSessionsResponse> {
        // Load DB sessions
        let dbSessions = try await SessionModel.query(on: req.db)
            .with(\.$project)
            .all()
        var merged: [ChatSession] = dbSessions.map { $0.toShared(projectName: $0.project?.name) }

        // Load external sessions and dedup
        let externalSessions = try await fileSystem.listExternalSessionsAsChatSessions()
        let dbClaudeIds = Set(dbSessions.compactMap(\.claudeSessionId))
        let uniqueExternal = externalSessions.filter { ext in
            guard let claudeId = ext.claudeSessionId else { return true }
            return !dbClaudeIds.contains(claudeId)
        }
        merged.append(contentsOf: uniqueExternal)

        // Sort by lastActiveAt descending, take top 10
        merged.sort { $0.lastActiveAt > $1.lastActiveAt }
        let recent = Array(merged.prefix(10))

        return APIResponse(
            success: true,
            data: RecentSessionsResponse(
                items: recent,
                total: merged.count
            )
        )
    }

    /// GET /server/status - Get local server connection status
    @Sendable
    func serverStatus(req: Request) async throws -> APIResponse<ServerStatus> {
        // Local server is always connected
        return APIResponse(success: true, data: ServerStatus(connected: true))
    }
}
