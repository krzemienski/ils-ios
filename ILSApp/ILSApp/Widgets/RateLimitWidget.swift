#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Rate Limit Timeline Provider

@available(iOS 17.0, *)
struct RateLimitTimelineProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> RateLimitWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RateLimitWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await dataProvider.fetchRateLimit()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RateLimitWidgetEntry>) -> Void) {
        Task {
            let entry = await dataProvider.fetchRateLimit()

            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Rate Limit Widget View (Small)

@available(iOS 17.0, *)
private struct RateLimitSmallView: View {
    let entry: RateLimitWidgetEntry

    private var gaugeColor: Color {
        let fraction = entry.consumptionFraction
        if fraction >= 0.9 {
            return Color(hex: WidgetColors.error)
        } else if fraction >= 0.7 {
            return Color(hex: WidgetColors.warning)
        } else {
            return Color(hex: WidgetColors.success)
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // Header
            HStack(spacing: 5) {
                Image(systemName: "gauge.medium")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(hex: WidgetColors.accent))
                Text("Rate Limit")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
            }

            Spacer()

            // Circular gauge
            Gauge(value: entry.consumptionFraction) {
                EmptyView()
            } currentValueLabel: {
                Text("\(entry.messagesUsed)")
                    .font(.callout.weight(.bold).monospaced())
                    .foregroundColor(gaugeColor)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeColor)
            .scaleEffect(1.35)

            Spacer()

            // Used / limit label
            Text("\(entry.messagesUsed) / \(entry.messagesLimit)")
                .font(.caption2.weight(.medium).monospaced())
                .foregroundColor(Color(hex: WidgetColors.textSecondary))
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(hex: WidgetColors.background)
        }
    }
}

// MARK: - Rate Limit Widget View (Medium)

@available(iOS 17.0, *)
private struct RateLimitMediumView: View {
    let entry: RateLimitWidgetEntry

    private var gaugeColor: Color {
        let fraction = entry.consumptionFraction
        if fraction >= 0.9 {
            return Color(hex: WidgetColors.error)
        } else if fraction >= 0.7 {
            return Color(hex: WidgetColors.warning)
        } else {
            return Color(hex: WidgetColors.success)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Gauge column
            VStack(alignment: .center, spacing: 4) {
                Gauge(value: entry.consumptionFraction) {
                    EmptyView()
                } currentValueLabel: {
                    Text("\(entry.messagesUsed)")
                        .font(.callout.weight(.bold).monospaced())
                        .foregroundColor(gaugeColor)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(gaugeColor)
                .scaleEffect(1.55)

                Text("\(Int(entry.consumptionFraction * 100))%")
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundColor(gaugeColor)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 80)

            // Separator
            Rectangle()
                .fill(Color(hex: WidgetColors.border))
                .frame(width: 1)

            // Details column
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "gauge.medium")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: WidgetColors.accent))
                    Text("Rate Limit")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Messages used / limit
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.messagesUsed) / \(entry.messagesLimit)")
                        .font(.footnote.weight(.semibold).monospaced())
                        .foregroundColor(.white)
                    Text("\(entry.messagesRemaining) remaining")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(Color(hex: WidgetColors.textSecondary))
                }

                Spacer()

                // Reset time (if available)
                if let resetsAt = entry.windowResetsAt,
                   let resetDate = ISO8601DateFormatter().date(from: resetsAt) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(Color(hex: WidgetColors.textTertiary))
                        Text("Resets \(resetDate, style: .relative)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(hex: WidgetColors.textTertiary))
                            .lineLimit(1)
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

// MARK: - Rate Limit Widget Composite View

@available(iOS 17.0, *)
struct RateLimitWidgetView: View {
    let entry: RateLimitWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            RateLimitMediumView(entry: entry)
        default:
            RateLimitSmallView(entry: entry)
        }
    }
}

// MARK: - Rate Limit Widget Definition

@available(iOS 17.0, *)
struct RateLimitWidget: Widget {
    let kind: String = "RateLimitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RateLimitTimelineProvider()) { entry in
            RateLimitWidgetView(entry: entry)
        }
        .configurationDisplayName("Rate Limit")
        .description("Monitor your Claude Code rate limit usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview("Rate Limit - Small", as: .systemSmall) {
    RateLimitWidget()
} timeline: {
    RateLimitWidgetEntry.placeholder
    RateLimitWidgetEntry.empty
}

@available(iOS 17.0, *)
#Preview("Rate Limit - Medium", as: .systemMedium) {
    RateLimitWidget()
} timeline: {
    RateLimitWidgetEntry.placeholder
    RateLimitWidgetEntry.empty
}
#endif
