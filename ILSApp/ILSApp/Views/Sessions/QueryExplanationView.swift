import SwiftUI
import ILSShared

/// A horizontal scrolling row of filter chips that displays the currently active
/// natural-language–parsed filters from a ``ParsedQuery``.
///
/// Renders one chip per structured predicate (date range, project, status, model,
/// and any leftover search tokens). Each chip carries a remove button (×) that
/// nils out the corresponding field on the bound ``ParsedQuery``. A **Clear all**
/// button at the trailing end dismisses every filter at once.
///
/// The view is only visible when `parsedQuery` is non-nil and the result contains
/// at least one structured predicate (`!isFullTextOnly`). It animates in/out with
/// a combined opacity + slide-from-top transition so callers can wrap it in a
/// `withAnimation` block.
///
/// ## Topics
/// ### Bindings
/// - ``parsedQuery`` - The currently active NL-parsed query; individual fields are
///   mutated when the user removes a chip.
/// - ``clearAll`` - Called when the user taps **Clear all** to dismiss all filters.
///
/// ### Sub-views
/// - ``FilterChipView`` - Reusable icon + label + remove-button pill.
struct QueryExplanationView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// The currently active parsed query. Setting a field to `nil` removes its chip.
    @Binding var parsedQuery: ParsedQuery?

    /// Called when the user taps **Clear all**.
    let clearAll: () -> Void

    var body: some View {
        if let query = parsedQuery, !query.isFullTextOnly {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingSM) {
                    // Date range chip
                    if let dateRange = query.dateRange {
                        FilterChipView(
                            icon: "calendar",
                            label: dateRange.displayName,
                            color: theme.info
                        ) {
                            parsedQuery?.dateRange = nil
                        }
                    }

                    // Project chip
                    if let project = query.projectFilter {
                        FilterChipView(
                            icon: "folder",
                            label: "project: \(project)",
                            color: theme.entityProject
                        ) {
                            parsedQuery?.projectFilter = nil
                        }
                    }

                    // Status chip
                    if let status = query.statusFilter {
                        FilterChipView(
                            icon: "circle.fill",
                            label: "status: \(status.rawValue)",
                            color: statusColor(for: status)
                        ) {
                            parsedQuery?.statusFilter = nil
                        }
                    }

                    // Model chip
                    if let model = query.modelFilter {
                        FilterChipView(
                            icon: "cpu",
                            label: "model: \(model)",
                            color: theme.accentSecondary
                        ) {
                            parsedQuery?.modelFilter = nil
                        }
                    }

                    // Topic / search-tokens chip
                    if !query.searchTokens.isEmpty {
                        FilterChipView(
                            icon: "magnifyingglass",
                            label: query.searchTokens.joined(separator: " "),
                            color: theme.accent
                        ) {
                            parsedQuery?.searchTokens = []
                        }
                    }

                    // Clear all
                    Button(action: clearAll) {
                        Text("Clear all")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                            .padding(.horizontal, theme.spacingSM)
                            .padding(.vertical, theme.spacingXS)
                    }
                    .accessibilityLabel("Clear all filters")
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingXS)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:    return theme.success
        case .completed: return theme.info
        case .error:     return theme.error
        case .cancelled: return theme.textTertiary
        }
    }
}

// MARK: - FilterChipView

/// A single filter chip pill displaying an icon, a label, and a remove (×) button.
private struct FilterChipView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// SF Symbol name for the leading icon.
    let icon: String
    /// Human-readable label describing the active filter value.
    let label: String
    /// Tint color applied to the leading icon and chip border.
    let color: Color
    /// Called when the user taps the remove button.
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    // ACC-007: Use 11pt minimum for Dynamic Type compliance
                    .font(.system(size: 11, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .accessibilityLabel("Remove \(label) filter")
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
