import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
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

    // iCloud sync
    @State private var iCloudSyncEnabled = true
    private let iCloudStore = iCloudKeyValueStore()

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
                        .frame(width: 50, alignment: .leading)
                    TextField("localhost", text: $serverHost)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                HStack {
                    Text("Port")
                        .frame(width: 50, alignment: .leading)
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
                VStack(alignment: .leading, spacing: 4) {
                    if let config = viewModel.config {
                        Text("Scope: \(config.scope) • \(config.path)")
                    }
                }
            }

            // MARK: - iCloud Sync Section
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: iCloudSyncEnabled ? "icloud.fill" : "icloud.slash")
                            .foregroundColor(iCloudSyncEnabled ? .blue : ILSTheme.secondaryText)
                        Text("Sync Settings")
                    }
                }
                .onChange(of: iCloudSyncEnabled) { _, newValue in
                    saveSyncPreference(enabled: newValue)
                }
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text(iCloudSyncEnabled ? "Settings are synced across your devices using iCloud Key-Value Store" : "Settings sync is disabled. Changes will only apply to this device")
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

                // Raw Config Editor Links
                NavigationLink("Edit User Settings") {
                    ConfigEditorView(scope: "user", apiClient: appState.apiClient)
                }

                NavigationLink("Edit Project Settings") {
                    ConfigEditorView(scope: "project", apiClient: appState.apiClient)
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
        Task {
            // Load sync preference from UserDefaults
            iCloudSyncEnabled = UserDefaults.standard.bool(forKey: "ils_icloud_sync_enabled_v2")
            // Default to true if key doesn't exist (first launch)
            if UserDefaults.standard.object(forKey: "ils_icloud_sync_enabled_v2") == nil {
                iCloudSyncEnabled = true
                UserDefaults.standard.set(true, forKey: "ils_icloud_sync_enabled_v2")
            }

            // Load from iCloud Key-Value Store if sync is enabled
            if iCloudSyncEnabled {
                if let savedHost = await iCloudStore.getString(forKey: "ils_server_host") {
                    serverHost = savedHost
                }
                if let savedPort = await iCloudStore.getString(forKey: "ils_server_port") {
                    serverPort = savedPort
                }
            }

            // Also parse from appState if available
            parseServerURL()
        }
    }

    private func saveServerSettings() {
        Task {
            // Save to iCloud Key-Value Store only if sync is enabled
            if iCloudSyncEnabled {
                do {
                    try await iCloudStore.setString(serverHost, forKey: "ils_server_host")
                    try await iCloudStore.setString(serverPort, forKey: "ils_server_port")

                    // Explicitly synchronize with iCloud
                    _ = await iCloudStore.synchronize()
                } catch {
                    print("❌ Failed to save server settings to iCloud: \(error.localizedDescription)")
                }
            }

            // Update appState serverURL
            let url = "http://\(serverHost):\(serverPort)"
            appState.serverURL = url
        }
    }

    private func saveSyncPreference(enabled: Bool) {
        // Save to UserDefaults (local preference)
        UserDefaults.standard.set(enabled, forKey: "ils_icloud_sync_enabled_v2")

        // If sync was just enabled, push current settings to iCloud
        if enabled {
            Task {
                do {
                    try await iCloudStore.setString(serverHost, forKey: "ils_server_host")
                    try await iCloudStore.setString(serverPort, forKey: "ils_server_port")
                    try await iCloudStore.setString(editedModel, forKey: "ils_default_model")
                    try await iCloudStore.setString(editedColorScheme, forKey: "ils_color_scheme")
                    _ = await iCloudStore.synchronize()
                } catch {
                    print("❌ Failed to sync settings to iCloud: \(error.localizedDescription)")
                }
            }
        }
    }

    private func testConnection() {
        Task {
            let url = "http://\(serverHost):\(serverPort)"
            appState.serverURL = url
            await viewModel.testConnection()

            // Save settings if connection successful
            if appState.isConnected {
                saveServerSettings()
            }
        }
    }

    private func saveConfigChanges() {
        Task {
            // Save to backend API
            let result = await viewModel.saveConfig(model: editedModel, colorScheme: editedColorScheme)
            if let error = result {
                saveErrorMessage = error
                showSaveError = true
            } else {
                // Also save to iCloud Key-Value Store for cross-device sync if enabled
                if iCloudSyncEnabled {
                    do {
                        try await iCloudStore.setString(editedModel, forKey: "ils_default_model")
                        try await iCloudStore.setString(editedColorScheme, forKey: "ils_color_scheme")

                        // Explicitly synchronize with iCloud
                        _ = await iCloudStore.synchronize()
                    } catch {
                        print("❌ Failed to save settings to iCloud: \(error.localizedDescription)")
                    }
                }

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
        Task {
            // Load from iCloud Key-Value Store first if sync is enabled
            var iCloudModel: String?
            var iCloudColorScheme: String?

            if iCloudSyncEnabled {
                iCloudModel = await iCloudStore.getString(forKey: "ils_default_model")
                iCloudColorScheme = await iCloudStore.getString(forKey: "ils_color_scheme")
            }

            // Prefer iCloud values if available, otherwise use config from API
            if let config = viewModel.config?.content {
                editedModel = iCloudModel ?? config.model ?? "claude-sonnet-4-20250514"
                editedColorScheme = iCloudColorScheme ?? config.theme?.colorScheme ?? "system"
            } else {
                // If no config loaded yet, use iCloud or defaults
                editedModel = iCloudModel ?? "claude-sonnet-4-20250514"
                editedColorScheme = iCloudColorScheme ?? "system"
            }
        }
    }
}

struct ConfigEditorView: View {
    let scope: String
    let apiClient: APIClient
    @StateObject private var viewModel = ConfigEditorViewModel()
    @State private var configText = ""
    @State private var isSaving = false
    @State private var validationErrors: [String] = []

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                TextEditor(text: $configText)
                    .font(ILSTheme.codeFont)
                    .padding()

                if !validationErrors.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(ILSTheme.captionFont)
                                .foregroundColor(ILSTheme.error)
                        }
                    }
                    .padding()
                    .background(ILSTheme.error.opacity(0.1))
                }
            }
        }
        .navigationTitle("\(scope.capitalized) Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveConfig()
                }
                .disabled(isSaving)
            }
        }
        .task {
            viewModel.configure(client: apiClient)
            await viewModel.loadConfig(scope: scope)
            configText = viewModel.configJson
        }
    }

    private func saveConfig() {
        isSaving = true
        validationErrors = []

        Task {
            let errors = await viewModel.saveConfig(scope: scope, json: configText)
            validationErrors = errors
            isSaving = false
        }
    }
}

