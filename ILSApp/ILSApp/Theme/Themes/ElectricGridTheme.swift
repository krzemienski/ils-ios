import SwiftUI

struct ElectricGridTheme: AppTheme {
    let name = "Electric Grid"
    let id = "electric-grid"

    // Backgrounds
    let bgPrimary = Color(hex: "050510")
    let bgSecondary = Color(hex: "0C0C1A")
    let bgTertiary = Color(hex: "141424")
    let bgSidebar = Color(hex: "04040C")

    // Accent
    let accent = Color(hex: "00FF88")
    let accentSecondary = Color(hex: "33FFAA")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "00FF88"), Color(hex: "33FFAA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "D8E8E0")
    let textSecondary = Color(hex: "7898A0")
    let textTertiary = Color(hex: "405860")
    let textOnAccent = Color(hex: "050510")

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "141828")
    let borderSubtle = Color(hex: "0E1218")
    let divider = Color(hex: "121620")

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
