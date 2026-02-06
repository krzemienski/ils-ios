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
                        .accessibilityLabel("Server host")
                }

                HStack {
                    Text("Port")
                        .frame(width: 50, alignment: .leading)
                    TextField("8080", text: $serverPort)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Server port")
                }

                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isConnected ? ILSTheme.success : ILSTheme.error)
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

                NavigationLink {
                    ServerConnectionView()
                        .environmentObject(appState)
                } label: {
                    Label("SSH Server Connection", systemImage: "network")
                }
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
                            .foregroundColor(config.alwaysThinkingEnabled == true ? ILSTheme.success : ILSTheme.secondaryText)
                    }

                    // Co-authored by (read-only)
                    LabeledContent("Include Co-Author") {
                        Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.includeCoAuthoredBy == true ? ILSTheme.success : ILSTheme.secondaryText)
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

            // MARK: - Quick Settings Section
            Section {
                if let config = viewModel.config?.content {
                    // Model Picker
                    Picker("Model", selection: Binding(
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

                    // Extended Thinking Toggle
                    Toggle("Extended Thinking", isOn: Binding(
                        get: { config.alwaysThinkingEnabled ?? false },
                        set: { _ in
                            // Read-only for now - toggle display only
                        }
                    ))
                    .disabled(true)

                    // Co-authored-by Toggle
                    Toggle("Include Co-Author", isOn: Binding(
                        get: { config.includeCoAuthoredBy ?? false },
                        set: { _ in
                            // Read-only for now - toggle display only
                        }
                    ))
                    .disabled(true)
                } else if !viewModel.isLoadingConfig {
                    Text("Load settings to see quick actions")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } header: {
                Text("Quick Settings")
            } footer: {
                Text("Change common settings without editing raw JSON")
            }

            // MARK: - API Key Section
            Section {
                if let config = viewModel.config?.content {
                    if let apiKeyStatus = config.apiKeyStatus {
                        HStack {
                            Image(systemName: apiKeyStatus.isConfigured ? "checkmark.shield.fill" : "shield.slash")
                                .foregroundColor(apiKeyStatus.isConfigured ? ILSTheme.success : ILSTheme.warning)
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
                                .foregroundColor(ILSTheme.warning)
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
                LabeledContent("App Version", value: "1.0.0")
                LabeledContent("Build", value: "1")

                if let claudeVersion = viewModel.claudeVersion {
                    LabeledContent("Claude CLI", value: claudeVersion)
                } else {
                    LabeledContent("Claude CLI") {
                        Text("Checking...")
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }

                LabeledContent("Backend Port", value: serverPort)

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
        .background(ILSTheme.background)
        .navigationTitle("Settings")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
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
        appState.serverURL = url
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

struct ConfigEditorView: View {
    let scope: String
    let apiClient: APIClient
    @StateObject private var viewModel = ConfigEditorViewModel()
    @State private var configText = ""
    @State private var originalConfigText = ""
    @State private var isSaving = false
    @State private var validationErrors: [String] = []
    @State private var hasUnsavedChanges = false
    @State private var showUnsavedChangesAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                TextEditor(text: $configText)
                    .font(ILSTheme.codeFont)
                    .padding()

                // JSON validation indicator
                HStack {
                    if isValidJSON(configText) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ILSTheme.success)
                        Text("Valid JSON")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.success)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ILSTheme.error)
                        Text("Invalid JSON")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.error)
                    }
                    Spacer()
                }
                .padding(.horizontal)

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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasUnsavedChanges {
                        showUnsavedChangesAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    saveConfig()
                }
                .disabled(isSaving || !hasUnsavedChanges)
            }
        }
        .task {
            viewModel.configure(client: apiClient)
            await viewModel.loadConfig(scope: scope)
            configText = viewModel.configJson
            originalConfigText = viewModel.configJson
        }
        .onChange(of: configText) { _, newValue in
            hasUnsavedChanges = (newValue != originalConfigText)
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You have unsaved changes. Are you sure you want to discard them?")
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onDisappear {
            // User dismissed with unsaved changes (swipe back)
            if hasUnsavedChanges {
                // The sheet has already been dismissed at this point
                // We rely on interactiveDismissDisabled to prevent the swipe
            }
        }
    }

    private func saveConfig() {
        isSaving = true
        validationErrors = []

        Task {
            let errors = await viewModel.saveConfig(scope: scope, json: configText)
            validationErrors = errors
            isSaving = false

            // If save was successful, update original text and clear unsaved flag
            if errors.isEmpty {
                originalConfigText = configText
                hasUnsavedChanges = false
                dismiss()
            }
        }
    }

    private func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

// MARK: - View Models

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var stats: StatsResponse?
    @Published var config: ConfigInfo?
    @Published var claudeVersion: String?
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
        async let healthTask: () = loadHealth()
        _ = await (statsTask, configTask, healthTask)
    }

    func loadHealth() async {
        guard let client else { return }
        do {
            let response: HealthResponse = try await client.get("/health")
            claudeVersion = response.claudeVersion
        } catch {
            // Health endpoint might return plain string — try alternate
            claudeVersion = nil
        }
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
