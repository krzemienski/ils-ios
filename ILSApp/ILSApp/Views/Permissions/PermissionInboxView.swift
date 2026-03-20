import SwiftUI
import ILSShared

/// Inbox of pending Claude Code tool-use permission requests.
///
/// Presents a scrollable card list of requests that are awaiting a user decision.
/// Each card shows the tool icon (coloured by risk level), tool name, optional session
/// name, and inline Allow / Deny action buttons. Tapping a card opens a full-detail
/// sheet modelled after `PermissionRequestModal`.
///
/// ## Multi-Select Mode
/// Tap **Select** in the navigation bar to enter multi-select mode. A checkbox appears
/// on each card; selecting one or more cards reveals a ``BatchPermissionView`` bar at
/// the bottom with **Allow All** and **Deny All** buttons. Tap **Done** to exit
/// multi-select without submitting.
///
/// ## Segmented Control
/// A `Picker` at the top switches between the Inbox (pending) and the
/// `PermissionHistoryView` (resolved) segments.
///
/// ## Topics
/// ### State
/// - ``selectedIds`` - Request IDs selected in multi-select mode
/// - ``isSelecting`` - Whether multi-select mode is active
/// - ``selectedSegment`` - 0 = Inbox, 1 = History
struct PermissionInboxView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var selectedIds: Set<String> = []
    @State private var isSelecting: Bool = false
    @State private var selectedPermission: PermissionRecord? = nil
    @State private var selectedSegment: Int = 0

    private var service: PermissionService { appState.permissionService }

    private var batchBarPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .bottomBar
        #else
        .automatic
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            segmentedPicker
            Divider().overlay(theme.divider)

            if selectedSegment == 0 {
                inboxContent
            } else {
                PermissionHistoryView()
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Permissions")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            toolbarContent
        }
        .sheet(item: $selectedPermission) { record in
            PermissionDetailSheet(record: record) { decision in
                submitDecision(record, decision: decision)
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        Picker("View", selection: $selectedSegment) {
            Text("Inbox").tag(0)
            Text("History").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .onChange(of: selectedSegment) {
            // Exit select mode when switching segments
            withAnimation {
                isSelecting = false
                selectedIds.removeAll()
            }
        }
    }

    // MARK: - Inbox Content

    private var inboxContent: some View {
        Group {
            if service.pendingPermissions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingSM) {
                        ForEach(service.pendingPermissions) { record in
                            permissionCard(record)
                        }
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                }
                .refreshable {
                    await refreshPending()
                }
            }
        }
    }

    // MARK: - History Placeholder (replaced by PermissionHistoryView in subtask-4-2)

    private var permissionHistoryPlaceholder: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text("Permission History")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Resolved permissions appear here.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: theme.spacingMD) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48, design: theme.fontDesign))
                .foregroundStyle(theme.success)
            Text("No Pending Permissions")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Claude will ask for approval when it needs to use a tool.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                ApprovalPoliciesView()
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "shield.checkered")
                        .accessibilityHidden(true)
                    Text("Manage Approval Policies")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.accent)
                .padding(.vertical, theme.spacingSM)
                .padding(.horizontal, theme.spacingMD)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(theme.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Permission Card

    @ViewBuilder
    private func permissionCard(_ record: PermissionRecord) -> some View {
        HStack(spacing: theme.spacingSM) {
            // Checkbox in multi-select mode
            if isSelecting {
                Button {
                    toggleSelection(record.requestId)
                } label: {
                    Image(systemName: selectedIds.contains(record.requestId)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.system(size: 22, design: theme.fontDesign))
                        .foregroundStyle(selectedIds.contains(record.requestId)
                                         ? theme.accent
                                         : theme.textTertiary)
                }
                .accessibilityLabel(selectedIds.contains(record.requestId)
                                    ? "Deselect \(record.toolName)"
                                    : "Select \(record.toolName)")
            }

            // Tool icon
            Image(systemName: toolIcon(for: record))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(riskColor(for: record))
                .frame(width: 32, height: 32)
                .background(riskColor(for: record).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            // Tool name + session
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
                    Text(relativeTime(record.requestedAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            // Inline Allow / Deny (hidden in select mode)
            if !isSelecting {
                HStack(spacing: theme.spacingXS) {
                    Button {
                        submitDecision(record, decision: "deny")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, design: theme.fontDesign))
                            .foregroundStyle(theme.error)
                    }
                    .accessibilityLabel("Deny \(record.toolName)")

                    Button {
                        submitDecision(record, decision: "allow")
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, design: theme.fontDesign))
                            .foregroundStyle(theme.success)
                    }
                    .accessibilityLabel("Allow \(record.toolName)")
                }
            }
        }
        .padding(theme.spacingSM)
        .modifier(GlassCard())
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                toggleSelection(record.requestId)
            } else {
                selectedPermission = record
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Select / Done toggle (only shown in Inbox segment with items)
        ToolbarItem(placement: .navigationBarTrailing) {
            if selectedSegment == 0 && !service.pendingPermissions.isEmpty {
                Button(isSelecting ? "Done" : "Select") {
                    withAnimation {
                        isSelecting.toggle()
                        if !isSelecting { selectedIds.removeAll() }
                    }
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
            }
        }

        // Batch action bar at the bottom when items are selected
        if isSelecting && !selectedIds.isEmpty {
            ToolbarItem(placement: batchBarPlacement) {
                BatchPermissionView(
                    selectedCount: selectedIds.count,
                    onAllowAll: { Task { await batchDecide("allow") } },
                    onDenyAll: { Task { await batchDecide("deny") } }
                )
            }
        }
    }

    // MARK: - Actions

    private func refreshPending() async {
        // Polling handles updates; a manual pull-to-refresh just surfaces existing state.
        // When polling is active, the next cycle will update within 2 seconds.
    }

    private func submitDecision(_ record: PermissionRecord, decision: String) {
        Task {
            try? await service.submitDecision(
                requestId: record.requestId,
                decision: decision,
                apiClient: appState.apiClient
            )
        }
    }

    private func batchDecide(_ decision: String) async {
        let ids = Array(selectedIds)
        await service.batchDecide(
            requestIds: ids,
            decision: decision,
            apiClient: appState.apiClient
        )
        withAnimation {
            selectedIds.removeAll()
            isSelecting = false
        }
    }

    private func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    // MARK: - Helpers

    private func toolIcon(for record: PermissionRecord) -> String {
        let name = record.toolName.lowercased()
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

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Permission Detail Sheet

/// Full-detail sheet for a single pending permission request.
///
/// Mirrors the layout of `PermissionRequestModal` — header, scrollable tool info +
/// input preview, and pinned Allow / Deny action buttons. The caller receives the
/// decision string and is responsible for submitting it to the backend.
struct PermissionDetailSheet: View {

    let record: PermissionRecord
    let onDecision: (String) -> Void

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
                    inputPreviewSection
                }
                .padding(theme.spacingMD)
            }
            Divider().overlay(theme.divider)
            actionButtons
        }
        .background(theme.bgPrimary)
        .task {
            formattedInput = Self.formatInput(record.toolInput)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Required")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("Claude wants to use a tool")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Tool Info

    private var toolInfoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("TOOL")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

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
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCard())
        }
    }

    // MARK: - Input Preview

    private var inputPreviewSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("INPUT")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            Text(formattedInput)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(20)
                .padding(theme.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GlassCard())
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            Button {
                onDecision("deny")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Deny")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Deny permission")

            Button {
                onDecision("allow")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Allow")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.success)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel("Allow permission")
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Helpers

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

    /// Formats tool input `AnyCodable` into a human-readable multiline string.
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
        PermissionInboxView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
            .environment(AppState())
    }
}
