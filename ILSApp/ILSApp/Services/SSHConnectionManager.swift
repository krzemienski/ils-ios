import Foundation
import Security

@MainActor
class SSHConnectionManager: ObservableObject {
    @Published var connections: [SSHConnection] = []

    private let storageKey = "ssh_connections"

    init() {
        loadConnections()
    }

    func loadConnections() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SSHConnection].self, from: data) else {
            return
        }
        connections = decoded
    }

    func save(_ connection: SSHConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
        } else {
            connections.append(connection)
        }
        persistConnections()
    }

    func delete(_ connection: SSHConnection) {
        connections.removeAll { $0.id == connection.id }
        deleteCredential(for: connection.id)
        persistConnections()
    }

    private func persistConnections() {
        if let data = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Keychain

    func saveCredential(_ credential: String, for connectionId: UUID) {
        let key = "ssh_cred_\(connectionId.uuidString)"
        guard let data = credential.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func loadCredential(for connectionId: UUID) -> String? {
        let key = "ssh_cred_\(connectionId.uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteCredential(for connectionId: UUID) {
        let key = "ssh_cred_\(connectionId.uuidString)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    func testConnection(_ connection: SSHConnection) async -> Bool {
        // Simulated connection test — real SSH would use Citadel/NIOSSHClient
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return !connection.host.isEmpty && !connection.username.isEmpty
    }
}
