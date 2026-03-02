import SwiftUI
import ILSShared

/// A collapsible dashboard widget that surfaces abandoned sessions worth resuming.
///
/// Displayed on the `HomeView` dashboard between the quick-actions grid and the
/// recent-sessions list. Fetches up to 3 abandoned sessions from the backend
/// (sessions inactive for 24+ hours with meaningful message history) and presents
/// each with a completion percentage, inactivity duration, and two actions:
/// **Resume** — navigates to the session — and **Dismiss** — removes the row and
/// records negative feedback so the session won't reappear.
///
/// The widget respects the `showSessionSuggestions` `AppStorage` preference; when
/// disabled globally the view renders nothing. The user can also collapse the widget
/// to free up vertical space without dismissing individual suggestions.
///
/// ## Topics
/// ### Inputs
/// - ``apiClient`` - API client used to fetch abandoned sessions
/// - ``onResume`` - Called when the user taps Resume on a suggestion row
///
/// ### Behaviour
/// - Hidden when the `showSessionSuggestions` preference is `false`
/// - Hidden while loading or when no suggestions are available
/// - Collapsible via header chevron with smooth animation
/// - Dismiss per-row calls feedback API and removes item immediately
struct SessionSuggestionsWidget: View {
    /// API client used to fetch abandoned sessions from the backend.
    let apiClient: APIClient
    /// Called when the user taps Resume on a suggestion row.
    let onResume: (ChatSession) -> Void

    @State private var viewModel = SuggestionsViewModel()
    @State private var isCollapsed = false
    @AppStorage("showSessionSuggestions") private var showSuggestions = true

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Group {
            if showSuggestions && !viewModel.abandonedSessions.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    headerRow
                    if !isCollapsed {
                        suggestionRows
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("session-suggestions-widget")
            }
        }
        .task {
            viewModel.configure(client: apiClient)
            await viewModel.loadAbandonedSessions(limit: 3)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerRow: some View {
        HStack {
            Label("Resume Where You Left Off", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: theme.fontCaption, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed ? "Expand suggestions" : "Collapse suggestions")
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var suggestionRows: some View {
        ForEach(Array(viewModel.abandonedSessions.prefix(3))) { suggestion in
            suggestionRow(suggestion)
        }
    }

    /// A single abandoned-session row showing name, completion estimate, inactivity, and actions.
    @ViewBuilder
    private func suggestionRow(_ suggestion: AbandonedSessionSuggestion) -> some View {
        HStack(spacing: theme.spacingSM) {
            // Completion ring indicator
            completionRing(suggestion.completionEstimate)

            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: theme.spacingXS) {
                    Text(suggestion.reason)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)

                    if let projectName = suggestion.session.projectName, !projectName.isEmpty {
                        Text("·")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                        Text(projectName)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: theme.spacingXS) {
                Button("Resume") {
                    Task {
                        await viewModel.recordFeedback(
                            action: "click",
                            suggestionType: "abandoned",
                            targetId: suggestion.id.uuidString
                        )
                        onResume(suggestion.session)
                    }
                }
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textOnAccent)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .accessibilityLabel("Resume \(suggestion.session.name ?? "session")")

                Button {
                    Task {
                        await viewModel.dismissSuggestion(
                            id: suggestion.id.uuidString,
                            type: "abandoned"
                        )
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss \(suggestion.session.name ?? "session")")
            }
        }
        .padding(theme.spacingSM)
        .background(theme.bgPrimary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Completion Ring

    /// A compact circular progress indicator showing the completion estimate.
    @ViewBuilder
    private func completionRing(_ percent: Int) -> some View {
        ZStack {
            Circle()
                .stroke(theme.textTertiary.opacity(0.2), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100.0)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(percent)%")
                .font(.system(size: 8, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(width: 36, height: 36)
        .accessibilityLabel("\(percent) percent complete")
    }
}
