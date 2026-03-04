import SwiftUI
import ILSShared

/// Displays the full permission decision history with stats, search, and navigation to auto-approve rules.
///
/// Shows three summary stat cards (Allowed, Denied, Auto-Approved), an approval-rate progress
/// bar, and a searchable, scrollable history list ordered newest-first. Each row shows the
/// decision badge, tool name, input summary, and relative timestamp. Tapping a row opens a
/// read-only ``PermissionHistoryDetailSheet``.
///
/// Toolbar contains a 'Rules' NavigationLink to ``AutoApproveRulesView`` and a 'Clear All'
/// menu item guarded by a confirmation alert.
struct PermissionHistoryView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState

    @State private var viewModel = PermissionHistoryViewModel()
    @State private var searchText: String = ""
    @State private var selectedRecord: PermissionRecord? = nil
    @State private var isLoading: Bool = false

    private var service: PermissionService { appState.permissionService }

    private var filteredHistory: [PermissionRecord] {
        guard !searchText.isEmpty else { return service.permissionHistory }
        let query = searchText.lowercased()
        return service.permissionHistory.filter {
            $0.toolName.lowercased().contains(query)
                || ($0.sessionName?.lowercased().contains(query) ?? false)
                || ($0.projectName?.lowercased().contains(query) ?? false)
        }
    }

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
            await loadServiceHistory()
        }
        .sheet(item: $selectedRecord) { record in
            PermissionHistoryDetailSheet(record: record)
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
        .searchable(text: $searchText, prompt: "Search tool, session, project")
        .refreshable {
            await viewModel.loadHistory()
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
            if filteredHistory.isEmpty && !searchText.isEmpty {
                noResultsState
            } else {
                ForEach(filteredHistory) { record in
                    historyRow(record: record)
                }
            }
        }
    }

    // MARK: - History Row (PermissionRecord — from service)

    @ViewBuilder
    private func historyRow(record: PermissionRecord) -> some View {
        HStack(spacing: theme.spacingSM) {
            // Tool icon (risk-coloured)
            Image(systemName: toolIcon(for: record.toolName))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(riskColor(for: record))
                .frame(width: 32, height: 32)
                .background(riskColor(for: record).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.toolName)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let session = record.sessionName {
                    Text(session)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(relativeTime(record.resolvedAt ?? record.requestedAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Status badge
            statusBadge(for: record)
        }
        .padding(theme.spacingSM)
        .modifier(GlassCard())
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRecord = record
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.toolName), \(statusLabel(for: record))")
    }

    // MARK: - Status Badge

    @ViewBuilder
    private func statusBadge(for record: PermissionRecord) -> some View {
        let (label, color, icon) = statusStyle(for: record)
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text(label)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(color)
        .padding(.horizontal, theme.spacingXS + 2)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
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

    private var noResultsState: some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("No results for \"\(searchText)\"")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity)
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

    // MARK: - Actions

    private func loadServiceHistory() async {
        isLoading = true
        await service.loadHistory(apiClient: appState.apiClient)
        isLoading = false
    }

    // MARK: - Helpers

    private func accessibilityLabel(for entry: PermissionHistoryEntry) -> String {
        let decision = entry.isAutoApproved ? "auto-approved" : (entry.decision == "allow" ? "allowed" : "denied")
        let time = DateFormatters.relativeDateTime.localizedString(for: entry.timestamp, relativeTo: Date())
        return "\(entry.toolName) \(decision), \(time)"
    }

    private func toolIcon(for toolName: String) -> String {
        let name = toolName.lowercased()
        if name.contains("bash") { return "terminal" }
        if name.contains("write") { return "doc.text" }
        if name.contains("edit") { return "pencil" }
        if name.contains("read") { return "eye" }
        if name.contains("glob") || name.contains("grep") { return "magnifyingglass" }
        return "wrench"
    }

    private func riskColor(for record: PermissionRecord) -> Color {
        switch record.riskLevel {
        case .low: return theme.accent
        case .medium: return theme.warning
        case .high, .critical: return theme.error
        }
    }

    /// Returns `(label, tintColor, sfSymbol)` for a history row status badge.
    private func statusStyle(for record: PermissionRecord) -> (String, Color, String) {
        switch record.status {
        case .approved:
            return ("Allowed", theme.success, "checkmark.circle.fill")
        case .denied:
            return ("Denied", theme.error, "xmark.circle.fill")
        case .autoApproved:
            return ("Auto", theme.accent, "bolt.circle.fill")
        case .expired:
            return ("Expired", theme.textTertiary, "clock.badge.xmark")
        case .pending:
            return ("Pending", theme.warning, "clock.fill")
        }
    }

    private func statusLabel(for record: PermissionRecord) -> String {
        statusStyle(for: record).0
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Permission History Detail Sheet

/// Read-only detail sheet for a resolved permission history record.
///
/// Shows the tool icon, name, description, formatted input, resolution metadata
/// (resolved-by, resolved-at, deny reason), and risk-level badge. Unlike
/// `PermissionDetailSheet` there are no action buttons — the decision is final.
struct PermissionHistoryDetailSheet: View {

    let record: PermissionRecord

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    @State private var formattedInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.divider)
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    toolInfoSection
                    resolutionSection
                    inputPreviewSection
                }
                .padding(theme.spacingMD)
            }
        }
        .background(theme.bgPrimary)
        .task {
            formattedInput = Self.formatInput(record.toolInput)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            let (_, color, icon) = statusStyle
            Image(systemName: icon)
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text("Permission History")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(statusStyle.0)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(statusStyle.1)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .accessibilityLabel("Close")
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Tool Info

    private var toolInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("TOOL")

            HStack(spacing: theme.spacingSM) {
                Image(systemName: toolIcon)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.toolName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(toolDescription)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                // Risk badge
                riskBadge
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCard())
        }
    }

    // MARK: - Resolution Section

    private var resolutionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("RESOLUTION")

            VStack(spacing: 0) {
                if let sessionName = record.sessionName {
                    metaRow("Session", value: sessionName)
                    Divider().background(theme.bgTertiary)
                }

                if let projectName = record.projectName {
                    metaRow("Project", value: projectName)
                    Divider().background(theme.bgTertiary)
                }

                if let resolvedBy = record.resolvedBy {
                    metaRow("Resolved By", value: resolvedByLabel(resolvedBy))
                    Divider().background(theme.bgTertiary)
                }

                if let resolvedAt = record.resolvedAt {
                    metaRow("Resolved At", value: formatDate(resolvedAt))
                    Divider().background(theme.bgTertiary)
                }

                metaRow("Requested At", value: formatDate(record.requestedAt))

                if let reason = record.denyReason {
                    Divider().background(theme.bgTertiary)
                    metaRow("Deny Reason", value: reason)
                }

                if record.isSessionApproval {
                    Divider().background(theme.bgTertiary)
                    metaRow("Scope", value: "Session-wide")
                }
            }
            .padding(theme.spacingSM)
            .modifier(GlassCard())
        }
    }

    // MARK: - Input Preview

    private var inputPreviewSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("INPUT")

            Text(formattedInput)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(30)
                .padding(theme.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GlassCard())
        }
    }

    // MARK: - Sub-Components

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    @ViewBuilder
    private func metaRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, theme.spacingXS)
    }

    private var riskBadge: some View {
        let (label, color) = riskStyle
        return Text(label)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var statusStyle: (String, Color, String) {
        switch record.status {
        case .approved:
            return ("Allowed", theme.success, "checkmark.circle.fill")
        case .denied:
            return ("Denied", theme.error, "xmark.circle.fill")
        case .autoApproved:
            return ("Auto-Approved", theme.accent, "bolt.circle.fill")
        case .expired:
            return ("Expired", theme.textTertiary, "clock.badge.xmark")
        case .pending:
            return ("Pending", theme.warning, "clock.fill")
        }
    }

    private var riskStyle: (String, Color) {
        switch record.riskLevel {
        case .low: return ("Low", theme.accent)
        case .medium: return ("Medium", theme.warning)
        case .high: return ("High", theme.error)
        case .critical: return ("Critical", theme.error)
        }
    }

    private var toolIcon: String {
        let name = record.toolName.lowercased()
        if name.contains("bash") { return "terminal" }
        if name.contains("write") { return "doc.text" }
        if name.contains("edit") { return "pencil" }
        if name.contains("read") { return "eye" }
        if name.contains("glob") || name.contains("grep") { return "magnifyingglass" }
        return "wrench"
    }

    private var toolDescription: String {
        let name = record.toolName.lowercased()
        if name.contains("bash") { return "Execute a shell command" }
        if name.contains("write") { return "Write to a file" }
        if name.contains("edit") { return "Edit a file" }
        if name.contains("read") { return "Read a file" }
        if name.contains("glob") { return "Search for files" }
        if name.contains("grep") { return "Search file contents" }
        return "Use a tool"
    }

    private func resolvedByLabel(_ resolvedBy: String) -> String {
        switch resolvedBy {
        case "user": return "User"
        case "auto": return "Auto-Approve Rule"
        case "timeout": return "Timeout"
        default: return resolvedBy.capitalized
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatInput(_ toolInput: AnyCodable) -> String {
        if let dict = toolInput.value as? [String: Any] {
            return dict.map { "\($0.key): \($0.value)" }
                .sorted()
                .joined(separator: "\n")
        }
        if let stringValue = toolInput.value as? String {
            return stringValue
        }
        return "\(toolInput.value)"
    }
}

#Preview {
    NavigationStack {
        PermissionHistoryView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
            .environment(AppState())
    }
}
