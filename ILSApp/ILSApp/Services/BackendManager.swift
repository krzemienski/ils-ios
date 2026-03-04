import Foundation
import Observation
import ILSShared

/// Manages multiple backend connections — maintains one `APIClient` per backend,
/// performs periodic health polling, tracks connection status per backend,
/// and emits changes via `@Observable`.
///
/// Integrates with:
/// - ``BackendConnectionStore`` — persistent storage of connection profiles
/// - ``LowPowerModeMonitor`` — doubles polling interval during Low Power Mode (ENRG-03)
/// - ``NetworkMonitor`` — skips polling when offline; triggers an immediate poll on reconnect
@MainActor
@Observable
final class BackendManager {
    static let shared = BackendManager()

    // MARK: - Published State

    /// All persisted backend connection profiles, including runtime health status.
    private(set) var backends: [BackendConnection] = []

    /// The ID of the currently active backend, or `nil` if none is active.
    private(set) var activeBackendId: UUID?

    // MARK: - Private State

    /// One `APIClient` instance per backend UUID.
    @ObservationIgnored private var clients: [UUID: APIClient] = [:]

    /// Background Task running the health-poll loop.
    @ObservationIgnored private var healthTask: Task<Void, Never>?

    /// Observer token for `.networkDidBecomeAvailable` notifications.
    @ObservationIgnored private var networkObserver: NSObjectProtocol?

    private let store = BackendConnectionStore.shared
    private let defaultPollingInterval: TimeInterval = 30

    private init() {}

    deinit {
        healthTask?.cancel()
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Load

    /// Loads all persisted backend connection profiles and rebuilds the client map.
    ///
    /// Health status is reset to `.unknown` for all backends on load
    /// (``BackendConnectionStore`` guarantees this).
    func loadBackends() async {
        let loaded = await store.loadAll()
        backends = loaded
        activeBackendId = loaded.first(where: { $0.isActive })?.id
        for backend in loaded {
            if clients[backend.id] == nil {
                clients[backend.id] = buildClient(for: backend)
            }
        }
    }

    // MARK: - CRUD

    /// Adds a new backend connection profile and optionally stores its API key.
    func add(_ connection: BackendConnection, apiKey: String? = nil) async {
        await store.save(connection)
        if let apiKey, !apiKey.isEmpty {
            await store.saveAPIKey(apiKey, forBackendId: connection.id)
        }
        backends.append(connection)
        clients[connection.id] = buildClient(for: connection)
    }

    /// Updates an existing backend connection profile and recreates its client.
    func update(_ connection: BackendConnection) async {
        await store.save(connection)
        if let index = backends.firstIndex(where: { $0.id == connection.id }) {
            backends[index] = connection
        }
        // Rebuild client in case the URL changed.
        clients[connection.id] = buildClient(for: connection)
    }

    /// Removes a backend connection profile, its stored API key, and its client.
    func remove(id: UUID) async {
        await store.delete(id: id)
        backends.removeAll { $0.id == id }
        clients.removeValue(forKey: id)
        if activeBackendId == id {
            activeBackendId = nil
        }
    }

    /// Marks a backend as active and persists the change across all profiles.
    /// Posts `.backendDidActivate` so that `AppState` can update `serverURL` for backward compat.
    func setActive(id: UUID) async {
        activeBackendId = id
        for i in backends.indices {
            backends[i].isActive = backends[i].id == id
            await store.save(backends[i])
        }
        // Notify AppState to update its serverURL for backward compat (AC: quick switch)
        if let activeURL = backends.first(where: { $0.id == id })?.url {
            NotificationCenter.default.post(
                name: .backendDidActivate,
                object: nil,
                userInfo: ["url": activeURL]
            )
        }
    }

    // MARK: - Client Access

    /// Returns the ``APIClient`` for the given backend ID, or `nil` if unknown.
    func client(for id: UUID) -> APIClient? {
        clients[id]
    }

    /// Returns the ``APIClient`` for the currently active backend, or `nil` if no backend is active.
    var activeClient: APIClient? {
        guard let id = activeBackendId else { return nil }
        return clients[id]
    }

    // MARK: - Health Polling

    /// Performs a single immediate health check on all backends, updating their status now.
    ///
    /// Unlike ``startHealthPolling(interval:)`` which sleeps before the first poll,
    /// `pollNow()` fires the health check immediately and awaits completion.
    func pollNow() async {
        await pollAllBackends()
    }

    /// Starts periodic health checks on all backends.
    ///
    /// - Parameter interval: Polling base interval in seconds (defaults to 30 s).
    ///
    /// **Energy policy (ENRG-03):** The effective interval is doubled while Low Power Mode
    /// is active. Polling is skipped entirely when the device has no network connectivity.
    /// An immediate poll fires when the network becomes available after being offline.
    func startHealthPolling(interval: TimeInterval? = nil) {
        stopHealthPolling()
        let base = interval ?? defaultPollingInterval

        // Trigger an immediate poll whenever network connectivity is restored.
        networkObserver = NotificationCenter.default.addObserver(
            forName: .networkDidBecomeAvailable,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollAllBackends()
            }
        }

        healthTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                // ENRG-03: Double interval in Low Power Mode to conserve battery.
                let effectiveInterval = LowPowerModeMonitor.shared.isLowPowerModeEnabled
                    ? base * 2
                    : base
                try? await Task.sleep(for: .seconds(effectiveInterval))
                guard !Task.isCancelled else { break }
                await self.pollAllBackends()
            }
        }
    }

    /// Cancels health polling and removes the network-availability observer.
    func stopHealthPolling() {
        healthTask?.cancel()
        healthTask = nil
        if let observer = networkObserver {
            NotificationCenter.default.removeObserver(observer)
            networkObserver = nil
        }
    }

    // MARK: - Private Helpers

    /// Checks health for every backend and updates `backends[i].healthStatus`.
    ///
    /// No-ops when the device has no network connectivity.
    private func pollAllBackends() async {
        guard NetworkMonitor.shared.isConnected else { return }
        for i in backends.indices {
            let id = backends[i].id
            guard let client = clients[id] else { continue }
            do {
                _ = try await client.healthCheck()
                backends[i].healthStatus = .healthy
            } catch {
                backends[i].healthStatus = .unreachable
                AppLogger.shared.warning(
                    "Health check failed for '\(backends[i].name)': \(error.localizedDescription)",
                    category: "backend"
                )
            }
        }
    }

    /// Creates an ``APIClient`` for the given backend and asynchronously applies
    /// the per-backend API key stored in ``BackendConnectionStore``.
    private func buildClient(for backend: BackendConnection) -> APIClient {
        let client = APIClient(baseURL: backend.url)
        Task { [weak self] in
            guard let self else { return }
            if let apiKey = await self.store.loadAPIKey(forBackendId: backend.id), !apiKey.isEmpty {
                await client.setAPIKey(apiKey)
            }
        }
        return client
    }
}
