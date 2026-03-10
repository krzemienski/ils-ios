import SwiftUI
import ILSShared

/// Sheet presented when the user taps thumbs-down on an AI response message.
///
/// Lets the user pick one or more predefined reason chips — "Wrong code", "Hallucination",
/// "Incomplete", "Off topic", "Other" — and optionally type a free-text comment.  On
/// submit the selected reasons and custom text are combined into a single comment string
/// that is forwarded to `FeedbackViewModel.submitFeedback` with a `.thumbsDown` rating.
/// Cancel dismisses the sheet without submitting.
///
/// ## Topics
/// ### Input Properties
/// - ``messageId`` - Unique identifier of the AI response message being rated
/// - ``sessionId`` - Identifier of the session containing the message
/// - ``projectId`` - Optional identifier of the project associated with the session
/// - ``model`` - Optional name of the AI model that generated the response
/// - ``feedbackViewModel`` - Shared view-model that persists and submits ratings
/// - ``isPresented`` - Binding controlling sheet visibility
struct FeedbackDetailSheet: View {
    let messageId: String
    let sessionId: String
    let projectId: String?
    let model: String?
    @Bindable var feedbackViewModel: FeedbackViewModel
    @Binding var isPresented: Bool

    // MARK: - Private State

    private let reasons = ["Wrong code", "Hallucination", "Incomplete", "Off topic", "Other"]

    @State private var selectedReasons: Set<String> = []
    @State private var customComment = ""
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingLG) {
                    reasonSection
                    commentSection
                    Spacer(minLength: theme.spacingMD)
                }
                .padding(theme.spacingLG)
            }
            .background(theme.bgPrimary)
            .navigationTitle("What went wrong?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.textSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submitFeedback()
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundColor(theme.accent)
                    .disabled(feedbackViewModel.isSubmitting)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Subviews

    /// Horizontally wrapping row of tappable reason pills.
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Select all that apply")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            FlowLayout(spacing: theme.spacingSM) {
                ForEach(reasons, id: \.self) { reason in
                    ReasonChip(
                        title: reason,
                        isSelected: selectedReasons.contains(reason),
                        theme: theme
                    ) {
                        if selectedReasons.contains(reason) {
                            selectedReasons.remove(reason)
                        } else {
                            selectedReasons.insert(reason)
                        }
                    }
                }
            }
        }
    }

    /// Optional free-text field for additional context.
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Additional comments (optional)")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)

            TextEditor(text: $customComment)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .frame(minHeight: 80)
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .cornerRadius(theme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .strokeBorder(theme.textTertiary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func dismiss() {
        selectedReasons = []
        customComment = ""
        isPresented = false
    }

    private func submitFeedback() {
        var parts: [String] = Array(selectedReasons).sorted()
        let trimmed = customComment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(trimmed)
        }
        let comment = parts.isEmpty ? nil : parts.joined(separator: "; ")

        isPresented = false
        selectedReasons = []
        customComment = ""

        Task {
            await feedbackViewModel.submitFeedback(
                rating: .thumbsDown,
                comment: comment,
                messageId: messageId,
                sessionId: sessionId,
                projectId: projectId,
                model: model
            )
        }
    }
}

// MARK: - ReasonChip

/// A tappable pill that highlights when selected.
private struct ReasonChip: View {
    let title: String
    let isSelected: Bool
    let theme: ThemeSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundColor(isSelected ? theme.bgPrimary : theme.textPrimary)
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
                .background(isSelected ? theme.accent : theme.bgSecondary)
                .cornerRadius(theme.cornerRadiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusLarge)
                        .strokeBorder(
                            isSelected ? Color.clear : theme.textTertiary.opacity(0.4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - FlowLayout

/// A simple left-to-right wrapping layout for the reason chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                height += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
