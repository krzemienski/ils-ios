import Vapor
import ILSShared

/// Controller for Cloudflare tunnel management endpoints.
///
/// Routes (all under `/api/v1/tunnel`):
/// - `POST /tunnel/start` — start a quick tunnel, returns public URL
/// - `POST /tunnel/stop` — stop the running tunnel
/// - `GET  /tunnel/status` — current tunnel status
struct TunnelController: RouteCollection {
    let tunnelService = TunnelService()

    func boot(routes: RoutesBuilder) throws {
        let tunnel = routes.grouped("tunnel")

        tunnel.post("start", use: self.startTunnel)
        tunnel.post("stop", use: self.stopTunnel)
        tunnel.get("status", use: self.getStatus)
    }

    // MARK: - Endpoints

    /// POST /tunnel/start — start a quick Cloudflare tunnel.
    @Sendable
    func startTunnel(req: Request) async throws -> Response {
        let isInstalled = await tunnelService.cloudflaredInstalled
        guard isInstalled else {
            return notInstalledResponse()
        }

        let body = try? req.content.decode(TunnelStartRequest.self)
        let port = 9999 // Default backend port

        do {
            let url = try await tunnelService.start(port: port)
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

    /// GET /tunnel/status — return current tunnel status.
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
            uptime: status.uptime
        )
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
