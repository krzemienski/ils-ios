import SwiftUI
import ILSShared

// MARK: - Config Section

/// Configuration editing section for the Settings screen.
///
/// Renders four sub-sections — General, API Key, Permissions, and Advanced — that
/// allow users to inspect and modify their Claude Code configuration. Settings are
/// loaded from the host CLI via ``SettingsViewModel`` and saved back asynchronously
/// using ``SettingsViewModel/saveConfig(model:colorScheme:)`` and
/// ``SettingsViewModel/saveConfigToggle(key:value:)``. Each save is immediately
/// followed by a ``SettingsViewModel/loadConfig()`` reload to keep the UI in sync.
///
/// Inherited settings (pulled from the host CLI config) are distinguished from
/// user-customised values with an ``InheritanceBadge`` indicator.
///
/// ## Topics
/// ### Properties
/// - ``viewModel`` - The shared settings view model providing config and stats
/// - ``colorSchemePreference`` - Binding to the persisted color-scheme selection
/// - ``availableModels`` - List of Claude model identifiers shown in the model picker
/// - ``formatModelName`` - Closure that converts a raw model ID to a display name
///
/// ### View Sections
/// - ``generalSettingsSection`` - Model, color scheme, updates channel, and feature toggles
/// - ``apiKeySection`` - API key status and masked key display (read-only)
/// - ``permissionsSection`` - Default permission mode plus allow/deny rule lists
/// - ``advancedSection`` - Hooks, plugins, raw JSON editors, and experimental flags
struct SettingsConfigSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// The shared settings view model providing config, stats, and save/load operations.
    var viewModel: SettingsViewModel
    /// Binding to the user's persisted color-scheme preference ("system", "light", or "dark").
    @Binding var colorSchemePreference: String
    /// Whether the experimental Agent Teams feature is enabled, persisted via AppStorage.
    @AppStorage("enableAgentTeams") private var enableAgentTeams = false

    /// The list of available Claude model identifiers to present in the model picker.
    let availableModels: [String]
    /// The list of valid color scheme options (e.g. "system", "light", "dark").
    let availableColorSchemes: [String]
    /// Closure that converts a raw model identifier string into a human-readable display name.
    let formatModelName: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            generalSettingsSection
            systemPromptSection
            apiKeySection
            permissionsSection
            advancedSection
        }
    }

    // MARK: - System Prompt

    @ViewBuilder
    var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("System Prompt")

            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configured via CLAUDE.md")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Text("System prompts are set using CLAUDE.md files on your host, not in settings.json. Per-session prompts can be set when creating a new session.")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                settingAnnotation(
                    isInherited: true,
                    tooltip: "Claude Code uses CLAUDE.md files at user, project, and local scopes for system prompts. Edit these files on your host to customize Claude's behavior. Per-session system prompts can also be set via the New Session screen."
                )
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
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
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }
                } else if let config = viewModel.config?.content {
                    Picker("Default Model", selection: Binding(
                        get: { config.model ?? SettingsViewModel.defaultModelID },
                        set: { newModel in
                            viewModel.updateModel(newModel)
                        }
                    )) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(formatModelName(model)).tag(model)
                        }
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Default Claude model")
                    settingAnnotation(
                        isInherited: config.model == nil,
                        tooltip: "The Claude model used for conversations. When inherited, uses the model configured in your host CLI settings."
                    )

                    Picker("Color Scheme", selection: $colorSchemePreference) {
                        ForEach(availableColorSchemes, id: \.self) { scheme in
                            Text(scheme.capitalized).tag(scheme)
                        }
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Color scheme preference")
                    settingAnnotation(
                        isInherited: config.theme?.colorScheme == nil,
                        tooltip: "Controls the app's appearance. System follows your device setting."
                    )

                    settingsRow("Updates Channel", value: (config.autoUpdatesChannel ?? "stable").capitalized)
                    settingAnnotation(
                        isInherited: config.autoUpdatesChannel == nil,
                        tooltip: "Controls which release channel Claude CLI auto-updates from. Stable is recommended for production use."
                    )

                    Toggle(isOn: Binding(
                        get: { config.alwaysThinkingEnabled ?? false },
                        set: { newValue in
                            HapticManager.selection()
                            viewModel.updateToggle(key: "alwaysThinkingEnabled", value: newValue)
                        }
                    )) {
                        Text("Extended Thinking")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Enable extended thinking mode")
                    settingAnnotation(
                        isInherited: config.alwaysThinkingEnabled == nil,
                        tooltip: "Enables extended thinking mode for deeper reasoning. Uses more tokens per response."
                    )

                    Toggle(isOn: Binding(
                        get: { config.includeCoAuthoredBy ?? false },
                        set: { newValue in
                            HapticManager.selection()
                            viewModel.updateToggle(key: "includeCoAuthoredBy", value: newValue)
                        }
                    )) {
                        Text("Include Co-Author")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Include co-authored-by attribution")
                    settingAnnotation(
                        isInherited: config.includeCoAuthoredBy == nil,
                        tooltip: "Adds co-authored-by attribution to git commits made during Claude sessions."
                    )
                } else {
                    Text("No configuration loaded")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            if let config = viewModel.config {
                Text("Scope: \(config.scope) • \(config.path)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                if let maskedKey = apiKeyStatus.maskedKey {
                                    Text("Key: \(maskedKey)")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textSecondary)
                                }
                                if let source = apiKeyStatus.source {
                                    Text("Source: \(source)")
                                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundStyle(theme.warning)
                            Text("API Key status unknown")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    settingAnnotation(
                        isInherited: true,
                        tooltip: "Your Anthropic API key. Managed on the host via environment variables or `claude config set apiKey`. Cannot be edited from the iOS app for security."
                    )
                } else if !viewModel.isLoadingConfig {
                    Text("Loading API key status...")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("API keys cannot be edited through the iOS app. Use: claude config set apiKey <your-key>")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
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
                    settingAnnotation(
                        isInherited: permissions.defaultMode == nil,
                        tooltip: "Controls which tools Claude can use without asking. Inherited from host CLI configuration."
                    )

                    if let allowed = permissions.allow, !allowed.isEmpty {
                        DisclosureGroup {
                            ForEach(allowed, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            settingsRow("Allowed", value: "\(allowed.count) rules")
                        }
                        .tint(theme.textTertiary)
                    } else {
                        settingsRow("Allowed", value: "None")
                    }
                    settingAnnotation(
                        isInherited: permissions.allow == nil,
                        tooltip: "Tools and patterns explicitly allowed to run without confirmation. Configured in host CLI settings."
                    )

                    if let denied = permissions.deny, !denied.isEmpty {
                        DisclosureGroup {
                            ForEach(denied, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            settingsRow("Denied", value: "\(denied.count) rules")
                        }
                        .tint(theme.textTertiary)
                    } else {
                        settingsRow("Denied", value: "None")
                    }
                    settingAnnotation(
                        isInherited: permissions.deny == nil,
                        tooltip: "Tools and patterns explicitly blocked from running. Configured in host CLI settings."
                    )
                } else if !viewModel.isLoadingConfig {
                    Text("No permissions configured")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
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
                        NavigationLink {
                            HooksManagementView()
                        } label: {
                            HStack {
                                settingsRow("Hooks Configured", value: "\(hookCount)")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        hookBreakdownView
                    } else {
                        NavigationLink {
                            HooksManagementView()
                        } label: {
                            HStack {
                                settingsRow("Hooks Configured", value: "0")
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    settingAnnotation(
                        isInherited: config.hooks == nil,
                        tooltip: "Lifecycle hooks that run custom commands at specific events (session start, before/after tool use). Configured in ~/.claude/settings.json."
                    )

                    if let plugins = config.enabledPlugins {
                        let enabledCount = plugins.count(where: { $0.value })
                        settingsRow("Enabled Plugins", value: "\(enabledCount)")
                    } else {
                        settingsRow("Enabled Plugins", value: "0")
                    }
                    settingAnnotation(
                        isInherited: config.enabledPlugins == nil,
                        tooltip: "Plugins installed and enabled on the host. Manage plugins from the Browse tab."
                    )

                    if let statusLine = config.statusLine {
                        settingsRow("Status Line", value: statusLine.type ?? "disabled")
                    } else {
                        settingsRow("Status Line", value: "Not configured")
                    }
                    settingAnnotation(
                        isInherited: config.statusLine == nil,
                        tooltip: "Custom status line displayed in the Claude Code terminal. Configured on the host."
                    )

                    if let env = config.env, !env.isEmpty {
                        settingsRow("Environment Vars", value: "\(env.count)")
                    } else {
                        settingsRow("Environment Vars", value: "0")
                    }
                    settingAnnotation(
                        isInherited: config.env == nil,
                        tooltip: "Environment variables passed to Claude Code sessions. Configured on the host."
                    )
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider().background(theme.bgTertiary)

                NavigationLink {
                    ConfigEditorView(scope: "user")
                } label: {
                    HStack {
                        Text("Edit User Settings")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                NavigationLink {
                    ConfigEditorView(scope: "project")
                } label: {
                    HStack {
                        Text("Edit Project Settings")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())

            Text("Edit raw JSON configuration files")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            // Experimental features
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                sectionLabel("Experimental")

                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Toggle(isOn: Binding(
                        get: { enableAgentTeams },
                        set: { newValue in
                            HapticManager.selection()
                            enableAgentTeams = newValue
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Agent Teams")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text("Coordinate multiple AI agents working together")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .tint(theme.accent)
                    settingAnnotation(
                        isInherited: false,
                        tooltip: "Experimental feature: coordinate multiple AI agents working together. This setting is stored locally on your device."
                    )
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .padding(.top, theme.spacingSM)
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
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }

    @ViewBuilder
    private func settingsRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    @ViewBuilder
    private func settingsRow(_ label: String, icon: String, iconColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
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

    /// Reads pre-computed hook event breakdown from ViewModel
    /// instead of building filtered arrays inline in the view body.
    @ViewBuilder
    var hookBreakdownView: some View {
        let events = viewModel.hookEventBreakdown
        if !events.isEmpty {
            HStack(spacing: theme.spacingSM) {
                ForEach(events, id: \.0) { event in
                    Text("\(event.1) \(event.0)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - Setting Annotation

    @ViewBuilder
    private func settingAnnotation(isInherited: Bool, tooltip: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            InheritanceBadge(isInherited: isInherited)
            Spacer()
            SettingsInfoButton(text: tooltip)
        }
    }
}

// MARK: - Inheritance Badge

/// Badge indicating whether a setting value is inherited from the host CLI or
/// has been explicitly overridden by the user.
///
/// Displays a "Host Default" label with a link icon when the value is inherited,
/// or a "Custom" label with a pencil icon when the value has been set locally.
struct InheritanceBadge: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    let isInherited: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isInherited ? "link" : "pencil")
            Text(isInherited ? "Host Default" : "Custom")
        }
        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        .foregroundStyle(isInherited ? theme.textTertiary : theme.accent)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (isInherited ? theme.textTertiary : theme.accent).opacity(0.12)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Settings Info Button

/// Tappable info icon that reveals a tooltip popover explaining a setting.
///
/// Tapping the `info.circle` button toggles a popover containing a plain-text
/// description of the adjacent setting's purpose and valid values.
struct SettingsInfoButton: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    let text: String
    @State private var isShowing = false

    var body: some View {
        Button { isShowing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing) {
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding()
                .frame(maxWidth: 280)
                .presentationCompactAdaptation(.popover)
        }
    }
}
