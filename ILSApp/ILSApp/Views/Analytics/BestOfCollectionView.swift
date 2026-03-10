import SwiftUI
import ILSShared

/// Card view displaying a curated list of highest-rated AI responses.
///
/// Renders a header with the item count, a scrollable list of ``BestOfItem`` rows each
/// showing a thumbs-up icon, a 2-line preview of the message content, the model name,
/// and a relative timestamp.  Tapping a row opens a full-content sheet.  An empty-state
/// placeholder is shown when ``bestOfItems`` is empty.
///
/// ## Topics
/// ### Parameters
/// - ``bestOfItems`` - The list of best-of items to display; pass an empty array for the empty-state.
///
/// ### Sections
/// - ``headerRow`` - Title and item-count subtitle.
/// - ``itemList`` - Scrollable list of best-of item rows.
/// - ``itemRow(_:)`` - A single row: thumbs-up icon, content preview, model badge, timestamp.
/// - ``emptyState`` - Placeholder shown when ``bestOfItems`` is empty.
///
/// ### Helpers
/// - ``formattedTimestamp(_:)`` - Formats an ISO-8601 timestamp into a human-readable relative string.
struct BestOfCollectionView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The best-of items to display. Pass an empty array to show the empty-state placeholder.
    let bestOfItems: [BestOfItem]

    /// The currently selected item to display in a detail sheet.
    @State private var selectedItem: BestOfItem?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            headerRow

            if bestOfItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .sheet(item: $selectedItem) { item in
            BestOfDetailSheet(item: item)
        }
    }

    // MARK: - Header

    /// Title and item-count subtitle.
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Best Of Collection")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                if !bestOfItems.isEmpty {
                    Text("\(bestOfItems.count) top-rated response\(bestOfItems.count == 1 ? "" : "s")")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Star badge showing count
            if !bestOfItems.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.success)
                    Text("\(bestOfItems.count)")
                        .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bestOfItems.count) highly rated response\(bestOfItems.count == 1 ? "" : "s")")
            }
        }
    }

    // MARK: - Item List

    /// Scrollable list of best-of item rows.
    private var itemList: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            ForEach(bestOfItems) { item in
                itemRow(item)
            }
        }
    }

    /// A single row: thumbs-up icon, content preview (2 lines), model badge, and timestamp.
    ///
    /// - Parameter item: The best-of item to render.
    private func itemRow(_ item: BestOfItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(alignment: .top, spacing: theme.spacingSM) {
                // Thumbs up icon
                Image(systemName: "hand.thumbsup.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.success)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    // Message content preview — truncated to 2 lines
                    Text(item.messageContent)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: theme.spacingXS) {
                        // Model name badge
                        Text(item.model)
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                        Spacer()

                        // Relative timestamp
                        Text(formattedTimestamp(item.timestamp))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(.vertical, theme.spacingXS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Highly rated response from \(item.model), \(formattedTimestamp(item.timestamp)). Tap to read full content.")
        .accessibilityHint("Double tap to expand")
    }

    // MARK: - Empty State

    /// Placeholder shown when ``bestOfItems`` is empty.
    private var emptyState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "hand.thumbsup")
                .font(.system(size: 32))
                .foregroundStyle(theme.textTertiary)
            Text("No highly-rated responses yet")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("Rate AI responses with thumbs up to build your collection.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No highly-rated responses yet. Rate AI responses with thumbs up to build your collection.")
    }

    // MARK: - Helpers

    /// Formats an ISO-8601 timestamp into a human-readable relative string.
    ///
    /// Falls back to the raw timestamp string if parsing fails.
    ///
    /// - Parameter timestamp: An ISO-8601 date string.
    /// - Returns: A relative description such as `"2 hours ago"` or `"Jan 5"`.
    private func formattedTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: timestamp)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: timestamp)
        }

        guard let date else { return timestamp }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 7 * 86400 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let display = DateFormatter()
            display.dateFormat = "MMM d"
            return display.string(from: date)
        }
    }
}

// MARK: - Detail Sheet

/// Full-content sheet displayed when a ``BestOfItem`` row is tapped.
private struct BestOfDetailSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    let item: BestOfItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    // Model and timestamp header
                    HStack {
                        Label(item.model, systemImage: "cpu")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                        Spacer()

                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundStyle(theme.success)
                    }

                    Divider()
                        .overlay(theme.bgSecondary)

                    // Full message content
                    Text(item.messageContent)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)

                    // Optional user comment
                    if let comment = item.comment, !comment.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your feedback")
                                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                            Text(comment)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .italic()
                        }
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusMedium))
                    }
                }
                .padding(theme.spacingMD)
            }
            .navigationTitle("Best Of Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                }
            }
            .background(theme.bgPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleItems: [BestOfItem] = [
        BestOfItem(
            messageContent: "Here's an efficient implementation using Swift's async/await pattern. The key insight is to use structured concurrency with task groups, which ensures all child tasks complete before the parent returns.",
            sessionId: "session-1",
            rating: 1,
            comment: "Exactly what I needed",
            model: "claude-opus-4-5",
            timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
            messageId: "msg-1"
        ),
        BestOfItem(
            messageContent: "The bug is in the index calculation on line 42. You're off by one because Swift arrays are 0-indexed. Change `count` to `count - 1` in the loop bounds.",
            sessionId: "session-2",
            rating: 1,
            comment: nil,
            model: "claude-sonnet-4-5",
            timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            messageId: "msg-2"
        ),
        BestOfItem(
            messageContent: "For your SwiftUI architecture question, I'd recommend the MVVM pattern with an ObservableObject view model. This keeps your views lightweight and business logic testable.",
            sessionId: "session-3",
            rating: 1,
            comment: "Clear and concise",
            model: "claude-haiku-4-5",
            timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-604800)),
            messageId: "msg-3"
        ),
    ]

    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                BestOfCollectionView(bestOfItems: sampleItems)
                BestOfCollectionView(bestOfItems: [])
            }
            .padding()
        }
        .background(.background)
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
