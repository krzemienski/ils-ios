import Fluent
import Vapor
import ILSShared

/// Fluent model for AgentQueueItem
final class AgentQueueItemModel: Model, Content, @unchecked Sendable {
    static let schema = "agent_queue_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "prompt")
    var prompt: String?

    @OptionalField(key: "project_id")
    var projectId: UUID?

    @Field(key: "priority")
    var priority: Int

    @Field(key: "position")
    var position: Int

    @Field(key: "status")
    var status: String

    @Field(key: "execution_mode")
    var executionMode: String

    @OptionalField(key: "session_id")
    var sessionId: UUID?

    @OptionalField(key: "error_message")
    var errorMessage: String?

    @OptionalField(key: "depends_on")
    var dependsOn: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalField(key: "started_at")
    var startedAt: Date?

    @OptionalField(key: "completed_at")
    var completedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String,
        prompt: String? = nil,
        projectId: UUID? = nil,
        priority: Int = 0,
        position: Int = 0,
        status: AgentQueueStatus = .queued,
        executionMode: QueueExecutionMode = .sequential,
        sessionId: UUID? = nil,
        errorMessage: String? = nil,
        dependsOn: String? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.projectId = projectId
        self.priority = priority
        self.position = position
        self.status = status.rawValue
        self.executionMode = executionMode.rawValue
        self.sessionId = sessionId
        self.errorMessage = errorMessage
        self.dependsOn = dependsOn
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    /// Convert to shared AgentQueueItem type
    func toShared() -> AgentQueueItem {
        var dependsOnIds: [String]? = nil
        if let raw = dependsOn,
           let data = raw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            dependsOnIds = ids
        }

        return AgentQueueItem(
            id: id?.uuidString ?? UUID().uuidString,
            title: title,
            description: prompt,
            projectId: projectId?.uuidString,
            sessionId: sessionId?.uuidString,
            status: AgentQueueStatus(rawValue: status) ?? .queued,
            priority: priority,
            position: position,
            dependsOn: dependsOnIds,
            createdAt: createdAt,
            startedAt: startedAt,
            completedAt: completedAt,
            errorMessage: errorMessage
        )
    }

    /// Create from shared AgentQueueItem type
    static func from(_ item: AgentQueueItem, executionMode: QueueExecutionMode = .sequential) -> AgentQueueItemModel {
        var dependsOnStr: String? = nil
        if let ids = item.dependsOn,
           let data = try? JSONEncoder().encode(ids),
           let str = String(data: data, encoding: .utf8) {
            dependsOnStr = str
        }

        return AgentQueueItemModel(
            id: UUID(uuidString: item.id),
            title: item.title,
            prompt: item.description,
            projectId: item.projectId.flatMap { UUID(uuidString: $0) },
            priority: item.priority,
            position: item.position,
            status: item.status,
            executionMode: executionMode,
            sessionId: item.sessionId.flatMap { UUID(uuidString: $0) },
            errorMessage: item.errorMessage,
            dependsOn: dependsOnStr,
            startedAt: item.startedAt,
            completedAt: item.completedAt
        )
    }
}
