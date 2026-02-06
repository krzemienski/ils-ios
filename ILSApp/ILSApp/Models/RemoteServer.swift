import Foundation

struct RemoteServer: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var status: ServerStatus
    var claudeVersion: String?
    var lastSynced: Date?
    var skillCount: Int
    var mcpServerCount: Int
    var group: String?

    enum ServerStatus: String, Codable, CaseIterable {
        case online = "Online"
        case offline = "Offline"
        case degraded = "Degraded"
        case unknown = "Unknown"
    }

    init(id: UUID = UUID(), name: String = "", host: String = "", port: Int = 22, username: String = "", status: ServerStatus = .unknown, claudeVersion: String? = nil, lastSynced: Date? = nil, skillCount: Int = 0, mcpServerCount: Int = 0, group: String? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.status = status
        self.claudeVersion = claudeVersion
        self.lastSynced = lastSynced
        self.skillCount = skillCount
        self.mcpServerCount = mcpServerCount
        self.group = group
    }

    static let sampleFleet: [RemoteServer] = [
        RemoteServer(name: "Dev Server", host: "dev.example.com", port: 22, username: "deploy", status: .online, claudeVersion: "1.0.16", lastSynced: Date(), skillCount: 42, mcpServerCount: 5, group: "Development"),
        RemoteServer(name: "Staging", host: "staging.example.com", port: 22, username: "deploy", status: .online, claudeVersion: "1.0.16", lastSynced: Date().addingTimeInterval(-3600), skillCount: 38, mcpServerCount: 4, group: "Staging"),
        RemoteServer(name: "Prod Worker 1", host: "prod-1.example.com", port: 22, username: "deploy", status: .degraded, claudeVersion: "1.0.15", lastSynced: Date().addingTimeInterval(-7200), skillCount: 35, mcpServerCount: 3, group: "Production"),
        RemoteServer(name: "Prod Worker 2", host: "prod-2.example.com", port: 22, username: "deploy", status: .offline, claudeVersion: nil, lastSynced: nil, skillCount: 0, mcpServerCount: 0, group: "Production"),
    ]
}
