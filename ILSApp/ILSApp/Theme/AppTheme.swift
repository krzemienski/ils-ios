import SwiftUI
import Observation

// MARK: - AppTheme Protocol

/// Protocol defining a complete visual theme for the ILS app.
///
/// Themes provide colors, typography, spacing, and geometry tokens that create
/// a cohesive visual language throughout the app. All themes share consistent
/// entity colors for cross-theme familiarity.
///
/// ## Topics
/// ### Theme Identity
/// - ``name`` - Human-readable theme name
/// - ``id`` - Unique theme identifier
///
/// ### Color Tokens
/// - ``bgPrimary`` - Primary background color
/// - ``accent`` - Primary accent color
/// - ``textPrimary`` - Primary text color
/// - ``entitySession`` - Session entity color (blue)
/// - ``entityProject`` - Project entity color (purple)
///
/// ### Typography
/// - ``fontDesign`` - Font design (default, rounded, serif, monospaced)
/// - ``fontBody`` - Body text size
/// - ``fontTitle1`` - Largest title size
///
/// ### Geometry
/// - ``cornerRadius`` - Standard corner radius
/// - ``spacingMD`` - Medium spacing unit
protocol AppTheme {
    /// Human-readable theme name (e.g., "Cyberpunk").
    var name: String { get }
    /// Unique theme identifier (e.g., "cyberpunk").
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

    // MeshGradient (optional, only custom themes)
    var meshGradientColors: [String]? { get }
    var meshGradientAnimated: Bool { get }
}

// MARK: - Default Entity Colors (consistent across ALL themes)

/// Default entity color implementations for `AppTheme`.
///
/// These colors are consistent across all themes to maintain visual familiarity:
/// - Sessions: Blue (#3B82F6)
/// - Projects: Purple (#8B5CF6)
/// - Skills: Amber (#F59E0B)
/// - MCP Servers: Green (#10B981)
/// - Plugins: Pink (#EC4899)
/// - System: Cyan (#06B6D4)
extension AppTheme {
    /// Session entity color (blue).
    var entitySession: Color { Color(hex: "3B82F6") }
    /// Project entity color (purple).
    var entityProject: Color { Color(hex: "8B5CF6") }
    /// Skill entity color (amber).
    var entitySkill: Color { Color(hex: "F59E0B") }
    /// MCP server entity color (green).
    var entityMCP: Color { Color(hex: "10B981") }
    /// Plugin entity color (pink).
    var entityPlugin: Color { Color(hex: "EC4899") }
    /// System entity color (cyan).
    var entitySystem: Color { Color(hex: "06B6D4") }

    var fontDesign: Font.Design { .default }
    var isLight: Bool { false }
    var meshGradientColors: [String]? { nil }
    var meshGradientAnimated: Bool { false }
}

// MARK: - Theme Environment Key

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeSnapshot = ThemeSnapshot(CyberpunkTheme())
}

extension EnvironmentValues {
    var theme: ThemeSnapshot {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme Manager

/// Manages theme selection and persistence.
///
/// Maintains a list of available themes and persists the user's choice to UserDefaults.
/// Provides 13 built-in themes including Cyberpunk, Obsidian, and Ghost Protocol.
///
/// ## Topics
/// ### Properties
/// - ``currentTheme`` - Currently active theme
/// - ``availableThemes`` - All registered themes
///
/// ### Methods
/// - ``setTheme(_:)`` - Switch to a different theme by ID
/// - ``registerTheme(_:)`` - Register a custom theme
@MainActor
@Observable
class ThemeManager {
    /// Currently active theme (internal storage).
    @ObservationIgnored private var _currentTheme: any AppTheme = CyberpunkTheme()

    /// Currently active theme. Setting this automatically rebuilds the cached snapshot.
    var currentTheme: any AppTheme {
        get { _currentTheme }
        set {
            _currentTheme = newValue
            currentSnapshot = ThemeSnapshot(newValue)
        }
    }

    /// Concrete snapshot of the current theme for SwiftUI environment injection.
    /// Cached — only rebuilt when `currentTheme` changes via `setTheme()`.
    /// Eliminates existential container overhead in view bodies.
    private(set) var currentSnapshot: ThemeSnapshot = ThemeSnapshot(CyberpunkTheme())

    private static let themeIDKey = "selectedThemeID"

    // SPERF-02: `any AppTheme` here is by design -- the theme registry stores heterogeneous
    // theme types (built-in + imported). The hot path (view body reads) uses ThemeSnapshot
    // (concrete value type) via @Environment(\.theme), eliminating existential boxing in
    // render paths. The remaining `any AppTheme` usage in ThemeManager is limited to
    // theme selection/registration, which runs infrequently (user-initiated).

    /// All available themes.
    private(set) var availableThemes: [any AppTheme] = []

    /// Observer token for `iCloudPreferencesDidChange` notifications.
    @ObservationIgnored private var iCloudChangeObserver: NSObjectProtocol?

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
        let selectedTheme = themes.first(where: { $0.id == savedID }) ?? CyberpunkTheme()
        self._currentTheme = selectedTheme
        self.currentSnapshot = ThemeSnapshot(selectedTheme)

        // Listen for iCloud-driven theme changes so the active theme updates
        // immediately when another device selects a different theme.
        iCloudChangeObserver = NotificationCenter.default.addObserver(
            forName: .iCloudPreferencesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyThemeFromCloud()
            }
        }
    }

    deinit {
        if let observer = iCloudChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Switch to a different theme by ID.
    ///
    /// Persists the selection to UserDefaults and immediately pushes the change
    /// to the iCloud key-value store for cross-device sync.
    /// - Parameter id: Theme identifier (e.g., "cyberpunk")
    func setTheme(_ id: String) {
        guard let theme = availableThemes.first(where: { $0.id == id }) else { return }
        currentTheme = theme
        UserDefaults.standard.set(id, forKey: Self.themeIDKey)
        ICloudSyncManager.shared.set(id, forKey: AppConstants.iCloudActiveThemeKey)
    }

    /// Applies a theme change that arrived from iCloud.
    ///
    /// Reads the theme ID already written to UserDefaults by `applyCloudPreferences()`
    /// and updates the in-memory theme without re-pushing to iCloud.
    private func applyThemeFromCloud() {
        let themeID = UserDefaults.standard.string(forKey: Self.themeIDKey) ?? "cyberpunk"
        guard themeID != currentTheme.id,
              let theme = availableThemes.first(where: { $0.id == themeID }) else { return }
        currentTheme = theme
        AppLogger.shared.info("Theme '\(themeID)' applied from iCloud sync", category: "icloud")
    }

    /// Register a custom theme.
    /// - Parameter theme: Theme to register
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
        let int = UInt64(cleaned, radix: 16) ?? 0
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
