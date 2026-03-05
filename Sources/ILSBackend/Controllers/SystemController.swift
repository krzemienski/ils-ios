import Vapor
import Fluent
import ILSShared

/// Actor for safe WebSocket cancellation signaling across concurrency boundaries.
actor WebSocketCancellation {
    private var cancelled = false
    func cancel() { cancelled = true }
    func isCancelled() -> Bool { cancelled }
}

/// Controller for system monitoring endpoints.
///
/// Routes:
/// - `GET /system/metrics` — current CPU, memory, disk, network stats
/// - `GET /system/processes` — running processes with optional sort
/// - `GET /system/files` — directory listing restricted to home
/// - `WS  /system/metrics/live` — live metrics stream every 2 seconds
/// - `GET /system/version/current` — current Claude Code CLI version
/// - `GET /system/version/history` — version history records
struct SystemController: RouteCollection {
    let metricsService = SystemMetricsService()

    func boot(routes: RoutesBuilder) throws {
        let system = routes.grouped("system")

        system.get("metrics", use: self.metrics)
        system.get("processes", use: self.processes)
        system.get("files", use: self.files)
        system.webSocket("metrics", "live", onUpgrade: self.liveMetrics)
        system.get("metrics", "source", use: self.metricsSource)

        system.get("version", "current", use: self.currentVersion)
        system.get("version", "history", use: self.versionHistory)
    }

    // MARK: - REST Endpoints

    /// GET /system/metrics — returns current system metrics.
    @Sendable
    func metrics(req: Request) async throws -> Response {
        let stats = await metricsService.getMetrics()

        let response = SystemMetricsResponse(
            cpu: stats.cpu,
            memory: SystemMetricsResponse.MemoryInfo(
                used: stats.memory.used,
                total: stats.memory.total,
                percentage: stats.memory.percentage
            ),
            disk: SystemMetricsResponse.DiskInfo(
                used: stats.disk.used,
                total: stats.disk.total,
                percentage: stats.disk.percentage
            ),
            network: SystemMetricsResponse.NetworkInfo(
                bytesIn: stats.network.bytesIn,
                bytesOut: stats.network.bytesOut
            ),
            loadAverage: stats.loadAverage
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(response)

        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }

    /// GET /system/processes — returns running processes, optionally sorted.
    @Sendable
    func processes(req: Request) async throws -> Response {
        let sortBy = req.query[String.self, at: "sort"] ?? "cpu"
        var procs = await metricsService.getProcesses()

        switch sortBy {
        case "memory":
            procs.sort { $0.memoryMB > $1.memoryMB }
        default:
            procs.sort { $0.cpuPercent > $1.cpuPercent }
        }

        let items = procs.map { p in
            ProcessInfoResponse(
                name: p.name,
                pid: p.pid,
                cpuPercent: p.cpuPercent,
                memoryMB: p.memoryMB
            )
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(items)

        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }

    /// GET /system/files?path= — returns directory listing, restricted to home.
    @Sendable
    func files(req: Request) async throws -> Response {
        guard let path = req.query[String.self, at: "path"] else {
            throw Abort(.badRequest, reason: "Missing 'path' query parameter")
        }

        guard let entries = await metricsService.listDirectory(path: path) else {
            throw Abort(.forbidden, reason: "Access denied: path is outside home directory")
        }

        let items = entries.map { entry in
            FileEntryResponse(
                name: entry.name,
                isDirectory: entry.isDirectory,
                size: entry.size,
                modifiedDate: entry.modifiedDate
            )
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)

        return Response(
            status: .ok,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }

    // MARK: - WebSocket

    /// WS /system/metrics/live — streams metrics JSON at a configurable interval.
    /// Accepts optional `?interval=N` query parameter (seconds, clamped to 2–60). Default: 5s.
    @Sendable
    func liveMetrics(req: Request, ws: WebSocket) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // ENRG-CRIT: Default 5s (was 2s). Client can request faster via ?interval=N.
        let requestedInterval = Double(req.query[String.self, at: "interval"] ?? "5") ?? 5
        let pushInterval = min(max(requestedInterval, 2), 60)  // Clamp to 2–60s

        let service = metricsService
        let cancellation = WebSocketCancellation()

        // Start streaming task
        let streamTask = Task {
            while !Task.isCancelled {
                guard await !cancellation.isCancelled() else { break }

                let stats = await service.getMetrics()

                let response = SystemMetricsResponse(
                    cpu: stats.cpu,
                    memory: SystemMetricsResponse.MemoryInfo(
                        used: stats.memory.used,
                        total: stats.memory.total,
                        percentage: stats.memory.percentage
                    ),
                    disk: SystemMetricsResponse.DiskInfo(
                        used: stats.disk.used,
                        total: stats.disk.total,
                        percentage: stats.disk.percentage
                    ),
                    network: SystemMetricsResponse.NetworkInfo(
                        bytesIn: stats.network.bytesIn,
                        bytesOut: stats.network.bytesOut
                    ),
                    loadAverage: stats.loadAverage
                )

                do {
                    let data = try encoder.encode(response)
                    if let text = String(data: data, encoding: .utf8) {
                        try await ws.send(text)
                    }
                } catch {
                    break
                }

                try? await Task.sleep(nanoseconds: UInt64(pushInterval * 1_000_000_000))
            }
        }

        ws.onClose.whenComplete { _ in
            Task { await cancellation.cancel() }
            streamTask.cancel()
        }
    }

    @Sendable
    func metricsSource(req: Request) async throws -> Response {
        let response = MetricsSourceResponse(
            source: .local,
            hostName: nil
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    // MARK: - Version Endpoints

    /// GET /system/version/current — returns the most recent version record.
    @Sendable
    func currentVersion(req: Request) async throws -> APIResponse<CurrentVersionResponse> {
        guard let latest = try await VersionHistoryModel.query(on: req.db)
            .sort(\.$detectedAt, .descending)
            .first() else {
            throw Abort(.notFound, reason: "No version history found")
        }

        let response = CurrentVersionResponse(
            version: latest.version,
            installMethod: latest.installMethod,
            binaryPath: nil,
            detectedAt: latest.detectedAt ?? Date()
        )

        return APIResponse(success: true, data: response)
    }

    /// GET /system/version/history — returns all version records ordered by detection date.
    @Sendable
    func versionHistory(req: Request) async throws -> APIResponse<VersionHistoryResponse> {
        let records = try await VersionHistoryModel.query(on: req.db)
            .sort(\.$detectedAt, .descending)
            .all()

        let entries = records.map { $0.toShared() }

        let response = VersionHistoryResponse(
            entries: entries,
            totalCount: entries.count
        )

        return APIResponse(success: true, data: response)
    }
}

// MARK: - Live Metrics WebSocket Message

/// JSON message sent over WebSocket for live metrics streaming.
private struct LiveMetricsMessage: Codable, Sendable {
    let timestamp: String
    let cpu: Double
    let memory: MemoryInfo
    let disk: DiskInfo
    let network: NetworkInfo

    struct MemoryInfo: Codable, Sendable {
        let used: UInt64
        let total: UInt64
        let percentage: Double
    }

    struct DiskInfo: Codable, Sendable {
        let used: UInt64
        let total: UInt64
        let percentage: Double
    }

    struct NetworkInfo: Codable, Sendable {
        let bytesIn: UInt64
        let bytesOut: UInt64
    }
}

// MARK: - Vapor Content Conformance for Shared DTOs

extension SystemMetricsResponse: Content {}
extension ProcessInfoResponse: Content {}
extension FileEntryResponse: Content {}
extension CurrentVersionResponse: Content {}
extension VersionHistoryResponse: Content {}
