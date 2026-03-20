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
/// - ACC-MED-2: Contrast ratios can be validated at runtime using `ContrastChecker.meetsWCAGAA()`
///   from `AccessibilityHelpers.swift`. Theme authors should verify WCAG AA compliance
///   (4.5:1 body text, 3:1 large text) using the checker or Xcode Accessibility Inspector.
/// - ACC-MED-5: Font sizes use theme tokens (`fontBody`, `fontCaption`, etc.) which scale with
///   Dynamic Type via `.dynamicTypeSize(...)` modifiers. Views should use `@ScaledMetric` for
///   padding/spacing values and the `scaledPadding(_:)` modifier from `AccessibilityHelpers.swift`.
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

        // Density — must be set before spacing/font calculations
        self.density = density

        // Apply density multipliers to spacing values
        let spacingMult: CGFloat
        switch density {
        case .compact: spacingMult = 0.85
        case .standard: spacingMult = 1.0
        case .comfortable: spacingMult = 1.15
        }

        self.spacingXS = source.spacingXS * spacingMult
        self.spacingSM = source.spacingSM * spacingMult
        self.spacingMD = source.spacingMD * spacingMult
        self.spacingLG = source.spacingLG * spacingMult
        self.spacingXL = source.spacingXL * spacingMult

        // Apply density multipliers to font sizes
        let fontMult: CGFloat
        switch density {
        case .compact: fontMult = 0.90
        case .standard: fontMult = 1.0
        case .comfortable: fontMult = 1.10
        }

        // Dynamic Type baseline floors: compact density must never produce font sizes
        // smaller than these iOS-recommended minimums. The app sets
        // `.dynamicTypeSize(.xSmall ... .accessibility3)` to allow Dynamic Type scaling,
        // and these floors ensure readability is preserved at all density levels.
        // Values correspond to iOS default sizes for the matching text style at the
        // `medium` content-size category (system default).
        //
        // Note: Full Dynamic Type scaling for large accessibility sizes is tracked as
        // future work (ACC-MED-5). The floor prevents compact mode from actively
        // harming users who rely on system font sizing.
        let minCaption: CGFloat = 11   // .caption1 minimum
        let minBody: CGFloat = 13      // .body minimum for compact density
        let minTitle3: CGFloat = 15    // .title3 minimum for compact density
        let minTitle2: CGFloat = 19    // .title2 minimum for compact density
        let minTitle1: CGFloat = 24    // .title minimum for compact density

        self.fontCaption = max(source.fontCaption * fontMult, minCaption)
        self.fontBody = max(source.fontBody * fontMult, minBody)
        self.fontTitle3 = max(source.fontTitle3 * fontMult, minTitle3)
        self.fontTitle2 = max(source.fontTitle2 * fontMult, minTitle2)
        self.fontTitle1 = max(source.fontTitle1 * fontMult, minTitle1)

        self.fontDesign = source.fontDesign
        self.isLight = source.isLight

        // MeshGradient — reads from AppTheme protocol; custom themes provide via CustomThemeAdapter
        self.meshGradientColors = source.meshGradientColors
        self.meshGradientAnimated = source.meshGradientAnimated
    }

    // MARK: - Contrast Validation

    /// Validates the primary text/background color pairs against WCAG AA requirements.
    ///
    /// Returns an array of human-readable violation descriptions. An empty array means
    /// all checked pairs pass.
    ///
    /// Checked pairs:
    /// - `textPrimary` on `bgPrimary` (body text, 4.5:1)
    /// - `textSecondary` on `bgPrimary` (body text, 4.5:1)
    /// - `textOnAccent` on `accent` (large text, 3:1)
    func contrastViolations() -> [String] {
        var violations: [String] = []

        let pairs: [(String, Color, Color, Bool)] = [
            ("textPrimary on bgPrimary", textPrimary, bgPrimary, false),
            ("textSecondary on bgPrimary", textSecondary, bgPrimary, false),
            ("textPrimary on bgSecondary", textPrimary, bgSecondary, false),
            ("textOnAccent on accent", textOnAccent, accent, true),
        ]

        for (name, fg, bg, isLarge) in pairs {
            let ratio = ContrastChecker.contrastRatio(fg, on: bg)
            let minimum = isLarge ? ContrastChecker.wcagAALargeTextMinimum : ContrastChecker.wcagAABodyMinimum
            if ratio < minimum {
                violations.append(
                    "\(name): \(String(format: "%.2f", ratio)):1 (requires \(String(format: "%.1f", minimum)):1)"
                )
            }
        }

        return violations
    }

}
