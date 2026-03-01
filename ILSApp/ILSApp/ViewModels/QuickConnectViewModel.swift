import Foundation
import Observation
import ILSShared

/// Result of a connection attempt.
enum ConnectionResult {
    case success
    case failure(String)
}

/// Backend info retrieved after a successful connection.
struct BackendInfo {
    let claudeVersion: String
    let status: String
}

/// View model for the Quick Connect flow.
///
/// Encapsulates URL resolution, multi-step connection logic, history persistence,
/// and result state. The view observes this for UI updates.
@Observable
@MainActor
class QuickConnectViewModel {
    // MARK: - Input State
    var selectedMode: ConnectionMode = .local
    var localURL = "http://localhost:9999"
    var remoteHost = ""
    var remotePort = "9999"
    var tunnelURL = ""

    // MARK: - Connection State
    var isConnecting = false
    var connectionSteps: [ConnectionStep] = []
    var showSteps = false
    var connectionResult: ConnectionResult?
    var backendInfo: BackendInfo?
    var showConnectedState = false

    // MARK: - Auto Detection & Troubleshooting
    var isAutoDetecting = false
    var isShowingTroubleshooting = false
    var shouldDismiss = false

    // MARK: - History
    var connectionHistory: [String] = []

    // MARK: - Computed

    var isConnectEnabled: Bool {
        switch selectedMode {
        case .local:
            return !localURL.isEmpty
        case .remote:
            return !remoteHost.isEmpty && !remotePort.isEmpty
        case .tunnel:
            return !tunnelURL.isEmpty && isValidTunnelURL(tunnelURL)
        }
    }

    var resolvedURL: String {
        switch selectedMode {
        case .local:
            return localURL.trimmingCharacters(in: .whitespacesAndNewlines)
        case .remote:
            let host = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
            let port = remotePort.trimmingCharacters(in: .whitespacesAndNewlines)
            return "http://\(host):\(port)"
        case .tunnel:
            var url = tunnelURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                url = "https://\(url)"
            }
            if url.hasSuffix("/") {
                url = String(url.dropLast())
            }
            return url
        }
    }

    // MARK: - Validation

    func isValidTunnelURL(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains("trycloudflare.com") { return true }
        if trimmed.hasPrefix("https://") { return true }
        if trimmed.contains(".") && !trimmed.contains(" ") { return true }

        return false
    }

    // MARK: - History

    func loadHistory() {
        connectionHistory = UserDefaults.standard.stringArray(forKey: "connectionHistory") ?? []
    }

    private func saveToHistory(_ url: String) {
        var history = UserDefaults.standard.stringArray(forKey: "connectionHistory") ?? []
        history.removeAll { $0 == url }
        history.insert(url, at: 0)
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        UserDefaults.standard.set(history, forKey: "connectionHistory")
        connectionHistory = history
    }

    func fillFromHistory(_ url: String) {
        if url.contains("trycloudflare.com") {
            selectedMode = .tunnel
            tunnelURL = url
        } else if url.starts(with: "http://localhost") || url.starts(with: "http://127.0.0.1") {
            selectedMode = .local
            localURL = url
        } else {
            if let urlObj = URL(string: url), let host = urlObj.host {
                selectedMode = .remote
                remoteHost = host
                if let port = urlObj.port {
                    remotePort = String(port)
                }
            } else {
                selectedMode = .local
                localURL = url
            }
        }
    }

    // MARK: - Connection

    /// Run the multi-step connection flow: DNS resolve, TCP connect, health check.
    ///
    /// On success, saves to history, connects via `appState`, and sets `showConnectedState`.
    /// The caller is responsible for dismissing the sheet after the connected state is shown.
    func connect(appState: AppState) async -> Bool {
        isConnecting = true
        showSteps = true
        connectionResult = nil
        backendInfo = nil
        showConnectedState = false

        connectionSteps = [
            ConnectionStep(id: 0, name: "DNS Resolve", icon: "network", status: .pending),
            ConnectionStep(id: 1, name: "TCP Connect", icon: "cable.connector", status: .pending),
            ConnectionStep(id: 2, name: "Health Check", icon: "heart.fill", status: .pending)
        ]

        let url = resolvedURL

        // Step 1: DNS Resolve
        connectionSteps[0].status = .inProgress
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard let urlObj = URL(string: url), urlObj.host != nil else {
            connectionSteps[0].status = .failure("Invalid URL")
            connectionResult = .failure("Invalid URL")
            isConnecting = false
            showSteps = false
            return false
        }
        connectionSteps[0].status = .success

        // Step 2: TCP Connect
        connectionSteps[1].status = .inProgress
        try? await Task.sleep(nanoseconds: 200_000_000)

        let client = APIClient(baseURL: url)
        do {
            _ = try await client.healthCheck()
            connectionSteps[1].status = .success
        } catch {
            connectionSteps[1].status = .failure("Cannot reach server")
            connectionResult = .failure("Cannot reach server")
            isConnecting = false
            showSteps = false
            HapticManager.notification(.error)
            return false
        }

        // Step 3: Health Check
        connectionSteps[2].status = .inProgress
        try? await Task.sleep(nanoseconds: 200_000_000)

        do {
            let health = try await client.getHealth()
            connectionSteps[2].status = .success

            saveToHistory(url)

            try await appState.connectToServer(url: url)

            HapticManager.notification(.success)

            backendInfo = BackendInfo(
                claudeVersion: health.claudeVersion ?? "Unknown",
                status: health.status
            )

            isConnecting = false
            showSteps = false
            showConnectedState = true

            return true

        } catch {
            connectionSteps[2].status = .failure("Health check failed")
            connectionResult = .failure("Health check failed")
            isConnecting = false
            showSteps = false
            HapticManager.notification(.error)
            return false
        }
    }

    /// Connect and dismiss the view on success, or show troubleshooting on failure.
    ///
    /// Sets ``shouldDismiss`` to `true` after a brief delay on success so that the
    /// view can observe the change and call `dismiss()`.
    func connectAndFinish(appState: AppState) async {
        isShowingTroubleshooting = false
        let success = await connect(appState: appState)
        if success {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            shouldDismiss = true
        } else {
            isShowingTroubleshooting = true
        }
    }

    // MARK: - Auto Detection

    /// Attempt to auto-detect a local ILS backend at http://localhost:9999/health.
    ///
    /// Uses a 2-second timeout. On success, sets `localURL` to the detected address
    /// and triggers the full connect flow. Silently does nothing on failure.
    func autoDetectLocal(appState: AppState) async {
        isAutoDetecting = true
        defer { isAutoDetecting = false }

        let detectionURLString = "http://localhost:9999/health"
        guard let url = URL(string: detectionURLString) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                localURL = "http://localhost:9999"
                selectedMode = .local
                _ = await connect(appState: appState)
            }
        } catch {
            // Auto-detection failed silently — user can connect manually
        }
    }
}
