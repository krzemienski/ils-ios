#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// Note: @main is commented out because these widget definitions live inside
// the main app target for now. When moved to a dedicated Widget Extension target,
// uncomment @main and remove the #if canImport(WidgetKit) guards.

// @main
@available(iOS 17.0, *)
struct ILSWidgets: WidgetBundle {
    var body: some Widget {
        SessionWidget()
        ServerStatusWidget()
    }
}
#endif
