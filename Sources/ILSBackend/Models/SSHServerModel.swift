import Fluent
import Vapor
import ILSShared

/// Fluent model for SSH Server
final class SSHServerModel: Model, Content, @unchecked Sendable {
    static let schema = "ssh_servers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "host")
    var host: String

    @Field(key: "port")
    var port: Int

    @Field(key: "username")
    var username: String

    @Field(key: "auth_type")
    var authType: String

    @OptionalField(key: "description")
    var description: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalField(key: "last_connected_at")
    var lastConnectedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authType: SSHAuthType = .password,
        description: String? = nil,
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType.rawValue
        self.description = description
        self.lastConnectedAt = lastConnectedAt
    }

    /// Convert to shared SSHServer type
    func toShared() -> SSHServer {
        SSHServer(
            id: id ?? UUID(),
            name: name,
            host: host,
            port: port,
            username: username,
            authType: SSHAuthType(rawValue: authType) ?? .password,
            description: description,
            createdAt: createdAt ?? Date(),
            lastConnectedAt: lastConnectedAt
        )
    }

    /// Create from shared SSHServer type
    static func from(_ server: SSHServer) -> SSHServerModel {
        SSHServerModel(
            id: server.id,
            name: server.name,
            host: server.host,
            port: server.port,
            username: server.username,
            authType: server.authType,
            description: server.description,
            lastConnectedAt: server.lastConnectedAt
        )
    }
}
