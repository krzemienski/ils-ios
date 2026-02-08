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

    func checkConnection() {
        Task { [weak self] in
            guard let self, let cm = self.connectionManager else { return }
            do {
                AppLogger.shared.info("Checking connection to: \(cm.serverURL)", category: "app")
                let response = try await cm.apiClient.healthCheck()
                AppLogger.shared.info("Connection successful! Response: \(response)", category: "app")
                cm.isConnected = true
                self.stopRetryPolling()
                self.startHealthPolling()
            } catch let error as URLError {
                AppLogger.shared.error("Connection failed with URLError: \(error.code.rawValue) - \(error.localizedDescription)", category: "app")
                cm.isConnected = false
                self.stopHealthPolling()
                self.startRetryPolling()
                cm.showOnboardingIfNeeded()
            } catch {
                AppLogger.shared.error("Connection failed: \(error.localizedDescription)", category: "app")
                cm.isConnected = false
                self.stopHealthPolling()
                self.startRetryPolling()
                cm.showOnboardingIfNeeded()
            }
        }
    }

    func startRetryPolling() {
        guard retryTask == nil else { return }
        AppLogger.shared.info("Starting retry polling (every 5 seconds)", category: "app")
        retryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
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
                    AppLogger.shared.warning("Still disconnected, retrying in 5s...", category: "app")
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
                try? await Task.sleep(nanoseconds: 30_000_000_000)
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
            checkConnection()
        case .background:
            stopHealthPolling()
            stopRetryPolling()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
