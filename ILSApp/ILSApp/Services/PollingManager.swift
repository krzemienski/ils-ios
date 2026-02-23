import Foundation

/// Manages connection health polling and retry logic.
@MainActor
class PollingManager {
    /// Scene lifecycle phase mirroring SwiftUI.ScenePhase
    /// so PollingManager has no SwiftUI dependency.
    enum AppPhase {
        case active, inactive, background
    }

    /// Unowned is safe: ConnectionManager creates and owns PollingManager,
    /// so ConnectionManager always outlives this instance. Avoids atomic
    /// weak-reference overhead on every health poll cycle.
    unowned let connectionManager: ConnectionManager

    private var retryTask: Task<Void, Never>?
    private var healthPollTask: Task<Void, Never>?
    // NET-MED-2: Observer for network restoration to resume polling.
    private var networkObserver: NSObjectProtocol?

    init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
        // Resume polling when network becomes available again.
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkConnection()
            }
        }
    }

    deinit {
        retryTask?.cancel()
        healthPollTask?.cancel()
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func checkConnection() {
        // NET-MED-2: Skip network requests when device has no connectivity.
        guard NetworkMonitor.shared.isConnected else {
            connectionManager.isConnected = false
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let cm = self.connectionManager
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
        AppLogger.shared.info("Starting retry polling (exponential backoff: 5s-60s)", category: "app")
        retryTask = Task { [weak self] in
            var delay: UInt64 = 5_000_000_000 // Start at 5 seconds
            let maxDelay: UInt64 = 60_000_000_000 // Cap at 60 seconds
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let cm = self.connectionManager
                do {
                    AppLogger.shared.info("Retry attempt to: \(cm.serverURL)", category: "app")
                    let response = try await cm.apiClient.healthCheck()
                    AppLogger.shared.info("Reconnected! Response: \(response)", category: "app")
                    cm.isConnected = true
                    self.stopRetryPolling()
                    self.startHealthPolling()
                    break
                } catch {
                    let delaySec = delay / 1_000_000_000
                    delay = min(delay * 2, maxDelay)
                    let nextDelaySec = delay / 1_000_000_000
                    AppLogger.shared.warning("Still disconnected after \(delaySec)s, retrying in \(nextDelaySec)s...", category: "app")
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
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s health check
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let cm = self.connectionManager
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

    func handleScenePhase(_ phase: AppPhase) {
        switch phase {
        case .active:
            checkConnection()
        case .background:
            stopHealthPolling()
            stopRetryPolling()
        case .inactive:
            break
        }
    }
}
