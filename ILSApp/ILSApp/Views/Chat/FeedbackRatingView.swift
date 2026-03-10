import SwiftUI
import ILSShared

/// Compact thumbs up/down rating control for AI response messages.
///
/// Displays two SF Symbol buttons — `hand.thumbsup` and `hand.thumbsdown` — which fill
/// when the user has already submitted a rating for the given message. Tapping thumbs-up
/// immediately submits positive feedback via `FeedbackViewModel`. Tapping thumbs-down
/// reveals a sheet where the user can optionally add a comment before submitting negative
/// feedback.
///
/// ## Topics
/// ### Input Properties
/// - ``messageId`` - Unique identifier of the AI response message being rated
/// - ``sessionId`` - Identifier of the session containing the message
/// - ``projectId`` - Optional identifier of the project associated with the session
/// - ``model`` - Optional name of the AI model that generated the response
/// - ``feedbackViewModel`` - Shared view-model that persists and submits ratings
struct FeedbackRatingView: View {
    let messageId: String
    let sessionId: String
    let projectId: String?
    let model: String?
    @Bindable var feedbackViewModel: FeedbackViewModel

    @State private var showFeedbackSheet = false
    @State private var commentText = ""
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
            negativeFeedbackSheet
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
                    model: model
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

    /// Sheet presented when the user taps thumbs-down, allowing an optional comment.
    private var negativeFeedbackSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("What went wrong?")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundColor(theme.textPrimary)

                TextEditor(text: $commentText)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundColor(theme.textPrimary)
                    .frame(minHeight: 100)
                    .padding(theme.spacingSM)
                    .background(theme.bgSecondary)
                    .cornerRadius(theme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.cornerRadius)
                            .strokeBorder(theme.textTertiary.opacity(0.3), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(theme.spacingLG)
            .background(theme.bgPrimary)
            .navigationTitle("Feedback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showFeedbackSheet = false
                        commentText = ""
                    }
                    .foregroundColor(theme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        let comment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmed = comment.isEmpty ? nil : comment
                        showFeedbackSheet = false
                        commentText = ""
                        Task {
                            await feedbackViewModel.submitFeedback(
                                rating: .thumbsDown,
                                comment: trimmed,
                                messageId: messageId,
                                sessionId: sessionId,
                                projectId: projectId,
                                model: model
                            )
                        }
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundColor(theme.accent)
                    .disabled(feedbackViewModel.isSubmitting)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
