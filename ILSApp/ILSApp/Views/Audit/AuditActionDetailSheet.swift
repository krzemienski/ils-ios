import SwiftUI
import ILSShared

/// Detail sheet for a single ``AuditAction`` showing full before/after state and a
/// one-tap rollback button.
///
/// Displays all metadata fields for the selected action — type, timestamp, session,
/// file path, command, or tool name — followed by an expandable before/after diff
/// section for file operations. A prominent **Rollback** button is shown when the
/// action is eligible for rollback.
///
/// ## Topics
/// ### Callbacks
/// - ``onRollback`` — Invoked when the user confirms and requests a rollback.
struct AuditActionDetailSheet: View {
    let action: AuditAction
    /// Called when the user confirms a rollback. The caller is responsible for
    /// executing the rollback via ``AuditTrailViewModel/rollbackAction(actionId:)``.
    var onRollback: ((AuditAction) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Local State

    /// Controls the rollback confirmation alert.
    @State private var showRollbackAlert = false
    /// Whether the "Before" content block is expanded.
    @State private var isBeforeExpanded = false
    /// Whether the "After" content block is expanded.
    @State private var isAfterExpanded = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    metadataSection

                    if action.actionType == .fileWrite || action.actionType == .fileCreate || action.actionType == .fileDelete {
                        contentDiffSection
                    }

                    if let command = action.command, !command.isEmpty {
                        commandSection(command)
                    }

                    if let metadata = action.metadata, !metadata.isEmpty {
                        metadataJsonSection(metadata)
                    }

                    rollbackSection
                }
                .padding()
            }
            .background(theme.bgPrimary)
            .navigationTitle("Action Detail")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // MARK: Rollback confirmation alert
        .alert("Rollback This Action?", isPresented: $showRollbackAlert) {
            Button("Rollback", role: .destructive) {
                onRollback?(action)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(rollbackAlertMessage)
        }
    }

    // MARK: - Subviews

    /// Header card with icon, action type, and primary title.
    private var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: action.actionType.systemImageName)
                .font(.system(size: theme.fontTitle2))
                .foregroundStyle(action.actionType.tintColor(theme: theme))
                .frame(width: 48, height: 48)
                .background(
                    action.actionType.tintColor(theme: theme).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(action.displayTitle)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Text(action.actionType.displayLabel)
                    .font(.subheadline)
                    .foregroundStyle(action.actionType.tintColor(theme: theme))
            }

            Spacer()

            if action.rollbackStatus == .rolledBack {
                Text("Rolled Back")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.bgSecondary, in: Capsule())
            }
        }
        .padding()
        .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Key/value metadata rows: session, timestamp, file path, tool name.
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Details")

            VStack(spacing: 0) {
                metadataRow(label: "Session", value: action.sessionName ?? action.sessionId)
                Divider().padding(.leading, 16)
                metadataRow(label: "Timestamp", value: action.createdAt.formatted(date: .abbreviated, time: .complete))

                if let filePath = action.filePath, !filePath.isEmpty {
                    Divider().padding(.leading, 16)
                    metadataRow(label: "File Path", value: filePath)
                }

                if let toolName = action.toolName, !toolName.isEmpty {
                    Divider().padding(.leading, 16)
                    metadataRow(label: "Tool", value: toolName)
                }

                if action.rollbackStatus == .rolledBack, let rolledBackAt = action.rolledBackAt {
                    Divider().padding(.leading, 16)
                    metadataRow(
                        label: "Rolled Back At",
                        value: rolledBackAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                Divider().padding(.leading, 16)
                metadataRow(label: "Rollbackable", value: action.isRollbackable ? "Yes" : "No")
            }
            .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Before/after content diff section for file operations.
    private var contentDiffSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Content Changes")

            if action.beforeContent == nil && action.afterContent == nil {
                Text("No content recorded for this action.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                if let before = action.beforeContent {
                    contentBlock(
                        label: "Before",
                        content: before,
                        accentColor: theme.error,
                        isExpanded: $isBeforeExpanded
                    )
                }

                if let after = action.afterContent {
                    contentBlock(
                        label: "After",
                        content: after,
                        accentColor: theme.success,
                        isExpanded: $isAfterExpanded
                    )
                }
            }
        }
    }

    /// Collapsible code block for before/after content.
    private func contentBlock(
        label: String,
        content: String,
        accentColor: Color,
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 16)

                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)

                    Spacer()

                    Text("\(content.components(separatedBy: .newlines).count) lines")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 280)
            }
        }
        .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    /// Command preview block for bash/shell actions.
    private func commandSection(_ command: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Command")

            ScrollView(.horizontal, showsIndicators: false) {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.warning.opacity(0.25), lineWidth: 1)
            )
        }
    }

    /// Raw JSON metadata block.
    private func metadataJsonSection(_ json: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Metadata")

            ScrollView(.horizontal, showsIndicators: false) {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(theme.bgSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    /// Rollback button section, shown only when the action can be rolled back.
    @ViewBuilder
    private var rollbackSection: some View {
        if action.canRollback {
            VStack(spacing: 10) {
                Button {
                    showRollbackAlert = true
                } label: {
                    Label("Rollback This Action", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.error, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Text("This will restore the file to its state before this action. The rollback itself will be recorded in the audit trail.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.textSecondary)
            .textCase(.uppercase)
            .padding(.bottom, 4)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Contextual alert message body for the rollback confirmation.
    private var rollbackAlertMessage: String {
        if let filePath = action.filePath, !filePath.isEmpty {
            return "This will restore \"\((filePath as NSString).lastPathComponent)\" to its state before this action. The rollback will be recorded in the audit trail."
        }
        if let command = action.command, !command.isEmpty {
            let preview = String(command.prefix(60))
            return "This will attempt to reverse the command: \(preview). The rollback will be recorded in the audit trail."
        }
        return "This will attempt to reverse the action. The rollback will be recorded in the audit trail."
    }
}

// MARK: - AuditActionType Helpers

private extension AuditActionType {
    /// SF Symbol name that represents this action category.
    var systemImageName: String {
        switch self {
        case .fileWrite:          return "pencil"
        case .fileCreate:         return "plus.square"
        case .fileDelete:         return "trash"
        case .bashCommand:        return "terminal"
        case .toolUse:            return "wrench.and.screwdriver"
        case .permissionDecision: return "lock.shield"
        case .rollback:           return "arrow.uturn.backward"
        }
    }

    /// Human-readable label for the action category.
    var displayLabel: String {
        switch self {
        case .fileWrite:          return "File Write"
        case .fileCreate:         return "File Create"
        case .fileDelete:         return "File Delete"
        case .bashCommand:        return "Bash Command"
        case .toolUse:            return "Tool Use"
        case .permissionDecision: return "Permission Decision"
        case .rollback:           return "Rollback"
        }
    }

    /// Tint colour appropriate for this action category.
    func tintColor(theme: ThemeSnapshot) -> Color {
        switch self {
        case .fileWrite:          return theme.accent
        case .fileCreate:         return theme.success
        case .fileDelete:         return theme.error
        case .bashCommand:        return theme.warning
        case .toolUse:            return theme.textSecondary
        case .permissionDecision: return theme.info
        case .rollback:           return theme.textSecondary
        }
    }
}
