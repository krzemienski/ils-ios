import SwiftUI

struct CarbonTheme: AppTheme {
    let name = "Carbon"
    let id = "carbon"

    // Backgrounds
    let bgPrimary = Color(hex: "0D0A12")
    let bgSecondary = Color(hex: "16121E")
    let bgTertiary = Color(hex: "201A2A")
    let bgSidebar = Color(hex: "0A080F")

    // Accent
    let accent = Color(hex: "8B5CF6")
    let accentSecondary = Color(hex: "A78BFA")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "A78BFA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E8E0F0")
    let textSecondary = Color(hex: "9088A0")
    let textTertiary = Color(hex: "585068")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "221A30")
    let borderSubtle = Color(hex: "1A1422")
    let divider = Color(hex: "1E182A")

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
