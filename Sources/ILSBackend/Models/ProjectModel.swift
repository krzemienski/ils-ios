import Fluent
import Vapor
import ILSShared

/// Fluent model for Project
final class ProjectModel: Model, Content, @unchecked Sendable {
    static let schema = "projects"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "path")
    var path: String

    @Field(key: "default_model")
    var defaultModel: String

    @OptionalField(key: "description")
    var description: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "last_accessed_at", on: .update)
    var lastAccessedAt: Date?

    @Children(for: \.$project)
    var sessions: [SessionModel]

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        path: String,
        defaultModel: String = "sonnet",
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.defaultModel = defaultModel
        self.description = description
    }

    /// Convert to shared Project type
    func toShared(sessionCount: Int? = nil) -> Project {
        Project(
            id: id ?? UUID(),
            name: name,
            path: path,
            defaultModel: defaultModel,
            description: description,
            createdAt: createdAt ?? Date(),
            lastAccessedAt: lastAccessedAt ?? Date(),
            sessionCount: sessionCount
        )
    }

    /// Create from shared Project type
    static func from(_ project: Project) -> ProjectModel {
        ProjectModel(
            id: project.id,
            name: project.name,
            path: project.path,
            defaultModel: project.defaultModel,
            description: project.description
        )
    }
}
