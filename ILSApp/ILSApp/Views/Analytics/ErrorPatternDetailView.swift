import SwiftUI
import ILSShared

/// Full-detail sheet for a single ``ErrorPattern``.
///
/// Presents the normalised error signature in a monospaced code block, an
/// occurrence history timeline (first seen / last seen / affected sessions),
/// a ranked list of ``ErrorFix`` suggestions with animated confidence bars, an
/// "Apply Suggested Fix" button that dispatches the fix prompt via
/// ``ErrorPatternsViewModel/applyFix(_:pattern:sessionId:)``, and a
/// "Mark as Resolved" action for unresolved patterns.
///
/// All data arrives pre-loaded inside the ``ErrorPattern`` value; no
/// additional network fetch is required on appearance.  Mutating actions
/// (resolve, apply-fix) delegate through ``viewModel`` so the parent list
/// refreshes automatically.
///
/// ## Topics
/// ### State
/// - ``viewModel`` — Owns resolve and apply-fix mutations; passed from the parent.
/// - ``isApplyingFix`` — Tracks the in-flight apply-fix request to show a spinner.
/// - ``isResolving`` — Tracks the in-flight resolve request to show a spinner.
/// - ``selectedFix`` — The fix chosen for the "Apply" action sheet.
/// - ``showFixConfirmation`` — Controls the apply-fix confirmation alert.
/// - ``showResolveConfirmation`` — Controls the resolve confirmation alert.
/// - ``applySucceeded`` — Set after a successful apply-fix to show a banner.
struct ErrorPatternDetailView: View {
    let pattern: ErrorPattern
    var viewModel: ErrorPatternsViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState

    @State private var isApplyingFix = false
    @State private var isResolving = false
    @State private var selectedFix: ErrorFix?
    @State private var showFixConfirmation = false
    @State private var showResolveConfirmation = false
    @State private var applySucceeded = false

    var body: some View {
        NavigationStack {
            scrollContent
                .background(theme.bgPrimary)
                .navigationTitle("Error Pattern")
                #if os(iOS)
                .inlineNavigationBarTitle()
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .alert(
                    "Apply Suggested Fix",
                    isPresented: $showFixConfirmation,
                    presenting: selectedFix
                ) { fix in
                    Button("Apply Fix") {
                        Task { await applyFix(fix) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { fix in
                    Text("This will send the fix prompt to your active Claude session:\n\n\"\(fix.description)\"")
                }
                .alert(
                    "Mark as Resolved",
                    isPresented: $showResolveConfirmation
                ) {
                    Button("Mark Resolved", role: .destructive) {
                        Task { await resolvePattern() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to mark this error pattern as resolved? This action cannot be undone.")
                }
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: theme.spacingLG) {
                // Success banner for applied fix
                if applySucceeded {
                    applySuccessBanner
                }

                // Error type + summary header
                headerSection

                // Normalised error signature
                signatureSection

                // Occurrence history timeline
                historySection

                // Ranked fix suggestions
                if !pattern.suggestedFixes.isEmpty {
                    fixesSection
                }

                // Mark Resolved action (unresolved patterns only)
                if !pattern.isResolved {
                    resolveButton
                }
            }
            .padding(theme.spacingMD)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                // Error type badge
                Text(pattern.errorType)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(errorTypeColor.opacity(0.9))
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, 4)
                    .background(errorTypeColor.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityLabel("Error type: \(pattern.errorType)")

                Spacer()

                // Resolution status badge
                HStack(spacing: 4) {
                    Image(systemName: pattern.isResolved ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                        .font(.system(size: theme.fontCaption))
                    Text(pattern.isResolved ? "Resolved" : "Unresolved")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(pattern.isResolved ? theme.success : theme.warning)
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, 4)
                .background((pattern.isResolved ? theme.success : theme.warning).opacity(0.1))
                .clipShape(Capsule())
            }

            Text(pattern.summary)
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(pattern.projectName)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Signature Section

    private var signatureSection: some View {
        GroupBox {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(pattern.errorSignature)
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingXS)
            }
        } label: {
            Label("Normalised Error Signature", systemImage: "doc.text.magnifyingglass")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(errorTypeColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error signature: \(pattern.errorSignature)")
    }

    // MARK: - History Section

    private var historySection: some View {
        GroupBox {
            VStack(spacing: theme.spacingSM) {
                historyRow(
                    icon: "clock",
                    label: "First Seen",
                    value: formattedDate(pattern.firstSeenAt),
                    color: theme.textSecondary
                )
                Divider()
                historyRow(
                    icon: "clock.fill",
                    label: "Last Seen",
                    value: formattedDate(pattern.lastSeenAt),
                    color: theme.warning
                )
                Divider()
                historyRow(
                    icon: "repeat",
                    label: "Occurrences",
                    value: "\(pattern.occurrenceCount)",
                    color: theme.error
                )
                Divider()
                historyRow(
                    icon: "text.bubble",
                    label: "Affected Sessions",
                    value: "\(pattern.affectedSessionCount)",
                    color: theme.accent
                )
            }
        } label: {
            Label("Occurrence History", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func historyRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Fixes Section

    private var fixesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Suggested Fixes")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: theme.spacingXS) {
                ForEach(Array(pattern.suggestedFixes.enumerated()), id: \.element.id) { index, fix in
                    fixCard(fix: fix, rank: index + 1)
                }
            }
        }
    }

    private func fixCard(fix: ErrorFix, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Rank and confidence header
            HStack(spacing: theme.spacingSM) {
                // Rank badge
                Text("#\(rank)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingXS)
                    .padding(.vertical, 2)
                    .background(confidenceColor(for: fix.confidence))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                // Confidence percentage
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, design: theme.fontDesign))
                    Text("\(Int(fix.confidence * 100))% confidence")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(confidenceColor(for: fix.confidence))

                Spacer()

                // Success/failure record
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 10))
                    Text("\(fix.successCount)")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.success)

                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                    Text("\(fix.failureCount)")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                }
                .foregroundStyle(theme.textSecondary)
                .font(.system(size: 10, design: theme.fontDesign))
            }

            // Confidence bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.bgSecondary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(confidenceColor(for: fix.confidence).gradient)
                        .frame(
                            width: geo.size.width * min(max(CGFloat(fix.confidence), 0), 1),
                            height: 6
                        )
                        .animation(.easeInOut(duration: 0.5).delay(Double(rank) * 0.1), value: fix.confidence)
                }
            }
            .frame(height: 6)

