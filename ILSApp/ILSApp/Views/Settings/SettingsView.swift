import SwiftUI
import ILSShared

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel = SettingsViewModel()
    @State private var serverHost: String = "localhost"
    @State private var serverPort: String = "9999"
    @State private var backendAPIKey: String = ""
    @State private var showAPIKeySaved = false

    // Editing state
    @State private var isEditing = false
    @State private var editedModel: String = ""
    @State private var editedColorScheme: String = "system"

    // Alert state
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showSaveSuccess = false

    // Available options
    private let availableModels = [
        "claude-sonnet-4-5",
        "claude-opus-4-6",
        "claude-haiku-4-5"
    ]

    private let availableColorSchemes = ["system", "light", "dark"]

    var body: some View {
        Form {
            // MARK: - Connection Section
            Section {
                HStack {
                    Text("Host")
                    TextField("localhost", text: $serverHost)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                HStack {
                    Text("Port")
                    TextField("9999", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Button {
                    testConnection()
                } label: {
                    HStack {
                        if viewModel.isTestingConnection {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(viewModel.isTestingConnection ? "Testing..." : "Test Connection")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTestingConnection)
            } header: {
                Text("Backend Connection")
            } footer: {
                Text("Configure the ILS backend server address")
            }

            // MARK: - Backend Authentication
            Section {
                SecureField("API Key", text: $backendAPIKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                Button {
                    saveBackendAPIKey()
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                        Text(backendAPIKey.isEmpty ? "Clear API Key" : "Save API Key")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } header: {
                Text("Backend Authentication")
            } footer: {
                Text("Optional. Required when the backend has ILS_API_KEY configured. Leave empty for local development.")
            }
            .alert("API Key Saved", isPresented: $showAPIKeySaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backendAPIKey.isEmpty ? "API key cleared." : "API key saved. All future requests will include authentication.")
            }

            // MARK: - General Settings Section
            Section {
                if viewModel.isLoadingConfig {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading configuration...")
                            .foregroundStyle(theme.textSecondary)
                    }
                } else if let config = viewModel.config?.content {
                    // Default Model - Editable
                    if isEditing {
                        Picker("Default Model", selection: $editedModel) {
                            ForEach(availableModels, id: \.self) { model in
                                Text(formatModelName(model))
                                    .tag(model)
                            }
                        }
                    } else {
                        LabeledContent("Default Model") {
                            HStack(spacing: 4) {
                                Text(formatModelName(config.model ?? "claude-opus-4-6"))
                                    .foregroundStyle(theme.textSecondary)
                                if config.model == nil {
                                    hostDefaultBadge
                                }
                            }
                        }
                    }

                    // Theme Color Scheme - Editable
                    if isEditing {
                        Picker("Color Scheme", selection: $editedColorScheme) {
                            ForEach(availableColorSchemes, id: \.self) { scheme in
                                Text(scheme.capitalized)
                                    .tag(scheme)
                            }
                        }
                    } else {
                        LabeledContent("Color Scheme") {
                            HStack(spacing: 4) {
                                Text((config.theme?.colorScheme ?? "system").capitalized)
                                    .foregroundStyle(theme.textSecondary)
                                if config.theme?.colorScheme == nil {
                                    hostDefaultBadge
                                }
                            }
                        }
                    }

                    // Auto Updates Channel (read-only)
                    if let channel = config.autoUpdatesChannel {
                        LabeledContent("Updates Channel") {
                            Text(channel.capitalized)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    // Always Thinking (read-only)
                    LabeledContent {
                        HStack(spacing: 4) {
                            Image(systemName: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(config.alwaysThinkingEnabled == true ? theme.success : theme.textSecondary)
                            if config.alwaysThinkingEnabled == nil {
                                hostDefaultBadge
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Extended Thinking")
                            InfoTooltipButton(text: "Allows Claude to use internal reasoning before responding. Uses additional tokens but improves response quality.")
                        }
                    }

                    // Co-authored by (read-only)
                    LabeledContent {
                        HStack(spacing: 4) {
                            Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(config.includeCoAuthoredBy == true ? theme.success : theme.textSecondary)
                            if config.includeCoAuthoredBy == nil {
                                hostDefaultBadge
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Include Co-Author")
                            InfoTooltipButton(text: "Adds 'Co-authored-by: Claude' attribution to git commits made during sessions.")
                        }
                    }

                    // System Prompt (informational — per-session config)
                    LabeledContent {
                        Text("Per-session")
                            .foregroundStyle(theme.textTertiary)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    } label: {
                        HStack(spacing: 4) {
                            Text("System Prompt")
                            InfoTooltipButton(text: "System prompts are configured per session in the New Session or Advanced Options views. There is no global default.")
                        }
                    }

                    // Save button when editing
                    if isEditing {
                        Button {
                            showSaveConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Changes")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSaving)
                    }
                } else {
                    Text("No configuration loaded")
                        .foregroundStyle(theme.textSecondary)
                }
            } header: {
                HStack {
                    Text("General")
                    Spacer()
                    if viewModel.config != nil && !viewModel.isLoadingConfig {
                        Button(isEditing ? "Cancel" : "Edit") {
                            if isEditing {
                                // Cancel editing - reset to original values
                                resetEditedValues()
                            }
                            isEditing.toggle()
                        }
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .textCase(nil)
                    }
                }
            } footer: {
                if let config = viewModel.config {
                    Text("Scope: \(config.scope) • \(config.path)")
                }
            }

            // MARK: - API Key Section
            Section {
                if let config = viewModel.config?.content {
                    if let apiKeyStatus = config.apiKeyStatus {
                        HStack {
                            Image(systemName: apiKeyStatus.isConfigured ? "checkmark.shield.fill" : "shield.slash")
                                .foregroundColor(apiKeyStatus.isConfigured ? theme.success : theme.warning)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(apiKeyStatus.isConfigured ? "API Key Configured" : "No API Key")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
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
                                .foregroundColor(theme.warning)
                            Text("API Key status unknown")
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("Loading API key status...")
                        .foregroundStyle(theme.textSecondary)
                }
            } header: {
                Text("API Key")
            } footer: {
                Text("For security, API keys cannot be edited through the iOS app. Use the terminal command: claude config set apiKey <your-key>")
            }

            // MARK: - Permissions Section
            Section {
                if let config = viewModel.config?.content, let permissions = config.permissions {
                    // Default Permission Mode
                    LabeledContent {
                        Text(permissions.defaultMode?.capitalized ?? "Prompt")
                            .foregroundStyle(theme.textSecondary)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Default Mode")
                            InfoTooltipButton(text: "Controls how Claude handles tool permissions. 'Allow' auto-approves, 'Deny' blocks, 'Prompt' asks each time.")
                        }
                    }

                    // Allowed Commands
                    if let allowed = permissions.allow, !allowed.isEmpty {
                        DisclosureGroup {
                            ForEach(allowed, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                LabeledContent("Allowed", value: "\(allowed.count) rules")
                                InfoTooltipButton(text: "Tools and patterns explicitly allowed without prompting. Supports glob patterns like 'Bash(npm:*)' or 'Read'.")
                            }
                        }
                    } else {
                        LabeledContent {
                            Text("None")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Allowed")
                                InfoTooltipButton(text: "Tools and patterns explicitly allowed without prompting. Supports glob patterns like 'Bash(npm:*)' or 'Read'.")
                            }
                        }
                    }

                    // Denied Commands
                    if let denied = permissions.deny, !denied.isEmpty {
                        DisclosureGroup {
                            ForEach(denied, id: \.self) { item in
                                Text(item)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                LabeledContent("Denied", value: "\(denied.count) rules")
                                InfoTooltipButton(text: "Tools and patterns explicitly blocked. Claude will not attempt to use denied tools.")
                            }
                        }
                    } else {
                        LabeledContent {
                            Text("None")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Denied")
                                InfoTooltipButton(text: "Tools and patterns explicitly blocked. Claude will not attempt to use denied tools.")
                            }
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No permissions configured")
                        .foregroundStyle(theme.textSecondary)
                }
            } header: {
                Text("Permissions")
            }

            // MARK: - Advanced Section
            Section {
                if let config = viewModel.config?.content {
                    // Hooks Management
                    NavigationLink {
                        HooksManagementView()
                    } label: {
                        let hookCount = config.hooks.map { countHooks($0) } ?? 0
                        LabeledContent {
                            Text("\(hookCount) configured")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Hooks")
                                InfoTooltipButton(text: "Shell commands that run at lifecycle events (session start, prompt submit, tool use). Useful for automation and custom workflows.")
                            }
                        }
                    }

                    // Enabled Plugins Count
                    if let plugins = config.enabledPlugins {
                        let enabledCount = plugins.filter { $0.value }.count
                        LabeledContent {
                            Text("\(enabledCount)")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Enabled Plugins")
                                InfoTooltipButton(text: "MCP server plugins that extend Claude's capabilities. Enable or disable via terminal: claude config set plugins.<name> true/false.")
                            }
                        }
                    } else {
                        LabeledContent("Enabled Plugins", value: "0")
                    }

                    // Status Line
                    if let statusLine = config.statusLine {
                        LabeledContent {
                            Text(statusLine.type ?? "disabled")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Status Line")
                                InfoTooltipButton(text: "Custom status display in the terminal. Runs a shell command to generate dynamic content shown during sessions.")
                            }
                        }
                    }

                    // Environment Variables
                    if let env = config.env, !env.isEmpty {
                        LabeledContent {
                            Text("\(env.count)")
                                .foregroundStyle(theme.textSecondary)
                        } label: {
                            HStack(spacing: 4) {
                                Text("Environment Vars")
                                InfoTooltipButton(text: "Custom environment variables passed to Claude CLI sessions. Used for API keys, feature flags, and tool configuration.")
                            }
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .foregroundStyle(theme.textSecondary)
                }

                // Theme Management
                NavigationLink("Browse Themes") {
                    ThemeMarketplaceView()
                }

                NavigationLink("Custom Themes") {
                    ThemesListView()
                }

                // Raw Config Editor Links
                NavigationLink("Edit User Settings") {
                    ConfigEditorView(scope: "user")
                }

                NavigationLink("Edit Project Settings") {
                    ConfigEditorView(scope: "project")
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Edit raw JSON configuration files")
            }

            // MARK: - Statistics Section
            Section("Statistics") {
                if viewModel.isLoading {
                    ProgressView()
                } else if let stats = viewModel.stats {
                    LabeledContent("Projects", value: "\(stats.projects.total)")
                    LabeledContent("Sessions", value: "\(stats.sessions.total) (\(stats.sessions.active) active)")
                    LabeledContent("Skills", value: "\(stats.skills.total)")
                    LabeledContent("MCP Servers", value: "\(stats.mcpServers.total) (\(stats.mcpServers.healthy) healthy)")
                    LabeledContent("Plugins", value: "\(stats.plugins.total) (\(stats.plugins.enabled) enabled)")
                }
            }

            // MARK: - About Section
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")

                Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                    HStack {
                        Text("Claude Code Documentation")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .foregroundStyle(theme.textPrimary)
        .navigationTitle("Settings")
        .inlineNavigationBarTitle()
        .screenshotProtected()
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            loadServerSettings()
            loadBackendAPIKey()
            await viewModel.loadAll()
            resetEditedValues()
        }
        .confirmationDialog("Save Configuration Changes?", isPresented: $showSaveConfirmation, titleVisibility: .visible) {
            Button("Save Changes") {
                saveConfigChanges()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will update your Claude Code configuration. Changes will take effect immediately.")
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .alert("Configuration Saved", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your configuration has been updated successfully.")
        }
        .onChange(of: serverHost) { _, newValue in
            saveServerSettings()
        }
        .onChange(of: serverPort) { _, newValue in
            saveServerSettings()
        }
    }

    // MARK: - Server Settings Persistence

    private func loadServerSettings() {
        // Load from UserDefaults
        if let savedHost = UserDefaults.standard.string(forKey: "ils_server_host") {
            serverHost = savedHost
        }
        if let savedPort = UserDefaults.standard.string(forKey: "ils_server_port") {
            serverPort = savedPort
        }
        // Also parse from appState if available
        parseServerURL()
    }

    private func saveServerSettings() {
        // Save to UserDefaults
        UserDefaults.standard.set(serverHost, forKey: "ils_server_host")
        UserDefaults.standard.set(serverPort, forKey: "ils_server_port")

        // Update appState serverURL
        let url = "http://\(serverHost):\(serverPort)"
        appState.connectionManager.serverURL = url
    }

    private func testConnection() {
        Task {
            let url = "http://\(serverHost):\(serverPort)"
            appState.connectionManager.serverURL = url
            await viewModel.testConnection()

            // Save settings if connection successful
            if appState.isConnected {
                saveServerSettings()
            }
        }
    }

    private func saveConfigChanges() {
        Task {
            let result = await viewModel.saveConfig(model: editedModel, colorScheme: editedColorScheme)
            if let error = result {
                saveErrorMessage = error
                showSaveError = true
            } else {
                isEditing = false
                showSaveSuccess = true
                await viewModel.loadConfig()
            }
        }
    }

    // MARK: - Backend API Key

    private func loadBackendAPIKey() {
        Task {
            if let masked = await appState.apiClient.maskedAPIKey() {
                backendAPIKey = masked
            }
        }
    }

    private func saveBackendAPIKey() {
        Task {
            await appState.apiClient.setAPIKey(backendAPIKey.isEmpty ? nil : backendAPIKey)
            showAPIKeySaved = true
        }
    }

    // MARK: - Reusable Components

    private var hostDefaultBadge: some View {
        Text("Host Default")
            .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.accent.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Helper Methods

    private func parseServerURL() {
        // Parse existing server URL into host and port
        if let url = URL(string: appState.serverURL),
           let host = url.host {
            serverHost = host
            if let port = url.port {
                serverPort = String(port)
            }
        }
    }

    private func countHooks(_ hooks: HooksConfig) -> Int {
        var count = 0
        if let h = hooks.sessionStart { count += h.count }
        if let h = hooks.subagentStart { count += h.count }
        if let h = hooks.userPromptSubmit { count += h.count }
        if let h = hooks.preToolUse { count += h.count }
        if let h = hooks.postToolUse { count += h.count }
        return count
    }

    private func formatModelName(_ model: String) -> String {
        // Convert model ID to human-readable name
        if model.contains("sonnet") {
            return "Claude Sonnet"
        } else if model.contains("opus") {
            return "Claude Opus"
        } else if model.contains("haiku") {
            return "Claude Haiku"
        }
        return model
    }

    private func resetEditedValues() {
        // Reset edited values to current config values
        if let config = viewModel.config?.content {
            editedModel = config.model ?? "claude-opus-4-6"
            editedColorScheme = config.theme?.colorScheme ?? "system"
        }
    }
}

// MARK: - Models
// Using models from ILSShared: StatsResponse, CountStat, SessionStat, MCPStat, PluginStat,
// ConfigInfo, ClaudeConfig, PermissionsConfig, UpdateConfigRequest

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
