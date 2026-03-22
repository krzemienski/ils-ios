import SwiftUI

/// Displays the execution history of hooks — when each hook fired and what it did.
///
/// Entries are shown in reverse chronological order (newest first).  Each row
/// shows a relative timestamp, event-type badge, optional matcher, action
/// summary, and a coloured exit-code badge (green for 0, red for non-zero).
///
/// A toolbar **Clear** button removes all entries via
/// ``HooksViewModel/clearExecutionLog()``.
struct HookExecutionLogView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let viewModel: HooksViewModel

    @State private var showClearConfirm = false
    /// Cached reverse-chronological log to avoid re-reversing on every body evaluation.
    @State private var cachedReversedLog: [HookExecutionEntry] = []
    /// Cached count of succeeded entries to avoid O(n) filter on every body evaluation.
    @State private var cachedSuccessCount: Int = 0

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.executionLog.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Execution Log")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            if !viewModel.executionLog.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear execution log")
                }
            }
        }
        .confirmationDialog(
            "Clear Execution Log?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All Entries", role: .destructive) {
                viewModel.clearExecutionLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all \(viewModel.executionLog.count) log entries.")
        }
        .onAppear { updateCachedLog() }
        .onChange(of: viewModel.executionLog.count) { _, _ in updateCachedLog() }
    }

    /// Refreshes the cached reversed log and success count from the source array.
    private func updateCachedLog() {
        cachedReversedLog = viewModel.executionLog.reversed()
        cachedSuccessCount = viewModel.executionLog.filter(\.succeeded).count
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingSM) {
                countHeader
                ForEach(cachedReversedLog) { entry in
                    logRow(entry)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Count Header

    private var countHeader: some View {
        HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(viewModel.executionLog.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Total Entries")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            let successCount = cachedSuccessCount
            VStack(spacing: 2) {
                Text("\(successCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
                Text("Succeeded")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.success.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Log Row

    private func logRow(_ entry: HookExecutionEntry) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Top row: action summary + result badge
            HStack(spacing: theme.spacingSM) {
                Image(systemName: iconForHookType(entry.hookType))
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text(entry.actionSummary)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Spacer()

                exitCodeBadge(for: entry)
            }

            // Metadata row: event type, matcher, duration, timestamp
            HStack(spacing: theme.spacingSM) {
                // Event type badge
                Text(labelForEventType(entry.eventType))
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Matcher badge
                if let matcher = entry.matcher, !matcher.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .accessibilityHidden(true)
                        Text(matcher)
                            .lineLimit(1)
                    }
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.warning.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()

                // Duration
                if let ms = entry.durationMs {
                    Text("\(ms) ms")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                // Relative timestamp
                Text(entry.timestamp, style: .relative)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }

            // Output snippet (if any)
            if let output = entry.output, !output.isEmpty {
                Text(output)
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(entry.succeeded ? theme.textSecondary : theme.error)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .padding(theme.spacingSM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(labelForEventType(entry.eventType)) hook, \(entry.actionSummary), \(entry.succeeded ? "succeeded" : "failed")")
    }

    // MARK: - Exit Code Badge

    @ViewBuilder
    private func exitCodeBadge(for entry: HookExecutionEntry) -> some View {
        if let code = entry.exitCode {
            Text("exit \(code)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: .monospaced))
                .foregroundStyle(entry.succeeded ? theme.success : theme.error)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((entry.succeeded ? theme.success : theme.error).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .accessibilityLabel("Succeeded")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 40, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)

                Text("No Execution History")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Hook execution entries will appear here once hooks begin firing. Configure hooks and run Claude Code to populate this log.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    // MARK: - Helpers

    private func labelForEventType(_ eventType: String) -> String {
        HooksViewModel.allEventTypes.first { $0.name == eventType }?.label ?? eventType
    }

    private func iconForHookType(_ type: String) -> String {
        switch type {
        case "command": return "terminal"
        case "http": return "network"
        case "prompt": return "text.bubble"
        case "agent": return "person.crop.circle"
        default: return "terminal"
        }
    }
}

#Preview {
    NavigationStack {
        HookExecutionLogView(viewModel: HooksViewModel())
    }
}
