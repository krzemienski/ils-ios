import Vapor
import Fluent
import ILSShared

/// Controller for fleet host management endpoints.
///
/// Routes:
/// - `GET /fleet` — list all fleet hosts
/// - `POST /fleet/register` — register a new host
/// - `POST /fleet/:id/activate` — set a host as active
/// - `DELETE /fleet/:id` — remove a host
/// - `GET /fleet/:id/health` — check host health
struct FleetController: RouteCollection {
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func boot(routes: RoutesBuilder) throws {
        let fleet = routes.grouped("fleet")

        fleet.get(use: self.list)
        fleet.post("register", use: self.register)
        fleet.post(":hostID", "activate", use: self.activate)
        fleet.delete(":hostID", use: self.remove)
        fleet.get(":hostID", "health", use: self.health)
    }

    // MARK: - List

    /// GET /fleet — returns all fleet hosts with the active host ID.
    @Sendable
    func list(req: Request) async throws -> Response {
        let models = try await FleetHostModel.query(on: req.db).all()
        let hosts = models.map { $0.toShared() }
        let activeId = models.first(where: { $0.isActive })?.id

        let response = APIResponse(
            success: true,
            data: FleetListResponse(hosts: hosts, activeHostId: activeId),
            error: nil
        )

        let data = try Self.jsonEncoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    // MARK: - Register

    /// POST /fleet/register — register a new fleet host.
    @Sendable
    func register(req: Request) async throws -> Response {
        let input = try req.content.decode(RegisterFleetHostRequest.self)

        let model = FleetHostModel(
            name: input.name,
            host: input.host,
            port: input.port,
            backendPort: input.backendPort,
            username: input.username,
            authMethod: input.authMethod
        )
        try await model.save(on: req.db)

        // If this is the first host, make it active
        let count = try await FleetHostModel.query(on: req.db).count()
        if count == 1 {
            model.isActive = true
            try await model.save(on: req.db)
        }

        let host = model.toShared()
        let response = APIResponse(success: true, data: host, error: nil)
        let data = try Self.jsonEncoder.encode(response)
        return Response(status: .created, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    // MARK: - Activate

    /// POST /fleet/:id/activate — set a host as the active target.
    @Sendable
    func activate(req: Request) async throws -> Response {
        guard let hostID = req.parameters.get("hostID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let model = try await FleetHostModel.find(hostID, on: req.db) else {
            throw Abort(.notFound, reason: "Fleet host not found")
        }

        // Deactivate all others
        let allHosts = try await FleetHostModel.query(on: req.db).all()
        for host in allHosts where host.isActive {
            host.isActive = false
            try await host.save(on: req.db)
        }

        // Activate this one
        model.isActive = true
        try await model.save(on: req.db)

        let host = model.toShared()
        let response = APIResponse(success: true, data: host, error: nil)
        let data = try Self.jsonEncoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    // MARK: - Remove

    /// DELETE /fleet/:id — remove a fleet host.
    @Sendable
    func remove(req: Request) async throws -> Response {
        guard let hostID = req.parameters.get("hostID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let model = try await FleetHostModel.find(hostID, on: req.db) else {
            throw Abort(.notFound, reason: "Fleet host not found")
        }

        try await model.delete(on: req.db)

        let response = APIResponse(success: true, data: DeletedResponse(deleted: true), error: nil)
        let data = try Self.jsonEncoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    // MARK: - Health

    /// GET /fleet/:id/health — check health of a fleet host by probing its backend.
    @Sendable
    func health(req: Request) async throws -> Response {
        guard let hostID = req.parameters.get("hostID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }

        guard let model = try await FleetHostModel.find(hostID, on: req.db) else {
            throw Abort(.notFound, reason: "Fleet host not found")
        }

        // Actually probe the host's backend to determine health
        let probeStatus = await probeHostHealth(host: model.host, backendPort: model.backendPort)

        model.healthStatus = probeStatus.rawValue
        model.lastHealthCheck = Date()
        try await model.save(on: req.db)

        let response = APIResponse(
            success: true,
            data: FleetHealthResponse(
                hostId: hostID,
                status: probeStatus,
                lastChecked: Date()
            ),
            error: nil
        )

        let data = try Self.jsonEncoder.encode(response)
        return Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(data: data))
    }

    /// Probe a host's backend by hitting its /health endpoint.
    private func probeHostHealth(host: String, backendPort: Int) async -> FleetHost.HealthStatus {
        let resolvedHost = (host == "localhost" || host == "127.0.0.1") ? "127.0.0.1" : host
        let urlString = "http://\(resolvedHost):\(backendPort)/health"
        guard let url = URL(string: urlString) else { return .unreachable }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return .healthy
            }
            return .degraded
        } catch {
            return .unreachable
        }
    }
}
