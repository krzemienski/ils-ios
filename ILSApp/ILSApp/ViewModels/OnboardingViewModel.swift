import Foundation
import Observation

/// Represents each step in the onboarding wizard.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case connect
    case tour
    case complete
}

/// Central state coordinator for the interactive onboarding setup wizard.
///
/// Tracks the user's position in the wizard, whether they skipped, and persists
/// onboarding completion state to UserDefaults. Exposes computed properties for
/// conditional UI rendering throughout the app.
@Observable
@MainActor
class OnboardingViewModel {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let onboardingCompletionDate = "onboardingCompletionDate"
        static let featureTourCompleted = "featureTourCompleted"
        static let onboardingSkipped = "onboardingSkipped"
    }

    // MARK: - Wizard State

    /// The current visible step in the wizard.
    var currentStep: OnboardingStep = .welcome

    /// Whether the user chose to skip the full onboarding flow.
    var didSkip: Bool = false

    // MARK: - Persisted State

    /// The date the user completed onboarding. `nil` if not yet completed.
    private(set) var onboardingCompletionDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.onboardingCompletionDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.onboardingCompletionDate)
        }
    }

    /// Whether the user has finished the feature tour.
    private(set) var featureTourCompleted: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.featureTourCompleted)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.featureTourCompleted)
        }
    }

    // MARK: - Computed Properties

    /// True once the user has completed or skipped onboarding.
    var isOnboardingComplete: Bool {
        onboardingCompletionDate != nil
    }

    /// True once the feature tour has been completed.
    var hasCompletedTour: Bool {
        featureTourCompleted
    }

    /// True when contextual feature tips should be surfaced — within the first 7 days
    /// of completing onboarding and only if the tour was not completed.
    var shouldShowFeatureTour: Bool {
        guard let completionDate = onboardingCompletionDate else { return false }
        let daysSinceCompletion = Calendar.current.dateComponents(
            [.day],
            from: completionDate,
            to: Date()
        ).day ?? 0
        return !featureTourCompleted && daysSinceCompletion < 7
    }

    // MARK: - Navigation

    /// Advance to the next wizard step.
    func advance() {
        let allSteps = OnboardingStep.allCases
        let currentIndex = allSteps.firstIndex(of: currentStep) ?? 0
        let nextIndex = currentIndex + 1
        if nextIndex < allSteps.count {
            currentStep = allSteps[nextIndex]
        }
    }

    /// Go back to the previous wizard step.
    func goBack() {
        let allSteps = OnboardingStep.allCases
        let currentIndex = allSteps.firstIndex(of: currentStep) ?? 0
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            currentStep = allSteps[previousIndex]
        }
    }

    /// Jump directly to a specific step.
    func goTo(_ step: OnboardingStep) {
        currentStep = step
    }

    // MARK: - Completion Actions

    /// Mark onboarding as complete (e.g. after finishing the tour or connecting).
    func completeOnboarding() {
        onboardingCompletionDate = Date()
        currentStep = .complete
        didSkip = false
    }

    /// Skip onboarding — records a completion date so it won't re-show, marks skipped.
    func skipOnboarding() {
        didSkip = true
        onboardingCompletionDate = Date()
        UserDefaults.standard.set(true, forKey: Keys.onboardingSkipped)
    }

    /// Mark the feature tour as completed.
    func completeFeatureTour() {
        featureTourCompleted = true
    }

    /// Reset all onboarding state (useful for debugging / re-running onboarding).
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Keys.onboardingCompletionDate)
        UserDefaults.standard.removeObject(forKey: Keys.featureTourCompleted)
        UserDefaults.standard.removeObject(forKey: Keys.onboardingSkipped)
        currentStep = .welcome
        didSkip = false
    }
}
