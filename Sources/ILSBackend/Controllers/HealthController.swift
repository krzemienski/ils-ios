import Vapor
import Fluent

/// Controller for health check endpoints.
///
/// Provides three levels of health checks:
/// - `GET /health` — Detailed health with database status, uptime, version
/// - `GET /health/ready` — Returns 200 only if all dependencies are up
/// - `GET /health/live` — Always returns 200 (k8s liveness probe)
struct HealthController: RouteCollection {
    /// Timestamp when the application started, used for uptime calculation.
    private let startTime: Date

    init(startTime: Date = Date()) {
        self.startTime = startTime
    }

    func boot(routes: RoutesBuilder) throws {
        let health = routes.grouped("health")

        health.get(use: detailed)
        health.get("ready", use: ready)
        health.get("live", use: live)
    }

    /// Detailed health check with database connectivity, uptime, version, and disk space.
    @Sendable
    func detailed(req: Request) async throws -> Response {
        let dbHealthy = await checkDatabase(req: req)
        let fsHealthy = checkFilesystem()
        let uptimeSeconds = Int(Date().timeIntervalSince(startTime))
        let diskInfo = checkDiskSpace()
        let allHealthy = dbHealthy && fsHealthy

        let body = HealthDetail(
            status: allHealthy ? "healthy" : "degraded",
            uptime: uptimeSeconds,
            version: "1.0.0",
            checks: HealthChecks(
                database: dbHealthy ? "ok" : "error",
                filesystem: fsHealthy ? "ok" : "error"
            ),
            disk: diskInfo
        )

        let response = Response(status: allHealthy ? .ok : .serviceUnavailable)
        response.headers.contentType = .json
        try response.content.encode(body)
        return response
    }

    /// Readiness probe — returns 200 only if all dependencies are healthy.
    @Sendable
    func ready(req: Request) async throws -> Response {
        let dbHealthy = await checkDatabase(req: req)
        let fsHealthy = checkFilesystem()

        if dbHealthy && fsHealthy {
            let body = ReadyResponse(status: "ready")
            let response = Response(status: .ok)
            response.headers.contentType = .json
            try response.content.encode(body)
            return response
        } else {
            let body = ReadyResponse(status: "not_ready")
            let response = Response(status: .serviceUnavailable)
            response.headers.contentType = .json
            try response.content.encode(body)
            return response
        }
    }

    /// Liveness probe — always returns 200.
    @Sendable
    func live(req: Request) async throws -> Response {
        let body = LiveResponse(status: "alive")
        let response = Response(status: .ok)
        response.headers.contentType = .json
        try response.content.encode(body)
        return response
    }

    // MARK: - Dependency Checks

    private func checkDatabase(req: Request) async -> Bool {
        do {
            // Simple query to verify database connectivity
            _ = try await SessionModel.query(on: req.db).count()
            return true
        } catch {
            req.logger.error("Health check: database unreachable — \(error.localizedDescription)")
            return false
        }
    }

    private func checkFilesystem() -> Bool {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        return fm.isReadableFile(atPath: homeDir)
    }

    private func checkDiskSpace() -> DiskInfo? {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser
        do {
            let attrs = try fm.attributesOfFileSystem(forPath: homeDir.path)
            let totalBytes = attrs[.systemSize] as? Int64 ?? 0
            let freeBytes = attrs[.systemFreeSize] as? Int64 ?? 0
            let totalGB = Double(totalBytes) / 1_073_741_824
            let freeGB = Double(freeBytes) / 1_073_741_824
            return DiskInfo(
                totalGB: round(totalGB * 10) / 10,
                freeGB: round(freeGB * 10) / 10,
                usedPercent: totalBytes > 0 ? round(Double(totalBytes - freeBytes) / Double(totalBytes) * 1000) / 10 : 0
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Response Types

struct HealthDetail: Content {
    let status: String
    let uptime: Int
    let version: String
    let checks: HealthChecks
    let disk: DiskInfo?
}

struct HealthChecks: Content {
    let database: String
    let filesystem: String
}

struct DiskInfo: Content {
    let totalGB: Double
    let freeGB: Double
    let usedPercent: Double
}

struct ReadyResponse: Content {
    let status: String
}

struct LiveResponse: Content {
    let status: String
}
