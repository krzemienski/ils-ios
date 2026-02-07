import SwiftUI

struct CrimsonTheme: AppTheme {
    let name = "Crimson"
    let id = "crimson"

    // Backgrounds
    let bgPrimary = Color(hex: "0F0A0A")
    let bgSecondary = Color(hex: "1A1212")
    let bgTertiary = Color(hex: "241A1A")
    let bgSidebar = Color(hex: "0C0808")

    // Accent
    let accent = Color(hex: "EF4444")
    let accentSecondary = Color(hex: "F87171")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "F87171")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "F0E0E0")
    let textSecondary = Color(hex: "A08888")
    let textTertiary = Color(hex: "685050")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "2A1818")
    let borderSubtle = Color(hex: "1E1212")
    let divider = Color(hex: "241616")

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
