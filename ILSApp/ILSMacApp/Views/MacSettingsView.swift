import SwiftUI
import ILSShared

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case approvalPolicies = "Guardrails"
    case connection = "Connection"
    case backend = "Backend"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .approvalPolicies: return "shield.lefthalf.filled"
        case .connection: return "network"
        case .backend: return "server.rack"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Mac Settings View

struct MacSettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.theme) var theme: ThemeSnapshot
    @State private var viewModel = SettingsViewModel()

    @State private var selectedTab: SettingsTab = .general
    @State private var serverURL: String = ""
    @AppStorage("colorScheme") var colorSchemePreference: String = "dark"
    @AppStorage("defaultModel") var defaultModel: String = "claude-sonnet-4-20250514"
    @AppStorage("enableAgentTeams") var enableAgentTeams: Bool = false
    @AppStorage("enableDebugMode") var enableDebugMode: Bool = false
    @AppStorage("showSessionSuggestions") var showSessionSuggestions: Bool = true
    @AppStorage("showPromptSuggestions") var showPromptSuggestions: Bool = true

    private let syncManager = ICloudSyncManager.shared

    let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
    ]

    let availableColorSchemes = ["system", "light", "dark"]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar with tabs
            settingsSidebar
                .frame(width: 200)
                .background(theme.bgSidebar)

            Divider()

            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingLG) {
                    switch selectedTab {
                    case .general:
                        generalSettings
                    case .appearance:
                        appearanceSettings
                    case .approvalPolicies:
                        ApprovalPoliciesView()
                    case .connection:
                        connectionSettings
                    case .backend:
                        MacBackendSettingsView()
                    case .advanced:
                        advancedSettings
                    case .about:
                        aboutSettings
                    }
                }
                .padding(theme.spacingXL)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.bgPrimary)
        }
        .navigationTitle("Settings")
        .frame(minWidth: 600, minHeight: 400)
        .task {
            viewModel.configure(client: appState.apiClient)
            loadServerSettings()
            await viewModel.loadAll()
        }
    }

    // MARK: - Settings Sidebar

    @ViewBuilder
    private var settingsSidebar: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - General Settings

    @ViewBuilder
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {
            sectionHeader("General Settings")

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                settingRow(label: "Default Model") {
                    Picker("Default Model", selection: Binding(
                        get: {
                            viewModel.effectiveConfig?.config.model ?? viewModel.config?.content.model ?? defaultModel
                        },
                        set: { newModel in
                            defaultModel = newModel  // Keep local fallback in sync
                            viewModel.updateModel(newModel)
                        }
                    )) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(ClaudeModel.displayNameForID(model)).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack(spacing: theme.spacingSM) {
                    InheritanceBadge(isInherited: viewModel.isInherited(key: "model"))
                    Spacer()
                    SettingsInfoButton(text: "The Claude model used for new conversations and chat sessions. When set to 'inherited', the model configured in your host's Claude CLI settings (via `claude config set model`) is used automatically. Override this locally to use a different model on this device.")
                }

                Divider()

                settingRow(label: "Agent Teams") {
                    Toggle("", isOn: $enableAgentTeams)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Enable experimental multi-agent collaboration features")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    InheritanceBadge(isInherited: false)
                    Spacer()
                    SettingsInfoButton(text: "Experimental feature that enables coordination of multiple AI agents working together on complex tasks. Agent Teams is a local-only setting stored on your device and is not synced with your host CLI configuration.")
                }

                Divider()

                settingRow(label: "Session Suggestions") {
                    Toggle("", isOn: $showSessionSuggestions)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Show smart suggestions when starting a new session")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Divider()

                settingRow(label: "Prompt Suggestions") {
                    Toggle("", isOn: $showPromptSuggestions)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Display contextual prompt chips above the chat input")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    // MARK: - Appearance Settings

    @ViewBuilder
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {
            sectionHeader("Appearance")

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                settingRow(label: "Theme") {
                    Picker("Theme", selection: Binding(
                        get: { themeManager.currentTheme.id },
                        set: { themeManager.setTheme($0) }
                    )) {
                        ForEach(themeManager.availableThemes, id: \.id) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack(spacing: theme.spacingSM) {
                    Spacer()
                    SettingsInfoButton(text: "Selects the visual theme for the ILS app interface. Themes control colors, typography, spacing, and corner radius throughout the app. This is a local preference stored on your device and is separate from the Claude CLI color scheme setting.")
                }

                Divider()

                settingRow(label: "Color Scheme") {
                    Picker("Color Scheme", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }

                Text("Choose how the app appears")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    InheritanceBadge(isInherited: viewModel.isInherited(key: "theme"))
                    Spacer()
                    SettingsInfoButton(text: "Controls whether the app uses light mode, dark mode, or follows your device's system appearance setting. When inherited, the color scheme configured in your host's Claude CLI theme settings is applied. Override locally to customize appearance on this device.")
                }
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            // Theme Preview
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Preview")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingMD) {
                    colorSwatch("Primary", color: theme.accent)
                    colorSwatch("Success", color: theme.success)
                    colorSwatch("Warning", color: theme.warning)
                    colorSwatch("Error", color: theme.error)
                }
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    // MARK: - Connection Settings

    @ViewBuilder
    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {
            sectionHeader("Server Connection")

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                settingRow(label: "Server URL") {
                    HStack(spacing: theme.spacingSM) {
                        TextField("http://localhost:9999", text: $serverURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)

                        Button("Test") {
                            testConnection()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Divider()

                settingRow(label: "Status") {
                    HStack(spacing: theme.spacingSM) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(appState.isConnected ? theme.success : theme.error)
                    }
                }
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            if let stats = viewModel.stats {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    Text("Server Statistics")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: theme.spacingMD
                    ) {
                        statItem("Sessions", value: "\(stats.sessions.total)")
                        statItem("Projects", value: "\(stats.projects.total)")
                        statItem("Skills", value: "\(stats.skills.total)")
                        statItem("MCP Servers", value: "\(stats.mcpServers.total)")
                    }
                }
                .padding(theme.spacingMD)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            }
        }
    }

    // MARK: - Advanced Settings

    @ViewBuilder
    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {
            sectionHeader("Advanced Settings")

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                settingRow(label: "Debug Mode") {
                    Toggle("", isOn: $enableDebugMode)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Enable verbose logging for troubleshooting")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    InheritanceBadge(isInherited: false)
                    Spacer()
                    SettingsInfoButton(text: "Enables verbose debug logging for troubleshooting connection issues, API errors, and unexpected behavior. Debug logs appear in the system console and can help diagnose problems with your ILS backend or Claude Code sessions.")
                }

                Divider()

                settingRow(label: "Cache") {
                    Button("Clear Cache") {
                        Task {
                            // Clear cache implementation
                        }
                    }
                }

                Text("Remove cached data and force refresh")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    Spacer()
                    SettingsInfoButton(text: "Removes all locally cached API responses, forcing the app to fetch fresh data from the backend on next load. Use this if you notice stale session lists, outdated config values, or display inconsistencies after backend changes.")
                }

                Divider()

                settingRow(label: "Reset") {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundStyle(theme.error)
                }

                Text("Restore all settings to their default values")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    Spacer()
                    SettingsInfoButton(text: "Restores all local macOS app settings to their factory default values, including the default model, color scheme, theme, and experimental feature flags. This does not affect your host CLI configuration or backend data.")
                }
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            // MARK: iCloud Sync

            VStack(alignment: .leading, spacing: theme.spacingMD) {
                settingRow(label: "iCloud Sync") {
                    Toggle("", isOn: Binding(
                        get: { syncManager.isSyncEnabled },
                        set: { syncManager.setSyncEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                Text("Sync preferences and settings across all your Apple devices")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: theme.spacingSM) {
                    InheritanceBadge(isInherited: false)
                    Spacer()
                    SettingsInfoButton(text: "When enabled, preferences such as server URL, default model, color scheme, and notification settings are synced via iCloud to all your Apple devices signed in to the same iCloud account. Disabling sync on this device will not affect other devices.")
                }

                Divider()

                settingRow(label: "Sync Status") {
                    HStack(spacing: theme.spacingSM) {
                        Circle()
                            .fill(iCloudStatusColor)
                            .frame(width: 8, height: 8)
                        Text(iCloudStatusLabel)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(iCloudStatusColor)
                    }
                }

                settingRow(label: "Last Synced") {
                    Text(iCloudLastSyncText)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                if syncManager.isSyncEnabled {
                    Divider()

                    settingRow(label: "Sync Now") {
                        Button("Sync Now") {
                            syncManager.syncPreferencesToCloud()
                        }
                        .disabled(syncManager.syncStatus == .syncing)
                    }
                }
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    // MARK: - About Settings

    @ViewBuilder
    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: theme.spacingLG) {
            sectionHeader("About ILS")

            VStack(spacing: theme.spacingLG) {
                // App Icon
                Image(systemName: "cube.fill")
                    .font(.system(size: 64, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)

                VStack(spacing: theme.spacingSM) {
                    Text("ILS for macOS")
                        .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("Version 1.0.0 (Build 1)")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider()
                    .frame(width: 200)

                VStack(spacing: theme.spacingXS) {
                    Text("Intelligent Learning System")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text("Native macOS application for managing Claude Code sessions")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: theme.spacingLG) {
                    Link(destination: URL(string: "https://github.com/krzemienski/ils-ios")!) {
                        Label("GitHub", systemImage: "link")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }

                    Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                        Label("Claude Code Docs", systemImage: "book")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }

                    Link(destination: URL(string: "https://krzemienski.github.io/ils-ios/privacy")!) {
                        Label("Privacy", systemImage: "hand.raised")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }

                    Link(destination: URL(string: "https://krzemienski.github.io/ils-ios/support")!) {
                        Label("Support", systemImage: "questionmark.circle")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                }

                Divider()
                    .frame(width: 200)

                Text("© 2026 ILS. All rights reserved.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingXL)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: theme.spacingMD) {
            Text(label)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 140, alignment: .trailing)

            content()

            Spacer()
        }
    }

    @ViewBuilder
    private func statItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    @ViewBuilder
    private func colorSwatch(_ label: String, color: Color) -> some View {
        VStack(spacing: theme.spacingXS) {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(color)
                .frame(width: 60, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.textTertiary.opacity(0.2), lineWidth: 1)
                )

            Text(label)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - iCloud Sync Helpers

    private var iCloudStatusLabel: String {
        switch syncManager.syncStatus {
        case .idle:     return syncManager.isSyncEnabled ? "Up to Date" : "Disabled"
        case .syncing:  return "Syncing…"
        case .error:    return "Error"
        case .disabled: return "Disabled"
        }
    }

    private var iCloudStatusColor: Color {
        switch syncManager.syncStatus {
        case .idle:     return syncManager.isSyncEnabled ? theme.success : theme.textTertiary
        case .syncing:  return theme.accent
        case .error:    return theme.error
        case .disabled: return theme.textTertiary
        }
    }

    private var iCloudLastSyncText: String {
        guard let date = syncManager.lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Actions

    func loadServerSettings() {
        serverURL = appState.serverURL
    }

    func saveServerSettings() {
        guard !serverURL.isEmpty else { return }
        appState.updateServerURL(serverURL)
    }

    func testConnection() {
        Task {
            guard !serverURL.isEmpty, URL(string: serverURL) != nil else { return }
            appState.updateServerURL(serverURL)
            await viewModel.testConnection()
            if appState.isConnected {
                saveServerSettings()
            }
        }
    }

    func resetToDefaults() {
        colorSchemePreference = "dark"
        defaultModel = "claude-sonnet-4-20250514"
        enableAgentTeams = false
        enableDebugMode = false
        showSessionSuggestions = true
        showPromptSuggestions = true
        serverURL = "http://localhost:9999"
        themeManager.setTheme("obsidian")
    }

}

#Preview {
    MacSettingsView()
        .environment(AppState())
        .environment(ThemeManager())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
