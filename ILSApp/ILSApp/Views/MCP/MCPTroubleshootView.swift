import SwiftUI
import ILSShared

// MARK: - Troubleshoot Step

private struct TroubleshootStep {
    let number: Int
    let title: String
    let description: String
}

// MARK: - Common Issue

private struct CommonIssue: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let fix: String
    let icon: String
}

// MARK: - MCP Troubleshoot View

struct MCPTroubleshootView: View {
    let server: MCPServer
    var viewModel: MCPViewModel

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isRefreshing = false
    @State private var isToggling = false
    @State private var expandedIssueID: UUID?
    @State private var showCopiedToast = false

    /// Live server looked up from viewModel so SwiftUI re-renders on state changes.
    private var liveServer: MCPServer {
        viewModel.servers.first(where: { $0.id == server.id }) ?? server
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                statusBanner

                sectionCard(title: "Diagnostic Steps") {
                    stepsContent
                }

                sectionCard(title: "Quick Actions") {
                    quickActionsContent
                }

                sectionCard(title: "Common Issues") {
                    commonIssuesContent
                }

                sectionCard(title: "Full Command") {
                    Text(fullCommand)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(theme.spacingMD)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Troubleshoot")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textOnAccent)
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(Capsule())
                    .padding(.bottom, theme.spacingLG)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showCopiedToast)
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: theme.spacingMD) {
            Image(systemName: statusIcon)
                .font(.system(size: theme.fontTitle1))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(statusSubtitle)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Steps Content

    @ViewBuilder
    private var stepsContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            ForEach(Array(diagnosticSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: theme.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text("\(step.number)")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text(step.description)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if index < diagnosticSteps.count - 1 {
                    Divider().background(theme.divider)
                }
            }
        }
    }

    // MARK: - Quick Actions Content

    @ViewBuilder
    private var quickActionsContent: some View {
        VStack(spacing: 0) {
            Button {
                Task { await refreshHealth() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(theme.accent)
                        .frame(width: 24)
                    Text("Refresh Health Check")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                            .tint(theme.accent)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing || isToggling)
            .accessibilityLabel("Refresh health check for \(server.name)")

            Divider().background(theme.divider).padding(.vertical, theme.spacingXS)

            Button {
                HapticManager.selection()
                Task { await toggleServer() }
            } label: {
                HStack {
                    Image(systemName: liveServer.isEnabled ? "pause.circle" : "play.circle")
                        .foregroundStyle(liveServer.isEnabled ? theme.warning : theme.success)
                        .frame(width: 24)
                    Text(liveServer.isEnabled ? "Disable Server" : "Enable Server")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if isToggling {
                        ProgressView()
                            .tint(theme.accent)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing || isToggling)
            .accessibilityLabel(liveServer.isEnabled ? "Disable \(server.name)" : "Enable \(server.name)")

            Divider().background(theme.divider).padding(.vertical, theme.spacingXS)

            Button {
                copyCommandToClipboard()
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(theme.accent)
                        .frame(width: 24)
                    Text("Copy Command")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy command for \(server.name)")

            Divider().background(theme.divider).padding(.vertical, theme.spacingXS)

            NavigationLink {
                MCPLogsView(server: server, viewModel: viewModel)
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(theme.accent)
                        .frame(width: 24)
                    Text("View Logs")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View logs for \(server.name)")
        }
    }

    // MARK: - Common Issues Content

    @ViewBuilder
    private var commonIssuesContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(commonIssues.enumerated()), id: \.element.id) { index, issue in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            expandedIssueID = expandedIssueID == issue.id ? nil : issue.id
                        }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: issue.icon)
                                .foregroundStyle(theme.warning)
                                .frame(width: 24)
                            Text(issue.title)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: expandedIssueID == issue.id ? "chevron.up" : "chevron.down")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(issue.title)
                    .accessibilityHint(expandedIssueID == issue.id ? "Tap to collapse" : "Tap to expand")

                    if expandedIssueID == issue.id {
                        VStack(alignment: .leading, spacing: theme.spacingSM) {
                            Text(issue.description)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Label("Fix", systemImage: "checkmark.seal")
                                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(theme.success)

                            Text(issue.fix)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, theme.spacingSM)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if index < commonIssues.count - 1 {
                    Divider().background(theme.divider).padding(.vertical, theme.spacingXS)
                }
            }
        }
    }

