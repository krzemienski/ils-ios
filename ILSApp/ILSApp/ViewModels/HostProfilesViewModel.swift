import Foundation
import Observation
import ILSShared

@MainActor
@Observable
final class HostProfilesViewModel {
    var hosts: [FleetHost] = []
    var activeHostId: UUID?
    var isLoading = false
    var loadError: String?

    private let appState: AppState
    @ObservationIgnored private var healthTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
    }

    deinit {
        healthTask?.cancel()
    }

    func loadHosts() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<FleetListResponse> = try await appState.apiClient.get("/fleet")
            guard let fleet = response.data else { return }
            hosts = fleet.hosts
            activeHostId = fleet.activeHostId
        } catch {
            loadError = "Failed to load host profiles: \(error.localizedDescription)"
        }
    }

    func register(name: String, host: String, port: Int, backendPort: Int, username: String?, authMethod: String?, credential: String?) async {
        let request = RegisterFleetHostRequest(
            name: name, host: host, port: port, backendPort: backendPort,
            username: username, authMethod: authMethod, credential: credential
        )
        do {
            let newHost: FleetHost = try await appState.apiClient.post("/fleet/register", body: request)
            hosts.append(newHost)
            if hosts.count == 1 { activeHostId = newHost.id }
        } catch {
            loadError = "Failed to register host: \(error.localizedDescription)"
        }
    }

    func activate(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            guard let host = hosts.first(where: { $0.id == id }) else { return }
            do {
                let _: FleetHost = try await appState.apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
                activeHostId = id
                for i in hosts.indices { hosts[i].isActive = hosts[i].id == id }
                let scheme = host.backendPort == 443 ? "https" : "http"
                let newURL = "\(scheme)://\(host.host):\(host.backendPort)"
                appState.updateServerURL(newURL)
                appState.activeHostName = host.name
                UserDefaults.standard.set(host.name, forKey: "activeHostName")
            } catch {
                loadError = "Failed to activate host '\(host.name)': \(error.localizedDescription)"
            }
        }
    }

    func remove(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: DeletedResponse = try await appState.apiClient.delete("/fleet/\(id)")
                hosts.removeAll { $0.id == id }
                if activeHostId == id {
                    activeHostId = nil
                    appState.activeHostName = nil
                    UserDefaults.standard.removeObject(forKey: "activeHostName")
                }
            } catch {
                loadError = "Failed to remove host: \(error.localizedDescription)"
            }
        }
    }

    /// Starts periodic host profile health polling at the given interval.
    func startHealthPolling(interval: TimeInterval = 30) {
        healthTask?.cancel()
        // ENRG-03: Double host profile health poll interval in Low Power Mode to reduce energy.
        let effectiveInterval = LowPowerModeMonitor.shared.isLowPowerModeEnabled ? interval * 2 : interval
        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(effectiveInterval))
                guard let self, !Task.isCancelled else { break }
                await self.refreshAllHealth()
            }
        }
    }

    func stopHealthPolling() {
        healthTask?.cancel()
        healthTask = nil
    }

    private func refreshAllHealth() async {
        for i in hosts.indices {
            do {
                let health: FleetHealthResponse = try await appState.apiClient.get("/fleet/\(hosts[i].id)/health")
                hosts[i].healthStatus = health.status
                hosts[i].lastHealthCheck = health.lastChecked
            } catch {
                // Health polling is best-effort; silently skip failures for individual hosts
            }
        }
    }
}
