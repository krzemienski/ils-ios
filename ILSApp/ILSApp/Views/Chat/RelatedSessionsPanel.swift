import SwiftUI
import ILSShared

/// A collapsible panel showing past sessions related to the current chat.
///
/// Displayed at the top of `ChatView` for brand-new sessions (0 messages).
/// Fetches suggestions from the backend using the current session's first prompt
/// and project name as context. The user can dismiss the panel via the close
/// button, or navigate directly to a related session using the Open button.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The current session used to derive suggestion context
/// - ``apiClient`` - The API client for backend suggestion requests
/// - ``onNavigate`` - Called when the user opens a related session
///
/// ### Behaviour
/// - Hidden when the `showSessionSuggestions` preference is `false`
/// - Hidden after the user taps the dismiss button (``isDismissed``)
/// - Hidden while loading or when no suggestions are available
struct RelatedSessionsPanel: View {
    /// The current chat session whose context drives the suggestions.
    let session: ChatSession
    /// API client used to fetch session suggestions from the backend.
    let apiClient: APIClient
    /// Called when the user taps Open on a related session row.
    let onNavigate: (ChatSession) -> Void

    @State private var viewModel = SuggestionsViewModel()
    @State private var isDismissed = false
    @AppStorage("showSessionSuggestions") private var showSuggestions = true

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Group {
            if !isDismissed && showSuggestions && !viewModel.sessionSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    // Header row
                    HStack {
                        Label("Related Sessions", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)

                        Spacer()

                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDismissed = true
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: theme.fontCaption, weight: .medium))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss related sessions")
                    }

                    // Suggestion rows
                    ForEach(Array(viewModel.sessionSuggestions.prefix(3))) { suggestion in
                        relatedRow(suggestion)
                    }
                }
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .padding(.horizontal, theme.spacingSM)
                .padding(.top, theme.spacingXS)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("related-sessions-panel")
            }
        }
        .task {
            viewModel.configure(client: apiClient)
            await viewModel.loadSessionSuggestions(
                context: session.firstPrompt ?? session.name ?? "",
                projectName: session.projectName
            )
        }
    }

    // MARK: - Row

    /// A single related-session row showing name, project, and an Open button.
    @ViewBuilder
    private func relatedRow(_ suggestion: SessionSuggestion) -> some View {
        HStack(spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.session.name ?? "Unnamed Session")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let projectName = suggestion.session.projectName, !projectName.isEmpty {
                    Text(projectName)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button("Open") {
                Task {
                    await viewModel.recordFeedback(
                        action: "click",
                        suggestionType: "session",
                        targetId: suggestion.session.id.uuidString,
                        sessionId: session.id
                    )
                    onNavigate(suggestion.session)
                }
            }
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(suggestion.session.name ?? "session")")
        }
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }
}
