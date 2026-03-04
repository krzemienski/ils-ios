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
        // CONC-28: Wrap non-@Sendable WidgetKit completion in SendableCompletion box so Task
        // can capture it without a 'passing closure as sending parameter' warning.
        let provider = dataProvider
        let box = SendableCompletion(completion)
        Task { [provider, box] in
            let sessions = await provider.fetchRecentSessions()
            let entry = SessionWidgetEntry(date: Date(), sessions: sessions, isPlaceholder: false)
            box.call(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionWidgetEntry>) -> Void) {
        // CONC-28: Wrap non-@Sendable WidgetKit completion in SendableCompletion box.
        let provider = dataProvider
        let box = SendableCompletion(completion)
        Task { [provider, box] in
            let sessions = await provider.fetchRecentSessions()
            let entry = SessionWidgetEntry(date: Date(), sessions: sessions, isPlaceholder: false)

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            box.call(timeline)
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
                    .foregroundColor(Color(widgetHex: WidgetColors.accent))
                Text("Recent Sessions")
                    .font(.footnote.weight(.bold).monospaced())
                    .foregroundColor(.primary)
                Spacer()
                Text("\(entry.sessions.count)")
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundColor(Color(widgetHex: WidgetColors.textSecondary))
            }

            if entry.sessions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(.title3)
                            .foregroundColor(Color(widgetHex: WidgetColors.textTertiary))
                        Text("No sessions")
                            .font(.caption.monospaced())
                            .foregroundColor(Color(widgetHex: WidgetColors.textTertiary))
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
            Color(widgetHex: WidgetColors.background)
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
                .fill(session.isActive ? Color(widgetHex: WidgetColors.success) : Color(widgetHex: WidgetColors.textTertiary))
                .frame(width: 6, height: 6)

            // Session name
            Text(session.name)
                .font(.caption.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Model badge
            Text(session.model.uppercased())
                .font(.caption2.weight(.bold).monospaced())
                .foregroundColor(Color(widgetHex: WidgetColors.accent))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(widgetHex: WidgetColors.accent).opacity(0.15))
                )

            // Message count
            HStack(spacing: 2) {
                Image(systemName: "message.fill")
                    .font(.caption2)
                Text("\(session.messageCount)")
                    .font(.caption2.weight(.medium).monospaced())
            }
            .foregroundColor(Color(widgetHex: WidgetColors.textSecondary))
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
