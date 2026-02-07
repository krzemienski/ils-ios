import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var serverURL: String = ""
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"

    // Available options
    private let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
    ]

    private let availableColorSchemes = ["system", "light", "dark"]

    var body: some View {
        Form {
            connectionSection
            remoteAccessSection
            manageSection
            generalSettingsSection
            apiKeySection
            permissionsSection
            advancedSection
            statisticsSection
            diagnosticsSection
            aboutSection
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
        }
    }

    // MARK: - View Sections

    @ViewBuilder
    private var connectionSection: some View {
        Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(ILSTheme.secondaryText)
                    TextField("https://example.com or http://localhost:9090", text: $serverURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Server URL")
                        .onSubmit {
                            saveServerSettings()
                        }
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
                .accessibilityLabel("Test connection to backend server")
            } header: {
                Text("Backend Connection")
            } footer: {
                Text("Configure the ILS backend server address")
            }

    }

    @ViewBuilder
    private var remoteAccessSection: some View {
        Section {
            NavigationLink {
                TunnelSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.body)
                        .foregroundColor(ILSTheme.info)
                        .frame(width: 28, height: 28)
                        .background(ILSTheme.info.opacity(0.15))
                        .cornerRadius(6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remote Access")
                        Text("Cloudflare Tunnel")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
        } header: {
            Text("Remote Access")
        }
    }

    @ViewBuilder
    private var manageSection: some View {
        Section {
            NavigationLink {
                SkillsListView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.body)
                        .foregroundColor(EntityType.skills.color)
                        .frame(width: 28, height: 28)
                        .background(EntityType.skills.color.opacity(0.15))
                        .cornerRadius(6)
                    Text("Skills")
                    Spacer()
                    if let stats = viewModel.stats {
                        Text("\(stats.skills.total)")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }

            NavigationLink {
                MCPServerListView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.body)
                        .foregroundColor(EntityType.mcp.color)
                        .frame(width: 28, height: 28)
                        .background(EntityType.mcp.color.opacity(0.15))
                        .cornerRadius(6)
                    Text("MCP Servers")
                    Spacer()
                    if let stats = viewModel.stats {
                        Text("\(stats.mcpServers.total)")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }

            NavigationLink {
                PluginsListView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.body)
                        .foregroundColor(EntityType.plugins.color)
                        .frame(width: 28, height: 28)
                        .background(EntityType.plugins.color.opacity(0.15))
                        .cornerRadius(6)
                    Text("Plugins")
                    Spacer()
                    if let stats = viewModel.stats {
                        Text("\(stats.plugins.total)")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }
            }
        } header: {
            Text("Manage")
        }
    }

    @ViewBuilder
    private var generalSettingsSection: some View {
        Section {
                if viewModel.isLoadingConfig {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Loading configuration...")
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                } else if let config = viewModel.config?.content {
                    // Model Picker (auto-saves on change)
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
                    .accessibilityLabel("Default Claude model")

                    // Color Scheme Picker (writes to UserDefaults)
                    Picker("Color Scheme", selection: $colorSchemePreference) {
                        ForEach(availableColorSchemes, id: \.self) { scheme in
                            Text(scheme.capitalized).tag(scheme)
                        }
                    }
                    .accessibilityLabel("Color scheme preference")

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
                } else {
                    Text("No configuration loaded")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } header: {
                Text("General")
            } footer: {
                if let config = viewModel.config {
                    Text("Scope: \(config.scope) • \(config.path)")
                }
            }

    }

    @ViewBuilder
    private var apiKeySection: some View {
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

    }

    @ViewBuilder
    private var permissionsSection: some View {
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

    }

    @ViewBuilder
    private var advancedSection: some View {
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

    }

    @ViewBuilder
    private var statisticsSection: some View {
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

    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section("DIAGNOSTICS") {
                Toggle(isOn: .init(
                    get: { AppLogger.shared.analyticsOptedIn },
                    set: { AppLogger.shared.analyticsOptedIn = $0 }
                )) {
                    Label("Analytics", systemImage: "chart.bar")
                }
                .tint(.orange)
                .accessibilityLabel("Enable analytics")

                NavigationLink(destination: LogViewerView()) {
                    Label("View Logs", systemImage: "doc.text")
                }
                NavigationLink(destination: NotificationPreferencesView()) {
                    Label("Notifications", systemImage: "bell.badge")
                }
            }

    }

    @ViewBuilder
    private var aboutSection: some View {
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

                LabeledContent("Backend URL", value: serverURL)

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

    // MARK: - Server Settings Persistence

    private func loadServerSettings() {
        // Load full URL from appState (which loads from UserDefaults)
        parseServerURL()
    }

    private func saveServerSettings() {
        // Validate URL format
        guard !serverURL.isEmpty else { return }
        
        // Update appState serverURL (persists to UserDefaults and recreates clients)
        appState.updateServerURL(serverURL)
    }

    private func testConnection() {
        Task {
            // Validate URL format
            guard !serverURL.isEmpty, URL(string: serverURL) != nil else {
                return
            }
            
            appState.updateServerURL(serverURL)
            await viewModel.testConnection()

            // Save settings if connection successful
            if appState.isConnected {
                saveServerSettings()
            }
        }
    }

    // MARK: - Helper Methods

    private func parseServerURL() {
        // Load full URL from appState
        serverURL = appState.serverURL
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
            let response = try await client.getHealth()
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
