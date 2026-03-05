import Fluent
import Vapor
import ILSShared

/// Fluent model for tracking Claude Code CLI version history
final class VersionHistoryModel: Model, Content, @unchecked Sendable {
    static let schema = "version_history"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "version")
    var version: String

    @Field(key: "install_method")
    var installMethod: String

    @Timestamp(key: "detected_at", on: .create)
    var detectedAt: Date?

    @Field(key: "was_auto_detected")
    var wasAutoDetected: Bool

    init() {}

    init(
        id: UUID? = nil,
        version: String,
        installMethod: String,
        detectedAt: Date? = nil,
        wasAutoDetected: Bool = true
    ) {
        self.id = id
        self.version = version
        self.installMethod = installMethod
        self.detectedAt = detectedAt
        self.wasAutoDetected = wasAutoDetected
    }

    /// Convert to shared VersionHistoryEntry type
    func toShared() -> VersionHistoryEntry {
        VersionHistoryEntry(
            id: id ?? UUID(),
            version: version,
            installMethod: installMethod,
            detectedAt: detectedAt ?? Date(),
            wasAutoDetected: wasAutoDetected
        )
    }

    /// Create from shared VersionHistoryEntry type
    static func from(_ entry: VersionHistoryEntry) -> VersionHistoryModel {
        VersionHistoryModel(
            id: entry.id,
            version: entry.version,
            installMethod: entry.installMethod,
            detectedAt: entry.detectedAt,
            wasAutoDetected: entry.wasAutoDetected
        )
    }
}