// MARK: - View Models

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var config: ConfigInfo?
    @Published var isLoading = false
    @Published var isLoadingConfig = false
    @Published var isSaving = false
    @Published var isTestingConnection = false
    @Published var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    func loadAll() async {
        async let statsTask: () = loadStats()
        async let configTask: () = loadConfig()
        _ = await (statsTask, configTask)
    }

    func loadStats() async {
        guard let client else { return }
        isLoading = true

        do {
            let response: APIResponse<StatsResponse> = try await client.get("/stats")
            stats = response.data
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func loadConfig(scope: String = "user") async {
        guard let client else { return }
        isLoadingConfig = true

        do {
            let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=\(scope)")
            config = response.data
        } catch {
            self.error = error
        }

        isLoadingConfig = false
    }

    func testConnection() async {
        guard let client else { return }
        isTestingConnection = true
        defer { isTestingConnection = false }

        do {
            _ = try await client.healthCheck()
        } catch {
            self.error = error
        }
    }

    func saveConfig(model: String, colorScheme: String) async -> String? {
        guard let client else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        // Build updated config from current config
        guard var currentConfig = config?.content else {
            return "No configuration loaded"
        }

        // Update model
        currentConfig.model = model

        // Update theme (create if doesn't exist)
        if currentConfig.theme == nil {
            currentConfig.theme = ThemeConfig(colorScheme: colorScheme, accentColor: nil)
        } else {
            currentConfig.theme?.colorScheme = colorScheme
        }

        do {
            let request = UpdateConfigRequest(scope: config?.scope ?? "user", content: currentConfig)
            let response: APIResponse<ConfigInfo> = try await client.put("/config", body: request)

            // Update local config with response
            if let updatedConfig = response.data {
                config = updatedConfig

                // Check for validation errors
                if !updatedConfig.isValid {
                    return updatedConfig.errors?.joined(separator: "\n") ?? "Configuration validation failed"
                }
            }

            return nil // Success
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var configJson = ""
    @Published var isLoading = false
    @Published var error: Error?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    func loadConfig(scope: String) async {
        guard let client else { return }
        isLoading = true

        do {
            let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=\(scope)")
            if let config = response.data {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let data = try? encoder.encode(config.content),
                   let json = String(data: data, encoding: .utf8) {
                    configJson = json
                }
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func saveConfig(scope: String, json: String) async -> [String] {
        guard let client else { return ["Client not configured"] }
        guard let data = json.data(using: .utf8),
              let content = try? JSONDecoder().decode(ClaudeConfig.self, from: data) else {
            return ["Invalid JSON format"]
        }

        do {
            let request = UpdateConfigRequest(scope: scope, content: content)
            let response: APIResponse<ConfigInfo> = try await client.put("/config", body: request)

            if let config = response.data, !config.isValid {
                return config.errors ?? []
            }
        } catch {
            return ["Failed to save: \(error.localizedDescription)"]
        }

        return []
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
