#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Lock Screen Widget Views

@available(iOS 17.0, *)
struct LockScreenWidgetView: View {
    let entry: ServerStatusEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        Group {
            switch widgetFamily {
            case .accessoryCircular:
                CircularLockScreenView(entry: entry)
            case .accessoryRectangular:
                RectangularLockScreenView(entry: entry)
            case .accessoryInline:
                InlineLockScreenView(entry: entry)
            default:
                CircularLockScreenView(entry: entry)
            }
        }
        .widgetURL(URL(string: "ils://sessions"))
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Accessory Circular View

/// Displays session count as a number with 'Sessions' label inside a circular accessory.
@available(iOS 17.0, *)
private struct CircularLockScreenView: View {
    let entry: ServerStatusEntry

    var body: some View {
        VStack(spacing: 1) {
            Text("\(entry.sessionCount)")
                .font(.title2.weight(.bold).monospaced())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Sessions")
                .font(.caption2.weight(.medium))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

// MARK: - Accessory Rectangular View

/// Displays ILS logo + connection status + session count in a rectangular accessory.
@available(iOS 17.0, *)
private struct RectangularLockScreenView: View {
    let entry: ServerStatusEntry

    var body: some View {
        HStack(spacing: 8) {
            // ILS logo
            Image(systemName: "server.rack")
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 2) {
                // Connection status row
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.isConnected ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(entry.isConnected ? "Connected" : "Offline")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }

                // Session count
                Text("\(entry.sessionCount) sessions")
                    .font(.caption.weight(.medium).monospaced())
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Accessory Inline View

/// Displays a short text summary: 'N sessions active' or 'Offline'.
@available(iOS 17.0, *)
private struct InlineLockScreenView: View {
    let entry: ServerStatusEntry

    var body: some View {
        Label {
            Text(entry.isConnected ? "\(entry.sessionCount) sessions active" : "Offline")
        } icon: {
            Image(systemName: "server.rack")
        }
    }
}

// MARK: - Lock Screen Widget Definition

@available(iOS 17.0, *)
struct LockScreenWidget: Widget {
    let kind: String = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusTimelineProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("ILS Lock Screen")
        .description("Monitor your ILS server status and session count from the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Lock Screen - Circular", as: .accessoryCircular) {
    LockScreenWidget()
} timeline: {
    ServerStatusEntry.placeholder
    ServerStatusEntry.disconnected
}

@available(iOS 17.0, *)
#Preview("Lock Screen - Rectangular", as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    ServerStatusEntry.placeholder
    ServerStatusEntry.disconnected
}

@available(iOS 17.0, *)
#Preview("Lock Screen - Inline", as: .accessoryInline) {
    LockScreenWidget()
} timeline: {
    ServerStatusEntry.placeholder
    ServerStatusEntry.disconnected
}
#endif
