import SwiftUI
import ILSShared

/// Compact thumbs up/down rating control for AI response messages.
///
/// Displays two SF Symbol buttons — `hand.thumbsup` and `hand.thumbsdown` — which fill
/// when the user has already submitted a rating for the given message. Tapping thumbs-up
/// immediately submits positive feedback via `FeedbackViewModel`. Tapping thumbs-down
/// presents `FeedbackDetailSheet` where the user can pick reason chips ("Wrong code",
/// "Hallucination", etc.) before submitting negative feedback.
///
/// ## Topics
/// ### Input Properties
/// - ``messageId`` - Unique identifier of the AI response message being rated
/// - ``sessionId`` - Identifier of the session containing the message
/// - ``projectId`` - Optional identifier of the project associated with the session
/// - ``model`` - Optional name of the AI model that generated the response
/// - ``messageContent`` - Full text of the AI response, stored with feedback for Best-Of
/// - ``feedbackViewModel`` - Shared view-model that persists and submits ratings
struct FeedbackRatingView: View {
    let messageId: String
    let sessionId: String
    let projectId: String?
    let model: String?
    let messageContent: String?
    @Bindable var feedbackViewModel: FeedbackViewModel

    @State private var showFeedbackSheet = false
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Derived State

    private var currentRating: FeedbackRating? {
        feedbackViewModel.submittedRating(for: messageId)
    }

    private var hasRated: Bool {
        feedbackViewModel.hasRated(messageId: messageId)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            thumbsUpButton
            thumbsDownButton
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackDetailSheet(
                messageId: messageId,
                sessionId: sessionId,
                projectId: projectId,
                model: model,
                messageContent: messageContent,
                feedbackViewModel: feedbackViewModel,
                isPresented: $showFeedbackSheet
            )
        }
    }

    // MARK: - Subviews

    private var thumbsUpButton: some View {
        Button {
            Task {
                await feedbackViewModel.submitFeedback(
                    rating: .thumbsUp,
                    comment: nil,
                    messageId: messageId,
                    sessionId: sessionId,
                    projectId: projectId,
                    model: model,
                    messageContent: messageContent
                )
            }
        } label: {
            Image(systemName: currentRating == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                .font(.system(size: theme.fontBody))
                .foregroundColor(currentRating == .thumbsUp ? theme.success : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .disabled(feedbackViewModel.isSubmitting || hasRated)
        .accessibilityLabel("Rate response positively")
    }

    private var thumbsDownButton: some View {
        Button {
            showFeedbackSheet = true
        } label: {
            Image(systemName: currentRating == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .font(.system(size: theme.fontBody))
                .foregroundColor(currentRating == .thumbsDown ? theme.error : theme.textSecondary)
        }
        .buttonStyle(.plain)
        .disabled(feedbackViewModel.isSubmitting || hasRated)
        .accessibilityLabel("Rate response negatively")
    }
}
