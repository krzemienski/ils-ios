#if os(iOS)
import UIKit

enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
#else
enum HapticManager {
    enum FeedbackStyle { case light, medium, heavy, rigid, soft }
    enum FeedbackType { case success, warning, error }

    static func impact(_ style: FeedbackStyle = .medium) {
        // No haptics on macOS
    }

    static func notification(_ type: FeedbackType) {
        // No haptics on macOS
    }

    static func selection() {
        // No haptics on macOS
    }
}
#endif
