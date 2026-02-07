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

    // Register controllers
    try api.register(collection: ProjectsController())
    try api.register(collection: SessionsController())
    try api.register(collection: ChatController())
    try api.register(collection: SkillsController())
    try api.register(collection: MCPController())
    try api.register(collection: PluginsController())
    try api.register(collection: ConfigController())
    try api.register(collection: StatsController())
    try api.register(collection: AuthController())
    try api.register(collection: SystemController())
    try api.register(collection: TunnelController())
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
