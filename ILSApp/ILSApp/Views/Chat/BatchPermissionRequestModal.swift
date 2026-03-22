import SwiftUI
import ILSShared

/// Grouped permission requests by tool name for batch display.
private struct BatchPermissionGroup: Identifiable {
    let id: String // toolName as unique key
    let toolName: String
    let items: [PermissionRequest]
}

/// Sheet for batch reviewing and approving/denying multiple pending permission requests.
///
/// Displays all pending `PermissionRequest` items grouped by tool name. Each item supports:
/// - Checkbox selection for batch operations
/// - Swipe right (leading edge) to allow an individual request
/// - Swipe left (trailing edge) to deny an individual request
///
/// The header shows total pending count, selected count, and a "Select All / Deselect All" toggle.
/// Batch action buttons in the footer operate on the currently selected items (defaulting to all
/// if none are explicitly selected).
///
/// Individual swipe decisions call `onDecision` immediately and remove the item from the list.
/// When all items have been individually resolved, the sheet auto-dismisses.
///
/// ## Topics
/// ### Input Properties
/// - ``requests`` - The array of pending `PermissionRequest` models to review
///
/// ### Callbacks
/// - ``onDecision`` - Called with an array of request IDs and `"allow"` or `"deny"`
struct BatchPermissionRequestModal: View {
    /// The pending permission requests to review.
    let requests: [PermissionRequest]
    /// Called with an array of request IDs and a decision string (`"allow"` or `"deny"`).
    /// May be called multiple times as items are individually swiped.
    let onDecision: ([String], String) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Selected request IDs for batch operations.
    @State private var selectedIds: Set<String> = []
    /// Requests not yet individually decided via swipe gesture.
    @State private var pendingRequests: [PermissionRequest] = []

    private var allSelected: Bool {
        !pendingRequests.isEmpty && selectedIds.count == pendingRequests.count
    }

    private var groupedRequests: [BatchPermissionGroup] {
        let groups = Dictionary(grouping: pendingRequests) { $0.toolName }
        return groups.sorted { $0.key < $1.key }
            .map { BatchPermissionGroup(id: $0.key, toolName: $0.key, items: $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(theme.divider)

            requestList

            Divider().overlay(theme.divider)

            actionButtons
        }
        .background(theme.bgPrimary)
        .onAppear {
            pendingRequests = requests
            selectedIds = Set(requests.map(\.id))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(pendingRequests.count) Permissions Pending")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("\(selectedIds.count) selected")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            Button {
                toggleSelectAll()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                }
                .foregroundStyle(theme.accent)
            }
            .accessibilityLabel(allSelected ? "Deselect all permissions" : "Select all permissions")
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Request List

    private var requestList: some View {
        List {
            ForEach(groupedRequests) { group in
                Section {
                    ForEach(group.items) { request in
                        permissionRow(for: request)
                            .listRowBackground(theme.bgSecondary)
                            .listRowInsets(EdgeInsets(
                                top: theme.spacingXS,
                                leading: theme.spacingMD,
                                bottom: theme.spacingXS,
                                trailing: theme.spacingMD
                            ))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    decideSingle(request: request, decision: "allow")
                                } label: {
                                    Label("Allow", systemImage: "checkmark.circle.fill")
                                }
                                .tint(theme.success)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    decideSingle(request: request, decision: "deny")
                                } label: {
                                    Label("Deny", systemImage: "xmark.circle.fill")
                                }
                                .tint(theme.error)
                            }
                    }
                } header: {
                    groupSectionHeader(toolName: group.toolName, count: group.items.count)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
    }

    // MARK: - Group Section Header

    private func groupSectionHeader(toolName: String, count: Int) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: toolIcon(for: toolName))
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(toolName.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .kerning(1)
            Text("·")
                .foregroundStyle(theme.textTertiary)
            Text("\(count)")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .padding(.vertical, theme.spacingXS)
        .textCase(nil)
    }

    // MARK: - Permission Row

    private func permissionRow(for request: PermissionRequest) -> some View {
        let isSelected = selectedIds.contains(request.id)
        return HStack(spacing: theme.spacingSM) {
            // Selection checkbox
            Button {
                toggleSelection(for: request.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? "Deselect \(request.toolName)" : "Select \(request.toolName)")

            // Tool icon
            Image(systemName: toolIcon(for: request.toolName))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 28, height: 28)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            // Tool name and input summary
            VStack(alignment: .leading, spacing: 2) {
                Text(request.toolName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(inputSummary(for: request))
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(.vertical, theme.spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: request.id)
        }
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            Button {
                let ids = selectedIds.isEmpty ? pendingRequests.map(\.id) : Array(selectedIds)
                onDecision(ids, "deny")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "xmark.circle.fill")
                    Text(selectedIds.isEmpty ? "Deny All" : "Deny Selected")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.error)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.error.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel(selectedIds.isEmpty ? "Deny all permissions" : "Deny selected permissions")

            Button {
                let ids = selectedIds.isEmpty ? pendingRequests.map(\.id) : Array(selectedIds)
                onDecision(ids, "allow")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(selectedIds.isEmpty ? "Allow All" : "Allow Selected")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM + 2)
                .background(theme.success)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .accessibilityLabel(selectedIds.isEmpty ? "Allow all permissions" : "Allow selected permissions")
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Helpers

    private func toggleSelectAll() {
        if allSelected {
            selectedIds.removeAll()
        } else {
            selectedIds = Set(pendingRequests.map(\.id))
        }
    }

    private func toggleSelection(for id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func decideSingle(request: PermissionRequest, decision: String) {
        onDecision([request.id], decision)
        selectedIds.remove(request.id)
        withAnimation {
            pendingRequests.removeAll { $0.id == request.id }
        }
        if pendingRequests.isEmpty {
            dismiss()
        }
    }

    /// Extracts a short human-readable summary of the tool input for display in the row subtitle.
    private func inputSummary(for request: PermissionRequest) -> String {
        if let dict = request.toolInput.value as? [String: Any] {
            let priorityKeys = ["command", "path", "file_path", "pattern", "query"]
            for key in priorityKeys {
                if let value = dict[key] {
                    return "\(key): \(value)"
                }
            }
            if let first = dict.sorted(by: { $0.key < $1.key }).first {
                return "\(first.key): \(first.value)"
            }
        }
        if let str = request.toolInput.value as? String {
            return str
        }
        return "\(request.toolInput.value)"
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
