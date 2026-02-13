import Fluent
import Vapor
import ILSShared

/// Fluent model for Fleet Host
final class FleetHostModel: Model, Content, @unchecked Sendable {
    static let schema = "fleet_hosts"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "host")
    var host: String

    @Field(key: "port")
    var port: Int

    @Field(key: "backend_port")
    var backendPort: Int

    @OptionalField(key: "username")
    var username: String?

    @OptionalField(key: "auth_method")
    var authMethod: String?

    @Field(key: "is_active")
    var isActive: Bool

    @Field(key: "health_status")
    var healthStatus: String

    @OptionalField(key: "last_health_check")
    var lastHealthCheck: Date?

    @OptionalField(key: "platform")
    var platform: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        host: String,
        port: Int = 22,
        backendPort: Int = 9090,
        username: String? = nil,
        authMethod: String? = nil,
        isActive: Bool = false,
        healthStatus: FleetHost.HealthStatus = .unknown
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.backendPort = backendPort
        self.username = username
        self.authMethod = authMethod
        self.isActive = isActive
        self.healthStatus = healthStatus.rawValue
    }

    /// Convert to shared FleetHost type
    func toShared() -> FleetHost {
        FleetHost(
            id: id ?? UUID(),
            name: name,
            host: host,
            port: port,
            backendPort: backendPort,
            username: username,
            authMethod: authMethod.flatMap { ServerConnection.AuthMethod(rawValue: $0) },
            isActive: isActive,
            healthStatus: FleetHost.HealthStatus(rawValue: healthStatus) ?? .unknown,
            lastHealthCheck: lastHealthCheck,
            platform: platform
        )
    }
}
