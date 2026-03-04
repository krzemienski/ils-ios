import SwiftUI
import ILSShared

/// A collapsible dashboard widget that surfaces abandoned sessions worth resuming.
///
/// Displayed on the `HomeView` dashboard between the quick-actions grid and the
/// recent-sessions list. Fetches up to 3 abandoned sessions from the backend
/// (sessions inactive for 24+ hours with meaningful message history) and presents
/// each with a completion percentage, inactivity duration, and two actions:
/// **Resume** — fetches a smart continuation summary then navigates to the session
/// — and **Dismiss** — removes the row and records negative feedback so the session
/// won't reappear.
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
/// - Resume fetches continuation summary and presents it before navigating
struct SessionSuggestionsWidget: View {
    /// API client used to fetch abandoned sessions from the backend.
    let apiClient: APIClient
    /// Called when the user taps Resume on a suggestion row.
    let onResume: (ChatSession) -> Void

    @State private var viewModel = SuggestionsViewModel()
    @State private var isCollapsed = false
    @AppStorage("showSessionSuggestions") private var showSuggestions = true

    // Smart continuation summary state
    @State private var continuationSummary: ContinuationSummary?
    @State private var pendingResumeSession: ChatSession?

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
        .sheet(item: $continuationSummary) { summary in
            ContinuationSummarySheet(
                summary: summary,
                onResume: {
                    if let session = pendingResumeSession {
                        onResume(session)
                    }
                    pendingResumeSession = nil
                },
                onCancel: {
                    pendingResumeSession = nil
                }
            )
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
                        // Fetch smart continuation summary for this session
                        let summary = await viewModel.loadContinuationSummary(
                            sessionId: suggestion.session.id
                        )

                        // Record click feedback using the session's actual UUID
                        await viewModel.recordFeedback(
                            action: "click",
                            suggestionType: "abandoned",
                            targetId: suggestion.session.id.uuidString
                        )

                        if let summary {
                            // Present continuation summary before navigating
                            pendingResumeSession = suggestion.session
                            continuationSummary = summary
                        } else {
                            // Fallback: navigate directly if summary unavailable
                            onResume(suggestion.session)
                        }
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
                        // Use the session's actual UUID so the backend can filter it
                        await viewModel.dismissSuggestion(
                            id: suggestion.session.id.uuidString,
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

// MARK: - Continuation Summary Sheet

/// A modal sheet that presents the smart continuation summary before the user
/// resumes an abandoned session. Shows what was accomplished and a suggested
/// prompt to pick up right where the session left off.
private struct ContinuationSummarySheet: View {
    let summary: ContinuationSummary
    let onResume: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // What was accomplished
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Where You Left Off", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Text(summary.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Suggested prompt to continue
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Suggested Prompt", systemImage: "text.bubble")
                            .font(.headline)
                        Text(summary.suggestedPrompt)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Key topics if available
                    if !summary.keyTopics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Key Topics", systemImage: "tag")
                                .font(.headline)
                            FlowLayout(spacing: 6) {
                                ForEach(summary.keyTopics, id: \.self) { topic in
                                    Text(topic)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Continue Session")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Resume") {
                        dismiss()
                        onResume()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout

/// A simple wrapping horizontal layout for displaying tag-like items.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
