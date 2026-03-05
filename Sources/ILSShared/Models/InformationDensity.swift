import Foundation

/// Information density level for UI spacing and typography.
/// Controls the amount of information shown per screen and the spacing between UI elements.
public enum InformationDensity: String, Codable, Hashable, Sendable {
    /// Compact density: minimal padding, smaller fonts, maximum information per screen.
    /// Ideal for power users monitoring multiple sessions on smaller devices.
    case compact

    /// Standard density: balanced spacing and readability.
    /// Default mode providing a good compromise between information density and comfort.
    case standard

    /// Comfortable density: generous spacing, larger fonts, enhanced readability.
    /// Ideal for extended reading sessions and code review on larger screens.
    case comfortable

    /// Human-readable display name for the density level.
    public var displayName: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .comfortable:
            return "Comfortable"
        }
    }

    /// Description of the density level's intended use case.
    public var description: String {
        switch self {
        case .compact:
            return "Maximum information per screen"
        case .standard:
            return "Balanced spacing and readability"
        case .comfortable:
            return "Enhanced readability for extended sessions"
        }
    }
}
