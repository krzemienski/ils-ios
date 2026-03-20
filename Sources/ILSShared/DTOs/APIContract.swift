import Foundation

// MARK: - API Contract Version

/// The current API contract version shared between the ILS backend and iOS/macOS clients.
///
/// Increment this constant whenever a breaking change is made to the shared DTOs
/// or backend endpoint contracts, so clients can detect mismatches at runtime.
public enum APIContractVersion {
    /// Current API contract version string (semver).
    public static let current: String = "1.0.0"

    /// Integer representation used for numeric comparisons.
    public static let major: Int = 1
    public static let minor: Int = 0
    public static let patch: Int = 0
}
