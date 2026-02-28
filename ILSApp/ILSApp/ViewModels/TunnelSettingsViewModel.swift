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

    // MARK: - UI State

    var isLoading = false
    var isToggling = false
    var errorMessage: String?
    var notInstalled = false
    var installURL: String?
    var keychainMigrationError: String?

    // MARK: - Custom Domain Credentials

    var cfToken = ""
    var cfTunnelName = ""
    var cfDomain = ""

    private var client: APIClient?

    func configure(client: APIClient) {
        self.client = client
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
            tunnelURL = nil
            uptime = nil
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
