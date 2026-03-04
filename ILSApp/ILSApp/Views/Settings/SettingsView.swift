import SwiftUI
import ILSShared

/// Root settings screen that acts as the hub for all app configuration.
///
/// Composes four delegated sub-section views — connection, appearance, config, and about —
/// each responsible for a distinct settings domain. The view owns server URL state with
/// whitespace trimming before persistence, and synchronises the color scheme preference
/// between the remote config and the local `@State` on every load. Supports pull-to-refresh
/// via `.refreshable` to reload all settings from the backend.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model loading and persisting all settings data
/// - ``serverURL`` - Editable server URL string, trimmed before saving
/// - ``colorSchemePreference`` - Currently selected color scheme ("system", "light", or "dark")
/// - ``showSessionSuggestions`` - Whether to show AI-powered session suggestions
///
/// ### View Components
/// - ``connectionSection`` - Server URL entry and connection testing
/// - ``remoteAccessSection`` - Remote/tunnel access configuration
/// - ``sessionSuggestionsSection`` - Toggle for smart session suggestions
/// - ``configSection`` - Model selection and appearance preferences
/// - ``statisticsSection`` - Usage statistics display
///
/// ### Server URL Management
/// - ``saveServerSettings()`` - Trim and persist the current server URL to AppState
/// - ``testConnection()`` - Save settings then trigger a connectivity test
///
/// ### Color Scheme
/// - ``syncColorScheme()`` - Pull the saved color scheme from remote config into local state
struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// View model responsible for loading, caching, and saving all settings data.
    @State private var viewModel = SettingsViewModel()
    /// The server URL string currently shown in the connection section; trimmed before saving.
    @State private var serverURL: String = ""
    /// The user's preferred color scheme, kept in sync with the remote config on load.
    @State private var colorSchemePreference: String = "system"
    @State private var showDeleteConfirmation: Bool = false
    @State private var commandRegistry = CommandRegistry()
    @State private var shortcutStore = KeyboardShortcutStore()
    // isDeleting and deleteResult moved to SettingsViewModel
    /// Whether to show AI-powered smart session suggestions in new session and chat views.
    @AppStorage("showSessionSuggestions") private var showSessionSuggestions: Bool = true

    @AppStorage("showContextWindowBar") private var showContextWindowBar: Bool = true
    @AppStorage("autoForkBeforeCompaction") private var autoForkBeforeCompaction: Bool = false
    @AppStorage("autoSnapshotEnabled") private var autoSnapshotEnabled: Bool = false

    /// The shell used when executing commands in the embedded terminal.
    @AppStorage("terminalShell") private var terminalShell: String = "zsh"

    @AppStorage("autoCheckpointsEnabled") private var autoCheckpointsEnabled: Bool = true
    @AppStorage("checkpointInterval") private var checkpointInterval: Int = 5
    @AppStorage("checkpointMaxCount") private var checkpointMaxCount: Int = 20
    /// Whether analytics collection is enabled; persisted in UserDefaults.
    @AppStorage("analyticsEnabled") private var analyticsEnabled = true

    @State private var checkpointIntervalIndex: Int = 1  // Default index → 10 messages
    @State private var isRunningIntegrityCheck: Bool = false
    @State private var showIntegrityAlert: Bool = false
    @State private var integrityAlertMessage: String = ""

    private let availableColorSchemes = ["system", "light", "dark"]
    private let checkpointIntervalOptions = [5, 10, 20, 50]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                connectionSection

                remoteAccessSection

                SettingsAppearanceSection()

                keyboardShortcutsSection

                sessionSuggestionsSection

                DashboardSettingsSection()

                configSection

                statisticsSection

                contextWindowSection

                checkpointSection

                contextPreservationSection

                sessionBackupSection

                OfflineCacheSettingsView()

                dataPrivacySection
                analyticsSection

                terminalSection

                iCloudSyncSection

                quickReplySection

                SettingsAboutSection(
                    viewModel: viewModel,
                    serverURL: serverURL
                )
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Settings")
        .inlineNavigationBarTitle()
        .screenshotProtected()
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            serverURL = appState.serverURL
            await viewModel.loadAll()
            syncColorScheme()
            syncCheckpointInterval()
        }
        .onChange(of: colorSchemePreference) { _, newValue in
            saveColorScheme(newValue)
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            serverURL = appState.serverURL
            Task { await viewModel.loadAll() }
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected {
                Task { await viewModel.loadAll() }
            }
        }
        .onChange(of: checkpointIntervalIndex) { _, newIdx in
            UserDefaults.standard.set(checkpointIntervalOptions[newIdx], forKey: "checkpointInterval")
        }
    }

    // MARK: - Section Wrappers

    private var connectionSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings,
            onSyncNow: syncNow
        )
    }

    private var remoteAccessSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings
        ).remoteAccessSection
    }

    private var sessionSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Session Suggestions")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(spacing: 0) {
                HStack {
                    Text("Show Session Suggestions")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $showSessionSuggestions)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .accessibilityLabel("Show session suggestions")
                .onChange(of: showSessionSuggestions) {
                    HapticManager.selection()
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Surface relevant past sessions and skills based on your current context.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var configSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: ClaudeModel.allModelIDs,
            availableColorSchemes: availableColorSchemes,
            formatModelName: ClaudeModel.displayNameForID
        )
    }

    private var statisticsSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: ClaudeModel.allModelIDs,
            availableColorSchemes: availableColorSchemes,
            formatModelName: ClaudeModel.displayNameForID
        ).statisticsSection
    }

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("KEYBOARD SHORTCUTS")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            NavigationLink {
                KeyboardShortcutsView(commandRegistry: commandRegistry, shortcutStore: shortcutStore)
                    .environment(appState)
                    .environment(\.theme, theme)
            } label: {
                HStack {
                    Image(systemName: "keyboard")
                        .foregroundStyle(theme.accent)
                    Text("Keyboard Shortcuts")
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    private var contextWindowSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("CONTEXT WINDOW")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                Toggle(isOn: $showContextWindowBar) {
                    HStack(spacing: theme.spacingMD) {
                        Image(systemName: "cpu")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.accent)
                            .frame(width: 28, height: 28)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Show context usage bar")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .padding(theme.spacingMD)
                .tint(theme.accent)
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text("Displays a bar in chat showing how much of Claude's context window is being used.")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
    }

    private var checkpointSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("SESSION CHECKPOINTS")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                Toggle(isOn: $autoCheckpointsEnabled) {
                    HStack(spacing: theme.spacingMD) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.accent)
                            .frame(width: 28, height: 28)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("Enable Auto-Checkpoints")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .padding(theme.spacingMD)
                .tint(theme.accent)
                .onChange(of: autoCheckpointsEnabled) {
                    HapticManager.selection()
                }

                Divider().background(theme.borderSubtle)

                Stepper(value: $checkpointInterval, in: 1...20) {
                    HStack(spacing: 4) {
                        Text("Auto-save every")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(
                                autoCheckpointsEnabled ? theme.textPrimary : theme.textTertiary
                            )
                        Text("\(checkpointInterval) msg\(checkpointInterval == 1 ? "" : "s")")
                            .font(.system(size: theme.fontBody, weight: .semibold))
                            .foregroundStyle(
                                autoCheckpointsEnabled ? theme.accent : theme.textTertiary
                            )
                    }
                }
                .padding(theme.spacingMD)
                .disabled(!autoCheckpointsEnabled)

                Divider().background(theme.borderSubtle)

                Stepper(value: $checkpointMaxCount, in: 5...50) {
                    HStack(spacing: 4) {
                        Text("Keep last")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Text("\(checkpointMaxCount)")
                            .font(.system(size: theme.fontBody, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text("checkpoint\(checkpointMaxCount == 1 ? "" : "s")")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text("Checkpoints save your session state automatically. Restore to any checkpoint to undo a bad direction.")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
    }

    private var contextPreservationSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("CONTEXT PRESERVATION")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                HStack {
                    Text("Auto-Fork at 95%")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $autoForkBeforeCompaction)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .accessibilityLabel("Automatically fork session before context compaction at 95%")
                .onChange(of: autoForkBeforeCompaction) {
                    HapticManager.selection()
                }
                .padding(theme.spacingMD)

                Divider().background(theme.bgTertiary)

                HStack {
                    Text("Auto-Snapshot at 85%")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $autoSnapshotEnabled)
                        .labelsHidden()
                        .tint(theme.accent)
                }
                .accessibilityLabel("Automatically save context snapshot when usage reaches 85%")
                .onChange(of: autoSnapshotEnabled) {
                    HapticManager.selection()
                }
                .padding(theme.spacingMD)

                Divider().background(theme.bgTertiary)

                NavigationLink(destination: NotificationPreferencesView()) {
                    HStack {
                        Text("Alert Settings")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }
                .accessibilityLabel("Context alert threshold settings")
            }
            .modifier(GlassCard())

            Text("Auto-fork creates a new session branch before context is compacted. Auto-snapshot saves a summary of recent messages. Alert thresholds are configured in Alert Settings.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
    }

    private var sessionBackupSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("SESSION BACKUP")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(theme.accent)
                    Text("Checkpoint Interval")
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Stepper(
                        "\(checkpointIntervalOptions[checkpointIntervalIndex]) messages",
                        value: $checkpointIntervalIndex,
                        in: 0...(checkpointIntervalOptions.count - 1)
                    )
                    .fixedSize()
                }
                .padding(theme.spacingMD)

                Divider().background(theme.borderSubtle)

                Button {
                    Task { await runIntegrityCheck() }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundStyle(theme.accent)
                        Text("Check Backup Integrity")
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        if isRunningIntegrityCheck {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(theme.spacingMD)
                }
                .disabled(isRunningIntegrityCheck)
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text("Auto-checkpoints are created every \(checkpointIntervalOptions[checkpointIntervalIndex]) messages. Run an integrity check to verify session data is consistent.")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
        .alert("Integrity Check", isPresented: $showIntegrityAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(integrityAlertMessage)
        }
    }

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("DATA & PRIVACY")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(theme.error)
                        Text("Delete All My Data")
                            .foregroundStyle(theme.error)
                        Spacer()
                        if viewModel.isDeleting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(theme.spacingMD)
                }
                .disabled(viewModel.isDeleting)

                if let result = viewModel.deleteResult {
                    Divider().background(theme.borderSubtle)
                    Text(result)
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                        .padding(theme.spacingMD)
                }
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text("Permanently deletes all sessions, messages, projects, themes, host profiles, and cached data from the server.")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await viewModel.performDataDeletion() }
            }
        } message: {
            Text("This will permanently delete all your sessions, messages, projects, themes, and cached data. This action cannot be undone.")
        }
    }

    // performDataDeletion() moved to SettingsViewModel

    // MARK: - iCloud Sync Section

    private var terminalSection: some View {
        Section {
            Picker("Default Shell", selection: $terminalShell) {
                Text("zsh").tag("zsh")
                Text("bash").tag("bash")
                Text("fish").tag("fish")
            }
        } header: {
            Label("Terminal", systemImage: "terminal.fill")
        }
    }

    private var iCloudSyncSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("ICLOUD SYNC")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)
                .padding(.horizontal, theme.spacingXS)

            NavigationLink(destination: ICloudSyncSettingsView()) {
                HStack {
                    Label("iCloud Sync", systemImage: "icloud.and.arrow.up.and.down")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    syncStatusBadge
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .modifier(GlassCard())
        }
    }

    @ViewBuilder
    private var syncStatusBadge: some View {
        let manager = ICloudSyncManager.shared
        let color: Color = {
            switch manager.syncStatus {
            case .idle:     return manager.isSyncEnabled ? theme.success : theme.textTertiary
            case .syncing:  return theme.accent
            case .error:    return theme.error
            case .disabled: return theme.textTertiary
            }
        }()
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    // MARK: - Quick Reply Section

    private var quickReplySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("QUICK REPLY")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)
                .padding(.horizontal, theme.spacingXS)

            let customCount = QuickReplyTemplateManager.shared.customTemplates.count

            NavigationLink(destination: QuickReplyTemplatesSettingsView()) {
                HStack {
                    Label("Quick Reply Templates", systemImage: "text.bubble")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if customCount > 0 {
                        Text("\(customCount) custom")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - Analytics Section

    /// Analytics privacy controls section allowing the user to enable or disable
    /// local analytics data collection.
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("Analytics")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Toggle(isOn: $analyticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Analytics Collection")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("Analytics data is processed locally on your device and never leaves the app.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .tint(theme.accent)
                .accessibilityLabel("Enable Analytics Collection")
                .accessibilityHint("Toggle to control whether analytics data is collected and displayed")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Session Backup

    /// Loads the stored checkpoint interval from UserDefaults and sets the matching index.
    private func syncCheckpointInterval() {
        let stored = UserDefaults.standard.integer(forKey: "checkpointInterval")
        if stored > 0, let idx = checkpointIntervalOptions.firstIndex(of: stored) {
            checkpointIntervalIndex = idx
        }
    }

    /// Calls `SessionBackupService` to verify session data consistency and shows the result.
    private func runIntegrityCheck() async {
        isRunningIntegrityCheck = true
        defer { isRunningIntegrityCheck = false }

        let response = await SessionBackupService.shared.runIntegrityCheck(client: appState.apiClient)

        if let results = response?.data {
            let issueCount = results.filter { !$0.passed }.count
            if issueCount == 0 {
                integrityAlertMessage = "All \(results.count) session(s) passed the integrity check."
            } else {
                integrityAlertMessage = "\(issueCount) integrity issue(s) found across \(results.count) session(s). Consider restoring from a checkpoint."
            }
        } else {
            integrityAlertMessage = "Integrity check could not be completed. Please check your connection."
        }

        showIntegrityAlert = true
    }

    // MARK: - Server URL Management

    /// Trims whitespace from ``serverURL`` and persists it to ``AppState`` if non-empty.
    private func saveServerSettings() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.updateServerURL(trimmed)
    }

    /// Saves the current server URL then asynchronously tests the connection via the view model.
    private func testConnection() {
        viewModel.saveAndTestConnection(url: serverURL, appState: appState)
    }

    /// Triggers a full data refresh from the server when online.
    private func syncNow() {
        HapticManager.impact(.medium)
        Task { await viewModel.loadAll() }
    }

    // MARK: - Color Scheme

    /// Pulls the color scheme stored in the remote config into ``colorSchemePreference``,
    /// defaulting to `"system"` when no preference has been saved.
    private func syncColorScheme() {
        if let config = viewModel.config?.content {
            colorSchemePreference = config.theme?.colorScheme ?? "system"
        }
    }

    /// Persists the given color scheme to the remote config and refreshes the local config cache.
    /// - Parameter scheme: One of `"system"`, `"light"`, or `"dark"`.
    private func saveColorScheme(_ scheme: String) {
        guard let config = viewModel.config?.content else { return }
        Task {
            _ = await viewModel.saveConfig(
                model: config.model ?? SettingsViewModel.defaultModelID,
                colorScheme: scheme
            )
        }
    }

    // MARK: - Helpers
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
