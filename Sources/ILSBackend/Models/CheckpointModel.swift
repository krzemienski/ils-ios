import Fluent
import Vapor
import ILSShared

/// Fluent model for Checkpoint persistence.
///
/// Checkpoints store an ordered list of message UUIDs (as a JSON string) rather
/// than duplicating message content, keeping storage efficient. Restoring a
/// checkpoint deletes any messages whose IDs are not present in
/// ``snapshotMessageIds``.
final class CheckpointModel: Model, Content, @unchecked Sendable {
    static let schema = "checkpoints"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "session_id")
    var session: SessionModel

    @OptionalField(key: "label")
    var label: String?

    @Field(key: "message_count")
    var messageCount: Int

    /// JSON-encoded array of message UUIDs captured at checkpoint time.
    @Field(key: "snapshot_message_ids")
    var snapshotMessageIds: String

    @Field(key: "is_auto")
    var isAuto: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        sessionId: UUID,
        label: String? = nil,
        messageCount: Int,
        snapshotMessageIds: [UUID],
        isAuto: Bool
    ) throws {
        self.id = id
        self.$session.id = sessionId
        self.label = label
        self.messageCount = messageCount
        self.snapshotMessageIds = try Self.encodeMessageIds(snapshotMessageIds)
        self.isAuto = isAuto
    }

    // MARK: - JSON helpers

    /// Encodes a `[UUID]` array to a compact JSON string for DB storage.
    static func encodeMessageIds(_ ids: [UUID]) throws -> String {
        let strings = ids.map { $0.uuidString }
        let data = try JSONEncoder().encode(strings)
        return String(decoding: data, as: UTF8.self)
    }

    /// Decodes the stored JSON string back to `[UUID]`.
    func decodeMessageIds() throws -> [UUID] {
        let data = Data(snapshotMessageIds.utf8)
        let strings = try JSONDecoder().decode([String].self, from: data)
        return strings.compactMap { UUID(uuidString: $0) }
    }

    // MARK: - Conversions

    /// Converts this model to the shared `Checkpoint` type.
    func toShared() throws -> Checkpoint {
        let ids = try decodeMessageIds()
        return Checkpoint(
            id: id ?? UUID(),
            sessionId: $session.id,
            label: label,
            messageCount: messageCount,
            snapshotMessageIds: ids,
            isAuto: isAuto,
            createdAt: createdAt ?? Date()
        )
    }
}
