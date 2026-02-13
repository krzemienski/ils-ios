import Foundation

/// Custom theme with user-defined design tokens
public struct CustomTheme: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var author: String?
    public var version: String?
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Design Tokens

    public var colors: ColorTokens?
    public var typography: TypographyTokens?
    public var spacing: SpacingTokens?
    public var cornerRadius: CornerRadiusTokens?
    public var shadows: ShadowTokens?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        author: String? = nil,
        version: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.shadows = shadows
    }
}

// MARK: - Color Tokens

/// Color design tokens for theme customization
public struct ColorTokens: Codable, Sendable {
    // Primary colors
    public var accent: String?
    public var background: String?
    public var secondaryBackground: String?
    public var tertiaryBackground: String?

    // Text colors
    public var primaryText: String?
    public var secondaryText: String?
    public var tertiaryText: String?

    // Status colors
    public var success: String?
    public var warning: String?
    public var error: String?
    public var info: String?

    // Message bubble colors
    public var userBubble: String?
    public var assistantBubble: String?

    // Additional colors
    public var border: String?
    public var separator: String?
    public var overlay: String?
    public var highlight: String?

    public init(
        accent: String? = nil,
        background: String? = nil,
        secondaryBackground: String? = nil,
        tertiaryBackground: String? = nil,
        primaryText: String? = nil,
        secondaryText: String? = nil,
        tertiaryText: String? = nil,
        success: String? = nil,
        warning: String? = nil,
        error: String? = nil,
        info: String? = nil,
        userBubble: String? = nil,
        assistantBubble: String? = nil,
        border: String? = nil,
        separator: String? = nil,
        overlay: String? = nil,
        highlight: String? = nil
    ) {
        self.accent = accent
        self.background = background
        self.secondaryBackground = secondaryBackground
        self.tertiaryBackground = tertiaryBackground
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.tertiaryText = tertiaryText
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
        self.userBubble = userBubble
        self.assistantBubble = assistantBubble
        self.border = border
        self.separator = separator
        self.overlay = overlay
        self.highlight = highlight
    }
}

// MARK: - Typography Tokens

/// Typography design tokens for theme customization
public struct TypographyTokens: Codable, Sendable {
    // Font families
    public var primaryFontFamily: String?
    public var monospacedFontFamily: String?

    // Font sizes
    public var titleSize: Double?
    public var headlineSize: Double?
    public var bodySize: Double?
    public var captionSize: Double?
    public var footnoteSize: Double?

    // Font weights
    public var titleWeight: String?
    public var headlineWeight: String?
    public var bodyWeight: String?

    // Line heights
    public var titleLineHeight: Double?
    public var bodyLineHeight: Double?
    public var captionLineHeight: Double?

    public init(
        primaryFontFamily: String? = nil,
        monospacedFontFamily: String? = nil,
        titleSize: Double? = nil,
        headlineSize: Double? = nil,
        bodySize: Double? = nil,
        captionSize: Double? = nil,
        footnoteSize: Double? = nil,
        titleWeight: String? = nil,
        headlineWeight: String? = nil,
        bodyWeight: String? = nil,
        titleLineHeight: Double? = nil,
        bodyLineHeight: Double? = nil,
        captionLineHeight: Double? = nil
    ) {
        self.primaryFontFamily = primaryFontFamily
        self.monospacedFontFamily = monospacedFontFamily
        self.titleSize = titleSize
        self.headlineSize = headlineSize
        self.bodySize = bodySize
        self.captionSize = captionSize
        self.footnoteSize = footnoteSize
        self.titleWeight = titleWeight
        self.headlineWeight = headlineWeight
        self.bodyWeight = bodyWeight
        self.titleLineHeight = titleLineHeight
        self.bodyLineHeight = bodyLineHeight
        self.captionLineHeight = captionLineHeight
    }
}

// MARK: - Spacing Tokens

/// Spacing design tokens for theme customization
public struct SpacingTokens: Codable, Sendable {
    public var spacingXS: Double?
    public var spacingS: Double?
    public var spacingM: Double?
    public var spacingL: Double?
    public var spacingXL: Double?
    public var spacingXXL: Double?

    // Component-specific spacing
    public var buttonPaddingHorizontal: Double?
    public var buttonPaddingVertical: Double?
    public var cardPadding: Double?
    public var listItemSpacing: Double?

