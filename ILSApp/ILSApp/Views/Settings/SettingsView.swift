import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @StateObject private var viewModel = SettingsViewModel()
    @State private var serverHost: String = "localhost"
    @State private var serverPort: String = "8080"

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
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
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
                    TextField("8080", text: $serverPort)
                        .keyboardType(.numberPad)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(ILSTheme.secondaryText)
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

            // MARK: - General Settings Section
            Section {
                if viewModel.isLoadingConfig {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading configuration...")
                            .foregroundColor(ILSTheme.secondaryText)
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
                            Text(formatModelName(config.model ?? "claude-sonnet-4-20250514"))
                                .foregroundColor(ILSTheme.secondaryText)
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
                            Text((config.theme?.colorScheme ?? "system").capitalized)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    // Auto Updates Channel (read-only)
                    if let channel = config.autoUpdatesChannel {
                        LabeledContent("Updates Channel") {
                            Text(channel.capitalized)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    // Always Thinking (read-only)
                    LabeledContent("Extended Thinking") {
                        Image(systemName: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.alwaysThinkingEnabled == true ? .green : ILSTheme.secondaryText)
                    }

                    // Co-authored by (read-only)
                    LabeledContent("Include Co-Author") {
                        Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.includeCoAuthoredBy == true ? .green : ILSTheme.secondaryText)
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
                        .foregroundColor(ILSTheme.secondaryText)
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
                        .font(ILSTheme.captionFont)
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
                                .foregroundColor(apiKeyStatus.isConfigured ? .green : .orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(apiKeyStatus.isConfigured ? "API Key Configured" : "No API Key")
                                    .font(ILSTheme.bodyFont)
                                if let maskedKey = apiKeyStatus.maskedKey {
                                    Text("Key: \(maskedKey)")
                                        .font(ILSTheme.captionFont)
                                        .foregroundColor(ILSTheme.secondaryText)
                                }
                                if let source = apiKeyStatus.source {
                                    Text("Source: \(source)")
                                        .font(ILSTheme.captionFont)
                                        .foregroundColor(ILSTheme.secondaryText)
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            Text("API Key status unknown")
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("Loading API key status...")
                        .foregroundColor(ILSTheme.secondaryText)
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
                    LabeledContent("Default Mode") {
                        Text(permissions.defaultMode?.capitalized ?? "Prompt")
                            .foregroundColor(ILSTheme.secondaryText)
                    }

                    // Allowed Commands
                    if let allowed = permissions.allow, !allowed.isEmpty {
                        DisclosureGroup {
                            ForEach(allowed, id: \.self) { item in
                                Text(item)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        } label: {
                            LabeledContent("Allowed", value: "\(allowed.count) rules")
                        }
                    } else {
                        LabeledContent("Allowed", value: "None")
                    }

                    // Denied Commands
                    if let denied = permissions.deny, !denied.isEmpty {
                        DisclosureGroup {
                            ForEach(denied, id: \.self) { item in
                                Text(item)
                                    .font(ILSTheme.captionFont)
                                    .foregroundColor(ILSTheme.secondaryText)
                            }
                        } label: {
                            LabeledContent("Denied", value: "\(denied.count) rules")
                        }
                    } else {
                        LabeledContent("Denied", value: "None")
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No permissions configured")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } header: {
                Text("Permissions")
            }

            // MARK: - Advanced Section
            Section {
                if let config = viewModel.config?.content {
                    // Hooks Summary
                    if let hooks = config.hooks {
                        let hookCount = countHooks(hooks)
                        LabeledContent("Hooks Configured", value: "\(hookCount)")
                    } else {
                        LabeledContent("Hooks Configured", value: "0")
                    }

                    // Enabled Plugins Count
                    if let plugins = config.enabledPlugins {
                        let enabledCount = plugins.filter { $0.value }.count
                        LabeledContent("Enabled Plugins", value: "\(enabledCount)")
                    } else {
                        LabeledContent("Enabled Plugins", value: "0")
                    }

                    // Status Line
                    if let statusLine = config.statusLine {
                        LabeledContent("Status Line") {
                            Text(statusLine.type ?? "disabled")
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    // Environment Variables
                    if let env = config.env, !env.isEmpty {
                        LabeledContent("Environment Vars", value: "\(env.count)")
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .foregroundColor(ILSTheme.secondaryText)
                }

                // Theme Management
                NavigationLink("Manage Themes") {
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
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .navigationTitle("Settings")
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            loadServerSettings()
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
            editedModel = config.model ?? "claude-sonnet-4-20250514"
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
            .environmentObject(AppState())
    }
}
