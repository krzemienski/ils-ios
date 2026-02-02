import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var serverHost: String = "localhost"
    @State private var serverPort: String = "8080"

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

                Button("Test Connection") {
                    let url = "http://\(serverHost):\(serverPort)"
                    appState.serverURL = url
                    appState.checkConnection()
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
                    // Default Model
                    LabeledContent("Default Model") {
                        Text(config.model ?? "claude-sonnet-4-20250514")
                            .foregroundColor(ILSTheme.secondaryText)
                    }

                    // Theme Color Scheme
                    if let theme = config.theme {
                        LabeledContent("Color Scheme") {
                            Text(theme.colorScheme?.capitalized ?? "System")
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    // Auto Updates Channel
                    if let channel = config.autoUpdatesChannel {
                        LabeledContent("Updates Channel") {
                            Text(channel.capitalized)
                                .foregroundColor(ILSTheme.secondaryText)
                        }
                    }

                    // Always Thinking
                    LabeledContent("Extended Thinking") {
                        Image(systemName: config.alwaysThinkingEnabled == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.alwaysThinkingEnabled == true ? .green : ILSTheme.secondaryText)
                    }

                    // Co-authored by
                    LabeledContent("Include Co-Author") {
                        Image(systemName: config.includeCoAuthoredBy == true ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.includeCoAuthoredBy == true ? .green : ILSTheme.secondaryText)
                    }
                } else {
                    Text("No configuration loaded")
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } header: {
                Text("General")
            } footer: {
                if viewModel.config != nil {
                    Text("Scope: \(viewModel.config?.scope ?? "user") • \(viewModel.config?.path ?? "")")
                }
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
        .navigationTitle("Settings")
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            parseServerURL()
            await viewModel.loadAll()
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
