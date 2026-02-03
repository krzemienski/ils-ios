import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var serverHost: String = "localhost"
    @State private var serverPort: String = "8080"

    // Scope state
    @State private var selectedScope: String = "user"

    // Editing state
    @State private var isEditing = false
    @State private var editedModel: String = ""
    @State private var editedColorScheme: String = "system"
    @State private var editedPermissions: PermissionsConfig = PermissionsConfig()
    @State private var editedAlwaysThinkingEnabled: Bool = false
    @State private var editedIncludeCoAuthoredBy: Bool = false
    @State private var editedEnvironment: [String: String] = [:]

    // Alert state
    @State private var showSaveConfirmation = false
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showSaveSuccess = false
    @State private var showDangerousPermissionWarning = false
    @State private var showResetConfirmation = false
    @State private var showResetSuccess = false
    @State private var showResetError = false
    @State private var resetErrorMessage = ""

    // Validation state
    @State private var validationErrors: [String] = []

    // Permission tracking for dangerous changes
    @State private var previousDefaultMode: String = "prompt"

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
                // Scope Picker
                Picker("Scope", selection: $selectedScope) {
                    Text("User").tag("user")
                    Text("Project").tag("project")
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isLoadingConfig)

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

                    // Always Thinking - Editable
                    if isEditing {
                        BooleanSettingsView(
                            label: "Extended Thinking",
                            value: $editedAlwaysThinkingEnabled,
                            description: "Enable extended thinking mode for complex tasks"
                        )
                    } else {
                        LabeledContent("Extended Thinking") {
                            Image(systemName: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(config.alwaysThinkingEnabled == true ? .green : ILSTheme.secondaryText)
                        }
                    }

                    // Co-authored by - Editable
                    if isEditing {
                        BooleanSettingsView(
                            label: "Include Co-Author",
                            value: $editedIncludeCoAuthoredBy,
                            description: "Add Claude as co-author in git commits"
                        )
                    } else {
                        LabeledContent("Include Co-Author") {
                            Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(config.includeCoAuthoredBy == true ? .green : ILSTheme.secondaryText)
                        }
                    }

                    // Validation errors display
                    if isEditing && !validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(validationErrors, id: \.self) { error in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(error)
                                        .font(ILSTheme.captionFont)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
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
                        .disabled(viewModel.isSaving || !validationErrors.isEmpty)
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
                if viewModel.config != nil {
                    Text("Scope: \(viewModel.config?.scope ?? "user") • \(viewModel.config?.path ?? "")")
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
                if let config = viewModel.config?.content {
                    let permissions = config.permissions ?? PermissionsConfig()

                    NavigationLink {
                        PermissionsEditorView(permissions: $editedPermissions)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            // Default Permission Mode
                            HStack {
                                Text("Default Mode")
                                    .foregroundColor(ILSTheme.primaryText)
                                Spacer()
                                HStack(spacing: 6) {
                                    Image(systemName: iconForPermissionMode(permissions.defaultMode ?? "prompt"))
                                        .foregroundColor(colorForPermissionMode(permissions.defaultMode ?? "prompt"))
                                    Text((permissions.defaultMode ?? "prompt").capitalized)
                                        .foregroundColor(ILSTheme.secondaryText)
                                }
                            }

                            Divider()

                            // Allowed Rules Summary
                            HStack {
                                Label("Allow Rules", systemImage: "checkmark.shield")
                                    .foregroundColor(ILSTheme.primaryText)
                                Spacer()
                                if let allowed = permissions.allow, !allowed.isEmpty {
                                    Text("\(allowed.count) rules")
                                        .foregroundColor(ILSTheme.secondaryText)
                                } else {
                                    Text("None")
                                        .foregroundColor(ILSTheme.tertiaryText)
                                }
                            }

                            Divider()

                            // Denied Rules Summary
                            HStack {
                                Label("Deny Rules", systemImage: "xmark.shield")
                                    .foregroundColor(ILSTheme.primaryText)
                                Spacer()
                                if let denied = permissions.deny, !denied.isEmpty {
                                    Text("\(denied.count) rules")
                                        .foregroundColor(ILSTheme.secondaryText)
                                } else {
                                    Text("None")
                                        .foregroundColor(ILSTheme.tertiaryText)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No permissions configured")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Tap to edit permission rules and default mode")
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
                    NavigationLink {
                        EnvironmentEditorView(environment: $editedEnvironment)
                    } label: {
                        HStack {
                            Label("Environment Variables", systemImage: "gearshape.2")
                                .foregroundColor(ILSTheme.primaryText)
                            Spacer()
                            if let env = config.env, !env.isEmpty {
                                Text("\(env.count)")
                                    .foregroundColor(ILSTheme.secondaryText)
                            } else {
                                Text("0")
                                    .foregroundColor(ILSTheme.tertiaryText)
                            }
                        }
                    }
                } else if !viewModel.isLoadingConfig {
                    Text("No advanced settings")
                        .foregroundColor(ILSTheme.secondaryText)
                }

                // Raw Config Editor Links
                NavigationLink("Edit User Settings") {
                    ConfigEditorView(scope: "user")
                }

                NavigationLink("Edit Project Settings") {
                    ConfigEditorView(scope: "project")
                }

                // Reset to Defaults Button
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset to Defaults")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } header: {
                Text("Advanced")
            } footer: {
                Text("Edit raw JSON configuration files or reset settings to defaults")
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
        .onChange(of: selectedScope) { _, newScope in
            // Cancel editing mode when switching scopes
            isEditing = false
            Task {
                await viewModel.loadConfig(scope: newScope)
                resetEditedValues()
            }
        }
        .onChange(of: isEditing) { _, _ in
            updateValidationErrors()
        }
        .onChange(of: editedModel) { _, _ in
            updateValidationErrors()
        }
        .onChange(of: editedColorScheme) { _, _ in
            updateValidationErrors()
        }
        .onChange(of: editedPermissions.defaultMode) { oldValue, newValue in
            // Check for dangerous permission change
            if let newMode = newValue, newMode == "allow", oldValue != "allow" {
                showDangerousPermissionWarning = true
            }
        }
        .alert("Dangerous Permission Change", isPresented: $showDangerousPermissionWarning) {
            Button("I Understand", role: .none) {}
            Button("Revert", role: .cancel) {
                // Revert to previous safe mode
                editedPermissions.defaultMode = previousDefaultMode
            }
        } message: {
            Text("Setting default mode to 'allow' will automatically approve all operations without prompting. This can be dangerous and may allow unintended actions. Are you sure you want to continue?")
        }
        .confirmationDialog("Reset Configuration to Defaults?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset to Defaults", role: .destructive) {
                resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all \(selectedScope) settings to their default values. This action cannot be undone.")
        }
        .alert("Configuration Reset", isPresented: $showResetSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your configuration has been reset to default values successfully.")
        }
        .alert("Reset Failed", isPresented: $showResetError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetErrorMessage)
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
            let result = await viewModel.saveConfig(
                model: editedModel,
                colorScheme: editedColorScheme,
                alwaysThinkingEnabled: editedAlwaysThinkingEnabled,
                includeCoAuthoredBy: editedIncludeCoAuthoredBy,
                permissions: editedPermissions,
                environment: editedEnvironment
            )
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

    private func resetToDefaults() {
        Task {
            let result = await viewModel.resetConfig(scope: selectedScope)
            if let error = result {
                resetErrorMessage = error
                showResetError = true
            } else {
                isEditing = false
                showResetSuccess = true
                await viewModel.loadConfig(scope: selectedScope)
                resetEditedValues()
            }
        }
    }

    // MARK: - Validation

    private func validateConfigChanges() -> [String] {
        var errors: [String] = []

        // Validate model
        if editedModel.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("Model cannot be empty")
        } else if !availableModels.contains(editedModel) {
            errors.append("Invalid model selected")
        }

        // Validate color scheme
        if !availableColorSchemes.contains(editedColorScheme) {
            errors.append("Invalid color scheme selected")
        }

        return errors
    }

    private func updateValidationErrors() {
        if isEditing {
            validationErrors = validateConfigChanges()
        } else {
            validationErrors = []
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

    private func iconForPermissionMode(_ mode: String) -> String {
        switch mode {
        case "allow":
            return "checkmark.shield.fill"
        case "deny":
            return "xmark.shield.fill"
        case "prompt":
            return "questionmark.circle.fill"
        default:
            return "shield"
        }
    }

    private func colorForPermissionMode(_ mode: String) -> Color {
        switch mode {
        case "allow":
            return .green
        case "deny":
            return .red
        case "prompt":
            return .orange
        default:
            return ILSTheme.secondaryText
        }
    }

    private func resetEditedValues() {
        // Reset edited values to current config values
        if let config = viewModel.config?.content {
            editedModel = config.model ?? "claude-sonnet-4-20250514"
            editedColorScheme = config.theme?.colorScheme ?? "system"
            editedPermissions = config.permissions ?? PermissionsConfig()
            editedAlwaysThinkingEnabled = config.alwaysThinkingEnabled ?? false
            editedIncludeCoAuthoredBy = config.includeCoAuthoredBy ?? false
            editedEnvironment = config.env ?? [:]
            // Track the initial default mode for dangerous change detection
            previousDefaultMode = editedPermissions.defaultMode ?? "prompt"
        }
        // Update selected scope from loaded config
        if let scope = viewModel.config?.scope {
            selectedScope = scope
        }
    }
}

struct ConfigEditorView: View {
    let scope: String
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

    private let client = APIClient()

    func loadAll() async {
        async let statsTask: () = loadStats()
        async let configTask: () = loadConfig()
        _ = await (statsTask, configTask)
    }

    func loadStats() async {
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
        isTestingConnection = true
        defer { isTestingConnection = false }

        do {
            _ = try await client.healthCheck()
        } catch {
            self.error = error
        }
    }

    func saveConfig(model: String, colorScheme: String, alwaysThinkingEnabled: Bool, includeCoAuthoredBy: Bool, permissions: PermissionsConfig, environment: [String: String]) async -> String? {
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

        // Update boolean fields
        currentConfig.alwaysThinkingEnabled = alwaysThinkingEnabled
        currentConfig.includeCoAuthoredBy = includeCoAuthoredBy

        // Update permissions
        currentConfig.permissions = permissions

        // Update environment variables
        currentConfig.env = environment.isEmpty ? nil : environment

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

    func resetConfig(scope: String) async -> String? {
        isSaving = true
        defer { isSaving = false }

        do {
            let response: APIResponse<ConfigInfo> = try await client.delete("/config?scope=\(scope)")

            // Update local config with response
            if let updatedConfig = response.data {
                config = updatedConfig

                // Check for validation errors
                if !updatedConfig.isValid {
                    return updatedConfig.errors?.joined(separator: "\n") ?? "Configuration reset failed"
                }
            }

            return nil // Success
        } catch {
            return "Failed to reset: \(error.localizedDescription)"
        }
    }
}

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var configJson = ""
    @Published var isLoading = false
    @Published var error: Error?

    private let client = APIClient()

    func loadConfig(scope: String) async {
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
