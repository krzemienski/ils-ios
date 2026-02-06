import SwiftUI
import ILSShared

@MainActor
class ServerConnectionViewModel: ObservableObject {
    @Published var host: String = ""
    @Published var port: String = "22"
    @Published var username: String = ""
    @Published var authMethod: AuthMethod = .password
    @Published var credential: String = ""
    @Published var isConnecting = false
    @Published var error: String?
    @Published var recentConnections: [RecentConnection] = []

    private var apiClient: APIClient?

    enum AuthMethod: String, CaseIterable {
        case password = "Password"
        case key = "SSH Key"
    }

    struct RecentConnection: Codable, Identifiable, Hashable {
        var id: String { "\(host):\(port)@\(username)" }
        let host: String
        let port: String
        let username: String
        let authMethod: String
        let lastConnected: Date
    }

    func configure(client: APIClient) {
        self.apiClient = client
    }

    func loadRecentConnections() {
        guard let data = UserDefaults.standard.data(forKey: "ils.recentConnections"),
              let connections = try? JSONDecoder().decode([RecentConnection].self, from: data) else {
            return
        }
        recentConnections = connections
    }

    func selectRecentConnection(_ connection: RecentConnection) {
        host = connection.host
        port = connection.port
        username = connection.username
        authMethod = AuthMethod(rawValue: connection.authMethod) ?? .password
    }

    func connect() async -> ConnectionResponse? {
        guard let apiClient else { return nil }
        guard !host.isEmpty, !username.isEmpty, !credential.isEmpty else {
            error = "Please fill in all fields"
            return nil
        }

        isConnecting = true
        error = nil

        // Retry with exponential backoff: 3 attempts (0s, 1s, 2s delay)
        for attempt in 0..<3 {
            do {
                // Add delay for retry attempts
                if attempt > 0 {
                    let delaySeconds = UInt64(attempt * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delaySeconds)
                }

                let portNum = Int(port) ?? 22
                let request = ConnectRequest(
                    host: host,
                    port: portNum,
                    username: username,
                    authMethod: authMethod.rawValue.lowercased(),
                    credential: credential
                )
                let response: APIResponse<ConnectionResponse> = try await apiClient.post("/auth/connect", body: request)

                if let data = response.data, data.success {
                    // Save to recent connections
                    saveToRecent()
                    // Save password to keychain
                    if authMethod == .password {
                        try? KeychainService.shared.savePassword(credential, for: "\(host):\(port)")
                    }
                    isConnecting = false
                    return data
                } else {
                    // Server returned error - don't retry
                    error = response.data?.error ?? response.error?.message ?? "Connection failed"
                    isConnecting = false
                    return nil
                }
            } catch {
                // Network/connection error - retry if we have attempts left
                if attempt == 2 {
                    // Final attempt failed
                    self.error = error.localizedDescription
                    isConnecting = false
                    return nil
                }
                // Continue to next retry attempt
            }
        }

        isConnecting = false
        return nil
    }

    private func saveToRecent() {
        let connection = RecentConnection(
            host: host,
            port: port,
            username: username,
            authMethod: authMethod.rawValue,
            lastConnected: Date()
        )
        // Remove duplicates, add to front, cap at 10
        var connections = recentConnections.filter { $0.id != connection.id }
        connections.insert(connection, at: 0)
        if connections.count > 10 {
            connections = Array(connections.prefix(10))
        }
        recentConnections = connections
        if let data = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(data, forKey: "ils.recentConnections")
        }
    }
}
