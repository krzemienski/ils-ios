import Foundation
import Observation

// MARK: - FeatureGate

/// Gates access to premium features based on the user's subscription status.
///
/// Provides a single source of truth for feature availability. Free-tier users
/// have access to core functionality with limits; premium users unlock all features.
///
/// ## Usage
/// ```swift
/// if FeatureGate.shared.isAvailable(.chatExport) {
///     // Show export button
/// }
/// ```
@MainActor
@Observable
final class FeatureGate {
    static let shared = FeatureGate()

    private let subscriptionManager = SubscriptionManager.shared

    // MARK: - Premium Status

    /// Whether the user has an active premium subscription.
    var isPremium: Bool { subscriptionManager.isPremium }

    // MARK: - Feature Definitions

    /// Premium features that can be gated.
    enum Feature: String, CaseIterable, Sendable {
        /// Export chat transcripts as Markdown or PDF.
        case chatExport
        /// Access to all 13 visual themes (free tier gets 3).
        case customThemes
        /// System monitoring with real-time metrics.
        case advancedMonitoring
        /// Unlimited concurrent sessions (free tier: 5).
        case unlimitedSessions
    }

    // MARK: - Feature Availability

    /// Checks whether a feature is available for the current user.
    /// - Parameter feature: The feature to check.
    /// - Returns: `true` if the feature is available.
    func isAvailable(_ feature: Feature) -> Bool {
        switch feature {
        case .chatExport, .customThemes, .advancedMonitoring:
            return isPremium
        case .unlimitedSessions:
            return isPremium
        }
    }

    // MARK: - Constants

    /// Maximum number of sessions for free-tier users.
    static let freeSessionLimit = 5

    // MARK: - Init

    private init() {}
}
