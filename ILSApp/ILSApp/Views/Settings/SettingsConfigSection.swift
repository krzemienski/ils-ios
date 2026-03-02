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
                        get: { viewModel.effectiveConfig?.config.model ?? config.model ?? SettingsViewModel.defaultModelID },
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
                        isInherited: viewModel.isInherited(key: "model"),
                        tooltip: "The Claude model used for new conversations and chat sessions. When set to 'inherited', the model configured in your host's Claude CLI settings (via `claude config set model`) is used automatically. Override this locally to use a different model on this device."
                    )

                    Picker("Color Scheme", selection: $colorSchemePreference) {
                        ForEach(availableColorSchemes, id: \.self) { scheme in
                            Text(scheme.capitalized).tag(scheme)
                        }
                    }
                    .tint(theme.accent)
                    .accessibilityLabel("Color scheme preference")
                    settingAnnotation(
                        isInherited: viewModel.isInherited(key: "theme"),
                        tooltip: "Controls whether the app uses light mode, dark mode, or follows your device's system appearance setting. When inherited, the color scheme configured in your host's Claude CLI theme settings is applied. Override locally to customize appearance on this device."
                    )

                    settingsRow("Updates Channel", value: (config.autoUpdatesChannel ?? "stable").capitalized)
                    settingAnnotation(
                        isInherited: viewModel.isInherited(key: "autoUpdatesChannel"),
                        tooltip: "Controls which release channel the Claude CLI uses for automatic updates on your host machine. The 'stable' channel is recommended for production use, while 'beta' provides early access to new features that may have rough edges."
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
                        isInherited: viewModel.isInherited(key: "alwaysThinkingEnabled"),
                        tooltip: "Enables extended thinking mode where Claude performs deeper multi-step reasoning before responding. This uses significantly more tokens per response but produces more thorough and accurate answers for complex questions and tasks."
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
                        isInherited: viewModel.isInherited(key: "includeCoAuthoredBy"),
                        tooltip: "Adds a 'Co-Authored-By: Claude' attribution line to git commits made during Claude Code sessions. This provides transparency about AI-assisted code changes and is recommended for team repositories where commit provenance matters."
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
                Text("Scope: \(config.scope.rawValue) • \(config.path)")
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
                        isInherited: viewModel.isInherited(key: "permissions"),
                        tooltip: "Controls the default permission mode for tool execution. In 'prompt' mode, Claude asks before running tools. In 'auto' mode, allowed tools run without confirmation. This setting is inherited from your host CLI's permissions configuration."
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
                        isInherited: viewModel.isInherited(key: "permissions"),
                        tooltip: "Tools and file patterns explicitly allowed to run without asking for confirmation. Each rule is a glob pattern matching tool names or file paths. These allow rules are configured in your host CLI's permissions settings and override the default permission mode."
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
                        isInherited: viewModel.isInherited(key: "permissions"),
                        tooltip: "Tools and file patterns explicitly blocked from running, even if they would otherwise be allowed. Deny rules take precedence over allow rules. These are configured in your host CLI's permissions settings to enforce security boundaries."
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
                        let hookCount = hooks.totalHookCount
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
                        isInherited: viewModel.isInherited(key: "hooks"),
                        tooltip: "Lifecycle hooks that run custom commands or scripts at specific Claude Code events such as session start, before tool use, and after tool use. Hooks are configured in your host's ~/.claude/settings.json file and can automate workflows or enforce policies."
                    )

                    if let plugins = config.enabledPlugins {
                        let enabledCount = plugins.count(where: { $0.value })
                        settingsRow("Enabled Plugins", value: "\(enabledCount)")
                    } else {
                        settingsRow("Enabled Plugins", value: "0")
                    }
                    settingAnnotation(
                        isInherited: viewModel.isInherited(key: "enabledPlugins"),
                        tooltip: "Plugins that are currently installed and enabled on your host machine. Plugins extend Claude Code with additional capabilities and integrations. You can browse, install, and manage plugins from the Browse tab in the sidebar."
                    )

                    if let statusLine = config.statusLine {
                        settingsRow("Status Line", value: statusLine.type ?? "disabled")
                    } else {
                        settingsRow("Status Line", value: "Not configured")
                    }
                    settingAnnotation(
                        isInherited: viewModel.isInherited(key: "statusLine"),
                        tooltip: "A custom status line displayed at the bottom of the Claude Code terminal interface on your host. The status line can show dynamic information like the current project, git branch, or custom text configured via your host's settings."
                    )

                    if let env = config.env, !env.isEmpty {
                        settingsRow("Environment Vars", value: "\(env.count)")
                    } else {
                        settingsRow("Environment Vars", value: "0")
                    }
                    settingAnnotation(
                        isInherited: viewModel.isInherited(key: "env"),
                        tooltip: "Environment variables that are injected into Claude Code sessions when they start on your host. These can include API keys, feature flags, or configuration values that tools and hooks need during execution."
                    )
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider().background(theme.bgTertiary)

                NavigationLink {
                    ConfigEditorView(scope: .user)
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
                    ConfigEditorView(scope: .project)
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
                        tooltip: "Experimental feature that enables coordination of multiple AI agents working together on complex tasks. Agent Teams is an iOS-only local setting stored on your device and is not synced with your host CLI configuration."
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

// MARK: - HooksConfig Extension

extension HooksConfig {
    /// Total number of hook entries across all event types.
    var totalHookCount: Int {
        events.values.reduce(0) { $0 + $1.count }
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
