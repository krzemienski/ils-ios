import SwiftUI
import ILSShared

/// Modal presented when Claude requests permission to use a tool.
/// Shows tool name, input preview, and allow/deny buttons.
struct PermissionRequestModal: View {
    let request: PermissionRequest
    let onDecision: (String) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
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
                    Text(request.toolName)
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

            Text(formatToolInput())
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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

    private static let toolIconMap: [String: String] = [
        "bash": "terminal",
        "write": "doc.text",
        "edit": "pencil",
        "read": "eye",
        "glob": "magnifyingglass",
        "grep": "magnifyingglass"
    ]

    private static let toolDescriptionMap: [String: String] = [
        "bash": "Execute a shell command",
        "write": "Write to a file",
        "edit": "Edit a file",
        "read": "Read a file",
        "glob": "Search for files",
        "grep": "Search file contents"
    ]

    /// All keywords sorted longest-first so "write" doesn't shadow "overwrite" etc.
    private static let toolKeywords: [String] = toolIconMap.keys.sorted { $0.count > $1.count }

    private var toolIcon: String {
        let name = request.toolName.lowercased()
        for keyword in Self.toolKeywords {
            if name.contains(keyword) { return Self.toolIconMap[keyword]! }
        }
        return "wrench"
    }

    private var toolDescription: String {
        let name = request.toolName.lowercased()
        for keyword in Self.toolKeywords {
            if name.contains(keyword) { return Self.toolDescriptionMap[keyword]! }
        }
        return "Use a tool"
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
