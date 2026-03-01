import SwiftUI
import ILSShared

/// Live JSON preview panel for a hook configuration under construction.
///
/// Accepts the raw form-field values from ``HookEditorSheet`` and renders the
/// serialized JSON that would be written to the Claude Code settings file.
/// Includes a validation status indicator and a copy-to-clipboard button.
struct HookPreviewPanel: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let eventType: String
    let matcher: String
    let handlerType: String
    let command: String
    let url: String
    let promptText: String
    let isAsync: Bool
    let timeout: String  // raw text input — may be empty or non-numeric

    @State private var showCopied = false

    // MARK: - Validation

    private var validationError: String? {
        switch handlerType {
        case "command":
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Command is required"
            }
        case "http":
            if url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "URL is required"
            }
        case "prompt", "agent":
            if promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Prompt text is required"
            }
        default:
            return "Unknown handler type"
        }
        return nil
    }

    private var isValid: Bool { validationError == nil }

    // MARK: - JSON Generation

    /// Builds a HookGroup from current form state and serializes it to JSON.
    ///
    /// Empty required fields are replaced with placeholder text so the preview
    /// always produces valid JSON structure even when the form is incomplete.
    private var previewJSON: String {
        var hookDef = HookDefinition()
        hookDef.type = handlerType

        switch handlerType {
        case "command":
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            hookDef.command = trimmed.isEmpty ? "<command>" : trimmed
            if isAsync { hookDef.isAsync = true }
        case "http":
            let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
            hookDef.url = trimmed.isEmpty ? "<url>" : trimmed
        case "prompt", "agent":
            let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            hookDef.prompt = trimmed.isEmpty ? "<prompt>" : trimmed
        default:
            break
        }

        if let t = Int(timeout), t > 0 {
            hookDef.timeout = t
        }

        let trimmedMatcher = matcher.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = HookGroup(
            matcher: trimmedMatcher.isEmpty ? nil : trimmedMatcher,
            hooks: [hookDef]
        )

        // Wrap in the structure used by Claude Code settings: { "EventType": [HookGroup] }
        let configDict = [eventType: [group]]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(configDict),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
                .background(theme.divider)
            ScrollView {
                Text(previewJSON)
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingMD)
                    .textSelection(.enabled)
            }
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: theme.spacingSM) {
            Label {
                Text("JSON Preview")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            } icon: {
                Image(systemName: "curlybraces")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            validationBadge

            Divider()
                .frame(height: 16)

            copyButton
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
    }

    // MARK: - Validation Badge

    private var validationBadge: some View {
        Group {
            if isValid {
                Label("Valid", systemImage: "checkmark.circle.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.success)
            } else {
                Label(validationError ?? "Invalid", systemImage: "xmark.circle.fill")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }
        }
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            copyToClipboard()
        } label: {
            Label(
                showCopied ? "Copied" : "Copy",
                systemImage: showCopied ? "checkmark" : "doc.on.doc"
            )
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(showCopied ? theme.success : theme.textSecondary)
            .animation(.easeInOut(duration: 0.2), value: showCopied)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = previewJSON
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(previewJSON, forType: .string)
        #endif

        showCopied = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            showCopied = false
        }
    }
}
