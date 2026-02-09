import SwiftUI
import ILSShared

// MARK: - ServerSetupSheet

/// Root sheet for onboarding. Wraps OnboardingView with a NavigationStack
/// to enable drill-down into QuickConnect or SSHSetup paths.
struct ServerSetupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme

    var body: some View {
        NavigationStack {
            OnboardingView()
                .navigationTitle("Welcome")
                .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(true)
    }
}
