import Vapor
import Fluent
import ILSShared
import Foundation

/// Controller for host profile management operations.
///
/// Routes match what HostProfilesViewModel.swift expects:
/// - `GET /host-profiles`: List all host profiles (returns HostProfileListResponse)
/// - `POST /host-profiles/register`: Register a new host profile
/// - `POST /host-profiles/:id/activate`: Set a host as active
/// - `DELETE /host-profiles/:id`: Remove a host profile
/// - `GET /host-profiles/:id/health`: Get health status for a host
///
/// Backward-compatible aliases (satisfy FOUND-01: old /fleet/* routes still work):
/// - `GET /fleet`, `POST /fleet/register`, etc. — same handlers
struct HostProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // New canonical routes
        let hostProfiles = routes.grouped("host-profiles")
        hostProfiles.get(use: index)
        hostProfiles.post("register", use: register)
        hostProfiles.post(":id", "activate", use: activate)
        hostProfiles.delete(":id", use: delete)
        hostProfiles.get(":id", "health", use: health)

        // Backward-compatible aliases (satisfy FOUND-01: old /fleet/* routes still work)
        let fleet = routes.grouped("fleet")
        fleet.get(use: index)
        fleet.post("register", use: register)
        fleet.post(":id", "activate", use: activate)
        fleet.delete(":id", use: delete)
        fleet.get(":id", "health", use: health)
    }

    /// List all host profiles with the active host ID.
    @Sendable
    func index(req: Request) async throws -> APIResponse<HostProfileListResponse> {
        let hosts = try await HostProfileModel.query(on: req.db)
            .sort(\.$isActive, .descending)
            .sort(\.$name, .ascending)
            .all()

        let shared = hosts.map { $0.toShared() }
        let activeId = shared.first(where: { $0.isActive })?.id

        return APIResponse(
            success: true,
            data: HostProfileListResponse(hosts: shared, activeHostId: activeId)
        )
    }

    /// Register a new host profile.
    @Sendable
    func register(req: Request) async throws -> APIResponse<HostProfile> {
        let input = try req.content.decode(RegisterHostProfileRequest.self)

        try PathSanitizer.validateStringLength(input.name, maxLength: 255, fieldName: "name")
        try PathSanitizer.validateStringLength(input.host, maxLength: 255, fieldName: "host")

        let model = HostProfileModel(
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
    func activate(req: Request) async throws -> APIResponse<HostProfile> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await HostProfileModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        // Wrap activation in a transaction so deactivate-all + activate is atomic
        try await req.db.transaction { db in
            let allHosts = try await HostProfileModel.query(on: db).all()
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

    /// Delete a host profile by ID.
    @Sendable
    func delete(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await HostProfileModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        try await host.delete(on: req.db)

        return APIResponse(
            success: true,
            data: DeletedResponse(deleted: true)
        )
    }

    /// Get health status for a specific host profile.
    ///
    /// Performs a real HTTP GET to `http(s)://{host}:{backendPort}/health` to verify
    /// the remote backend is reachable. Falls back to `.unknown` on timeout or error.
    @Sendable
    func health(req: Request) async throws -> APIResponse<HostProfileHealthResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let host = try await HostProfileModel.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }

        // Perform a real HTTP health check to the host's backend port
        let backendPort = host.backendPort
        let scheme = backendPort == 443 ? "https" : "http"
        let healthURL = "\(scheme)://\(host.host):\(backendPort)/health"

        var healthStatus: HostProfile.HealthStatus = .unknown
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
                        req.logger.debug("Host profile health response not JSON-decodable: \(error)")
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
            data: HostProfileHealthResponse(
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
