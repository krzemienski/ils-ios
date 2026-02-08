import SwiftUI
import ILSShared

// MARK: - Settings View Sections (Coordinator)

extension SettingsView {

    // MARK: - Connection Section

    @ViewBuilder
    var connectionSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings
        )
    }

    // MARK: - Remote Access

    @ViewBuilder
    var remoteAccessSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings
        )
        .remoteAccessSection
    }

    // MARK: - Appearance

    @ViewBuilder
    var appearanceSection: some View {
        SettingsAppearanceSection()
    }

    // MARK: - General Settings

    @ViewBuilder
    var generalSettingsSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: availableModels,
            availableColorSchemes: availableColorSchemes,
            formatModelName: formatModelName
        )
        .generalSettingsSection
    }

    // MARK: - API Key

    @ViewBuilder
    var apiKeySection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: availableModels,
            availableColorSchemes: availableColorSchemes,
            formatModelName: formatModelName
        )
        .apiKeySection
    }

    // MARK: - Permissions

    @ViewBuilder
    var permissionsSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: availableModels,
            availableColorSchemes: availableColorSchemes,
            formatModelName: formatModelName
        )
        .permissionsSection
    }

    // MARK: - Advanced

    @ViewBuilder
    var advancedSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: availableModels,
            availableColorSchemes: availableColorSchemes,
            formatModelName: formatModelName
        )
        .advancedSection
    }

    // MARK: - Statistics

    @ViewBuilder
    var statisticsSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: availableModels,
            availableColorSchemes: availableColorSchemes,
            formatModelName: formatModelName
        )
        .statisticsSection
    }

    // MARK: - Diagnostics

    @ViewBuilder
    var diagnosticsSection: some View {
        SettingsAboutSection(
            viewModel: viewModel,
            serverURL: serverURL
        )
        .diagnosticsSection
    }

    // MARK: - About

    @ViewBuilder
    var aboutSection: some View {
        SettingsAboutSection(
            viewModel: viewModel,
            serverURL: serverURL
        )
        .aboutSection
    }

    // MARK: - Server Settings

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
            if appState.isConnected { saveServerSettings() }
        }
    }

    // MARK: - Helpers

    func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "Claude Sonnet" }
        if model.contains("opus") { return "Claude Opus" }
        if model.contains("haiku") { return "Claude Haiku" }
        return model
    }
}
