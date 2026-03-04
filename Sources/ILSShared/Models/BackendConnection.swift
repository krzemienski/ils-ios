import Foundation

/// Represents a direct HTTP connection profile to a remote ILS backend instance.
public struct BackendConnection: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this connection profile.
    public let id: UUID
    /// Human-readable name for the backend instance.
    public var name: String
    /// Full URL of the backend (e.g., "http://192.168.1.10:9999").
    public var url: String
    /// Hex color string for visual identification in the UI (e.g., "#FF5733").
    public var colorHex: String
    /// Whether push notifications are enabled for this backend.
    public var notificationsEnabled: Bool
    /// Whether this backend is currently the active target.
    public var isActive: Bool
    /// Current health check status.
    public var healthStatus: HealthStatus

    /// Health status of a backend connection.
    public enum HealthStatus: String, Codable, Sendable {
        /// Backend is healthy and fully operational.
        case healthy
        /// Backend is partially functional.
        case degraded
        /// Backend cannot be reached.
        case unreachable
        /// Health status has not been checked.
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unrecognized HealthStatus: '\(raw)'. Expected: healthy, degraded, unreachable, unknown"
                    )
                )
            }
            self = value
        }
    }

    /// Creates a new backend connection profile.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name. Must not be empty.
    ///   - url: Full backend URL. Must not be empty.
    ///   - colorHex: Hex color for UI identification (default: "#4A90E2").
    ///   - notificationsEnabled: Whether notifications are enabled (default: true).
    ///   - isActive: Whether this is the active backend (default: false).
    ///   - healthStatus: Current health status (default: .unknown).
    public init(
        id: UUID = UUID(),
        name: String,
        url: String,
        colorHex: String = "#4A90E2",
        notificationsEnabled: Bool = true,
        isActive: Bool = false,
        healthStatus: HealthStatus = .unknown
    ) {
        precondition(!name.isEmpty, "BackendConnection name must not be empty")
        precondition(!url.isEmpty, "BackendConnection url must not be empty")
        self.id = id
        self.name = name
        self.url = url
        self.colorHex = colorHex
        self.notificationsEnabled = notificationsEnabled
        self.isActive = isActive
        self.healthStatus = healthStatus
    }
}
