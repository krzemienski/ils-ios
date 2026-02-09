import SwiftUI

struct PaperTheme: AppTheme {
    let name = "Paper"
    let id = "paper"
    let isLight = true

    // Backgrounds
    let bgPrimary = Color(hex: "FAFAF9")
    let bgSecondary = Color(hex: "F0F0EE")
    let bgTertiary = Color(hex: "E4E4E2")
    let bgSidebar = Color(hex: "F4F4F2")

    // Accent
    let accent = Color(hex: "EA580C")
    let accentSecondary = Color(hex: "F97316")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "EA580C"), Color(hex: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "1A1A18")
    let textSecondary = Color(hex: "6B6B68")
    let textTertiary = Color(hex: "757572")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "D4D4D0")
    let borderSubtle = Color(hex: "E2E2DE")
    let divider = Color(hex: "DADAD6")

    // Glass (light theme = black opacity)
    let glassBackground = Color.black.opacity(0.05)
    let glassBorder = Color.black.opacity(0.10)

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
