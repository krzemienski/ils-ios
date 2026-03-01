import WidgetKit
import SwiftUI

@main
@available(iOS 17.0, *)
struct ILSWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SessionWidget()
        ServerStatusWidget()
        LargeSessionWidget()
        LockScreenWidget()
    }
}
