import Foundation
import ILSShared

@MainActor
final class FleetViewModel: ObservableObject {
    @Published var hosts: [FleetHost] = []
    @Published var activeHostId: UUID?
    @Published var isLoading = false
    @Published var loadError: String?

    private let apiClient: APIClient
    private var healthTimer: Timer?

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    deinit {
        healthTimer?.invalidate()
    }

    func loadHosts() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<FleetListResponse> = try await apiClient.get("/fleet")
            guard let fleet = response.data else { return }
            hosts = fleet.hosts
            activeHostId = fleet.activeHostId
        } catch {
            loadError = "Failed to load fleet hosts: \(error.localizedDescription)"
        }
    }

    func register(name: String, host: String, port: Int, backendPort: Int, username: String?, authMethod: String?, credential: String?) async {
        let request = RegisterFleetHostRequest(
            name: name, host: host, port: port, backendPort: backendPort,
            username: username, authMethod: authMethod, credential: credential
        )
        let newHost: FleetHost? = try? await apiClient.post("/fleet/register", body: request)
        if let newHost {
            hosts.append(newHost)
            if hosts.count == 1 { activeHostId = newHost.id }
        }
    }

    func activate(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            let updated: FleetHost? = try? await apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
            if updated != nil {
                activeHostId = id
                for i in hosts.indices { hosts[i].isActive = hosts[i].id == id }
            }
        }
    }

    func remove(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            let _: DeletedResponse? = try? await apiClient.delete("/fleet/\(id)")
            hosts.removeAll { $0.id == id }
            if activeHostId == id { activeHostId = nil }
        }
    }

    func startHealthPolling(interval: TimeInterval = 30) {
        healthTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refreshAllHealth() }
        }
        healthTimer?.tolerance = 5
    }

    func stopHealthPolling() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    private func refreshAllHealth() async {
        for i in hosts.indices {
            if let health: FleetHealthResponse = try? await apiClient.get("/fleet/\(hosts[i].id)/health") {
                hosts[i].healthStatus = health.status
                hosts[i].lastHealthCheck = health.lastChecked
            }
        }
    }
}
