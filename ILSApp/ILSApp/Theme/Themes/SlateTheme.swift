import SwiftUI

struct SlateTheme: AppTheme {
    let name = "Slate"
    let id = "slate"

    // Backgrounds
    let bgPrimary = Color(hex: "0F1117")
    let bgSecondary = Color(hex: "161B26")
    let bgTertiary = Color(hex: "1E2433")
    let bgSidebar = Color(hex: "0C0F15")

    // Accent
    let accent = Color(hex: "3B82F6")
    let accentSecondary = Color(hex: "60A5FA")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "60A5FA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E2E8F0")
    let textSecondary = Color(hex: "94A3B8")
    let textTertiary = Color(hex: "7B8DA3")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1E293B")
    let borderSubtle = Color(hex: "151D2C")
    let divider = Color(hex: "1A2332")

    // Glass (dark theme = white opacity)
    let glassBackground = Color.white.opacity(0.05)
    let glassBorder = Color.white.opacity(0.10)

    // Geometry
    let cornerRadius: CGFloat = 12
    let cornerRadiusSmall: CGFloat = 8
    let cornerRadiusLarge: CGFloat = 20

    // Spacing
    let spacingXS: CGFloat = 4
    let spacingSM: CGFloat = 8
    let spacingMD: CGFloat = 16
    let spacingLG: CGFloat = 24
    let spacingXL: CGFloat = 32

    // Typography
    let fontCaption: CGFloat = 11
    let fontBody: CGFloat = 15
    let fontTitle3: CGFloat = 18
    let fontTitle2: CGFloat = 22
    let fontTitle1: CGFloat = 28
}
