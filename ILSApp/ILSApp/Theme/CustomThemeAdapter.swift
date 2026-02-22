import SwiftUI
import ILSShared

// MARK: - Custom Theme Adapter

/// Adapts a `CustomTheme` (backend DTO with hex color strings) to the `AppTheme` protocol.
///
/// Any token that is nil in the `CustomTheme` falls back to the corresponding value from
/// a built-in fallback theme (Obsidian), so partial custom themes render correctly without
/// crashing on missing fields.
struct CustomThemeAdapter: AppTheme {
    private let customTheme: CustomTheme
    private let fallback: any AppTheme

    /// Creates an adapter for the given custom theme.
    /// - Parameters:
    ///   - customTheme: Backend custom theme DTO.
    ///   - fallback: Built-in theme used for any nil token values.
    init(_ customTheme: CustomTheme, fallback: any AppTheme = ObsidianTheme()) {
        self.customTheme = customTheme
        self.fallback = fallback
    }

    // MARK: - Identity

    var name: String { customTheme.name }
    var id: String { "custom-\(customTheme.id.uuidString.lowercased())" }

    // MARK: - Color Helpers

    private func color(_ hex: String?, fallback: Color) -> Color {
        guard let hex, !hex.isEmpty else { return fallback }
        return Color(hex: hex)
    }

    // MARK: - Backgrounds

    var bgPrimary: Color {
        color(customTheme.colors?.background, fallback: fallback.bgPrimary)
    }

    var bgSecondary: Color {
        color(customTheme.colors?.secondaryBackground, fallback: fallback.bgSecondary)
    }

    var bgTertiary: Color {
        color(customTheme.colors?.tertiaryBackground, fallback: fallback.bgTertiary)
    }

    var bgSidebar: Color {
        // Use secondaryBackground as sidebar bg — most custom themes don't have dedicated sidebar color
        color(customTheme.colors?.secondaryBackground, fallback: fallback.bgSidebar)
    }

    // MARK: - Accent

    var accent: Color {
        color(customTheme.colors?.accent, fallback: fallback.accent)
    }

    var accentSecondary: Color {
        // Derive from accent with reduced opacity
        accent.opacity(0.7)
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Text

    var textPrimary: Color {
        color(customTheme.colors?.primaryText, fallback: fallback.textPrimary)
    }

    var textSecondary: Color {
        color(customTheme.colors?.secondaryText, fallback: fallback.textSecondary)
    }

    var textTertiary: Color {
        color(customTheme.colors?.tertiaryText, fallback: fallback.textTertiary)
    }

    var textOnAccent: Color {
        // White on dark accents, black on light accents — use fallback
        fallback.textOnAccent
    }

    // MARK: - Semantic

    var success: Color {
        color(customTheme.colors?.success, fallback: fallback.success)
    }

    var warning: Color {
        color(customTheme.colors?.warning, fallback: fallback.warning)
    }

    var error: Color {
        color(customTheme.colors?.error, fallback: fallback.error)
    }

    var info: Color {
        color(customTheme.colors?.info, fallback: fallback.info)
    }

    // MARK: - Borders & Dividers

    var border: Color {
        color(customTheme.colors?.border, fallback: fallback.border)
    }

    var borderSubtle: Color {
        color(customTheme.colors?.border, fallback: fallback.borderSubtle).opacity(0.5)
    }

    var divider: Color {
        color(customTheme.colors?.separator, fallback: fallback.divider)
    }

    // MARK: - Glass

    var glassBackground: Color {
        bgSecondary.opacity(0.6)
    }

    var glassBorder: Color {
        border.opacity(0.3)
    }

    // MARK: - Geometry

    var cornerRadius: CGFloat {
        CGFloat(customTheme.cornerRadius?.cardCornerRadius ?? customTheme.cornerRadius?.cornerRadiusM ?? 12)
    }

    var cornerRadiusSmall: CGFloat {
        CGFloat(customTheme.cornerRadius?.cornerRadiusS ?? 8)
    }

    var cornerRadiusLarge: CGFloat {
        CGFloat(customTheme.cornerRadius?.cornerRadiusL ?? 20)
    }

    // MARK: - Spacing

    var spacingXS: CGFloat {
        CGFloat(customTheme.spacing?.spacingXS ?? 4)
    }

    var spacingSM: CGFloat {
        CGFloat(customTheme.spacing?.spacingS ?? 8)
    }

    var spacingMD: CGFloat {
        CGFloat(customTheme.spacing?.spacingM ?? 16)
    }

    var spacingLG: CGFloat {
        CGFloat(customTheme.spacing?.spacingL ?? 24)
    }

    var spacingXL: CGFloat {
        CGFloat(customTheme.spacing?.spacingXL ?? 32)
    }

    // MARK: - Typography

    var fontCaption: CGFloat {
        CGFloat(customTheme.typography?.captionSize ?? Double(fallback.fontCaption))
    }

    var fontBody: CGFloat {
        CGFloat(customTheme.typography?.bodySize ?? Double(fallback.fontBody))
    }

    var fontTitle3: CGFloat {
        CGFloat(customTheme.typography?.headlineSize ?? Double(fallback.fontTitle3))
    }

    var fontTitle2: CGFloat {
        CGFloat(customTheme.typography?.headlineSize ?? Double(fallback.fontTitle2))
    }

    var fontTitle1: CGFloat {
        CGFloat(customTheme.typography?.titleSize ?? Double(fallback.fontTitle1))
    }

    var fontDesign: Font.Design {
        switch customTheme.typography?.primaryFontFamily?.lowercased() {
        case "monospaced", "mono": return .monospaced
        case "rounded": return .rounded
        case "serif": return .serif
        default: return fallback.fontDesign
        }
    }

    var isLight: Bool {
        // Detect light theme based on background brightness
        guard let bgHex = customTheme.colors?.background else {
            return fallback.isLight
        }
        let bg = Color(hex: bgHex)
        // Simple heuristic: if the hex value is > 0xAAAAAA it's likely light
        let cleaned = bgHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 6, let value = UInt64(cleaned, radix: 16) {
            let r = (value >> 16) & 0xFF
            let g = (value >> 8) & 0xFF
            let b = value & 0xFF
            let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255.0
            return luminance > 0.5
        }
        _ = bg  // suppress warning
        return fallback.isLight
    }
}

// MARK: - ThemeManager Extension

extension ThemeManager {
    /// Load custom themes from the backend and register them.
    /// Call this after app launch when the API client is available.
    func loadAndRegisterCustomThemes(client: APIClient) async {
        do {
            let response: APIResponse<ListResponse<CustomTheme>> = try await client.get("/themes")
            guard let themes = response.data?.items else { return }

            for customTheme in themes {
                let adapter = CustomThemeAdapter(customTheme)
                registerTheme(adapter)
            }
        } catch {
            // Custom theme loading is non-critical — built-in themes still work
            AppLogger.shared.error("Failed to load custom themes: \(error.localizedDescription)", category: "themes")
        }
    }
}
