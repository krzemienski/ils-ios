#if canImport(WidgetKit)
// CONC-28: @preconcurrency suppresses Sendable warnings for WidgetKit TimelineProvider
// completion callbacks, which pre-date Swift 6 and lack @Sendable annotations.
@preconcurrency import WidgetKit
import SwiftUI

// MARK: - Sendable Completion Wrapper

/// Wraps a WidgetKit completion callback (which lacks @Sendable) as @unchecked Sendable
/// so it can be safely captured by a Task. WidgetKit guarantees correct thread handling
/// for these callbacks — the @unchecked annotation is an explicit trust-the-framework call.
private final class SendableCompletion<T>: @unchecked Sendable {
    let call: (T) -> Void
    init(_ completion: @escaping (T) -> Void) { self.call = completion }
}

// MARK: - Server Status Timeline Provider

@available(iOS 17.0, *)
struct ServerStatusTimelineProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> ServerStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        // CONC-28: Wrap non-@Sendable WidgetKit completion in SendableCompletion box so Task
        // can capture it without a 'passing closure as sending parameter' warning.
        let provider = dataProvider
        let box = SendableCompletion(completion)
        Task { [provider, box] in
            let entry = await provider.fetchServerStatus()
            box.call(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        // CONC-28: Wrap non-@Sendable WidgetKit completion in SendableCompletion box.
        let provider = dataProvider
        let box = SendableCompletion(completion)
        Task { [provider, box] in
            let entry = await provider.fetchServerStatus()

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            box.call(timeline)
        }
    }
}

// MARK: - Server Status Widget View

@available(iOS 17.0, *)
struct ServerStatusWidgetView: View {
    let entry: ServerStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with ILS branding
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(widgetHex: WidgetColors.accent))
                Text("ILS")
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundColor(.primary)
            }

            Spacer()

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.isConnected ? Color(widgetHex: WidgetColors.success) : Color(widgetHex: WidgetColors.error))
                    .frame(width: 8, height: 8)
                    .shadow(
                        color: entry.isConnected
                            ? Color(widgetHex: WidgetColors.success).opacity(0.6)
                            : Color(widgetHex: WidgetColors.error).opacity(0.6),
                        radius: 4
                    )
                Text(entry.isConnected ? "Connected" : "Offline")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(entry.isConnected ? Color(widgetHex: WidgetColors.success) : Color(widgetHex: WidgetColors.error))
            }

            Spacer()

            // Stats row
            HStack(spacing: 12) {
                // Session count
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.sessionCount)")
                        .font(.callout.weight(.bold).monospaced())
                        .foregroundColor(.primary)
                    Text("Sessions")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color(widgetHex: WidgetColors.textTertiary))
                }

                Spacer()

                // Version
                VStack(alignment: .trailing, spacing: 1) {
                    Text("v\(entry.backendVersion)")
                        .font(.caption.weight(.medium).monospaced())
                        .foregroundColor(Color(widgetHex: WidgetColors.textSecondary))
                    Text("Backend")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color(widgetHex: WidgetColors.textTertiary))
                }
            }

            // Rate limit bar (shown when rate limit data is available)
            if let used = entry.rateLimitUsed, let limit = entry.rateLimitLimit, limit > 0 {
                let fraction = min(1.0, Double(used) / Double(limit))
                let limitColor: Color = fraction >= 0.9
                    ? Color(hex: WidgetColors.error)
                    : fraction >= 0.7
                        ? Color(hex: WidgetColors.warning)
                        : Color(hex: WidgetColors.success)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Limit")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(hex: WidgetColors.textTertiary))
                        Spacer()
                        Text("\(used)/\(limit)")
                            .font(.caption2.weight(.semibold).monospaced())
                            .foregroundColor(limitColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: WidgetColors.border))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(limitColor)
                                .frame(width: geo.size.width * fraction, height: 4)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(12)
        .widgetURL(URL(string: "ils://sessions"))
        .containerBackground(for: .widget) {
            Color(widgetHex: WidgetColors.background)
        }
    }
}

// MARK: - Server Status Widget Definition

@available(iOS 17.0, *)
struct ServerStatusWidget: Widget {
    let kind: String = "ServerStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusTimelineProvider()) { entry in
            ServerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Monitor your ILS backend connection and health.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Server Status - Connected", as: .systemSmall) {
    ServerStatusWidget()
} timeline: {
    ServerStatusEntry.placeholder
    ServerStatusEntry.disconnected
}
#endif
