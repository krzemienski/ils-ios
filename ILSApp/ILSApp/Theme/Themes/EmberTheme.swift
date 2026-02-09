import SwiftUI

struct EmberTheme: AppTheme {
    let name = "Ember"
    let id = "ember"

    // Backgrounds
    let bgPrimary = Color(hex: "0F0D0A")
    let bgSecondary = Color(hex: "1A1610")
    let bgTertiary = Color(hex: "24201A")
    let bgSidebar = Color(hex: "0C0A08")

    // Accent
    let accent = Color(hex: "F59E0B")
    let accentSecondary = Color(hex: "FBBF24")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "FBBF24")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "F0E8E0")
    let textSecondary = Color(hex: "A09080")
    let textTertiary = Color(hex: "8E8678")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "FBBF24")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "2A2418")
    let borderSubtle = Color(hex: "1E1A12")
    let divider = Color(hex: "241E16")

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
