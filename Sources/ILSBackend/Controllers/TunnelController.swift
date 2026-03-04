import Vapor
import ILSShared

/// Controller for Cloudflare tunnel management endpoints.
///
/// Routes (all under `/api/v1/tunnel`):
/// - `POST /tunnel/start` — start a quick tunnel, returns public URL
/// - `POST /tunnel/stop` — stop the running tunnel
/// - `GET  /tunnel/status` — current tunnel status (includes connectionState)
/// - `GET  /tunnel/health` — tunnel health metrics (latency, uptime, etc.)
/// - `GET  /tunnel/logs` — recent tunnel log entries (optional `limit` query param)
struct TunnelController: RouteCollection {
    let tunnelService = TunnelService()

    func boot(routes: RoutesBuilder) throws {
        let tunnel = routes.grouped("tunnel")

        tunnel.post("start", use: self.startTunnel)
        tunnel.post("stop", use: self.stopTunnel)
        tunnel.get("status", use: self.getStatus)
        tunnel.get("health", use: self.getHealth)
        tunnel.get("logs", use: self.getLogs)
    }

    // MARK: - Endpoints

    /// POST /tunnel/start — start a Cloudflare tunnel (quick or named).
    /// If token + tunnelName + domain are all provided, starts a named tunnel.
    /// Otherwise starts a quick tunnel with a random trycloudflare.com URL.
    @Sendable
    func startTunnel(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        let body = try? req.content.decode(TunnelStartRequest.self)
        let port = 9999 // Default backend port

        do {
            let url: String
            if let token = body?.token, !token.isEmpty,
               let tunnelName = body?.tunnelName, !tunnelName.isEmpty,
               let domain = body?.domain, !domain.isEmpty {
                url = try await tunnelService.startNamed(
                    token: token, tunnelName: tunnelName,
                    domain: domain, port: port
                )
            } else {
                url = try await tunnelService.start(port: port)
            }
            let response = TunnelStartResponse(url: url)
            return try encodeResponse(response, status: .ok)
        } catch {
            throw Abort(.internalServerError, reason: "Failed to start tunnel: \(error)")
        }
    }

    /// POST /tunnel/stop — stop the running tunnel.
    @Sendable
    func stopTunnel(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        await tunnelService.stop()
        let response = TunnelStopResponse(stopped: true)
        return try encodeResponse(response, status: .ok)
    }

    /// GET /tunnel/status — return current tunnel status including connectionState.
    @Sendable
    func getStatus(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        let status = await tunnelService.status()
        let response = TunnelStatusResponse(
            running: status.running,
            url: status.url,
            uptime: status.uptime,
            mode: status.mode,
            connectionState: status.connectionState
        )
        return try encodeResponse(response, status: .ok)
    }

    /// GET /tunnel/health — return tunnel health metrics including latency.
    @Sendable
    func getHealth(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        let status = await tunnelService.status()
        let latencyMs = await tunnelService.measureLatency()
        let response = TunnelHealthResponse(
            connectionState: status.connectionState,
            latencyMs: latencyMs,
            uptime: status.uptime
        )
        return try encodeResponse(response, status: .ok)
    }

    /// GET /tunnel/logs — return recent tunnel log entries.
    /// Optional query param: `limit` (default 50, max 100).
    @Sendable
    func getLogs(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        let requestedLimit = (try? req.query.get(Int.self, at: "limit")) ?? 50
        let limit = min(max(requestedLimit, 1), 100)

        let allLogs = await tunnelService.recentLogs
        let total = allLogs.count
        let sliced = Array(allLogs.suffix(limit))
        let hasMore = total > limit

        let response = TunnelLogsResponse(entries: sliced, total: total, hasMore: hasMore)
        return try encodeResponse(response, status: .ok)
    }

    // MARK: - Helpers

    private func notInstalledResponse() -> Response {
        let body: [String: String] = [
            "error": "cloudflared not installed",
            "installUrl": "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
        ]
        let data = try! JSONEncoder().encode(body)
        return Response(
            status: .notFound,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }

    private func encodeResponse<T: Encodable>(_ value: T, status: HTTPResponseStatus) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return Response(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: .init(data: data)
        )
    }
}

// MARK: - Vapor Content Conformance

extension TunnelStartResponse: Content {}
extension TunnelStopResponse: Content {}
extension TunnelStatusResponse: Content {}
extension TunnelStartRequest: Content {}
extension TunnelHealthResponse: Content {}
extension TunnelLogsResponse: Content {}
extension TunnelLogEntry: Content {}
