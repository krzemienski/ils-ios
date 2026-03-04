import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct ChatStreamingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChatStreamingAttributes.self) { context in
            ChatStreamingLockScreenView(context: context)
                .widgetURL(URL(string: "ils://sessions/" + context.attributes.sessionId))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LiveActivityColors.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.model)
                        .font(.caption.weight(.medium).monospaced())
                        .foregroundStyle(LiveActivityColors.accent.opacity(0.8))
                }
                DynamicIslandExpandedRegion(.center) {
                    ChatStreamingExpandedView(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                ChatStreamingCompactLeading()
            } compactTrailing: {
                ChatStreamingCompactTrailing(tokenCount: context.state.tokenCount)
            } minimal: {
                let isWaiting = context.state.status == .waitingForInput
                Image(systemName: isWaiting ? "person.fill.questionmark" : "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(isWaiting ? Color.orange : LiveActivityColors.accent)
            }
        }
    }
}
