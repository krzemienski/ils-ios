import SwiftUI

/// Displays the full permission decision history with stats and navigation to auto-approve rules.
///
/// Shows three summary stat cards (Allowed, Denied, Auto-Approved), an approval-rate progress
/// bar, and a scrollable history list ordered newest-first. Each row shows the decision badge,
/// tool name, input summary, and relative timestamp.
///
/// Toolbar contains a 'Rules' NavigationLink to ``AutoApproveRulesView`` and a 'Clear All'
/// menu item guarded by a confirmation alert.
struct PermissionHistoryView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = PermissionHistoryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.history.isEmpty {
                loadingState
            } else if viewModel.history.isEmpty {
                emptyState
            } else {
                historyContent
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Permissions")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: theme.spacingSM) {
                    NavigationLink {
                        AutoApproveRulesView()
                    } label: {
                        Text("Rules")
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    }
                    .accessibilityLabel("Auto-approve rules")

                    Menu {
                        Button(role: .destructive) {
                            viewModel.showClearConfirmation = true
                        } label: {
                            Label("Clear All History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .refreshable {
            await viewModel.loadHistory()
        }
        .task {
            await viewModel.loadHistory()
        }
        .alert("Clear Permission History", isPresented: $viewModel.showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel.clearHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all permission history. This cannot be undone.")
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                statsSection
                historySection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                statCard(label: "Allowed", count: viewModel.stats.totalApproved, color: theme.success)
                statCard(label: "Denied", count: viewModel.stats.totalDenied, color: theme.error)
                statCard(label: "Auto", count: viewModel.stats.totalAutoApproved, color: theme.info)
            }

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack {
                    Text("Approval Rate")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("\(Int(viewModel.stats.approvalRate * 100))%")
                        .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.success)
                }
                ProgressView(value: viewModel.stats.approvalRate)
                    .tint(theme.success)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    private func statCard(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingSM)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(count)")
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(spacing: theme.spacingXS) {
            ForEach(viewModel.history) { entry in
                historyRow(entry: entry)
            }
        }
    }

    private func historyRow(entry: PermissionHistoryEntry) -> some View {
        HStack(spacing: theme.spacingSM) {
            decisionBadge(for: entry)

            Image(systemName: toolIcon(for: entry.toolName))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 28, height: 28)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.toolName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                if !entry.toolInputSummary.isEmpty {
                    Text(entry.toolInputSummary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            Text(DateFormatters.relativeDateTime.localizedString(for: entry.timestamp, relativeTo: Date()))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
    }

    private func decisionBadgeInfo(for entry: PermissionHistoryEntry) -> (String, Color) {
        if entry.isAutoApproved {
            return ("Auto", theme.info)
        } else if entry.decision == "allow" {
            return ("Allow", theme.success)
        } else {
            return ("Deny", theme.error)
        }
    }

    private func decisionBadge(for entry: PermissionHistoryEntry) -> some View {
        let (label, color) = decisionBadgeInfo(for: entry)
        return Text(label)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                Image(systemName: "shield.slash")
                    .font(.system(size: 40, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)

                Text("No Permission History")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("Allow or deny requests during a Claude Code session to see them here.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)

                NavigationLink {
                    AutoApproveRulesView()
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "checkmark.shield.fill")
                            .accessibilityHidden(true)
                        Text("Manage Auto-Approve Rules")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingMD)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading history...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func accessibilityLabel(for entry: PermissionHistoryEntry) -> String {
        let decision = entry.isAutoApproved ? "auto-approved" : (entry.decision == "allow" ? "allowed" : "denied")
        let time = DateFormatters.relativeDateTime.localizedString(for: entry.timestamp, relativeTo: Date())
        return "\(entry.toolName) \(decision), \(time)"
    }

    private func toolIcon(for toolName: String) -> String {
        switch toolName.lowercased() {
        case let name where name.contains("bash"):
            return "terminal"
        case let name where name.contains("write"):
            return "doc.text"
        case let name where name.contains("edit"):
            return "pencil"
        case let name where name.contains("read"):
            return "eye"
        case let name where name.contains("glob"), let name where name.contains("grep"):
            return "magnifyingglass"
        default:
            return "wrench"
        }
    }
}

#Preview {
    NavigationStack {
        PermissionHistoryView()
    }
}
