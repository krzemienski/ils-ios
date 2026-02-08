import SwiftUI
import ILSShared

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.theme) var theme: any AppTheme
    @StateObject var viewModel = SettingsViewModel()
    @State var serverURL: String = ""
    @AppStorage("colorScheme") var colorSchemePreference: String = "dark"

    let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-haiku-3-5-20241022"
    ]

    let availableColorSchemes = ["system", "light", "dark"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                connectionSection
                remoteAccessSection
                appearanceSection
                generalSettingsSection
                apiKeySection
                permissionsSection
                advancedSection
                statisticsSection
                diagnosticsSection
                aboutSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Settings")
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            loadServerSettings()
            await viewModel.loadAll()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
            .environment(\.theme, ObsidianTheme())
    }
}
