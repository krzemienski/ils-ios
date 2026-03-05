import SwiftUI
import ILSShared

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
///
/// ## Accessibility Notes
/// - ACC-MED-2: Contrast ratios are not validated at compile time. Theme authors should verify
///   WCAG AA (4.5:1 body text, 3:1 large text) using the Xcode Accessibility Inspector.
///   Future: add a `contrastRatio(_:on:)` helper and flag violations in ThemeEditorView.
/// - ACC-MED-5: Font sizes use theme tokens (`fontBody`, `fontCaption`, etc.) which scale with
///   Dynamic Type via `.dynamicTypeSize(...)` modifiers. Full Dynamic Type audit (all screens)
///   is tracked as future work.
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

    // MARK: - MeshGradient

    /// Optional MeshGradient background color hex strings (9 colors for 3x3 grid).
    /// Nil means no mesh gradient; use standard background.
    let meshGradientColors: [String]?
    let meshGradientAnimated: Bool

    // MARK: - Density

    /// Information density level affecting spacing and typography.
    let density: InformationDensity

    /// Multiplier applied to all spacing values based on density level.
    /// - Compact: 0.85 (tighter spacing)
    /// - Standard: 1.0 (baseline)
    /// - Comfortable: 1.15 (generous spacing)
    var spacingMultiplier: CGFloat {
        switch density {
        case .compact:
            return 0.85
        case .standard:
            return 1.0
        case .comfortable:
            return 1.15
        }
    }

    /// Multiplier applied to all font sizes based on density level.
    /// - Compact: 0.90 (smaller fonts)
    /// - Standard: 1.0 (baseline)
    /// - Comfortable: 1.10 (larger fonts)
    var fontSizeMultiplier: CGFloat {
        switch density {
        case .compact:
            return 0.90
        case .standard:
            return 1.0
        case .comfortable:
            return 1.10
        }
    }

    // MARK: - Init from Protocol

    /// Creates a snapshot by copying all properties from an `AppTheme` conforming type.
    /// This is the only place existential dispatch occurs — once at snapshot creation,
    /// not on every view body evaluation.
    ///
    /// - Parameters:
    ///   - source: The theme to snapshot
    ///   - density: Information density level (defaults to .standard)
    init(_ source: any AppTheme, density: InformationDensity = .standard) {
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

        // MeshGradient — reads from AppTheme protocol; custom themes provide via CustomThemeAdapter
        self.meshGradientColors = source.meshGradientColors
        self.meshGradientAnimated = source.meshGradientAnimated

        // Density
        self.density = density
    }

}
