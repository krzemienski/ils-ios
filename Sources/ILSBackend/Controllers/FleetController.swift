import Vapor
import ILSShared

struct FleetController: RouteCollection {
    let fleetService: FleetService

    func boot(routes: RoutesBuilder) throws {
        let fleet = routes.grouped("fleet")
        fleet.post("register", use: register)
        fleet.get(use: list)
        fleet.get(":id", use: getHost)
        fleet.delete(":id", use: remove)
        fleet.post(":id", "activate", use: activate)
        fleet.get(":id", "health", use: health)
        fleet.post(":id", "lifecycle", use: lifecycle)
        fleet.get(":id", "logs", use: getLogs)
    }

    @Sendable
    func register(req: Request) async throws -> APIResponse<FleetHost> {
        let input = try req.content.decode(RegisterFleetHostRequest.self)
        let host = try await fleetService.register(from: input, db: req.db)
        return APIResponse(success: true, data: host)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<FleetListResponse> {
        let response = try await fleetService.list(db: req.db)
        return APIResponse(success: true, data: response)
    }

    @Sendable
    func getHost(req: Request) async throws -> APIResponse<FleetHost> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        guard let host = try await fleetService.getHost(id: id, db: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }
        return APIResponse(success: true, data: host)
    }

    @Sendable
    func remove(req: Request) async throws -> APIResponse<DeletedResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        guard try await fleetService.remove(id: id, db: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }
        return APIResponse(success: true, data: DeletedResponse())
    }

    @Sendable
    func activate(req: Request) async throws -> APIResponse<FleetHost> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        guard let host = try await fleetService.activate(id: id, db: req.db) else {
            throw Abort(.notFound, reason: "Host not found")
        }
        return APIResponse(success: true, data: host)
    }

    @Sendable
    func health(req: Request) async throws -> APIResponse<FleetHealthResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        let response = await fleetService.checkHealth(id: id, db: req.db)
        return APIResponse(success: true, data: response)
    }

    @Sendable
    func lifecycle(req: Request) async throws -> APIResponse<LifecycleResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        let input = try req.content.decode(LifecycleRequest.self)
        let response = await fleetService.lifecycle(id: id, action: input.action, db: req.db)
        return APIResponse(success: true, data: response)
    }

    @Sendable
    func getLogs(req: Request) async throws -> APIResponse<RemoteLogsResponse> {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid host ID")
        }
        let response = await fleetService.getLogs(id: id, db: req.db)
        return APIResponse(success: true, data: response)
    }
}
