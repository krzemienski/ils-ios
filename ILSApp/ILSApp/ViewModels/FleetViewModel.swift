import SwiftUI
import Observation
import ILSShared

@MainActor
@Observable
final class FleetViewModel {
    var hosts: [FleetHost] = []
    var activeHostId: UUID?
    var isLoading = false
    var loadError: String?
    /// Error message when auto-registering localhost fails.
    var autoRegisterError: String?
    /// Error message for mutation operations (register, activate, remove).
    var mutationError: String?
    var scenePhase: ScenePhase = .active {
        didSet {
            handleScenePhaseChange()
        }
    }

    private let apiClient: APIClient
    @ObservationIgnored private var healthTimer: Timer?
    @ObservationIgnored private var isPollingActive = false

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    deinit {
        healthTimer?.invalidate()
    }

    private func handleScenePhaseChange() {
        switch scenePhase {
        case .active:
            if isPollingActive {
                startHealthPolling(interval: 60)
            }
        case .inactive, .background:
            healthTimer?.invalidate()
            healthTimer = nil
        @unknown default:
            break
        }
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

            // Auto-populate localhost:9999 on first load if no hosts exist
            if hosts.isEmpty {
                await autoRegisterLocalhost()
            }
        } catch {
            loadError = "Failed to load fleet hosts: \(error.localizedDescription)"
        }
    }

    private func autoRegisterLocalhost() async {
        autoRegisterError = nil
        let request = RegisterFleetHostRequest(
            name: "Local Backend",
            host: "localhost",
            port: 22,
            backendPort: 9999,
            username: nil,
            authMethod: nil,
            credential: nil
        )

        do {
            let response: APIResponse<FleetHost> = try await apiClient.post("/fleet/register", body: request)
            if let newHost = response.data {
                hosts.append(newHost)
                activeHostId = newHost.id
            }
        } catch {
            autoRegisterError = "Could not auto-register localhost: \(error.localizedDescription)"
        }
    }

    func register(name: String, host: String, port: Int, backendPort: Int, username: String?, authMethod: String?, credential: String?) async {
        let request = RegisterFleetHostRequest(
            name: name, host: host, port: port, backendPort: backendPort,
            username: username, authMethod: authMethod, credential: credential
        )
        do {
            let newHost: FleetHost = try await apiClient.post("/fleet/register", body: request)
            hosts.append(newHost)
            if hosts.count == 1 { activeHostId = newHost.id }
        } catch {
            AppLogger.shared.error("Fleet registration failed: \(error)", category: "fleet")
            mutationError = "Failed to register host: \(error.localizedDescription)"
        }
    }

    func activate(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: FleetHost = try await apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
                activeHostId = id
                hosts = hosts.map { host in
                    var copy = host
                    copy.isActive = host.id == id
                    return copy
                }
            } catch {
                AppLogger.shared.error("Fleet activation failed for \(id): \(error)", category: "fleet")
                mutationError = "Failed to activate host: \(error.localizedDescription)"
            }
        }
    }

    func remove(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: DeletedResponse = try await apiClient.delete("/fleet/\(id)")
                hosts.removeAll { $0.id == id }
                if activeHostId == id { activeHostId = nil }
            } catch {
                AppLogger.shared.error("Fleet removal failed for \(id): \(error)", category: "fleet")
                mutationError = "Failed to remove host: \(error.localizedDescription)"
            }
        }
    }

    func startHealthPolling(interval: TimeInterval = 60) {
        healthTimer?.invalidate()
        isPollingActive = true
        healthTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refreshAllHealth() }
        }
        healthTimer?.tolerance = 10
    }

    func stopHealthPolling() {
        healthTimer?.invalidate()
        healthTimer = nil
        isPollingActive = false
    }

    private func refreshAllHealth() async {
        var updatedHosts = hosts
        for index in updatedHosts.indices {
            do {
                let health: FleetHealthResponse = try await apiClient.get("/fleet/\(updatedHosts[index].id)/health")
                var copy = updatedHosts[index]
                copy.healthStatus = health.status
                copy.lastHealthCheck = health.lastChecked
                updatedHosts[index] = copy
            } catch {
                AppLogger.shared.warning("Health check failed for \(updatedHosts[index].name): \(error)", category: "fleet")
                var copy = updatedHosts[index]
                copy.healthStatus = .unknown
                updatedHosts[index] = copy
            }
        }
        hosts = updatedHosts
    }
}
