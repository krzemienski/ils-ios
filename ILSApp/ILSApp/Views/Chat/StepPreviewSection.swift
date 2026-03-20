import SwiftUI
import ILSShared

/// Reusable view that renders a human-readable "action plan" for a permission request.
///
/// Displays five information zones:
/// 1. **Action summary** — plain-English description of what the tool will do
///    (e.g. "Write 45 lines to src/models/User.swift").
/// 2. **Affected files** — file paths extracted from the tool input, with path highlighting.
/// 3. **Risk level badge** — color-coded pill indicating `low` / `medium` / `high` / `critical`.
/// 4. **Policy match** — which approval policy matched and why (if a `PolicyEvaluationResult`
///    is provided).
/// 5. **Command preview** — for bash tools, the full command rendered in a `ThemedCodeBlockView`.
///
/// Designed to be embedded inside `PermissionRequestModal` or any approval-flow sheet.
///
/// ## Topics
/// ### Input Properties
/// - ``request`` - The `PermissionRequest` describing the tool and its input
/// - ``riskLevel`` - Assessed risk level for color-coded badge display
/// - ``policyEvaluation`` - Optional policy evaluation result explaining the matched policy
struct StepPreviewSection: View {
    /// The permission request describing which tool Claude wants to invoke.
    let request: PermissionRequest
    /// The assessed risk level for this action.
    let riskLevel: PermissionRiskLevel
    /// Optional policy evaluation result, shown when a policy matched the request.
    let policyEvaluation: PolicyEvaluationResult?

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            actionSummarySection
            affectedFilesSection
            riskLevelSection

            if let evaluation = policyEvaluation {
                policyMatchSection(evaluation)
            }

