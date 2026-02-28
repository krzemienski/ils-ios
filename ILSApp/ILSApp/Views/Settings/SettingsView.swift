import SwiftUI
import ILSShared

/// Root settings screen that acts as the hub for all app configuration.
///
/// Composes four delegated sub-section views — connection, appearance, config, and about —
/// each responsible for a distinct settings domain. The view owns server URL state with
/// whitespace trimming before persistence, and synchronises the color scheme preference
/// between the remote config and the local `@State` on every load. Supports pull-to-refresh
/// via `.refreshable` to reload all settings from the backend.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - View model loading and persisting all settings data
/// - ``serverURL`` - Editable server URL string, trimmed before saving
/// - ``colorSchemePreference`` - Currently selected color scheme ("system", "light", or "dark")
///
/// ### View Components
/// - ``connectionSection`` - Server URL entry and connection testing
/// - ``remoteAccessSection`` - Remote/tunnel access configuration
/// - ``configSection`` - Model selection and appearance preferences
/// - ``statisticsSection`` - Usage statistics display
///
/// ### Server URL Management
/// - ``saveServerSettings()`` - Trim and persist the current server URL to AppState
/// - ``testConnection()`` - Save settings then trigger a connectivity test
///
/// ### Color Scheme
/// - ``syncColorScheme()`` - Pull the saved color scheme from remote config into local state
struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    /// View model responsible for loading, caching, and saving all settings data.
    @State private var viewModel = SettingsViewModel()
    /// The server URL string currently shown in the connection section; trimmed before saving.
    @State private var serverURL: String = ""
    /// The user's preferred color scheme, kept in sync with the remote config on load.
    @State private var colorSchemePreference: String = "system"
    @State private var showDeleteConfirmation: Bool = false
    // isDeleting and deleteResult moved to SettingsViewModel

    private let availableColorSchemes = ["system", "light", "dark"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingLG) {
                connectionSection

                remoteAccessSection

                SettingsAppearanceSection()

                configSection

                statisticsSection

                dataPrivacySection

                SettingsAboutSection(
                    viewModel: viewModel,
                    serverURL: serverURL
                )
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Settings")
        .inlineNavigationBarTitle()
        .screenshotProtected()
        .refreshable {
            #if os(iOS)
            HapticManager.impact(.light)
            #endif
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            serverURL = appState.serverURL
            await viewModel.loadAll()
            syncColorScheme()
        }
        .onChange(of: colorSchemePreference) { _, newValue in
            saveColorScheme(newValue)
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            serverURL = appState.serverURL
            Task { await viewModel.loadAll() }
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected {
                Task { await viewModel.loadAll() }
            }
        }
    }

    // MARK: - Section Wrappers

    private var connectionSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings
        )
    }

    private var remoteAccessSection: some View {
        SettingsConnectionSection(
            viewModel: viewModel,
            serverURL: $serverURL,
            onTestConnection: testConnection,
            onSaveServerSettings: saveServerSettings
        ).remoteAccessSection
    }

    private var configSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: ClaudeModel.allModelIDs,
            availableColorSchemes: availableColorSchemes,
            formatModelName: ClaudeModel.displayNameForID
        )
    }

    private var statisticsSection: some View {
        SettingsConfigSection(
            viewModel: viewModel,
            colorSchemePreference: $colorSchemePreference,
            availableModels: ClaudeModel.allModelIDs,
            availableColorSchemes: availableColorSchemes,
            formatModelName: ClaudeModel.displayNameForID
        ).statisticsSection
    }

    private var dataPrivacySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("DATA & PRIVACY")
                .font(.system(size: theme.fontCaption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, theme.spacingXS)

            VStack(spacing: 0) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(theme.error)
                        Text("Delete All My Data")
                            .foregroundStyle(theme.error)
                        Spacer()
                        if viewModel.isDeleting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(theme.spacingMD)
                }
                .disabled(viewModel.isDeleting)

                if let result = viewModel.deleteResult {
                    Divider().background(theme.borderSubtle)
                    Text(result)
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textSecondary)
                        .padding(theme.spacingMD)
                }
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text("Permanently deletes all sessions, messages, projects, themes, host profiles, and cached data from the server.")
                .font(.system(size: theme.fontCaption))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, theme.spacingXS)
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await viewModel.performDataDeletion() }
            }
        } message: {
            Text("This will permanently delete all your sessions, messages, projects, themes, and cached data. This action cannot be undone.")
        }
    }

    // performDataDeletion() moved to SettingsViewModel

    // MARK: - Server URL Management

    /// Trims whitespace from ``serverURL`` and persists it to ``AppState`` if non-empty.
    private func saveServerSettings() {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.updateServerURL(trimmed)
    }

    /// Saves the current server URL then asynchronously tests the connection via the view model.
    private func testConnection() {
        viewModel.saveAndTestConnection(url: serverURL, appState: appState)
    }

    // MARK: - Color Scheme

    /// Pulls the color scheme stored in the remote config into ``colorSchemePreference``,
    /// defaulting to `"system"` when no preference has been saved.
    private func syncColorScheme() {
        if let config = viewModel.config?.content {
            colorSchemePreference = config.theme?.colorScheme ?? "system"
        }
    }

    /// Persists the given color scheme to the remote config and refreshes the local config cache.
    /// - Parameter scheme: One of `"system"`, `"light"`, or `"dark"`.
    private func saveColorScheme(_ scheme: String) {
        guard let config = viewModel.config?.content else { return }
        Task {
            _ = await viewModel.saveConfig(
                model: config.model ?? SettingsViewModel.defaultModelID,
                colorScheme: scheme
            )
            await viewModel.loadConfig()
        }
    }

    // MARK: - Helpers
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppState())
    }
}
