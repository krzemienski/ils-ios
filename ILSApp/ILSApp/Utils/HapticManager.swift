#if os(iOS)
import UIKit

enum HapticManager {
    // CONC-26: @MainActor required — UIKit feedback generators must be created and triggered
    // on the main thread. Swift 6 strict mode infers @MainActor for UIKit types (SE-0434).
    @MainActor
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    @MainActor
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    @MainActor
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
