import SwiftUI

struct CyberpunkTheme: AppTheme {
    let name = "Cyberpunk"
    let id = "cyberpunk"

    // Backgrounds — near-black with subtle blue undertones
    let bgPrimary = Color(hex: "030306")
    let bgSecondary = Color(hex: "07070c")
    let bgTertiary = Color(hex: "0b0b12")
    let bgSidebar = Color(hex: "07070c")

    // Accent — neon cyan + magenta
    let accent = Color(hex: "00fff2")
    let accentSecondary = Color(hex: "ff00ff")
    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "00fff2"), Color(hex: "ff00ff")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Text
    let textPrimary = Color.white
    let textSecondary = Color(hex: "a0a0b0")
    let textTertiary = Color(hex: "9595b8")
    let textOnAccent = Color.black

    // Semantic — neon variants
    let success = Color(hex: "00ff88")
    let warning = Color(hex: "ffd000")
    let error = Color(hex: "ff3366")
    let info = Color(hex: "a855f7")

    // Borders
    let border = Color(hex: "1a1a2e")
    let borderSubtle = Color(hex: "1a1a2e")
    let divider = Color(hex: "1a1a2e")

    // Entity Colors — neon overrides
    let entitySession = Color(hex: "00fff2")   // cyan
    let entityProject = Color(hex: "ff00ff")   // magenta
    let entitySkill = Color(hex: "ffd000")     // yellow
    let entityMCP = Color(hex: "a855f7")       // purple
    let entityPlugin = Color(hex: "00ff88")    // green
    let entitySystem = Color(hex: "ff6b00")    // orange

    // Glass
    let glassBackground = Color(hex: "09090f")
    let glassBorder = Color(hex: "1a1a2e")

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

    // Typography sizes
    let fontCaption: CGFloat = 11
    let fontBody: CGFloat = 15
    let fontTitle3: CGFloat = 18
    let fontTitle2: CGFloat = 22
    let fontTitle1: CGFloat = 28

    // Typography — monospaced for terminal aesthetic
    let fontDesign: Font.Design = .monospaced
}
