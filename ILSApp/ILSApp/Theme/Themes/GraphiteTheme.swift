import SwiftUI

struct GraphiteTheme: AppTheme {
    let name = "Graphite"
    let id = "graphite"

    // Backgrounds
    let bgPrimary = Color(hex: "0A0F0F")
    let bgSecondary = Color(hex: "121A1A")
    let bgTertiary = Color(hex: "1A2424")
    let bgSidebar = Color(hex: "080C0C")

    // Accent
    let accent = Color(hex: "14B8A6")
    let accentSecondary = Color(hex: "2DD4BF")
    var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: "14B8A6"), Color(hex: "2DD4BF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // Text
    let textPrimary = Color(hex: "E0F0F0")
    let textSecondary = Color(hex: "88A0A0")
    let textTertiary = Color(hex: "506060")
    let textOnAccent = Color.white

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "EAB308")
    let error = Color(hex: "EF4444")
    let info = Color(hex: "3B82F6")

    // Borders
    let border = Color(hex: "1A2828")
    let borderSubtle = Color(hex: "141E1E")
    let divider = Color(hex: "182424")

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
