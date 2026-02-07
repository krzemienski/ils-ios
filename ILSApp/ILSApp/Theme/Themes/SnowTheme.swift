import SwiftUI

struct SnowTheme: AppTheme {
    let name = "Snow"
    let id = "snow"
    let isLight = true

    // Backgrounds
    let bgPrimary = Color(hex: "FAFBFF")
    let bgSecondary = Color(hex: "F0F2FA")
    let bgTertiary = Color(hex: "E4E6F0")
    let bgSidebar = Color(hex: "F4F5FC")

    // Accent
    let accent = Color(hex: "2563EB")
    let accentSecondary = Color(hex: "3B82F6")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "3B82F6")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "0F172A")
    let textSecondary = Color(hex: "475569")
    let textTertiary = Color(hex: "94A3B8")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "CBD5E1")
    let borderSubtle = Color(hex: "E2E8F0")
    let divider = Color(hex: "D1D9E6")

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
