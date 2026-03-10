import SwiftUI
import ILSShared

// MARK: - ServerSetupSheet

/// Root sheet for onboarding. Presents OnboardingWizardView which manages
/// the complete multi-step onboarding flow including welcome carousel,
/// connection setup, feature tour, and first session creation.
// TODO: UXF-002 — Add retry button and diagnostic info when initial server connection fails
struct ServerSetupSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        OnboardingWizardView {
            appState.showOnboarding = false
        }
        .interactiveDismissDisabled(true)
    }
}
