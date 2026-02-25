import Fluent
import Vapor
import ILSShared

/// Fluent model for a user-defined session template.
final class TemplateModel: Model, Content, @unchecked Sendable {
    static let schema = "templates"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "description")
    var description: String

    @Field(key: "model")
    var model: String

    @Field(key: "permission_mode")
    var permissionMode: String

    @Field(key: "system_prompt")
    var systemPrompt: String

    @OptionalField(key: "max_budget_usd")
    var maxBudgetUSD: Double?

    @OptionalField(key: "max_turns")
    var maxTurns: Int?

    @Field(key: "is_favorite")
    var isFavorite: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        description: String = "",
        model: String = "sonnet",
        permissionMode: String = "default",
        systemPrompt: String = "",
        maxBudgetUSD: Double? = nil,
        maxTurns: Int? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.permissionMode = permissionMode
        self.systemPrompt = systemPrompt
        self.maxBudgetUSD = maxBudgetUSD
        self.maxTurns = maxTurns
        self.isFavorite = isFavorite
    }

    /// Convert to shared SessionTemplate type (always user-defined, not built-in).
    func toShared() -> ILSShared.SessionTemplate {
        ILSShared.SessionTemplate(
            id: id ?? UUID(),
            name: name,
            description: description,
            model: model,
            permissionMode: permissionMode,
            systemPrompt: systemPrompt,
            maxBudgetUSD: maxBudgetUSD,
            maxTurns: maxTurns,
            isBuiltIn: false,
            isFavorite: isFavorite,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
