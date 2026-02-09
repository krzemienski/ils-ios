import SwiftUI
import ILSShared

/// Modal presented when Claude requests permission to use a tool.
/// Shows tool name, input preview, and allow/deny buttons.
struct PermissionRequestModal: View {
    let request: PermissionRequest
    let onDecision: (String) -> Void

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider().overlay(theme.divider)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    toolInfoSection
                    inputPreviewSection
                }
                .padding(theme.spacingMD)
            }

            Divider().overlay(theme.divider)

            // Action buttons
            actionButtons
        }
        .background(theme.bgPrimary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 20))
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Permission Required")
                    .font(.system(size: theme.fontTitle3, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text("Claude wants to use a tool")
                    .font(.system(size: theme.fontCaption))
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
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)

            HStack(spacing: theme.spacingSM) {
                Image(systemName: toolIcon)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.toolName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                    Text(toolDescription)
                        .font(.system(size: theme.fontCaption))
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
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)

            Text(formatToolInput())
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(20)
                .padding(theme.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .modifier(GlassCard())
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            Button {
                onDecision("deny")
                dismiss()
            } label: {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Deny")
                        .font(.system(size: theme.fontBody, weight: .semibold))
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
                        .font(.system(size: theme.fontBody, weight: .semibold))
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
        switch request.toolName.lowercased() {
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

    private var toolDescription: String {
        switch request.toolName.lowercased() {
        case let name where name.contains("bash"):
            return "Execute a shell command"
        case let name where name.contains("write"):
            return "Write to a file"
        case let name where name.contains("edit"):
            return "Edit a file"
        case let name where name.contains("read"):
            return "Read a file"
        case let name where name.contains("glob"):
            return "Search for files"
        case let name where name.contains("grep"):
            return "Search file contents"
        default:
            return "Use a tool"
        }
    }

    private func formatToolInput() -> String {
        // AnyCodable wraps the tool input — extract a readable preview
        if let dict = request.toolInput.value as? [String: Any] {
            return dict.map { key, value in
                "\(key): \(String(describing: value))"
            }
            .sorted()
            .joined(separator: "\n")
        }
        return String(describing: request.toolInput.value)
    }
}
