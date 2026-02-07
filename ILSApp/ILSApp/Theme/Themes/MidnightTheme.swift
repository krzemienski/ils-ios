import SwiftUI

struct MidnightTheme: AppTheme {
    let name = "Midnight"
    let id = "midnight"

    // Backgrounds
    let bgPrimary = Color(hex: "0A0F0D")
    let bgSecondary = Color(hex: "111A16")
    let bgTertiary = Color(hex: "1A2620")
    let bgSidebar = Color(hex: "080C0A")

    // Accent
    let accent = Color(hex: "10B981")
    let accentSecondary = Color(hex: "34D399")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "34D399")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E2F0E8")
    let textSecondary = Color(hex: "8AA898")
    let textTertiary = Color(hex: "506860")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1E302B")
    let borderSubtle = Color(hex: "15231E")
    let divider = Color(hex: "1A2B25")

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
