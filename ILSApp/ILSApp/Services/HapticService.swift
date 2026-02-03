import UIKit

/// Provides standardized haptic feedback for user actions
@MainActor
class HapticService {
    static let shared = HapticService()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for reduced latency
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
    }

    // MARK: - Impact Feedback

    /// Light impact feedback for subtle interactions (e.g., button taps, list selections)
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact feedback for standard interactions (e.g., sending messages, confirmations)
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Heavy impact feedback for significant interactions (e.g., deleting items, major actions)
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    // MARK: - Notification Feedback

    /// Success feedback for completed actions (e.g., message sent, operation succeeded)
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Warning feedback for cautionary actions (e.g., validation errors, warnings)
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// Error feedback for failed actions (e.g., network errors, operation failures)
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
}
