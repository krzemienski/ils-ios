import SwiftUI
import ILSShared

// MARK: - ServerSetupSheet

/// Root sheet for onboarding. Wraps OnboardingView with a NavigationStack
/// to enable drill-down into QuickConnect or SSHSetup paths.
struct ServerSetupSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        NavigationStack {
            OnboardingView()
                .navigationTitle("Welcome")
                #if os(iOS)
                .inlineNavigationBarTitle()
                #endif
        }
        .interactiveDismissDisabled(true)
    }
}
