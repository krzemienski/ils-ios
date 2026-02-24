import Vapor
import Fluent
import ILSShared
import Foundation

/// Controller for fleet host management operations.
///
/// Routes match what FleetViewModel.swift expects:
/// - `GET /fleet`: List all fleet hosts (returns FleetListResponse)
/// - `POST /fleet/register`: Register a new fleet host
/// - `POST /fleet/:id/activate`: Set a host as active
/// - `DELETE /fleet/:id`: Remove a fleet host
/// - `GET /fleet/:id/health`: Get health status for a host
struct FleetController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let fleet = routes.grouped("fleet")

        fleet.get(use: index)
        fleet.post("register", use: register)
        fleet.post(":id", "activate", use: activate)
        fleet.delete(":id", use: delete)
        fleet.get(":id", "health", use: health)
    }

    /// List all fleet hosts with the active host ID.
    @Sendable
    func index(req: Request) async throws -> APIResponse<FleetListResponse> {
        let hosts = try await FleetHostModel.query(on: req.db)
            .sort(\.$isActive, .descending)
            .sort(\.$name, .ascending)
            .all()

        let shared = hosts.map { $0.toShared() }
        let activeId = shared.first(where: { $0.isActive })?.id

        return APIResponse(
            success: true,
            data: FleetListResponse(hosts: shared, activeHostId: activeId)
        )
    }

    /// Register a new fleet host.
    @Sendable
    func register(req: Request) async throws -> APIResponse<FleetHost> {
        let input = try req.content.decode(RegisterFleetHostRequest.self)

        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateStringLength(input.host, maxLength: 255, fieldName: "host")

        let model = FleetHostModel(
            name: input.name,
            host: input.host,
            port: input.port,
            backendPort: input.backendPort,
            username: input.username,
            authMethod: input.authMethod,
            isActive: false,
            healthStatus: .unknown
        )

        try await model.save(on: req.db)

        return APIResponse(
            success: true,
            data: model.toShared()
        )
    }

    /// Set a host as active (deactivate all others).
    @Sendable
    func activate(req: Request) async throws -> APIResponse<FleetHost> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await FleetHostModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        // Wrap activation in a transaction so deactivate-all + activate is atomic
        try await req.db.transaction { db in
            let allHosts = try await FleetHostModel.query(on: db).all()
            for h in allHosts {
                if h.isActive {
                    h.isActive = false
                    try await h.save(on: db)
                }
            }

            host.isActive = true
            try await host.save(on: db)
        }

        return APIResponse(
            success: true,
            data: host.toShared()
        )
    }

    /// Delete a fleet host by ID.
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await FleetHostModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        try await host.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse(deleted: true)
        )
    }

    /// Get health status for a specific host.
    ///
    /// Performs a real HTTP GET to `http(s)://{host}:{backendPort}/health` to verify
    /// the remote backend is reachable. Falls back to `.unknown` on timeout or error.
    @Sendable
    func health(req: Request) async throws -> APIResponse<FleetHealthResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await FleetHostModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        // Perform a real HTTP health check to the host's backend port
        let backendPort = host.backendPort
        let scheme = backendPort == 443 ? "https" : "http"
        let healthURL = "\(scheme)://\(host.host):\(backendPort)/health"

        var healthStatus: FleetHost.HealthStatus = .unknown
        var backendVersion = "unknown"
        var claudeAvailable = false

        if let url = URL(string: healthURL) {
            do {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 5 // 5-second timeout for health checks
                let checkSession = URLSession(configuration: config)
                defer { checkSession.invalidateAndCancel() }
                let (data, response) = try await checkSession.data(from: url)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    healthStatus = .healthy
                    // Parse version from health response JSON using Codable
                    let healthBody: HealthCheckBody?
                    do {
                        healthBody = try JSONDecoder().decode(HealthCheckBody.self, from: data)
                    } catch {
                        req.logger.debug("Fleet health response not JSON-decodable: \(error)")
                        healthBody = nil
                    }
                    if let healthBody = healthBody {
                        backendVersion = healthBody.version ?? backendVersion
                    }
                    claudeAvailable = true
                } else {
                    healthStatus = .degraded
                }
            } catch {
                // Connection refused, timeout, or DNS failure
                healthStatus = .unreachable
            }
        }

        // Persist updated health status and timestamp
        host.lastHealthCheck = Date()
        host.healthStatus = healthStatus.rawValue
        try await host.save(on: req.db)

        return APIResponse(
            success: true,
            data: FleetHealthResponse(
                hostId: host.id ?? UUID(),
                status: healthStatus,
                backendVersion: backendVersion,
                claudeAvailable: claudeAvailable,
                lastChecked: Date()
            )
        )
    }
}

// MARK: - Codable Helper

/// Codable type for decoding the remote backend's `/health` JSON response.
private struct HealthCheckBody: Decodable {
    let version: String?
    let status: String?
}
