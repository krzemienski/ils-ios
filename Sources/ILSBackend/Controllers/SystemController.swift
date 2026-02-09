import Vapor
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
struct SystemController: RouteCollection {
    let metricsService = SystemMetricsService()
    var remoteMetricsService: RemoteMetricsService?
    var sshService: SSHService?

    init(remoteMetricsService: RemoteMetricsService? = nil, sshService: SSHService? = nil) {
        self.remoteMetricsService = remoteMetricsService
        self.sshService = sshService
    }

    func boot(routes: RoutesBuilder) throws {
        let system = routes.grouped("system")

        system.get("metrics", use: self.metrics)
        system.get("processes", use: self.processes)
        system.get("files", use: self.files)
        system.webSocket("metrics", "live", onUpgrade: self.liveMetrics)
        system.get("metrics", "source", use: self.metricsSource)
    }

    // MARK: - REST Endpoints

    /// GET /system/metrics — returns current system metrics.
    @Sendable
    func metrics(req: Request) async throws -> Response {
        let source = req.query[String.self, at: "source"]
        if source == "remote", let remoteService = remoteMetricsService,
           let ssh = sshService, await ssh.isConnected() {
            let remoteMetrics = try await remoteService.getMetrics()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(remoteMetrics)
            return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
        }

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
        let source = req.query[String.self, at: "source"]
        let highlight = req.query[Bool.self, at: "highlight"] ?? false
        if source == "remote", let remoteService = remoteMetricsService,
           let ssh = sshService, await ssh.isConnected() {
            let remoteProcs = try await remoteService.getProcesses(highlight: highlight)
            let encoder = JSONEncoder()
            let data = try encoder.encode(remoteProcs)
            return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
        }

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

    /// WS /system/metrics/live — streams metrics JSON every 2 seconds.
    @Sendable
    func liveMetrics(req: Request, ws: WebSocket) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let service = metricsService
        let cancellation = WebSocketCancellation()

        // Start streaming task
        let streamTask = Task {
            while !Task.isCancelled {
                guard await !cancellation.isCancelled() else { break }

                let stats = await service.getMetrics()

                let response = LiveMetricsMessage(
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    cpu: stats.cpu,
                    memory: LiveMetricsMessage.MemoryInfo(
                        used: stats.memory.used,
                        total: stats.memory.total,
                        percentage: stats.memory.percentage
                    ),
                    disk: LiveMetricsMessage.DiskInfo(
                        used: stats.disk.used,
                        total: stats.disk.total,
                        percentage: stats.disk.percentage
                    ),
                    network: LiveMetricsMessage.NetworkInfo(
                        bytesIn: stats.network.bytesIn,
                        bytesOut: stats.network.bytesOut
                    )
                )

                do {
                    let data = try encoder.encode(response)
                    if let text = String(data: data, encoding: .utf8) {
                        try await ws.send(text)
                    }
                } catch {
                    break
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }

        ws.onClose.whenComplete { _ in
            Task { await cancellation.cancel() }
            streamTask.cancel()
        }
    }

    @Sendable
    func metricsSource(req: Request) async throws -> Response {
        var isRemote = false
        if let ssh = sshService {
            isRemote = await ssh.isConnected()
        }
        let status = isRemote ? await sshService!.getStatus() : nil
        let response = MetricsSourceResponse(
            source: isRemote ? .remote : .local,
            hostName: status?.host
        )
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
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
