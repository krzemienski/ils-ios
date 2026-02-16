import SwiftUI

// MARK: - ThemeSnapshot

/// Concrete value-type replacement for `any AppTheme` existential containers.
///
/// SwiftUI environments using `any AppTheme` create existential container overhead
/// on every view body evaluation (~82 sites). `ThemeSnapshot` captures all theme
/// properties into a concrete struct, eliminating dynamic dispatch and existential
/// boxing costs.
///
/// ## Usage
/// ```swift
/// // Before (existential container on every access):
/// @Environment(\.theme) private var theme: any AppTheme
///
/// // After (zero-cost struct access):
/// @Environment(\.theme) private var theme: ThemeSnapshot
/// ```
struct ThemeSnapshot: Sendable {
    // MARK: - Identity

    let name: String
    let id: String

    // MARK: - Backgrounds

    let bgPrimary: Color
    let bgSecondary: Color
    let bgTertiary: Color
    let bgSidebar: Color

    // MARK: - Accent

    let accent: Color
    let accentSecondary: Color
    let accentGradient: LinearGradient

    // MARK: - Text

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textOnAccent: Color

    // MARK: - Semantic

    let success: Color
    let warning: Color
    let error: Color
    let info: Color

    // MARK: - Borders & Dividers

    let border: Color
    let borderSubtle: Color
    let divider: Color

    // MARK: - Entity Colors

    let entitySession: Color
    let entityProject: Color
    let entitySkill: Color
    let entityMCP: Color
    let entityPlugin: Color
    let entitySystem: Color

    // MARK: - Glass

    let glassBackground: Color
    let glassBorder: Color

    // MARK: - Geometry

    let cornerRadius: CGFloat
    let cornerRadiusSmall: CGFloat
    let cornerRadiusLarge: CGFloat

    // MARK: - Spacing

    let spacingXS: CGFloat
    let spacingSM: CGFloat
    let spacingMD: CGFloat
    let spacingLG: CGFloat
    let spacingXL: CGFloat

    // MARK: - Typography Sizes

    let fontCaption: CGFloat
    let fontBody: CGFloat
    let fontTitle3: CGFloat
    let fontTitle2: CGFloat
    let fontTitle1: CGFloat

    // MARK: - Typography

    let fontDesign: Font.Design
    let isLight: Bool

    // MARK: - Init from Protocol

    /// Creates a snapshot by copying all properties from an `AppTheme` conforming type.
    /// This is the only place existential dispatch occurs — once at snapshot creation,
    /// not on every view body evaluation.
    init(_ source: any AppTheme) {
        self.name = source.name
        self.id = source.id

        self.bgPrimary = source.bgPrimary
        self.bgSecondary = source.bgSecondary
        self.bgTertiary = source.bgTertiary
        self.bgSidebar = source.bgSidebar

        self.accent = source.accent
        self.accentSecondary = source.accentSecondary
        self.accentGradient = source.accentGradient

        self.textPrimary = source.textPrimary
        self.textSecondary = source.textSecondary
        self.textTertiary = source.textTertiary
        self.textOnAccent = source.textOnAccent

        self.success = source.success
        self.warning = source.warning
        self.error = source.error
        self.info = source.info

        self.border = source.border
        self.borderSubtle = source.borderSubtle
        self.divider = source.divider

        self.entitySession = source.entitySession
        self.entityProject = source.entityProject
        self.entitySkill = source.entitySkill
        self.entityMCP = source.entityMCP
        self.entityPlugin = source.entityPlugin
        self.entitySystem = source.entitySystem

        self.glassBackground = source.glassBackground
        self.glassBorder = source.glassBorder

        self.cornerRadius = source.cornerRadius
        self.cornerRadiusSmall = source.cornerRadiusSmall
        self.cornerRadiusLarge = source.cornerRadiusLarge

        self.spacingXS = source.spacingXS
        self.spacingSM = source.spacingSM
        self.spacingMD = source.spacingMD
        self.spacingLG = source.spacingLG
        self.spacingXL = source.spacingXL

        self.fontCaption = source.fontCaption
        self.fontBody = source.fontBody
        self.fontTitle3 = source.fontTitle3
        self.fontTitle2 = source.fontTitle2
        self.fontTitle1 = source.fontTitle1

        self.fontDesign = source.fontDesign
        self.isLight = source.isLight
    }
}