            // Fix description
            Text(fix.description)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Apply button
            if !isApplyingFix {
                Button {
                    selectedFix = fix
                    showFixConfirmation = true
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Apply Suggested Fix")
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(confidenceColor(for: fix.confidence))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Apply suggested fix: \(fix.description)")
                .accessibilityHint("Sends the fix prompt to your active Claude session")
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Applying…")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.vertical, theme.spacingSM)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(confidenceColor(for: fix.confidence).opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Resolve Button

    private var resolveButton: some View {
        Button {
            showResolveConfirmation = true
        } label: {
            Group {
                if isResolving {
                    HStack(spacing: theme.spacingXS) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Resolving…")
                    }
                } else {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Mark as Resolved")
                    }
                }
            }
            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.success)
            .frame(maxWidth: .infinity)
            .padding(theme.spacingSM)
            .background(theme.success.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.success.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isResolving)
        .accessibilityLabel("Mark this error pattern as resolved")
    }

    // MARK: - Apply Success Banner

    private var applySuccessBanner: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fix Applied")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("The fix prompt has been sent to your Claude session.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .background(theme.success.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.success.opacity(0.3), lineWidth: 0.5)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fix applied successfully")
    }

    // MARK: - Actions

    private func applyFix(_ fix: ErrorFix) async {
        isApplyingFix = true
        // Use a placeholder session UUID — the backend dispatches the
        // prompt into the most-recent active session when no session is specified.
        // In a production flow the parent would inject the current session ID.
        let sessionId = appState.lastSessionId ?? UUID()
        await viewModel.applyFix(fix, pattern: pattern, sessionId: sessionId)
        isApplyingFix = false
        withAnimation {
            applySucceeded = true
        }
    }

    private func resolvePattern() async {
        isResolving = true
        await viewModel.resolvePattern(pattern)
        isResolving = false
        dismiss()
    }

    // MARK: - Helpers

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        // Fallback without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return isoString
    }

    /// Colour-coded by error category, matching ``ErrorPatternsView``.
    private var errorTypeColor: Color {
        switch pattern.errorType.lowercased() {
        case "compilation", "compile": return theme.error
        case "test_failure", "test":   return theme.warning
        case "lint", "linting":        return theme.entitySystem
        case "runtime":                return Color.purple
        default:                       return theme.accent
        }
    }

    /// Colour for confidence score: green ≥ 0.8, orange ≥ 0.5, red otherwise.
    private func confidenceColor(for confidence: Double) -> Color {
        if confidence >= 0.8 { return theme.success }
        if confidence >= 0.5 { return theme.warning }
        return theme.error
    }
}

// MARK: - Preview

#Preview {
    let fix1 = ErrorFix(
        description: "Add missing import for Foundation at the top of the file.",
        fixPrompt: "Please add `import Foundation` to the top of the file that is causing the compilation error.",
        successCount: 12,
        failureCount: 1,
        confidence: 0.92
    )
    let fix2 = ErrorFix(
        description: "Run `swift package resolve` to restore missing dependencies.",
        fixPrompt: "Run `swift package resolve` in the terminal to restore the missing Swift Package Manager dependencies.",
        successCount: 7,
        failureCount: 3,
        confidence: 0.70
    )
    let pattern = ErrorPattern(
        projectName: "ILSApp",
        errorType: "compilation",
        summary: "Missing Foundation import causes build failure",
        errorSignature: "error: no such module 'Foundation'\nimport Foundation\n^",
        occurrenceCount: 14,
        affectedSessionCount: 5,
        firstSeenAt: "2025-10-01T10:30:00Z",
        lastSeenAt: "2025-11-12T14:22:00Z",
        isResolved: false,
        suggestedFixes: [fix1, fix2]
    )
    let viewModel = ErrorPatternsViewModel()
    return ErrorPatternDetailView(pattern: pattern, viewModel: viewModel)
        .environment(AppState())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
