import Foundation

// MARK: - Theme Manifest

/// Codable model for theme import/export via JSON files.
///
/// Provides a portable format for sharing themes between users. Contains
/// all color hex values needed to reconstruct a theme along with metadata
/// about the theme author and version.
struct ThemeManifest: Codable, Sendable {
    /// Human-readable theme name.
    let name: String
    /// Theme author or creator.
    let author: String
    /// Semantic version string.
    let version: String
    /// Brief description of the theme style.
    let description: String
    /// Color hex values defining the theme palette.
    let colors: ThemeColors

    /// Color tokens stored as hex strings for portability.
    struct ThemeColors: Codable, Sendable {
        /// Primary background hex color (e.g., "#030306").
        let background: String
        /// Secondary background hex color.
        let backgroundSecondary: String
        /// Primary accent hex color.
        let accent: String
        /// Primary text hex color.
        let text: String
        /// Secondary text hex color.
        let textSecondary: String
        /// Border hex color.
        let border: String
    }
}
