import Vapor

/// Health response returned by GET /health
struct HealthInfo: Content {
    let status: String
    let version: String
    let claudeAvailable: Bool
    let claudeVersion: String?
    let port: Int
}

func routes(_ app: Application) throws {
    // Health check — returns structured JSON for iOS client
    app.get("health") { req -> HealthInfo in
        let claudeVersion = detectClaudeVersion()
        let port = app.http.server.configuration.port
        return HealthInfo(
            status: "ok",
            version: "1.0.0",
            claudeAvailable: claudeVersion != nil,
            claudeVersion: claudeVersion,
            port: port
        )
    }

    // API v1 routes
    let api = app.grouped("api", "v1")

    // Create shared FileSystemService for DI
    let fileSystem = FileSystemService()

    // Register controllers
    try api.register(collection: ProjectsController(fileSystem: fileSystem))
    try api.register(collection: SessionsController(fileSystem: fileSystem))
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController(fileSystem: fileSystem))
    try api.register(collection: MCPController(fileSystem: fileSystem))
    try api.register(collection: PluginsController(fileSystem: fileSystem))
    try api.register(collection: ConfigController(fileSystem: fileSystem))
    try api.register(collection: StatsController(fileSystem: fileSystem))
    try api.register(collection: AuthController())

    // SSH & Remote Management
    let sshService = SSHService(eventLoopGroup: app.eventLoopGroup)
    try api.register(collection: SSHController(sshService: sshService))

    let fleetService = FleetService()
    try api.register(collection: FleetController(fleetService: fleetService))

    let setupService = SetupService(sshService: sshService)
    try api.register(collection: SetupController(setupService: setupService))

    let remoteMetricsService = RemoteMetricsService(sshService: sshService)
    try api.register(collection: SystemController(
        remoteMetricsService: remoteMetricsService,
        sshService: sshService
    ))

    try api.register(collection: TunnelController())

    // Agent Teams
    let teamsFileService = TeamsFileService()
    let teamsExecutorService = TeamsExecutorService()
    try api.register(collection: TeamsController(fileService: teamsFileService, executorService: teamsExecutorService))
}

/// Detect Claude CLI version by running `claude --version`
private func detectClaudeVersion() -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["claude", "--version"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output?.isEmpty == true ? nil : output
    } catch {
        return nil
    }
}
