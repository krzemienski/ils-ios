import SwiftUI

struct ObsidianTheme: AppTheme {
    let name = "Obsidian"
    let id = "obsidian"

    // Backgrounds
    let bgPrimary = Color(hex: "0A0A0F")
    let bgSecondary = Color(hex: "12121A")
    let bgTertiary = Color(hex: "1C1C28")
    let bgSidebar = Color(hex: "08080C")

    // Accent
    let accent = Color(hex: "FF6933")
    let accentSecondary = Color(hex: "FF8C5C")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "FF6933"), Color(hex: "FF8C5C")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E8ECF0")
    let textSecondary = Color(hex: "8892A0")
    let textTertiary = Color(hex: "505868")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1E2230")
    let borderSubtle = Color(hex: "141820")
    let divider = Color(hex: "1A1E28")

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
