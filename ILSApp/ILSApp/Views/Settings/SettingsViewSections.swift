import SwiftUI
import ILSShared

// MARK: - Settings View Sections

extension SettingsView {

    // MARK: - Connection Section

    @ViewBuilder
    var connectionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Backend Connection")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                    TextField("https://example.com or http://localhost:9090", text: $serverURL)
                        .font(.system(size: theme.fontBody))
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .foregroundStyle(theme.textPrimary)
                        .padding(theme.spacingSM)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .accessibilityLabel("Server URL")
                        .onSubmit { saveServerSettings() }
                }

                HStack {
                    Text("Status")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Button {
                    testConnection()
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .tint(theme.textOnAccent)
                                .controlSize(.small)
                        }
                        Text(viewModel.isTestingConnection ? "Testing..." : "Test Connection")
                            .font(.system(size: theme.fontBody, weight: .medium))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .disabled(viewModel.isTestingConnection)
                .opacity(viewModel.isTestingConnection ? 0.7 : 1.0)
                .accessibilityLabel("Test connection to backend server")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Configure the ILS backend server address")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Remote Access

    @ViewBuilder
    var remoteAccessSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Remote Access")

            NavigationLink {
                TunnelSettingsView()
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Image(systemName: "network")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.info)
                        .frame(width: 28, height: 28)
                        .background(theme.info.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remote Access")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Text("Cloudflare Tunnel")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Appearance

    @ViewBuilder
    var appearanceSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Appearance")

            NavigationLink {
                ThemePickerView()
            } label: {
                HStack(spacing: theme.spacingMD) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.accent)
                        .frame(width: 28, height: 28)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Theme")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Text(themeManager.currentTheme.name)
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - General Settings

    @ViewBuilder
    var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("General")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if viewModel.isLoadingConfig {
                    HStack {
                        ProgressView().tint(theme.accent)
                        Text("Loading configuration...")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textSecondary)
                    }
                } else if let config = viewModel.config?.content {
                    Picker("Default Model", selection: Binding(
                        get: { config.model ?? "claude-sonnet-4-20250514" },
                        set: { newModel in
                            Task {
                                _ = await viewModel.saveConfig(model: newModel, colorScheme: config.theme?.colorScheme ?? "system")
                                await viewModel.loadConfig()
                            }
                        }
                    )) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(formatModelName(model)).tag(model)
                        }
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Default Claude model")

                    Picker("Color Scheme", selection: $colorSchemePreference) {
                        ForEach(availableColorSchemes, id: \.self) { scheme in
                            Text(scheme.capitalized).tag(scheme)
                        }
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Color scheme preference")

                    if let channel = config.autoUpdatesChannel {
                        settingsRow("Updates Channel", value: channel.capitalized)
                    }

                    settingsRow("Extended Thinking", icon: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle", iconColor: config.alwaysThinkingEnabled == true ? theme.success : theme.textSecondary)

                    settingsRow("Include Co-Author", icon: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle", iconColor: config.includeCoAuthoredBy == true ? theme.success : theme.textSecondary)
                } else {
                    Text("No configuration loaded")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            if let config = viewModel.config {
                Text("Scope: \(config.scope) \u{2022} \(config.path)")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - API Key

    @ViewBuilder
    var apiKeySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("API Key")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let config = viewModel.config?.content {
                    if let apiKeyStatus = config.apiKeyStatus {
                        HStack {
                            Image(systemName: apiKeyStatus.isConfigured ? "checkmark.shield.fill" : "shield.slash")
                                .foregroundStyle(apiKeyStatus.isConfigured ? theme.success : theme.warning)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(apiKeyStatus.isConfigured ? "API Key Configured" : "No API Key")
                                    .font(.system(size: theme.fontBody))
                                    .foregroundStyle(theme.textPrimary)
                                if let maskedKey = apiKeyStatus.maskedKey {
                                    Text("Key: \(maskedKey)")
                                        .font(.system(size: theme.fontCaption))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                if let source = apiKeyStatus.source {
                                    Text("Source: \(source)")
                                        .font(.system(size: theme.fontCaption))
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(theme.warning)
                            Text("API Key status unknown")
                                .font(.system(size: theme.fontBody))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("Loading API key status...")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("API keys cannot be edited through the iOS app. Use: claude config set apiKey <your-key>")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Permissions

    @ViewBuilder
    var permissionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Permissions")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let config = viewModel.config?.content, let permissions = config.permissions {
                    settingsRow("Default Mode", value: permissions.defaultMode?.capitalized ?? "Prompt")

                    if let allowed = permissions.allow, !allowed.isEmpty {
                        DisclosureGroup {
                            ForEach(allowed, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            settingsRow("Allowed", value: "\(allowed.count) rules")
                        }
                        .tint(theme.textTertiary)
                    } else {
                        settingsRow("Allowed", value: "None")
                    }

                    if let denied = permissions.deny, !denied.isEmpty {
                        DisclosureGroup {
                            ForEach(denied, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            settingsRow("Denied", value: "\(denied.count) rules")
                        }
                        .tint(theme.textTertiary)
                    } else {
                        settingsRow("Denied", value: "None")
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No permissions configured")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Advanced

    @ViewBuilder
    var advancedSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Advanced")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if let config = viewModel.config?.content {
                    if let hooks = config.hooks {
                        let hookCount = countHooks(hooks)
                        settingsRow("Hooks Configured", value: "\(hookCount)")
                    } else {
                        settingsRow("Hooks Configured", value: "0")
                    }

                    if let plugins = config.enabledPlugins {
                        let enabledCount = plugins.filter { $0.value }.count
                        settingsRow("Enabled Plugins", value: "\(enabledCount)")
                    } else {
                        settingsRow("Enabled Plugins", value: "0")
                    }

                    if let statusLine = config.statusLine {
                        settingsRow("Status Line", value: statusLine.type ?? "disabled")
                    }

                    if let env = config.env, !env.isEmpty {
                        settingsRow("Environment Vars", value: "\(env.count)")
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider().background(theme.bgTertiary)

                NavigationLink {
                    ConfigEditorView(scope: "user", apiClient: appState.apiClient)
                } label: {
                    HStack {
                        Text("Edit User Settings")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                NavigationLink {
                    ConfigEditorView(scope: "project", apiClient: appState.apiClient)
                } label: {
                    HStack {
                        Text("Edit Project Settings")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Edit raw JSON configuration files")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Statistics

    @ViewBuilder
    var statisticsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Statistics")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                if viewModel.isLoading {
                    HStack { Spacer(); ProgressView().tint(theme.accent); Spacer() }
                } else if let stats = viewModel.stats {
                    settingsRow("Projects", value: "\(stats.projects.total)")
                    settingsRow("Sessions", value: "\(stats.sessions.total) (\(stats.sessions.active) active)")
                    settingsRow("Skills", value: "\(stats.skills.total)")
                    settingsRow("MCP Servers", value: "\(stats.mcpServers.total) (\(stats.mcpServers.healthy) healthy)")
                    settingsRow("Plugins", value: "\(stats.plugins.total) (\(stats.plugins.enabled) enabled)")
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Diagnostics

    @ViewBuilder
    var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Diagnostics")

            VStack(spacing: 0) {
                HStack {
                    Label("Analytics", systemImage: "chart.bar")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: .init(
                        get: { AppLogger.shared.analyticsOptedIn },
                        set: { AppLogger.shared.analyticsOptedIn = $0 }
                    ))
                    .labelsHidden()
                    .tint(theme.accent)
                    .accessibilityLabel("Enable analytics")
                }
                .padding(theme.spacingMD)

                Divider().background(theme.bgTertiary)

                NavigationLink(destination: LogViewerView()) {
                    HStack {
                        Label("View Logs", systemImage: "doc.text")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }

                Divider().background(theme.bgTertiary)

                NavigationLink(destination: NotificationPreferencesView()) {
                    HStack {
                        Label("Notifications", systemImage: "bell.badge")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(theme.spacingMD)
                }
            }
            .modifier(GlassCard())
        }
    }

    // MARK: - About

    @ViewBuilder
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("About")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                settingsRow("App Version", value: "1.0.0")
                settingsRow("Build", value: "1")

                if let claudeVersion = viewModel.claudeVersion {
                    settingsRow("Claude CLI", value: claudeVersion)
                } else {
                    HStack {
                        Text("Claude CLI")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("Checking...")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                settingsRow("Backend URL", value: serverURL)

                Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                    HStack {
                        Text("Claude Code Documentation")
                            .font(.system(size: theme.fontBody))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Reusable Components

    @ViewBuilder
    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
        }
    }

    @ViewBuilder
    func settingsRow(_ label: String, icon: String, iconColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Image(systemName: icon)
                .foregroundStyle(iconColor)
        }
    }

    // MARK: - Server Settings

    func loadServerSettings() {
        serverURL = appState.serverURL
    }

    func saveServerSettings() {
        guard !serverURL.isEmpty else { return }
        appState.updateServerURL(serverURL)
    }

    func testConnection() {
        Task {
            guard !serverURL.isEmpty, URL(string: serverURL) != nil else { return }
            appState.updateServerURL(serverURL)
            await viewModel.testConnection()
            if appState.isConnected { saveServerSettings() }
        }
    }

    // MARK: - Helpers

    func countHooks(_ hooks: HooksConfig) -> Int {
        var count = 0
        if let h = hooks.sessionStart { count += h.count }
        if let h = hooks.subagentStart { count += h.count }
        if let h = hooks.userPromptSubmit { count += h.count }
        if let h = hooks.preToolUse { count += h.count }
        if let h = hooks.postToolUse { count += h.count }
        return count
    }

    func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "Claude Sonnet" }
        if model.contains("opus") { return "Claude Opus" }
        if model.contains("haiku") { return "Claude Haiku" }
        return model
    }
}
