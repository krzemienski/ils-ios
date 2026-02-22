#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Session Widget Timeline Provider

@available(iOS 17.0, *)
struct SessionTimelineProvider: TimelineProvider {
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

// MARK: - Session Widget View

@available(iOS 17.0, *)
struct SessionWidgetView: View {
    let entry: SessionWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                // Session rows
                ForEach(entry.sessions.prefix(5)) { session in
                    if let deepLink = URL(string: "ils://sessions/\(session.id)") {
                        Link(destination: deepLink) {
                            SessionWidgetRow(session: session)
                        }
                    } else {
                        SessionWidgetRow(session: session)
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(hex: WidgetColors.background)
        }
    }
}

// MARK: - Session Row

@available(iOS 17.0, *)
private struct SessionWidgetRow: View {
    let session: WidgetSessionInfo

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(session.isActive ? Color(hex: WidgetColors.success) : Color(hex: WidgetColors.textTertiary))
                .frame(width: 6, height: 6)

            // Session name
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
        .padding(.vertical, 2)
    }
}

// MARK: - Session Widget Definition

@available(iOS 17.0, *)
struct SessionWidget: Widget {
    let kind: String = "SessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionTimelineProvider()) { entry in
            SessionWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Sessions")
        .description("Quick access to your recent Claude Code sessions.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Session Widget", as: .systemMedium) {
    SessionWidget()
} timeline: {
    SessionWidgetEntry.placeholder
    SessionWidgetEntry.empty
}
#endif