    // MARK: - Section Card Helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text(title.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            content()
                .padding(theme.spacingMD)
                .modifier(GlassCard())
        }
    }

    // MARK: - Computed Properties

    private var fullCommand: String {
        guard !server.args.isEmpty else { return server.command }
        return "\(server.command) \(server.args.joined(separator: " "))"
    }

    private var statusColor: Color {
        guard liveServer.isEnabled else { return theme.textTertiary }
        switch liveServer.status {
        case .healthy:   return theme.success
        case .unhealthy: return theme.error
        case .unknown:   return theme.warning
        }
    }

    private var statusIcon: String {
        guard liveServer.isEnabled else { return "pause.circle.fill" }
        switch liveServer.status {
        case .healthy:   return "checkmark.circle.fill"
        case .unhealthy: return "exclamationmark.triangle.fill"
        case .unknown:   return "questionmark.circle.fill"
        }
    }

    private var statusTitle: String {
        guard liveServer.isEnabled else { return "Server Disabled" }
        switch liveServer.status {
        case .healthy:   return "Server is Healthy"
        case .unhealthy: return "Server is Unhealthy"
        case .unknown:   return "Status Unknown"
        }
    }

    private var statusSubtitle: String {
        guard liveServer.isEnabled else {
            return "\(server.name) is currently disabled. Enable it to start troubleshooting."
        }
        switch liveServer.status {
        case .healthy:
            return "\(server.name) is responding normally."
        case .unhealthy:
            return "\(server.name) failed its last health check. Follow the steps below."
        case .unknown:
            return "Health status hasn't been determined yet. Run a health check."
        }
    }

    private var diagnosticSteps: [TroubleshootStep] {
        if !liveServer.isEnabled {
            return [
                TroubleshootStep(number: 1, title: "Enable the Server",
                    description: "The server is currently disabled. Use Quick Actions below to enable it."),
                TroubleshootStep(number: 2, title: "Verify the Command",
                    description: "Confirm \"\(server.command)\" is installed and accessible on your system PATH."),
                TroubleshootStep(number: 3, title: "Refresh Health Check",
                    description: "After enabling, run a health check to confirm the server is responding.")
            ]
        }

        switch liveServer.status {
        case .healthy:
            return [
                TroubleshootStep(number: 1, title: "Server is Healthy",
                    description: "No action needed. The server is responding normally."),
                TroubleshootStep(number: 2, title: "Monitor Logs",
                    description: "Check logs periodically to catch transient errors early.")
            ]
        case .unhealthy:
            return [
                TroubleshootStep(number: 1, title: "Check Logs",
                    description: "Review recent error logs to identify the root cause of the failure."),
                TroubleshootStep(number: 2, title: "Verify Command Exists",
                    description: "Confirm \"\(server.command)\" is installed and executable on this machine."),
                TroubleshootStep(number: 3, title: "Check Environment Variables",
                    description: server.env?.isEmpty == false
                        ? "Verify all required environment variables have valid, non-empty values."
                        : "No environment variables configured — check if the server requires any."),
                TroubleshootStep(number: 4, title: "Disable and Re-enable",
                    description: "Toggle the server off and on to force a fresh connection attempt."),
                TroubleshootStep(number: 5, title: "Refresh Health Check",
                    description: "After making changes, run a health check to confirm the server recovers.")
            ]
        case .unknown:
            return [
                TroubleshootStep(number: 1, title: "Run a Health Check",
                    description: "Tap \"Refresh Health Check\" in Quick Actions to get the current status."),
                TroubleshootStep(number: 2, title: "Verify the Command",
                    description: "Confirm \"\(server.command)\" can be found and executed on this machine."),
                TroubleshootStep(number: 3, title: "Check Logs",
                    description: "Review the logs for startup errors or missing dependency warnings.")
            ]
        }
    }

    private var commonIssues: [CommonIssue] {
        [
            CommonIssue(
                title: "Command Not Found",
                description: "The executable specified as the server command could not be located. This usually means the tool is not installed or not on the system PATH.",
                fix: "Install the required tool (e.g. npm install -g @modelcontextprotocol/server-filesystem) or provide the full absolute path to the executable.",
                icon: "terminal.fill"
            ),
            CommonIssue(
                title: "Missing API Keys or Tokens",
                description: "The server requires authentication credentials but the required environment variables are missing or contain empty values.",
                fix: "Add the required environment variable (e.g. API_KEY) to this server's configuration via the Edit screen.",
                icon: "key.fill"
            ),
            CommonIssue(
                title: "Permission Denied",
                description: "The server process lacks permission to access required files, directories, or network resources.",
                fix: "Check that the command binary is executable (chmod +x) and that configured paths are accessible by the current user.",
                icon: "lock.fill"
            ),
            CommonIssue(
                title: "Port Already in Use",
                description: "Another process is occupying the port the MCP server is trying to bind to, preventing it from starting.",
                fix: "Stop conflicting processes on the same port, or configure the server to use a different port via its arguments.",
                icon: "network"
            ),
            CommonIssue(
                title: "Invalid or Missing Arguments",
                description: "The server was started with incorrect, incomplete, or improperly formatted arguments.",
                fix: "Review the server's documentation for the correct argument format and update them via the Edit screen.",
                icon: "list.bullet.rectangle"
            ),
            CommonIssue(
                title: "Runtime Not Installed",
                description: "The server requires Node.js, Python, or another runtime that is not installed or is an incompatible version.",
                fix: "Install the required runtime (e.g. brew install node) and ensure it is available on your system PATH.",
                icon: "puzzlepiece.extension.fill"
            )
        ]
    }

    // MARK: - Actions

    private func refreshHealth() async {
        isRefreshing = true
        await viewModel.checkHealth()
        isRefreshing = false
    }

    private func toggleServer() async {
        isToggling = true
        await viewModel.toggleEnabled(server)
        isToggling = false
    }

    private func copyCommandToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = fullCommand
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullCommand, forType: .string)
        #endif
        showCopiedToast = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showCopiedToast = false
            }
        }
    }
}
