import SwiftUI

struct GhostProtocolTheme: AppTheme {
    let name = "Ghost Protocol"
    let id = "ghost-protocol"

    // Backgrounds
    let bgPrimary = Color(hex: "08080C")
    let bgSecondary = Color(hex: "101018")
    let bgTertiary = Color(hex: "181824")
    let bgSidebar = Color(hex: "06060A")

    // Accent
    let accent = Color(hex: "7DF9FF")
    let accentSecondary = Color(hex: "A0FCFF")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "7DF9FF"), Color(hex: "A0FCFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E0E4F0")
    let textSecondary = Color(hex: "808CA0")
    let textTertiary = Color(hex: "485068")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1A1E2E")
    let borderSubtle = Color(hex: "121622")
    let divider = Color(hex: "161A28")

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
