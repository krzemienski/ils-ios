import SwiftUI

/// Sheet shown after a context compaction event is detected.
///
/// Informs the user that their session context was compacted and provides
/// token-count statistics (before and after compaction), the pre-compaction
/// snapshot text when available, and a one-tap button to copy that snapshot
/// to the clipboard for pasting into a new message to restore key context.
///
/// ## Layout
/// - Header banner: compaction-event icon + title
/// - Token stats card: tokens before / after / delta
/// - Snapshot section: scrollable snapshot text or a "no snapshot" notice
/// - Action row: "Copy Context to Clipboard" + "Dismiss"
///
/// ## Topics
/// ### Input Properties
/// - ``tokensBeforeCompaction`` - Context window tokens consumed before compaction
/// - ``tokensAfterCompaction`` - Context window tokens after compaction (fresh window)
/// - ``snapshot`` - Optional pre-compaction context snapshot
/// - ``onDismiss`` - Action invoked when the user dismisses this sheet
struct PostCompactionRecoverySheet: View {
    /// Token count recorded immediately before compaction occurred.
    let tokensBeforeCompaction: Int
    /// Token count in the new context window after compaction.
    let tokensAfterCompaction: Int
    /// Optional pre-compaction context snapshot captured before truncation.
    let snapshot: ContextSnapshot?
    /// Optional closure invoked when the user taps "Paste as Message". Receives the snapshot text.
    let onPasteAsMessage: ((String) -> Void)?
    /// Closure invoked to dismiss this sheet.
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var copiedToClipboard = false

    // MARK: - Computed Properties

    /// Tokens freed by the compaction event.
    private var tokensDelta: Int {
        max(0, tokensBeforeCompaction - tokensAfterCompaction)
    }

