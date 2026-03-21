import SwiftUI
import ILSShared

/// A horizontal scrollable bar of suggestion chips displayed above the chat input.
///
/// Shows 3-4 contextually relevant prompt suggestions based on the current conversation
/// and project context. Each chip is tappable and populates the chat input field when selected.
/// The user's selections are tracked as feedback to improve future suggestions.
///
/// ## Topics
/// ### Inputs
/// - ``session`` - The current session used to derive suggestion context
/// - ``apiClient`` - The API client for backend suggestion requests
/// - ``onSuggestionTap`` - Called when the user taps a suggestion chip
///
/// ### Behaviour
/// - Hidden when the `showPromptSuggestions` preference is `false`
/// - Hidden while loading or when no suggestions are available
/// - Displays up to 4 suggestion chips in a horizontal scrollable row
struct PromptSuggestionsChipBar: View {
    /// The current chat session whose context drives the suggestions.
    let session: ChatSession
    /// API client used to fetch prompt suggestions from the backend.
    let apiClient: APIClient
    /// Called when the user taps a suggestion chip.
    let onSuggestionTap: (String) -> Void
    /// Incrementing this value causes suggestions to reload. Increment after each Claude response.
    var refreshToken: Int = 0

    @State private var viewModel = SuggestionsViewModel()
    @AppStorage("showPromptSuggestions") private var showSuggestions = true

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Group {
            // UXF-007: Return empty view when no suggestions to avoid wasting vertical space
            if showSuggestions && !viewModel.promptSuggestions.isEmpty && !viewModel.isLoadingPrompts {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingXS) {
                        ForEach(Array(viewModel.promptSuggestions.prefix(4))) { suggestion in
                            chipButton(suggestion)
                        }
                    }
                    .padding(.horizontal, theme.spacingSM)
                }
                .frame(height: 36)
                .accessibilityIdentifier("prompt-suggestions-chip-bar")
            }
        }
        .task(id: refreshToken) {
            viewModel.configure(client: apiClient)
            await viewModel.loadPromptSuggestions(session: session)
        }
    }

    // MARK: - Chip Button

    /// A single suggestion chip button.
    @ViewBuilder
    private func chipButton(_ suggestion: PromptSuggestion) -> some View {
        Button {
            Task {
                await viewModel.recordFeedback(
                    action: "click",
                    suggestionType: "prompt",
                    targetId: suggestion.prompt,
                    sessionId: session.id
                )
                onSuggestionTap(suggestion.prompt)
            }
        } label: {
            Text(suggestion.prompt)
                .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, theme.spacingXS)
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(theme.border, lineWidth: 1)
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Suggestion: \(suggestion.prompt)")
    }

}
