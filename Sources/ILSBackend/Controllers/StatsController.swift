import Vapor
import Fluent
import ILSShared

struct StatsController: RouteCollection {
    let fileSystem = FileSystemService()

    func boot(routes: RoutesBuilder) throws {
        routes.get("stats", use: stats)
    }

    /// GET /stats - Get overall statistics
    @Sendable
    func stats(req: Request) async throws -> APIResponse<StatsResponse> {
        // Count projects
        let projectCount = try await ProjectModel.query(on: req.db).count()

        // Count sessions
        let totalSessions = try await SessionModel.query(on: req.db).count()
        let activeSessions = try await SessionModel.query(on: req.db)
            .filter(\.$status == "active")
            .count()

        // Count skills
        let skills = try fileSystem.listSkills()
        let activeSkills = skills.filter { $0.isActive }.count

        // Count MCP servers
        let mcpServers = try fileSystem.readMCPServers()
        let healthyServers = mcpServers.filter { $0.status == .healthy }.count

        // Count plugins
        let config = try? fileSystem.readConfig(scope: "user")
        let enabledPlugins = config?.content.enabledPlugins ?? [:]
        let totalPlugins = enabledPlugins.count
        let enabledCount = enabledPlugins.values.filter { $0 }.count

        return APIResponse(
            success: true,
            data: StatsResponse(
                projects: CountStat(total: projectCount),
                sessions: SessionStat(total: totalSessions, active: activeSessions),
                skills: CountStat(total: skills.count, active: activeSkills),
                mcpServers: MCPStat(total: mcpServers.count, healthy: healthyServers),
                plugins: PluginStat(total: totalPlugins, enabled: enabledCount)
            )
        )
    }
}
