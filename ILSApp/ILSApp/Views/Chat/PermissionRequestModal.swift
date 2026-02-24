import SwiftUI
import ILSShared

/// Sheet that interrupts the chat flow to let the user approve or deny a Claude tool-use request.
///
/// Structured as a fixed three-zone layout: a header with a shield icon and "Permission Required"
/// title, a scrollable body showing the tool name/icon/description and a formatted input preview,
/// and a pinned footer with Deny (error-tinted) and Allow (success-filled) buttons.
///
/// The tool icon and human-readable description are derived from keyword matching on
/// `request.toolName` (bash → terminal, write → doc.text, etc.) via private computed properties.
/// The `request.toolInput` `AnyCodable` value is unpacked into a sorted `key: value` multiline
/// string for the input preview section.
///
/// Tapping either action button calls `onDecision` with `"allow"` or `"deny"`, then dismisses
/// the sheet using the SwiftUI environment `dismiss` action. The caller is responsible for
/// forwarding the decision string to the backend permission endpoint.
///
/// ## Topics
/// ### Input Properties
/// - ``request`` - The `PermissionRequest` model describing the tool name and encoded input
///
/// ### Callbacks
/// - ``onDecision`` - Called with `"allow"` or `"deny"` before the sheet is dismissed
struct PermissionRequestModal: View {
    /// The permission request describing which tool Claude wants to invoke and its input payload.
    let request: PermissionRequest
    /// Called with `"allow"` or `"deny"` when the user taps an action button.
    /// The sheet is dismissed immediately after this closure returns.
    let onDecision: (String) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    /// Pre-computed formatted tool input string, populated on appear.
    @State private var formattedToolInput: String = ""

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
        .task {
            formattedToolInput = Self.formatToolInput(request.toolInput)
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

            Text(formattedToolInput)
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

    /// Formats tool input for display. Static to keep it out of the body evaluation path.
    // MOD-MED-3: Use string interpolation instead of String(describing:).
    // For [String: Any] dictionaries, interpolation is equivalent but more idiomatic.
    private static func formatToolInput(_ toolInput: AnyCodable) -> String {
        if let dict = toolInput.value as? [String: Any] {
            return dict.map { key, value in
                "\(key): \(value)"
            }
            .sorted()
            .joined(separator: "\n")
        }
        if let stringValue = toolInput.value as? String {
            return stringValue
        }
        return "\(toolInput.value)"
    }
}
