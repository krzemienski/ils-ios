import Fluent
import Vapor
import ILSShared

/// Fluent model for SessionTemplate
final class SessionTemplateModel: Model, Content, @unchecked Sendable {
    static let schema = "session_templates"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "initial_prompt")
    var initialPrompt: String?

    @Field(key: "model")
    var model: String

    @Field(key: "permission_mode")
    var permissionMode: String

    @Field(key: "is_favorite")
    var isFavorite: Bool

    @Field(key: "is_default")
    var isDefault: Bool

    @Field(key: "tags")
    var tags: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        description: String? = nil,
        initialPrompt: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        isFavorite: Bool = false,
        isDefault: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.initialPrompt = initialPrompt
        self.model = model
        self.permissionMode = permissionMode.rawValue
        self.isFavorite = isFavorite
        self.isDefault = isDefault
        self.tags = tags
    }

    /// Convert to shared SessionTemplate type
    func toShared() -> SessionTemplate {
        SessionTemplate(
            id: id ?? UUID(),
            name: name,
            description: description,
            initialPrompt: initialPrompt,
            model: model,
            permissionMode: PermissionMode(rawValue: permissionMode) ?? .default,
            isFavorite: isFavorite,
            isDefault: isDefault,
            tags: tags,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    /// Create from shared SessionTemplate type
    static func from(_ template: SessionTemplate) -> SessionTemplateModel {
        SessionTemplateModel(
            id: template.id,
            name: template.name,
            description: template.description,
            initialPrompt: template.initialPrompt,
            model: template.model,
            permissionMode: template.permissionMode,
            isFavorite: template.isFavorite,
            isDefault: template.isDefault,
            tags: template.tags
        )
    }
}
