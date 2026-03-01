import WidgetKit
import SwiftUI

@main
struct ILSWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ChatStreamingLiveActivityWidget()
        }
        SessionWidget()
        ServerStatusWidget()
    }
}
