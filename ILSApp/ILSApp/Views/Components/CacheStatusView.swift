import SwiftUI

/// Displays a relative timestamp showing when cached data was last refreshed.
///
/// Shows "Last updated X ago" with theme-appropriate styling.
/// Updates every 30 seconds for freshness.
struct CacheStatusView: View {
    let lastUpdated: Date?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        if let lastUpdated {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.fontCaption - 1))

                Text("Updated \(relativeTime(from: lastUpdated))")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .foregroundStyle(theme.textTertiary)
            .accessibilityLabel("Last updated \(relativeTime(from: lastUpdated))")
        }
    }

    // MARK: - Relative Time

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        switch interval {
        case ..<5:
            return "just now"
        case ..<60:
            let seconds = Int(interval)
            return "\(seconds)s ago"
        case ..<3600:
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        case ..<86400:
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        default:
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CacheStatusView(lastUpdated: Date())
        CacheStatusView(lastUpdated: Date().addingTimeInterval(-120))
        CacheStatusView(lastUpdated: Date().addingTimeInterval(-7200))
        CacheStatusView(lastUpdated: nil)
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