    public init(
        spacingXS: Double? = nil,
        spacingS: Double? = nil,
        spacingM: Double? = nil,
        spacingL: Double? = nil,
        spacingXL: Double? = nil,
        spacingXXL: Double? = nil,
        buttonPaddingHorizontal: Double? = nil,
        buttonPaddingVertical: Double? = nil,
        cardPadding: Double? = nil,
        listItemSpacing: Double? = nil
    ) {
        self.spacingXS = spacingXS
        self.spacingS = spacingS
        self.spacingM = spacingM
        self.spacingL = spacingL
        self.spacingXL = spacingXL
        self.spacingXXL = spacingXXL
        self.buttonPaddingHorizontal = buttonPaddingHorizontal
        self.buttonPaddingVertical = buttonPaddingVertical
        self.cardPadding = cardPadding
        self.listItemSpacing = listItemSpacing
    }
}

// MARK: - Corner Radius Tokens

/// Corner radius design tokens for theme customization
public struct CornerRadiusTokens: Codable, Sendable {
    public var cornerRadiusS: Double?
    public var cornerRadiusM: Double?
    public var cornerRadiusL: Double?
    public var cornerRadiusXL: Double?

    // Component-specific corner radius
    public var buttonCornerRadius: Double?
    public var cardCornerRadius: Double?
    public var inputCornerRadius: Double?
    public var bubbleCornerRadius: Double?

    public init(
        cornerRadiusS: Double? = nil,
        cornerRadiusM: Double? = nil,
        cornerRadiusL: Double? = nil,
        cornerRadiusXL: Double? = nil,
        buttonCornerRadius: Double? = nil,
        cardCornerRadius: Double? = nil,
        inputCornerRadius: Double? = nil,
        bubbleCornerRadius: Double? = nil
    ) {
        self.cornerRadiusS = cornerRadiusS
        self.cornerRadiusM = cornerRadiusM
        self.cornerRadiusL = cornerRadiusL
        self.cornerRadiusXL = cornerRadiusXL
        self.buttonCornerRadius = buttonCornerRadius
        self.cardCornerRadius = cardCornerRadius
        self.inputCornerRadius = inputCornerRadius
        self.bubbleCornerRadius = bubbleCornerRadius
    }
}

// MARK: - Shadow Tokens

/// Shadow design tokens for theme customization
public struct ShadowTokens: Codable, Sendable {
    public var shadowLightColor: String?
    public var shadowLightOpacity: Double?
    public var shadowLightRadius: Double?
    public var shadowLightOffsetX: Double?
    public var shadowLightOffsetY: Double?

    public var shadowMediumColor: String?
    public var shadowMediumOpacity: Double?
    public var shadowMediumRadius: Double?
    public var shadowMediumOffsetX: Double?
    public var shadowMediumOffsetY: Double?

    public var shadowHeavyColor: String?
    public var shadowHeavyOpacity: Double?
    public var shadowHeavyRadius: Double?
    public var shadowHeavyOffsetX: Double?
    public var shadowHeavyOffsetY: Double?

    public init(
        shadowLightColor: String? = nil,
        shadowLightOpacity: Double? = nil,
        shadowLightRadius: Double? = nil,
        shadowLightOffsetX: Double? = nil,
        shadowLightOffsetY: Double? = nil,
        shadowMediumColor: String? = nil,
        shadowMediumOpacity: Double? = nil,
        shadowMediumRadius: Double? = nil,
        shadowMediumOffsetX: Double? = nil,
        shadowMediumOffsetY: Double? = nil,
        shadowHeavyColor: String? = nil,
        shadowHeavyOpacity: Double? = nil,
        shadowHeavyRadius: Double? = nil,
        shadowHeavyOffsetX: Double? = nil,
        shadowHeavyOffsetY: Double? = nil
    ) {
        self.shadowLightColor = shadowLightColor
        self.shadowLightOpacity = shadowLightOpacity
        self.shadowLightRadius = shadowLightRadius
        self.shadowLightOffsetX = shadowLightOffsetX
        self.shadowLightOffsetY = shadowLightOffsetY
        self.shadowMediumColor = shadowMediumColor
        self.shadowMediumOpacity = shadowMediumOpacity
        self.shadowMediumRadius = shadowMediumRadius
        self.shadowMediumOffsetX = shadowMediumOffsetX
        self.shadowMediumOffsetY = shadowMediumOffsetY
        self.shadowHeavyColor = shadowHeavyColor
        self.shadowHeavyOpacity = shadowHeavyOpacity
        self.shadowHeavyRadius = shadowHeavyRadius
        self.shadowHeavyOffsetX = shadowHeavyOffsetX
        self.shadowHeavyOffsetY = shadowHeavyOffsetY
    }
}
