import Foundation
import Observation
import ILSShared

/// View model for TunnelSettingsView, extracting all API calls and credential management
/// from the view to follow unidirectional data-flow conventions.
@Observable
@MainActor
class TunnelSettingsViewModel {
    // MARK: - Connection State

    var isRunning = false
    var tunnelURL: String?
    var uptime: Int?
    var tunnelMode: String?
    /// Detailed connection state derived from health checks.
    var connectionState: TunnelConnectionState = .disconnected
    /// Round-trip latency to the tunnel endpoint in milliseconds.
    var latencyMs: Int?

    // MARK: - UI State

    var isLoading = false
    var isToggling = false
    var errorMessage: String?
    var notInstalled = false
    var installURL: String?
    var keychainMigrationError: String?
    /// Whether the user explicitly wants the tunnel running (persists intent across reconnects).
    var userWantsRunning = false
    /// Whether the system is currently attempting an automatic reconnect.
    var isAutoReconnecting = false

    // MARK: - Access Log

    /// Recent tunnel log entries for display in the UI.
    var accessLog: [TunnelLogEntry] = []

    // MARK: - Custom Domain Credentials

    var cfToken = ""
    var cfTunnelName = ""
    var cfDomain = ""

    private var client: APIClient?
    // nonisolated(unsafe) allows Task cancellation from deinit (Task is Sendable)
    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?
    private var networkObserver: NSObjectProtocol?

    func configure(client: APIClient) {
        self.client = client
    }

    deinit {
        pollingTask?.cancel()
    }

    /// Whether all three custom-domain fields are non-empty.
    var isCustomDomainValid: Bool {
        !cfToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !cfDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// Fetches the current tunnel status from the backend.
    func fetchStatus() async {
        guard let client else { return }
        do {
            let status: TunnelStatusResponse = try await client.get("/tunnel/status")
            isRunning = status.running
            tunnelURL = status.url
            uptime = status.uptime
            tunnelMode = status.mode
            if let state = status.connectionState {
                connectionState = state
            } else {
                connectionState = status.running ? .connected : .disconnected
            }
            notInstalled = false
            errorMessage = nil
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches tunnel health metrics including latency and connection state.
    func fetchHealth() async {
        guard let client, isRunning else { return }
        do {
            let health: TunnelHealthResponse = try await client.get("/tunnel/health")
            connectionState = health.connectionState
            latencyMs = health.latencyMs
            if let healthUptime = health.uptime {
                uptime = healthUptime
            }
        } catch {
            // Health endpoint is best-effort; don't surface errors to UI
            AppLogger.shared.warning("Tunnel health fetch failed: \(error)", category: "tunnel")
        }
    }

    /// Fetches recent tunnel log entries and updates accessLog.
    func fetchLogs() async {
        guard let client, isRunning else { return }
        do {
            let logs: TunnelLogsResponse = try await client.get("/tunnel/logs")
            accessLog = logs.entries
        } catch {
            AppLogger.shared.warning("Tunnel logs fetch failed: \(error)", category: "tunnel")
        }
    }

    /// Starts an anonymous Cloudflare quick tunnel.
    func startTunnel() async {
        guard let client else { return }
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        do {
            let request = TunnelStartRequest()
            let response: TunnelStartResponse = try await client.post("/tunnel/start", body: request)
            tunnelURL = response.url
            isRunning = true
            userWantsRunning = true
            connectionState = .connected
            notInstalled = false
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops the active tunnel.
    func stopTunnel() async {
        guard let client else { return }
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        do {
            let request = TunnelStartRequest()
            let _: TunnelStopResponse = try await client.post("/tunnel/stop", body: request)
            isRunning = false
            userWantsRunning = false
            tunnelURL = nil
            uptime = nil
            latencyMs = nil
            connectionState = .disconnected
            accessLog = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Persists custom-domain credentials and starts a named tunnel.
    func startNamedTunnel() async {
        guard let client else { return }
        isToggling = true
        errorMessage = nil
        defer { isToggling = false }

        // Persist credentials
        let defaults = UserDefaults.standard
        do {
            try await KeychainService.shared.saveCredential(key: "cfToken", value: cfToken)
        } catch {
            AppLogger.shared.error("Failed to save cfToken to Keychain: \(error)", category: "keychain")
        }
        defaults.set(cfTunnelName, forKey: "cfTunnelName")
        defaults.set(cfDomain, forKey: "cfDomain")

        do {
            let request = TunnelStartRequest(
                token: cfToken.trimmingCharacters(in: .whitespacesAndNewlines),
                tunnelName: cfTunnelName.trimmingCharacters(in: .whitespacesAndNewlines),
                domain: cfDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let response: TunnelStartResponse = try await client.post("/tunnel/start", body: request)
            tunnelURL = response.url
            isRunning = true
            userWantsRunning = true
            connectionState = .connected
            notInstalled = false
        } catch let apiError as APIError {
            if case .httpError(let code) = apiError, code == 404 {
                notInstalled = true
                installURL = "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Restores saved credentials from Keychain and UserDefaults.
    func loadCustomDomainSettings() {
        let defaults = UserDefaults.standard
        Task {
            // CODBL-03: try? intentional — token may not exist yet
            if let token = try? await KeychainService.shared.getCredential(key: "cfToken") {
                await MainActor.run { cfToken = token }
            } else if let legacyToken = defaults.string(forKey: "cfToken"), !legacyToken.isEmpty {
                do {
                    try await KeychainService.shared.saveCredential(key: "cfToken", value: legacyToken)
                } catch {
                    AppLogger.shared.error("Failed to migrate cfToken to Keychain: \(error)", category: "keychain")
                    await MainActor.run {
                        keychainMigrationError = "Tunnel token couldn't be secured. Please re-enter your token."
                    }
                }
                defaults.removeObject(forKey: "cfToken")
                await MainActor.run { cfToken = legacyToken }
            }
        }
        cfTunnelName = defaults.string(forKey: "cfTunnelName") ?? ""
        cfDomain = defaults.string(forKey: "cfDomain") ?? ""
    }

    // MARK: - Polling

    /// Starts a 10-second polling loop that refreshes tunnel status, health, and logs.
    /// Cancels any existing polling task before starting a new one.
    func startStatusPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetchStatus()
                if self.isRunning {
                    await self.fetchHealth()
                    await self.fetchLogs()
                }
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            }
        }
    }

    /// Stops the active status polling loop.
    func stopStatusPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Network Change Observation

    /// Observes network availability changes and triggers auto-reconnect when
    /// the network is restored and the user previously wanted the tunnel running.
    func observeNetworkChanges() {
        if let existing = networkObserver {
            NotificationCenter.default.removeObserver(existing)
        }

        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.userWantsRunning && !self.isRunning else { return }
                self.isAutoReconnecting = true
                AppLogger.shared.info("Network restored — auto-reconnecting tunnel", category: "tunnel")
                if self.cfToken.isEmpty {
                    await self.startTunnel()
                } else {
                    await self.startNamedTunnel()
                }
                self.isAutoReconnecting = false
            }
        }
    }

    // MARK: - Helpers

    func formatUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, secs)
        } else {
            return String(format: "%ds", secs)
        }
    }
}
