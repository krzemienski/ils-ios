import Foundation
import Observation
import ILSShared

@MainActor
@Observable
final class HostProfilesViewModel {
    var hosts: [HostProfile] = []
    var activeHostId: UUID?
    var isLoading = false
    var error: Error?
    /// Name of the most recently activated host, used to trigger the success banner.
    /// Set by activate() and cleared by the view after the banner auto-dismisses.
    var lastActivatedHostName: String?
    var operationState: AsyncOperationState?
    var operationMessage: String?

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
        error = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<HostProfileListResponse> = try await appState.apiClient.get("/host-profiles")
            guard let fleet = response.data else { return }
            hosts = fleet.hosts
            activeHostId = fleet.activeHostId
        } catch {
            self.error = error
        }
    }

    func register(name: String, host: String, port: Int, backendPort: Int, username: String?, authMethod: String?, credential: String?) async {
        operationState = .connecting
        operationMessage = "Registering host..."
        defer {
            operationState = nil
            operationMessage = nil
        }
        let request = RegisterHostProfileRequest(
            name: name, host: host, port: port, backendPort: backendPort,
            username: username, authMethod: authMethod, credential: credential
        )
        do {
            let newHost: HostProfile = try await appState.apiClient.post("/host-profiles/register", body: request)
            hosts.append(newHost)
            if hosts.count == 1 { activeHostId = newHost.id }
        } catch {
            self.error = error
        }
    }

    func activate(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            guard let host = hosts.first(where: { $0.id == id }) else { return }
            operationState = .connecting
            operationMessage = "Activating host..."
            defer {
                operationState = nil
                operationMessage = nil
            }
            do {
                let _: HostProfile = try await appState.apiClient.post("/host-profiles/\(id)/activate", body: EmptyBody())
                activeHostId = id
                for i in hosts.indices { hosts[i].isActive = hosts[i].id == id }
                let scheme = host.backendPort == 443 ? "https" : "http"
                let newURL = "\(scheme)://\(host.host):\(host.backendPort)"
                appState.updateServerURL(newURL)
                appState.activeHostName = host.name
                UserDefaults.standard.set(host.name, forKey: "activeHostName")
                self.lastActivatedHostName = host.name
            } catch {
                self.error = error
            }
        }
    }

    func remove(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let _: DeletedResponse = try await appState.apiClient.delete("/host-profiles/\(id)")
                hosts.removeAll { $0.id == id }
                if activeHostId == id {
                    activeHostId = nil
                    appState.activeHostName = nil
                    UserDefaults.standard.removeObject(forKey: "activeHostName")
                }
            } catch {
                self.error = error
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
                let health: HostProfileHealthResponse = try await appState.apiClient.get("/host-profiles/\(hosts[i].id)/health")
                hosts[i].healthStatus = health.status
                hosts[i].lastHealthCheck = health.lastChecked
            } catch {
                // Health polling is best-effort; silently skip failures for individual hosts
            }
        }
    }
}
