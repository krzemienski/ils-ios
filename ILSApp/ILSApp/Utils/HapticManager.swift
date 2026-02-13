#if os(iOS)
import UIKit

enum HapticManager {
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}
#else
enum HapticManager {
    enum FeedbackType { case success, warning, error }
    static func notification(_ type: FeedbackType) {
        // No haptics on macOS
    }
}
#endif