    // MARK: - Helpers

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingLG) {
                    headerBanner
                    tokenStatsCard
                    snapshotSection
                    actionRow
                }
                .padding(theme.spacingMD)
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgPrimary)
            .navigationTitle("Session Compacted")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dismiss") { onDismiss() }
                        .foregroundColor(theme.accent)
                        .accessibilityLabel("Dismiss post-compaction recovery sheet")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // UXF-006: Prevent accidental dismissal before user reads compaction details
        .interactiveDismissDisabled(true)
    }

    // MARK: - Header Banner

    /// Prominent banner explaining what happened during compaction.
    private var headerBanner: some View {
        HStack(spacing: theme.spacingMD) {
            ZStack {
                Circle()
                    .fill(theme.warning.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: "scissors")
                    .font(.system(size: theme.fontTitle2, weight: .semibold))
                    .foregroundStyle(theme.warning)
            }

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("Your session was compacted")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Earlier messages were truncated to free up context window space. Paste the snapshot below to restore key decisions.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .background(theme.warning.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.warning.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your session was compacted. Earlier messages were truncated.")
    }

    // MARK: - Token Stats Card

    /// Card showing token counts before, after, and the delta freed by compaction.
    private var tokenStatsCard: some View {
        VStack(spacing: theme.spacingXS) {
            Text("Token Summary")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                tokenStatRow(
                    label: "Before Compaction",
                    description: "Context window usage at compaction",
                    systemImage: "arrow.up.circle",
                    tokens: tokensBeforeCompaction,
                    color: theme.error
                )

                Divider()
                    .background(theme.divider)

                tokenStatRow(
                    label: "After Compaction",
                    description: "Tokens in new context window",
                    systemImage: "arrow.down.circle",
                    tokens: tokensAfterCompaction,
                    color: theme.success
                )

                Divider()
                    .background(theme.divider)

                tokenStatRow(
                    label: "Tokens Freed",
                    description: "Context reclaimed by compaction",
                    systemImage: "minus.circle.fill",
                    tokens: tokensDelta,
                    color: theme.info
                )
            }
            .glassCard(padding: 0)
        }
    }

    /// A single stat row in the token summary card.
    private func tokenStatRow(
        label: String,
        description: String,
        systemImage: String,
        tokens: Int,
        color: Color
    ) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: systemImage)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(color)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            Text(formatTokens(tokens))
                .font(
                    .system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign)
                    .monospacedDigit()
                )
                .foregroundStyle(theme.textPrimary)
        }
        .padding(theme.spacingMD)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(formatTokens(tokens)) tokens")
    }

    // MARK: - Snapshot Section

    /// Displays the pre-compaction snapshot text or a notice when none is available.
    @ViewBuilder
    private var snapshotSection: some View {
        VStack(spacing: theme.spacingXS) {
            HStack {
                Text("Context Snapshot")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Spacer()

                if let snap = snapshot {
                    Text(snap.triggeredAt, style: .relative)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text("ago")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if let snap = snapshot {
                ScrollView {
                    Text(snap.snapshotText)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(theme.spacingMD)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 220)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.divider, lineWidth: 1)
                )
                .accessibilityLabel("Pre-compaction snapshot text")
            } else {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "doc.text")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textTertiary)
                    Text("No snapshot was saved before compaction.")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(theme.spacingMD)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .accessibilityLabel("No pre-compaction snapshot available")
            }
        }
    }

    // MARK: - Action Row

    /// Primary actions: paste as message, copy snapshot to clipboard, and dismiss.
    private var actionRow: some View {
        VStack(spacing: theme.spacingSM) {
            if let snap = snapshot {
                if let paste = onPasteAsMessage {
                    Button {
                        paste(snap.snapshotText)
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: theme.fontBody, weight: .semibold))

                            Text("Paste as Message")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(theme.spacingMD)
                        .background(theme.accent)
                        .foregroundStyle(theme.textOnAccent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paste context snapshot as a message in the chat input")
                }

                Button {
                    copySnapshotToClipboard(snap.snapshotText)
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: copiedToClipboard ? "checkmark.circle.fill" : "doc.on.clipboard")
                            .font(.system(size: theme.fontBody, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))

                        Text(copiedToClipboard ? "Copied!" : "Copy Context to Clipboard")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .background(copiedToClipboard ? theme.success : theme.bgSecondary)
                    .foregroundStyle(copiedToClipboard ? .white : theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                    .animation(.easeInOut(duration: 0.2), value: copiedToClipboard)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copiedToClipboard ? "Context copied to clipboard" : "Copy context snapshot to clipboard for pasting into a new message")
            }

            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .background(theme.bgSecondary)
                    .foregroundStyle(theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss the post-compaction recovery sheet")
        }
    }

    // MARK: - Clipboard

    private func copySnapshotToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        withAnimation {
            copiedToClipboard = true
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation {
                    copiedToClipboard = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Snapshot") {
    PostCompactionRecoverySheet(
        tokensBeforeCompaction: 192_000,
        tokensAfterCompaction: 14_500,
        snapshot: ContextSnapshot(
            id: UUID().uuidString,
            sessionId: UUID().uuidString,
            usedTokens: 192_000,
            contextWindowSize: 200_000,
            snapshotText: """
            ## Session Context Summary

            **Goal:** Refactoring the authentication module to use JWT tokens with refresh logic.

            **Key decisions:**
            - Switched from session cookies to stateless JWT (RS256)
            - Refresh token TTL: 30 days, stored in Keychain under `com.ils.app.refreshToken`
            - Access token TTL: 15 minutes

            **Files modified:**
            - `Sources/ILSBackend/Controllers/AuthController.swift`
            - `ILSApp/ILSApp/Services/KeychainService.swift`
            - `ILSApp/ILSApp/Services/APIClient.swift`

            **Current blocker:** Token refresh race condition when two parallel requests fire simultaneously — need a serial DispatchQueue or async mutex.
            """,
            triggeredAt: Date().addingTimeInterval(-120)
        ),
        onPasteAsMessage: { _ in },
        onDismiss: {}
    )
}

#Preview("No Snapshot") {
    PostCompactionRecoverySheet(
        tokensBeforeCompaction: 188_000,
        tokensAfterCompaction: 11_200,
        snapshot: nil,
        onPasteAsMessage: nil,
        onDismiss: {}
    )
}
