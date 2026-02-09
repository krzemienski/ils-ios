import SwiftUI

struct ObsidianTheme: AppTheme {
    let name = "Obsidian"
    let id = "obsidian"

    // Backgrounds — pure black base
    let bgPrimary = Color(hex: "000000")
    let bgSecondary = Color(hex: "111111")
    let bgTertiary = Color(hex: "0D0D0D")
    let bgSidebar = Color(hex: "000000")

    // Accent — hot orange
    let accent = Color(hex: "FF6933")
    let accentSecondary = Color(hex: "FF8C5C")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "FF6933"), Color(hex: "FF8C5C")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E8ECF0")
    let textSecondary = Color(hex: "777777")
    let textTertiary = Color(hex: "808080")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders — very subtle on black
    let border = Color(hex: "1A1A1A")
    let borderSubtle = Color(hex: "1A1A1A")
    let divider = Color(hex: "1A1A1A")

    // Glass — minimal, near-invisible on black
    let glassBackground = Color(hex: "111111")
    let glassBorder = Color(hex: "1A1A1A")

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
