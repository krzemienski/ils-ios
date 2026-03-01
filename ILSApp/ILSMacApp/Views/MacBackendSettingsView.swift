import SwiftUI
import AppKit
import ILSShared

/// Settings panel for the macOS ILS backend service.
///
/// Displays backend status, start/stop controls, install wizard, live logs,
/// port conflict warnings, health troubleshooting, and uninstall.
struct MacBackendSettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) var theme: ThemeSnapshot

    @State private var viewModel = BackendSetupViewModel()
    @State private var showUninstallConfirm = false
    @State private var showTroubleshooting = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {

            sectionHeader("Backend Service")

            // ── 1. STATUS ────────────────────────────────────────────────
            statusSection

            // ── 2. CONTROLS ──────────────────────────────────────────────
            if viewModel.backendStatus != .notInstalled {
                controlsSection
            }

            // ── 3. INSTALL WIZARD (only when not installed) ───────────────
            if viewModel.showInstallSection {
                installSection
            }

            // ── 4. LOGS ──────────────────────────────────────────────────
            if viewModel.backendStatus != .notInstalled {
                logsSection
            }

            // ── 5. PORT CONFLICT WARNING ──────────────────────────────────
            if viewModel.portConflictProcess != nil {
                portConflictSection
            }

            // ── 6. HEALTH TROUBLESHOOTING ────────────────────────────────
            if case .error = viewModel.backendStatus {
                troubleshootingSection
            }

            // ── 7. UNINSTALL ─────────────────────────────────────────────
            if viewModel.backendStatus != .notInstalled {
                uninstallSection
            }

            // Error banner
            if let msg = viewModel.errorMessage {
                errorBanner(msg)
            }
        }
        .task {
            await viewModel.startMonitoringIfInstalled()
            await viewModel.checkForUpdates()
        }
    }

    // MARK: - 1. Status Section

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {

            settingRow(label: "Status") {
                HStack(spacing: theme.spacingSM) {
                    Circle()
                        .fill(viewModel.statusColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.statusText)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(viewModel.statusColor)
                }
            }

            if let version = viewModel.currentVersion {
                Divider()
                settingRow(label: "Version") {
                    HStack(spacing: theme.spacingSM) {
                        Text(version)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        if viewModel.updateAvailable {
                            Text("Update Available")
                                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                                .foregroundStyle(.white)
                                .padding(.horizontal, theme.spacingSM)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if viewModel.backendStatus == .running {
                Divider()
                settingRow(label: "CPU") {
                    Text(viewModel.formattedCPU)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }

                Divider()
                settingRow(label: "Memory") {
                    Text(viewModel.formattedMemory)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                }
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - 2. Controls Section

    @ViewBuilder
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            Text("Controls")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: theme.spacingSM) {
                Button("Start") {
                    viewModel.startBackend()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStart)

                Button("Stop") {
                    viewModel.stopBackend()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canStop)

                Button("Restart") {
                    viewModel.restartBackend()
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canRestart)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - 3. Install Section

    @ViewBuilder
    private var installSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            Text("One-Click Install")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Text("Select your local ILS repo to build and install the backend as a macOS service. The backend will start automatically and restart on login.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            settingRow(label: "Repo Path") {
                HStack(spacing: theme.spacingSM) {
                    TextField("/path/to/ils-ios", text: $viewModel.repoPathInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)

                    Button("Browse…") {
                        browseForRepoPath()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if viewModel.installPhase == .buildingBinary || viewModel.installPhase == .installingAgent {
                HStack(spacing: theme.spacingSM) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(viewModel.installPhase == .buildingBinary ? "Building binary (this may take a few minutes)…" : "Installing service…")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if viewModel.installPhase == .complete {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installation complete!")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(.green)
                }
            }

            Button("Install Backend") {
                Task { await viewModel.installBackend() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                viewModel.repoPathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.installPhase == .buildingBinary
                || viewModel.installPhase == .installingAgent
            )

            // Build log output (shown during install)
            if !viewModel.logLines.isEmpty && viewModel.installPhase != .idle {
                ScrollView {
                    Text(viewModel.logLines.suffix(50).joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(theme.spacingSM)
                }
                .frame(height: 120)
                .background(theme.bgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - 4. Logs Section

    @ViewBuilder
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            HStack {
                Text("Logs")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                Button("Refresh") {
                    Task { await viewModel.refreshLogs() }
                }
                .buttonStyle(.bordered)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))

                Button("Copy") {
                    viewModel.copyLogsToClipboard()
                }
                .buttonStyle(.bordered)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }

            if viewModel.logLines.isEmpty {
                Text("No log output yet.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(theme.spacingMD)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(viewModel.logLines.joined(separator: "\n"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(theme.spacingSM)
                            .id("log-bottom")
                    }
                    .frame(height: 200)
                    .background(theme.bgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .onChange(of: viewModel.logLines.count) {
                        withAnimation { proxy.scrollTo("log-bottom", anchor: .bottom) }
                    }
                }
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - 5. Port Conflict Section

    @ViewBuilder
    private var portConflictSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Port Conflict Detected")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }

            if let conflictProcess = viewModel.portConflictProcess {
                Text("Process \"\(conflictProcess)\" is already using port 9999.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Text("To free the port, find and stop that process:")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Text("lsof -ti :9999 | xargs kill -9")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .padding(theme.spacingSM)
                    .background(theme.bgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .padding(theme.spacingMD)
        .background(Color.yellow.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - 6. Troubleshooting Section

    @ViewBuilder
    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            Button {
                withAnimation { showTroubleshooting.toggle() }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: showTroubleshooting ? "chevron.down" : "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("Health Troubleshooting")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    Spacer()
                }
                .foregroundStyle(theme.textPrimary)
            }
            .buttonStyle(.plain)

            if showTroubleshooting {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    troubleshootingStep(
                        number: 1,
                        title: "Check logs",
                        detail: "Scroll up to the Logs section and look for error messages."
                    )
                    troubleshootingStep(
                        number: 2,
                        title: "Verify binary",
                        detail: "Ensure ~/.ils/bin/ILSBackend exists and is executable."
                    )
                    troubleshootingStep(
                        number: 3,
                        title: "Check port",
                        detail: "Confirm nothing else is using port 9999 (see port conflict above if detected)."
                    )
                    troubleshootingStep(
                        number: 4,
                        title: "Restart service",
                        detail: "Use the Controls section above to restart the backend."
                    )
                    troubleshootingStep(
                        number: 5,
                        title: "Reinstall",
                        detail: "Uninstall and reinstall the backend to get a fresh copy."
                    )
                }
                .padding(.leading, theme.spacingMD)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    @ViewBuilder
    private func troubleshootingStep(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Text("\(number).")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 16, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(detail)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: - 7. Uninstall Section

    @ViewBuilder
    private var uninstallSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingMD) {
            Text("Danger Zone")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            settingRow(label: "Uninstall") {
                Button("Uninstall Backend") {
                    showUninstallConfirm = true
                }
                .foregroundStyle(.red)
                .buttonStyle(.bordered)
            }

            Text("Removes the LaunchAgent and the installed binary. Your repo and sessions are unaffected.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .confirmationDialog(
            "Uninstall ILS Backend?",
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                viewModel.uninstallBackend()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the backend service, remove the LaunchAgent, and delete the installed binary. Your data and repo are not affected.")
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(3)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(theme.spacingMD)
        .background(Color.red.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    // MARK: - Shared Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: theme.spacingMD) {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 140, alignment: .trailing)
            content()
            Spacer()
        }
    }

    // MARK: - NSOpenPanel

    private func browseForRepoPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the ILS iOS repo directory"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.repoPathInput = url.path
        }
    }
}
