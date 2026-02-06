import Foundation

struct SSHConnection: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var isConnected: Bool
    var lastConnected: Date?
    var claudeCodeVersion: String?

    enum AuthMethod: String, Codable, CaseIterable {
        case password = "password"
        case sshKey = "sshKey"
    }

    init(id: UUID = UUID(), name: String = "", host: String = "", port: Int = 22, username: String = "", authMethod: AuthMethod = .sshKey, isConnected: Bool = false, lastConnected: Date? = nil, claudeCodeVersion: String? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.isConnected = isConnected
        self.lastConnected = lastConnected
        self.claudeCodeVersion = claudeCodeVersion
    }
}
