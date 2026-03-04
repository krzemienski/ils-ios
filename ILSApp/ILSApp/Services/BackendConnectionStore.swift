import Foundation
import ILSShared

/// Persists BackendConnection profiles across app launches using a layered storage strategy:
///
/// - **Non-sensitive data** (name, url, colorHex, notificationsEnabled, isActive):
///   `NSUbiquitousKeyValueStore` (iCloud sync) with `UserDefaults` as fallback.
/// - **API keys**: Keychain only, keyed as `backend_apikey_{uuid}`.
/// - **healthStatus**: Runtime-only field, always reset to `.unknown` on load.
actor BackendConnectionStore {
    static let shared = BackendConnectionStore()

    private let storageKey = "backend_connections_v1"

    // MARK: - Read

    /// Load all persisted backend connection profiles.
    /// Tries iCloud KV Store first, falls back to UserDefaults.
    /// API keys are NOT included — load them separately via `loadAPIKey(forBackendId:)`.
    /// healthStatus is reset to `.unknown` on every load.
    func loadAll() -> [BackendConnection] {
        let data: Data?
        let iCloudStore = NSUbiquitousKeyValueStore.default
        if let iCloudData = iCloudStore.data(forKey: storageKey) {
            data = iCloudData
        } else {
            data = UserDefaults.standard.data(forKey: storageKey)
        }
        guard let data else { return [] }
        let connections = (try? JSONDecoder().decode([BackendConnection].self, from: data)) ?? []
        // healthStatus is runtime state — always start fresh
        return connections.map {
            var c = $0
            c.healthStatus = .unknown
            return c
        }
    }

    // MARK: - Write

    /// Persist a backend connection profile. Deduplicates by `id`.
    /// API key must be saved separately via `saveAPIKey(_:forBackendId:)`.
    func save(_ connection: BackendConnection) {
        var connections = loadAll()
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        persist(connections)
    }

    /// Remove a backend connection profile and its associated Keychain API key.
    func delete(id: UUID) {
        var connections = loadAll()
        connections.removeAll { $0.id == id }
        persist(connections)
        KeychainService.deleteSync(key: apiKeyKeychainKey(for: id))
    }

    // MARK: - API Keys (Keychain only)

    /// Store an API key for a backend. Never written to iCloud or UserDefaults.
    func saveAPIKey(_ key: String, forBackendId id: UUID) {
        KeychainService.saveSync(key: apiKeyKeychainKey(for: id), value: key)
    }

    /// Retrieve the API key for a backend from the Keychain.
    /// Returns `nil` if no key has been stored.
    func loadAPIKey(forBackendId id: UUID) -> String? {
        KeychainService.loadSync(key: apiKeyKeychainKey(for: id))
    }

    // MARK: - Private Helpers

    private func apiKeyKeychainKey(for id: UUID) -> String {
        "backend_apikey_\(id.uuidString.lowercased())"
    }

    private func persist(_ connections: [BackendConnection]) {
        guard let data = try? JSONEncoder().encode(connections) else { return }
        let iCloudStore = NSUbiquitousKeyValueStore.default
        iCloudStore.set(data, forKey: storageKey)
        iCloudStore.synchronize()
        // Mirror to UserDefaults so data is available if iCloud KV Store is unavailable
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