            if isBashTool, let command = extractCommand() {
                commandPreviewSection(command)
            }
        }
    }

    // MARK: - Action Summary

    private var actionSummarySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionHeader("ACTION")

            HStack(spacing: theme.spacingSM) {
                Image(systemName: toolIcon)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(riskBadgeColor)
                    .frame(width: 28, height: 28)
                    .background(riskBadgeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                Text(actionDescription)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(3)
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCard())
        }
    }

    // MARK: - Affected Files

    private var affectedFilesSection: some View {
        let files = extractAffectedFiles()
        return Group {
            if !files.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionHeader("AFFECTED FILES")

                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(files, id: \.self) { filePath in
                            HStack(spacing: theme.spacingXS) {
                                Image(systemName: "doc")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)

                                filePathText(filePath)
                            }
                        }
                    }
                    .padding(theme.spacingSM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GlassCard())
                }
            }
        }
    }

    // MARK: - Risk Level Badge

    private var riskLevelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionHeader("RISK LEVEL")

            HStack(spacing: theme.spacingSM) {
                Text(riskLevel.rawValue.uppercased())
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(riskTextColor)
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, theme.spacingXS)
                    .background(riskBadgeColor.opacity(0.15))
                    .clipShape(Capsule())

                Text(riskExplanation)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCard())
        }
    }

    // MARK: - Policy Match

    private func policyMatchSection(_ evaluation: PolicyEvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionHeader("POLICY MATCH")

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: policyActionIcon(evaluation.action))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(policyActionColor(evaluation.action))

                    Text(policyActionLabel(evaluation.action))
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(policyActionColor(evaluation.action))
                }

                Text(evaluation.explanation)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(4)

                if let reasonCode = evaluation.reasonCode {
                    Text("Reason: \(reasonCode.rawValue)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(theme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassCard())
        }
    }

    // MARK: - Command Preview

    private func commandPreviewSection(_ command: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionHeader("COMMAND")

            ThemedCodeBlockView(language: "bash", code: command)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    /// Renders a file path with the directory portion dimmed and the filename highlighted.
    private func filePathText(_ path: String) -> some View {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if components.count > 1 {
            let directory = components.dropLast().joined(separator: "/") + "/"
            let filename = String(components.last ?? "")
            return (
                Text(directory)
                    .font(.system(size: theme.fontCaption, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                +
                Text(filename)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
            )
        } else {
            return (
                Text(path)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                +
                Text("")  // Ensures consistent return type
            )
        }
    }

    // MARK: - Tool Analysis Helpers

    private var isBashTool: Bool {
        request.toolName.lowercased().contains("bash")
    }

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

    /// Generates a plain-English description of what the tool will do.
    private var actionDescription: String {
        let toolName = request.toolName.lowercased()
        let dict = request.toolInput.value as? [String: Any]

        if toolName.contains("bash") {
            let command = dict?["command"] as? String ?? "a shell command"
            let truncated = command.count > 80 ? String(command.prefix(77)) + "..." : command
            return "Run command: \(truncated)"
        } else if toolName.contains("write") {
            let filePath = dict?["file_path"] as? String ?? dict?["filePath"] as? String ?? "a file"
            let content = dict?["content"] as? String
            let lineCount = content?.components(separatedBy: "\n").count ?? 0
            let lineInfo = lineCount > 0 ? " (\(lineCount) lines)" : ""
            return "Write\(lineInfo) to \(shortenPath(filePath))"
        } else if toolName.contains("edit") {
            let filePath = dict?["file_path"] as? String ?? dict?["filePath"] as? String ?? "a file"
            return "Edit \(shortenPath(filePath))"
        } else if toolName.contains("read") {
            let filePath = dict?["file_path"] as? String ?? dict?["filePath"] as? String ?? "a file"
            return "Read \(shortenPath(filePath))"
        } else if toolName.contains("glob") {
            let pattern = dict?["pattern"] as? String ?? "files"
            return "Search for files matching \(pattern)"
        } else if toolName.contains("grep") {
            let pattern = dict?["pattern"] as? String ?? "a pattern"
            return "Search file contents for \(pattern)"
        } else {
            return "Use tool: \(request.toolName)"
        }
    }

    /// Extracts file paths from the tool input payload.
    private func extractAffectedFiles() -> [String] {
        guard let dict = request.toolInput.value as? [String: Any] else { return [] }
        var files: [String] = []

        for key in ["file_path", "filePath", "path", "notebook_path"] {
            if let path = dict[key] as? String, !path.isEmpty {
                files.append(path)
            }
        }

        return files
    }

    /// Extracts the bash command from the tool input.
    private func extractCommand() -> String? {
        guard let dict = request.toolInput.value as? [String: Any] else { return nil }
        return dict["command"] as? String
    }

    /// Shortens a file path for display, keeping the last two path components.
    private func shortenPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 2 {
            return "…/" + components.suffix(2).joined(separator: "/")
        }
        return path
    }

    // MARK: - Risk Level Styling

    private var riskBadgeColor: Color {
        switch riskLevel {
        case .low:
            return theme.success
        case .medium:
            return theme.warning
        case .high:
            return theme.error
        case .critical:
            return theme.error
        }
    }

    private var riskTextColor: Color {
        switch riskLevel {
        case .low:
            return theme.success
        case .medium:
            return theme.warning
        case .high, .critical:
            return theme.error
        }
    }

    private var riskExplanation: String {
        switch riskLevel {
        case .low:
            return "Read-only or low-impact operation"
        case .medium:
            return "Modifies files within expected scope"
        case .high:
            return "Potentially destructive or broad-scope change"
        case .critical:
            return "System-level or irreversible operation"
        }
    }

    // MARK: - Policy Action Styling

    private func policyActionIcon(_ action: PolicyAction) -> String {
        switch action {
        case .autoApprove:
            return "checkmark.seal.fill"
        case .autoDeny:
            return "xmark.seal.fill"
        case .alwaysAsk:
            return "questionmark.circle.fill"
        case .requireConfirmation:
            return "exclamationmark.triangle.fill"
        }
    }

    private func policyActionColor(_ action: PolicyAction) -> Color {
        switch action {
        case .autoApprove:
            return theme.success
        case .autoDeny:
            return theme.error
        case .alwaysAsk:
            return theme.accent
        case .requireConfirmation:
            return theme.warning
        }
    }

    private func policyActionLabel(_ action: PolicyAction) -> String {
        switch action {
        case .autoApprove:
            return "Auto-Approved"
        case .autoDeny:
            return "Auto-Denied"
        case .alwaysAsk:
            return "Requires Approval"
        case .requireConfirmation:
            return "Confirmation Required"
        }
    }
}
