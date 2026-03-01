#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Large Session Widget Timeline Provider

@available(iOS 17.0, *)
struct LargeSessionTimelineProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> SessionWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let sessions = await dataProvider.fetchRecentSessions()
            let entry = SessionWidgetEntry(date: Date(), sessions: sessions, isPlaceholder: false)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionWidgetEntry>) -> Void) {
        Task {
            let sessions = await dataProvider.fetchRecentSessions()
            let entry = SessionWidgetEntry(date: Date(), sessions: sessions, isPlaceholder: false)

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Large Session Widget View

@available(iOS 17.0, *)
struct LargeSessionWidgetView: View {
    let entry: SessionWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: WidgetColors.accent))
                Text("Recent Sessions")
                    .font(.footnote.weight(.bold).monospaced())
                    .foregroundColor(.white)
                Spacer()
                Text("\(entry.sessions.count)")
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundColor(Color(hex: WidgetColors.textSecondary))
            }
            .padding(.bottom, 2)

            if entry.sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(.title3)
                            .foregroundColor(Color(hex: WidgetColors.textTertiary))
                        Text("No sessions")
                            .font(.caption.monospaced())
                            .foregroundColor(Color(hex: WidgetColors.textTertiary))
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Session rows — up to 7 for the large widget
                ForEach(entry.sessions.prefix(7)) { session in
                    if let deepLink = URL(string: "ils://sessions/\(session.id)") {
                        Link(destination: deepLink) {
                            LargeSessionWidgetRow(session: session)
                        }
                    } else {
                        LargeSessionWidgetRow(session: session)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(hex: WidgetColors.background)
        }
    }
}

// MARK: - Large Session Row (two-line)

@available(iOS 17.0, *)
private struct LargeSessionWidgetRow: View {
    let session: WidgetSessionInfo

    /// Last message preview, capped at ~60 characters.
    private var lastMessagePreview: String? {
        guard let msg = session.lastMessage, !msg.isEmpty else { return nil }
        if msg.count <= 60 { return msg }
        return String(msg.prefix(60)) + "…"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Status dot — aligned to top of first line
            Circle()
                .fill(session.isActive
                      ? Color(hex: WidgetColors.success)
                      : Color(hex: WidgetColors.textTertiary))
                .frame(width: 6, height: 6)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                // First line: name + badges
                HStack(spacing: 6) {
                    Text(session.name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    // Model badge
                    Text(session.model.uppercased())
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundColor(Color(hex: WidgetColors.accent))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: WidgetColors.accent).opacity(0.15))
                        )

                    // Message count
                    HStack(spacing: 2) {
                        Image(systemName: "message.fill")
                            .font(.caption2)
                        Text("\(session.messageCount)")
                            .font(.caption2.weight(.medium).monospaced())
                    }
                    .foregroundColor(Color(hex: WidgetColors.textSecondary))
                }

                // Second line: last message preview in muted color
                if let preview = lastMessagePreview {
                    Text(preview)
                        .font(.caption2)
                        .foregroundColor(Color(hex: WidgetColors.textTertiary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Large Session Widget Definition

@available(iOS 17.0, *)
struct LargeSessionWidget: Widget {
    let kind: String = "LargeSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LargeSessionTimelineProvider()) { entry in
            LargeSessionWidgetView(entry: entry)
        }
        .configurationDisplayName("Sessions — Large")
        .description("View up to 7 recent Claude Code sessions with message previews.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Large Session Widget", as: .systemLarge) {
    LargeSessionWidget()
} timeline: {
    SessionWidgetEntry.placeholder
    SessionWidgetEntry.empty
}
#endif
