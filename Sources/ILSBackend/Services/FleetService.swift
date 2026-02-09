import Vapor
import ILSShared
import Foundation

actor FleetService {
    private var hosts: [UUID: FleetHost] = [:]
    private var activeHostId: UUID?
    private var healthCheckTask: Task<Void, Never>?
    private let healthCheckInterval: TimeInterval = 30

    func register(from request: RegisterFleetHostRequest) -> FleetHost {
        let host = FleetHost(
            name: request.name,
            host: request.host,
            port: request.port,
            backendPort: request.backendPort,
            username: request.username,
            authMethod: request.authMethod.flatMap { ServerConnection.AuthMethod(rawValue: $0) },
            isActive: hosts.isEmpty,
            healthStatus: .unknown
        )
        hosts[host.id] = host
        if hosts.count == 1 { activeHostId = host.id }
        return host
    }

    func list() -> FleetListResponse {
        FleetListResponse(
            hosts: Array(hosts.values).sorted { $0.name < $1.name },
            activeHostId: activeHostId
        )
    }

    func getHost(id: UUID) -> FleetHost? { hosts[id] }

    func remove(id: UUID) -> Bool {
        if activeHostId == id { activeHostId = nil }
        return hosts.removeValue(forKey: id) != nil
    }

    func activate(id: UUID) -> FleetHost? {
        guard var host = hosts[id] else { return nil }
        for key in hosts.keys { hosts[key]?.isActive = false }
        host.isActive = true
        hosts[id] = host
        activeHostId = id
        return host
    }

    func checkHealth(id: UUID) async -> FleetHealthResponse {
        guard let host = hosts[id] else {
            return FleetHealthResponse(hostId: id, status: .unreachable)
        }

        do {
            guard let url = URL(string: "http://\(host.host):\(host.backendPort)/health") else {
                hosts[id]?.healthStatus = .unreachable
                hosts[id]?.lastHealthCheck = Date()
                return FleetHealthResponse(hostId: id, status: .unreachable, lastChecked: Date())
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                hosts[id]?.healthStatus = .unreachable
                hosts[id]?.lastHealthCheck = Date()
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
            hosts[id]?.healthStatus = status
            hosts[id]?.lastHealthCheck = Date()

            return FleetHealthResponse(
                hostId: id,
                status: status,
                backendVersion: health.version,
                claudeAvailable: health.claudeAvailable,
                lastChecked: Date()
            )
        } catch {
            hosts[id]?.healthStatus = .unreachable
            hosts[id]?.lastHealthCheck = Date()
            return FleetHealthResponse(hostId: id, status: .unreachable, lastChecked: Date())
        }
    }

    func lifecycle(id: UUID, action: LifecycleRequest.LifecycleAction) async -> LifecycleResponse {
        guard let host = hosts[id] else {
            return LifecycleResponse(success: false, action: action.rawValue, message: "Host not found")
        }
        // Forward lifecycle action to the remote backend
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

    func getLogs(id: UUID, lines: Int = 100) async -> RemoteLogsResponse {
        guard let host = hosts[id] else {
            return RemoteLogsResponse(lines: [], hostId: id)
        }
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

    func startPeriodicHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let hostIds = await self.allHostIds()
                for id in hostIds {
                    _ = await self.checkHealth(id: id)
                }
                try? await Task.sleep(nanoseconds: UInt64(30 * 1_000_000_000))
            }
        }
    }

    func stopPeriodicHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    private func allHostIds() -> [UUID] {
        Array(hosts.keys)
    }
}
