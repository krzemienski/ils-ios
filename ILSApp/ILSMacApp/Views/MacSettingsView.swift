import SwiftUI
import ILSShared

// MARK: - Settings Tab

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case connection = "Connection"
    case advanced = "Advanced"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .connection: return "network"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Mac Settings View

struct MacSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme: any AppTheme
    @StateObject var viewModel = SettingsViewModel()

    @State private var selectedTab: SettingsTab = .general
    @State var serverURL: String = ""
    @AppStorage("colorScheme") var colorSchemePreference: String = "dark"
    @AppStorage("defaultModel") var defaultModel: String = "claude-sonnet-4-20250514"
    @AppStorage("enableAgentTeams") var enableAgentTeams: Bool = false
    @AppStorage("enableDebugMode") var enableDebugMode: Bool = false

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
                    case .connection:
                        connectionSettings
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
                    Picker("Default Model", selection: $defaultModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(formatModelName(model)).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                Divider()

                settingRow(label: "Agent Teams") {
                    Toggle("", isOn: $enableAgentTeams)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Text("Enable experimental multi-agent collaboration features")
                    .font(.system(size: theme.fontCaption))
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
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(theme.spacingMD)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            // Theme Preview
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("Preview")
                    .font(.system(size: theme.fontCaption, weight: .semibold))
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
                            .font(.system(size: theme.fontBody))
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
                        .font(.system(size: theme.fontBody, weight: .semibold))
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
                        statItem("Sessions", value: "\(stats.sessions)")
                        statItem("Projects", value: "\(stats.projects)")
                        statItem("Skills", value: "\(stats.skills)")
                        statItem("MCP Servers", value: "\(stats.mcpServers)")
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
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)

                Divider()

                settingRow(label: "Cache") {
                    Button("Clear Cache") {
                        Task {
                            // Clear cache implementation
                        }
                    }
                }

                Text("Remove cached data and force refresh")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)

                Divider()

                settingRow(label: "Reset") {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundStyle(theme.error)
                }

                Text("Restore all settings to their default values")
                    .font(.system(size: theme.fontCaption))
                    .foregroundStyle(theme.textSecondary)
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
                    .font(.system(size: 64))
                    .foregroundStyle(theme.accent)

                VStack(spacing: theme.spacingSM) {
                    Text("ILS for macOS")
                        .font(.system(size: theme.fontTitle2, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Version 1.0.0 (Build 1)")
                        .font(.system(size: theme.fontBody))
                        .foregroundStyle(theme.textSecondary)
                }

                Divider()
                    .frame(width: 200)

                VStack(spacing: theme.spacingXS) {
                    Text("Intelligent Learning System")
                        .font(.system(size: theme.fontBody, weight: .medium))
                        .foregroundStyle(theme.textPrimary)

                    Text("Native macOS application for managing Claude Code sessions")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: theme.spacingLG) {
                    Link(destination: URL(string: "https://github.com/krzemienski/ils-ios")!) {
                        Label("GitHub", systemImage: "link")
                            .font(.system(size: theme.fontCaption))
                    }

                    Link(destination: URL(string: "https://github.com/anthropics/claude-code")!) {
                        Label("Claude Code Docs", systemImage: "book")
                            .font(.system(size: theme.fontCaption))
                    }

                    Link(destination: URL(string: "https://krzemienski.github.io/ils-ios/privacy")!) {
                        Label("Privacy", systemImage: "hand.raised")
                            .font(.system(size: theme.fontCaption))
                    }

                    Link(destination: URL(string: "https://krzemienski.github.io/ils-ios/support")!) {
                        Label("Support", systemImage: "questionmark.circle")
                            .font(.system(size: theme.fontCaption))
                    }
                }

                Divider()
                    .frame(width: 200)

                Text("© 2026 ILS. All rights reserved.")
                    .font(.system(size: theme.fontCaption))
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
            .font(.system(size: theme.fontTitle2, weight: .bold))
            .foregroundStyle(theme.textPrimary)
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: theme.spacingMD) {
            Text(label)
                .font(.system(size: theme.fontBody))
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
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: .monospaced))
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
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textSecondary)
        }
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
        serverURL = "http://localhost:9999"
        themeManager.setTheme("obsidian")
    }

    func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "Claude Sonnet" }
        if model.contains("opus") { return "Claude Opus" }
        if model.contains("haiku") { return "Claude Haiku" }
        return model
    }
}

#Preview {
    MacSettingsView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environment(\.theme, ObsidianTheme())
}
