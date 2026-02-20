#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

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
        Task {
            let entry = await dataProvider.fetchServerStatus()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        Task {
            let entry = await dataProvider.fetchServerStatus()

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: WidgetColors.accent))
                Text("ILS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(entry.isConnected ? Color(hex: WidgetColors.success) : Color(hex: WidgetColors.error))
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: entry.isConnected
                            ? Color(hex: WidgetColors.success).opacity(0.6)
                            : Color(hex: WidgetColors.error).opacity(0.6),
                        radius: 4
                    )
                Text(entry.isConnected ? "Connected" : "Offline")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(entry.isConnected ? Color(hex: WidgetColors.success) : Color(hex: WidgetColors.error))
            }

            Spacer()

            // Stats row
            HStack(spacing: 12) {
                // Session count
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.sessionCount)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Sessions")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: WidgetColors.textTertiary))
                }

                Spacer()

                // Version
                VStack(alignment: .trailing, spacing: 1) {
                    Text("v\(entry.backendVersion)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: WidgetColors.textSecondary))
                    Text("Backend")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: WidgetColors.textTertiary))
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(hex: WidgetColors.background)
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
