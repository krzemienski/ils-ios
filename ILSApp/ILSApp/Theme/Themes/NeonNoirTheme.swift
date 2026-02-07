import SwiftUI

struct NeonNoirTheme: AppTheme {
    let name = "Neon Noir"
    let id = "neon-noir"

    // Backgrounds
    let bgPrimary = Color(hex: "0A0A0F")
    let bgSecondary = Color(hex: "111118")
    let bgTertiary = Color(hex: "1A1A24")
    let bgSidebar = Color(hex: "07070C")

    // Accent
    let accent = Color(hex: "00D4FF")
    let accentSecondary = Color(hex: "33DFFF")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "00D4FF"), Color(hex: "33DFFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E0E8F0")
    let textSecondary = Color(hex: "8090A0")
    let textTertiary = Color(hex: "485060")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1C1E2C")
    let borderSubtle = Color(hex: "14161E")
    let divider = Color(hex: "181A26")

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
