import Vapor
import Fluent
import ILSShared
import Foundation

actor FleetService {
    private var healthCheckTask: Task<Void, Never>?
    private let healthCheckInterval: TimeInterval = 30

    func register(from request: RegisterFleetHostRequest, db: Database) async throws -> FleetHost {
        let isFirst = try await FleetHostModel.query(on: db).count() == 0
        let model = FleetHostModel(
            name: request.name,
            host: request.host,
            port: request.port,
            backendPort: request.backendPort,
            username: request.username,
            authMethod: request.authMethod,
            isActive: isFirst,
            healthStatus: .unknown
        )
        try await model.save(on: db)
        return model.toShared()
    }

    func list(db: Database) async throws -> FleetListResponse {
        let models = try await FleetHostModel.query(on: db)
            .sort(\.$name)
            .all()
        let hosts = models.map { $0.toShared() }
        let activeHostId = models.first(where: { $0.isActive })?.id
        return FleetListResponse(hosts: hosts, activeHostId: activeHostId)
    }

    func getHost(id: UUID, db: Database) async throws -> FleetHost? {
        guard let model = try await FleetHostModel.find(id, on: db) else {
            return nil
        }
        return model.toShared()
    }

    func remove(id: UUID, db: Database) async throws -> Bool {
        guard let model = try await FleetHostModel.find(id, on: db) else {
            return false
        }
        try await model.delete(on: db)
        return true
    }

    func activate(id: UUID, db: Database) async throws -> FleetHost? {
        guard let model = try await FleetHostModel.find(id, on: db) else {
            return nil
        }
        // Deactivate all hosts
        let allModels = try await FleetHostModel.query(on: db).all()
        for other in allModels {
            if other.isActive {
                other.isActive = false
                try await other.save(on: db)
            }
        }
        // Activate the target
        model.isActive = true
        try await model.save(on: db)
        return model.toShared()
    }

    func checkHealth(id: UUID, db: Database) async -> FleetHealthResponse {
        guard let model = try? await FleetHostModel.find(id, on: db) else {
            return FleetHealthResponse(hostId: id, status: .unreachable)
        }

        let host = model.toShared()

        do {
            guard let url = URL(string: "http://\(host.host):\(host.backendPort)/health") else {
                model.healthStatus = FleetHost.HealthStatus.unreachable.rawValue
                model.lastHealthCheck = Date()
                try? await model.save(on: db)
                return FleetHealthResponse(hostId: id, status: .unreachable, lastChecked: Date())
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                model.healthStatus = FleetHost.HealthStatus.unreachable.rawValue
                model.lastHealthCheck = Date()
                try? await model.save(on: db)
                return FleetHealthResponse(hostId: id, status: .unreachable, lastChecked: Date())
            }

            struct HealthInfo: Codable {
                let status: String
                let version: String
                let claudeAvailable: Bool
                let claudeVersion: String?
            }

            let health = try JSONDecoder().decode(HealthInfo.self, from: data)
            let status: FleetHost.HealthStatus = health.status == "ok" ? .healthy : .degraded
            model.healthStatus = status.rawValue
            model.lastHealthCheck = Date()
            try? await model.save(on: db)

            return FleetHealthResponse(
                hostId: id,
                status: status,
                backendVersion: health.version,
                claudeAvailable: health.claudeAvailable,
                lastChecked: Date()
            )
        } catch {
            model.healthStatus = FleetHost.HealthStatus.unreachable.rawValue
            model.lastHealthCheck = Date()
            try? await model.save(on: db)
            return FleetHealthResponse(hostId: id, status: .unreachable, lastChecked: Date())
        }
    }

    func lifecycle(id: UUID, action: LifecycleRequest.LifecycleAction, db: Database) async -> LifecycleResponse {
        guard let model = try? await FleetHostModel.find(id, on: db) else {
            return LifecycleResponse(success: false, action: action.rawValue, message: "Host not found")
        }
        let host = model.toShared()
        do {
            let url = URL(string: "http://\(host.host):\(host.backendPort)/api/v1/lifecycle")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body = try JSONEncoder().encode(LifecycleRequest(action: action, hostId: id))
            request.httpBody = body
            let (_, response) = try await URLSession.shared.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            return LifecycleResponse(success: success, action: action.rawValue, message: success ? "Action \(action.rawValue) sent" : "Remote host returned error")
        } catch {
            return LifecycleResponse(success: false, action: action.rawValue, message: "Failed to reach host: \(error.localizedDescription)")
        }
    }

    func getLogs(id: UUID, lines: Int = 100, db: Database) async -> RemoteLogsResponse {
        guard let model = try? await FleetHostModel.find(id, on: db) else {
            return RemoteLogsResponse(lines: [], hostId: id)
        }
        let host = model.toShared()
        do {
            let url = URL(string: "http://\(host.host):\(host.backendPort)/api/v1/logs?lines=\(lines)")!
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return RemoteLogsResponse(lines: ["Error: Remote host returned non-200 status"], hostId: id)
            }
            let decoded = try JSONDecoder().decode(RemoteLogsResponse.self, from: data)
            return RemoteLogsResponse(lines: decoded.lines, hostId: id)
        } catch {
            return RemoteLogsResponse(lines: ["Error: \(error.localizedDescription)"], hostId: id)
        }
    }

    func startPeriodicHealthChecks(db: Database) {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let hostIds = await self.allHostIds(db: db)
                for id in hostIds {
                    _ = await self.checkHealth(id: id, db: db)
                }
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000))
            }
        }
    }

    func stopPeriodicHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    private func allHostIds(db: Database) async -> [UUID] {
        let models = (try? await FleetHostModel.query(on: db).all()) ?? []
        return models.compactMap { $0.id }
    }
}
