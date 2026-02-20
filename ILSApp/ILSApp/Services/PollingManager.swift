import SwiftUI

/// Manages connection health polling and retry logic.
@MainActor
class PollingManager {
    weak var connectionManager: ConnectionManager?

    private var retryTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    deinit {
        retryTask?.cancel()
        healthPollTask?.cancel()
    }

    func checkConnection() async {
        guard let cm = connectionManager else { return }
        do {
            AppLogger.shared.info("Checking connection to: \(cm.serverURL)", category: "app")
            let response = try await cm.apiClient.healthCheck()
            AppLogger.shared.info("Connection successful! Response: \(response)", category: "app")
            cm.isConnected = true
            stopRetryPolling()
            startHealthPolling()
        } catch let error as URLError {
            AppLogger.shared.error("Connection failed with URLError: \(error.code.rawValue) - \(error.localizedDescription)", category: "app")
            cm.isConnected = false
            stopHealthPolling()
            startRetryPolling()
            cm.showOnboardingIfNeeded()
        } catch {
            AppLogger.shared.error("Connection failed: \(error.localizedDescription)", category: "app")
            cm.isConnected = false
            stopHealthPolling()
            startRetryPolling()
            cm.showOnboardingIfNeeded()
        }
    }

    func startRetryPolling() {
        guard retryTask == nil else { return }
        AppLogger.shared.info("Starting retry polling (exponential backoff: 5s-60s)", category: "app")
        retryTask = Task { [weak self] in
            var delaySec: Double = 5.0
            let maxDelaySec: Double = 60.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delaySec))
                guard !Task.isCancelled else { break }
                guard let self, let cm = self.connectionManager else { break }
                do {
                    AppLogger.shared.info("Retry attempt to: \(cm.serverURL)", category: "app")
                    let response = try await cm.apiClient.healthCheck()
                    AppLogger.shared.info("Reconnected! Response: \(response)", category: "app")
                    cm.isConnected = true
                    self.stopRetryPolling()
                    self.startHealthPolling()
                    break
                } catch {
                    let currentDelay = Int(delaySec)
                    delaySec = min(delaySec * 2, maxDelaySec)
                    AppLogger.shared.warning("Still disconnected after \(currentDelay)s, retrying in \(Int(delaySec))s...", category: "app")
                }
            }
        }
    }

    func stopRetryPolling() {
        retryTask?.cancel()
        retryTask = nil
    }

    func startHealthPolling() {
        guard healthPollTask == nil else { return }
        healthPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                guard let self, let cm = self.connectionManager else { break }
                do {
                    _ = try await cm.apiClient.healthCheck()
                } catch {
                    cm.isConnected = false
                    self.stopHealthPolling()
                    self.startRetryPolling()
                    break
                }
            }
        }
    }

    func stopHealthPolling() {
        healthPollTask?.cancel()
        healthPollTask = nil
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task { await checkConnection() }
        case .background, .inactive:
            stopHealthPolling()
            stopRetryPolling()
        @unknown default:
            break
        }
    }
}
