import SwiftUI
import ILSShared

// MARK: - Config Section

struct SettingsConfigSection: View {
    @Environment(\.theme) private var theme: any AppTheme
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var colorSchemePreference: String

    let availableModels: [String]
    let availableColorSchemes: [String]
    let formatModelName: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            generalSettingsSection
            apiKeySection
            permissionsSection
            advancedSection
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
                Text("Scope: \(config.scope) • \(config.path)")
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
}
