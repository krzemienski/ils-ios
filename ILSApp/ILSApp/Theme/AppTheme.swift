import SwiftUI

// MARK: - AppTheme Protocol

protocol AppTheme {
    var name: String { get }
    var id: String { get }

    // Backgrounds
    var bgPrimary: Color { get }
    var bgSecondary: Color { get }
    var bgTertiary: Color { get }
    var bgSidebar: Color { get }

    // Accent
    var accent: Color { get }
    var accentSecondary: Color { get }
    var accentGradient: LinearGradient { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textOnAccent: Color { get }

    // Semantic
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var info: Color { get }

    // Borders & Dividers
    var border: Color { get }
    var borderSubtle: Color { get }
    var divider: Color { get }

    // Entity Colors (consistent across themes)
    var entitySession: Color { get }
    var entityProject: Color { get }
    var entitySkill: Color { get }
    var entityMCP: Color { get }
    var entityPlugin: Color { get }
    var entitySystem: Color { get }

    // Glass
    var glassBackground: Color { get }
    var glassBorder: Color { get }

    // Geometry
    var cornerRadius: CGFloat { get }
    var cornerRadiusSmall: CGFloat { get }
    var cornerRadiusLarge: CGFloat { get }

    // Spacing
    var spacingXS: CGFloat { get }
    var spacingSM: CGFloat { get }
    var spacingMD: CGFloat { get }
    var spacingLG: CGFloat { get }
    var spacingXL: CGFloat { get }

    // Typography sizes
    var fontCaption: CGFloat { get }
    var fontBody: CGFloat { get }
    var fontTitle3: CGFloat { get }
    var fontTitle2: CGFloat { get }
    var fontTitle1: CGFloat { get }

    // Typography
    var fontDesign: Font.Design { get }

    // Light/dark detection for glass inversion
    var isLight: Bool { get }
}

// MARK: - Default Entity Colors (consistent across ALL themes)

extension AppTheme {
    var entitySession: Color { Color(hex: "3B82F6") }
    var entityProject: Color { Color(hex: "8B5CF6") }
    var entitySkill: Color { Color(hex: "F59E0B") }
    var entityMCP: Color { Color(hex: "10B981") }
    var entityPlugin: Color { Color(hex: "EC4899") }
    var entitySystem: Color { Color(hex: "06B6D4") }

    var fontDesign: Font.Design { .default }
    var isLight: Bool { false }
}

// MARK: - Theme Environment Key

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: any AppTheme = CyberpunkTheme()
}

extension EnvironmentValues {
    var theme: any AppTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: any AppTheme

    private static let themeIDKey = "selectedThemeID"

    private(set) var availableThemes: [any AppTheme] = []

    init() {
        // Migrate legacy theme IDs from before the rename
        var savedID = UserDefaults.standard.string(forKey: Self.themeIDKey) ?? "cyberpunk"
        let legacyMigrations = ["ghost": "ghost-protocol", "electric": "electric-grid"]
        if let migrated = legacyMigrations[savedID] {
            savedID = migrated
            UserDefaults.standard.set(migrated, forKey: Self.themeIDKey)
        }
        let themes: [any AppTheme] = [
            CyberpunkTheme(),
            ObsidianTheme(),
            SlateTheme(),
            MidnightTheme(),
            GhostProtocolTheme(),
            NeonNoirTheme(),
            ElectricGridTheme(),
            EmberTheme(),
            CrimsonTheme(),
            CarbonTheme(),
            GraphiteTheme(),
            PaperTheme(),
            SnowTheme()
        ]
        self.availableThemes = themes
        self.currentTheme = themes.first(where: { $0.id == savedID }) ?? CyberpunkTheme()
    }

    func setTheme(_ id: String) {
        guard let theme = availableThemes.first(where: { $0.id == id }) else { return }
        currentTheme = theme
        UserDefaults.standard.set(id, forKey: Self.themeIDKey)
    }

    func registerTheme(_ theme: any AppTheme) {
        if !availableThemes.contains(where: { $0.id == theme.id }) {
            availableThemes.append(theme)
        }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
