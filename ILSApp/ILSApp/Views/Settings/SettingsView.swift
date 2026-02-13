import SwiftUI
import ILSShared
import LocalAuthentication

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

    // Biometric protection state
    @State private var biometricProtectionEnabled = false
    @State private var biometricType: String?

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
            generalSection
            apiKeySection
            securitySection
            permissionsSection
            advancedSection
            statisticsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            loadServerSettings()
            loadBiometricSettings()
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

    // MARK: - Extracted Sections

    @ViewBuilder
    private var connectionSection: some View {
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
    }

    @ViewBuilder
    private var generalSection: some View {
        Section {
            if viewModel.isLoadingConfig {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Loading configuration...")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } else if let config = viewModel.config?.content {
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

                if let channel = config.autoUpdatesChannel {
                    LabeledContent("Updates Channel") {
                        Text(channel.capitalized)
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }

                LabeledContent("Extended Thinking") {
                    Image(systemName: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(config.alwaysThinkingEnabled == true ? .green : ILSTheme.secondaryText)
                }

                LabeledContent("Include Co-Author") {
                    Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(config.includeCoAuthoredBy == true ? .green : ILSTheme.secondaryText)
                }

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
    }

    @ViewBuilder
    private var apiKeySection: some View {
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
    }

    @ViewBuilder
    private var securitySection: some View {
        Section {
            if let biometricType = biometricType {
                Toggle(isOn: $biometricProtectionEnabled) {
                    HStack {
                        Image(systemName: biometricType.contains("Face") ? "faceid" : "touchid")
                            .foregroundColor(.blue)
                        Text("Require \(biometricType)")
                    }
                }
                .onChange(of: biometricProtectionEnabled) { _, newValue in
                    toggleBiometricProtection(enabled: newValue)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(.orange)
                    Text("Biometric authentication not available")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            }
        } header: {
            Text("Security")
        } footer: {
            if biometricType != nil {
                Text("When enabled, \(biometricType!) is required to access server credentials stored in the Keychain.")
            } else {
                Text("Enable Face ID or Touch ID in iOS Settings to protect your credentials.")
            }
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        Section {
            if let config = viewModel.config?.content, let permissions = config.permissions {
                LabeledContent("Default Mode") {
                    Text(permissions.defaultMode?.capitalized ?? "Prompt")
                        .foregroundColor(ILSTheme.secondaryText)
                }

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
                if let hooks = config.hooks {
                    let hookCount = countHooks(hooks)
                    LabeledContent("Hooks Configured", value: "\(hookCount)")
                } else {
                    LabeledContent("Hooks Configured", value: "0")
                }

                if let plugins = config.enabledPlugins {
                    let enabledCount = plugins.filter { $0.value }.count
                    LabeledContent("Enabled Plugins", value: "\(enabledCount)")
                } else {
                    LabeledContent("Enabled Plugins", value: "0")
                }

                if let statusLine = config.statusLine {
                    LabeledContent("Status Line") {
                        Text(statusLine.type ?? "disabled")
                            .foregroundColor(ILSTheme.secondaryText)
                    }
                }

                if let env = config.env, !env.isEmpty {
                    LabeledContent("Environment Vars", value: "\(env.count)")
                }
            } else if !viewModel.isLoadingConfig {
                Text("No advanced settings")
                    .foregroundColor(ILSTheme.secondaryText)
            }

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
    private var aboutSection: some View {
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

    // MARK: - Settings Persistence

    func loadServerSettings() {
        parseServerURL()
    }

    func saveServerSettings() {
        guard !serverHost.isEmpty, !serverPort.isEmpty else { return }
        let urlString = "http://\(serverHost):\(serverPort)"
        appState.updateServerURL(urlString)
    }

    func testConnection() {
        Task {
            let urlString = "http://\(serverHost):\(serverPort)"
            guard URL(string: urlString) != nil else { return }
            appState.updateServerURL(urlString)
            await viewModel.testConnection()
            if appState.isConnected { saveServerSettings() }
        }
    }

    func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "Claude Sonnet" }
        if model.contains("opus") { return "Claude Opus" }
        if model.contains("haiku") { return "Claude Haiku" }
        return model
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

    private func resetEditedValues() {
        if let config = viewModel.config?.content {
            editedModel = config.model ?? "claude-sonnet-4-20250514"
            editedColorScheme = config.theme?.colorScheme ?? "system"
        }
    }

    // MARK: - Biometric Protection Methods

    private func loadBiometricSettings() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: biometricType = "Face ID"
            case .touchID: biometricType = "Touch ID"
            default: biometricType = nil
            }
        } else {
            biometricType = nil
        }
        biometricProtectionEnabled = UserDefaults.standard.bool(forKey: "biometric_protection_enabled")
    }

    private func toggleBiometricProtection(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometric_protection_enabled")
    }
}

// MARK: - View Models
// ConfigEditorView is in Views/Settings/ConfigEditorView.swift
// SettingsViewModel is in ViewModels/SettingsViewModel.swift

// MARK: - Models
// Using models from ILSShared: StatsResponse, CountStat, SessionStat, MCPStat, PluginStat,
// ConfigInfo, ClaudeConfig, PermissionsConfig, UpdateConfigRequest
// ConfigEditorViewModel is in ViewModels/ConfigEditorViewModel.swift

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
