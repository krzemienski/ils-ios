import SwiftUI
import ILSShared

/// Main wizard container that orchestrates the entire onboarding flow.
///
/// Manages four steps — ``OnboardingStep/welcome``, ``OnboardingStep/connect``,
/// ``OnboardingStep/tour``, and ``OnboardingStep/complete`` — with asymmetric slide
/// transitions between in-line steps and modal sheet presentation for the tour and
/// first-session wizard.
///
/// ## Flow
/// 1. **welcome** — ``WelcomeCarouselView`` with animated feature slides.
/// 2. **connect** — ``OnboardingView`` (Quick Connect / SSH Setup path picker) inside a
///    ``NavigationStack`` that enables drill-down to ``QuickConnectView`` or ``SSHSetupView``.
/// 3. **tour** — ``FeatureTourView`` presented as a sheet on top of the connect step.
/// 4. **complete** — ``FirstSessionWizardView`` presented as a sheet; dismissal calls `onComplete`.
///
/// ## Step Transitions
/// New steps slide in from the trailing edge; old steps exit to the leading edge.
/// Users who have enabled Reduce Motion see no animation.
///
/// ## Skip
/// A Skip toolbar button is always visible during the welcome and connect steps and
/// immediately calls `onComplete` after recording the skip in ``OnboardingViewModel``.
///
/// ## Completion Detection
/// Successful backend connection is detected via `appState.isConnected` changing to
/// `true` while the wizard is on the connect step.
struct OnboardingWizardView: View {

    // MARK: - Input

    /// Called when onboarding is fully finished or skipped, allowing the parent to
    /// dismiss this wizard and show the main app UI.
    var onComplete: () -> Void

    // MARK: - Environment

    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var viewModel = OnboardingViewModel()
    @State private var showFeatureTourSheet = false
    @State private var showFirstSessionSheet = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgPrimary
                    .ignoresSafeArea()

                stepContent
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.35),
                        value: viewModel.currentStep
                    )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { skipToolbarItem }
        }
        // Feature tour sheet — on dismiss, chain to first session wizard.
        .sheet(isPresented: $showFeatureTourSheet, onDismiss: {
            showFirstSessionSheet = true
        }) {
            FeatureTourView {
                viewModel.completeFeatureTour()
                showFeatureTourSheet = false
            }
        }
        // First session wizard sheet — on dismiss (any path), complete onboarding.
        .sheet(isPresented: $showFirstSessionSheet, onDismiss: {
            viewModel.completeOnboarding()
            onComplete()
        }) {
            FirstSessionWizardView(
                onboardingViewModel: viewModel,
                onStart: { _, _ in }
            )
        }
        // Advance the wizard when a backend connection is established.
        .onChange(of: appState.isConnected) { _, isConnected in
            guard isConnected, viewModel.currentStep == .connect else { return }
            advanceFromConnect()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeCarouselView(
                onGetStarted: { advanceToConnect() },
                onSkip: { skip() }
            )
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            ))

        case .connect, .tour, .complete:
            OnboardingView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var skipToolbarItem: some ToolbarContent {
        if viewModel.currentStep == .welcome || viewModel.currentStep == .connect {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Skip") {
                    skip()
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .accessibilityLabel("Skip onboarding setup")
            }
        }
    }

    // MARK: - Navigation Actions

    private func advanceToConnect() {
        HapticManager.impact(.medium)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            viewModel.goTo(.connect)
        }
    }

    private func advanceFromConnect() {
        if viewModel.hasCompletedTour {
            viewModel.goTo(.complete)
            showFirstSessionSheet = true
        } else {
            viewModel.goTo(.tour)
            showFeatureTourSheet = true
        }
    }

    private func skip() {
        HapticManager.selection()
        viewModel.skipOnboarding()
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    OnboardingWizardView { }
        .environment(AppState())
}
