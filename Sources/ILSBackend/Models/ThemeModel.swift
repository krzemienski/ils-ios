import Fluent
import Vapor
import ILSShared

/// Fluent model for CustomTheme
final class ThemeModel: Model, Content, @unchecked Sendable {
    static let schema = "themes"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "author")
    var author: String?

    @OptionalField(key: "version")
    var version: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @OptionalField(key: "colors")
    var colors: ColorTokens?

    @OptionalField(key: "typography")
    var typography: TypographyTokens?

    @OptionalField(key: "spacing")
    var spacing: SpacingTokens?

    @OptionalField(key: "corner_radius")
    var cornerRadius: CornerRadiusTokens?

    @OptionalField(key: "shadows")
    var shadows: ShadowTokens?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        colors: ColorTokens? = nil,
        typography: TypographyTokens? = nil,
        spacing: SpacingTokens? = nil,
        cornerRadius: CornerRadiusTokens? = nil,
        shadows: ShadowTokens? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.shadows = shadows
    }

    /// Convert to shared CustomTheme type
    func toShared() -> CustomTheme {
        CustomTheme(
            id: id ?? UUID(),
            name: name,
            description: description,
            author: author,
            version: version,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            colors: colors,
            typography: typography,
            spacing: spacing,
            cornerRadius: cornerRadius,
            shadows: shadows
        )
    }

    /// Create from shared CustomTheme type
    static func from(_ theme: CustomTheme) -> ThemeModel {
        ThemeModel(
            id: theme.id,
            name: theme.name,
            description: theme.description,
            author: theme.author,
            version: theme.version,
            colors: theme.colors,
            typography: theme.typography,
            spacing: theme.spacing,
            cornerRadius: theme.cornerRadius,
            shadows: theme.shadows
        )
    }
}
