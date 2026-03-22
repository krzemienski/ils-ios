import SwiftUI
import ILSShared

// MARK: - Onboarding Template

/// A predefined starting point presented in the first-session wizard.
struct OnboardingTemplate: Identifiable {
    let id: String
    let icon: String
    let name: String
    let description: String
}

extension OnboardingTemplate {
    static let all: [OnboardingTemplate] = [
        OnboardingTemplate(
            id: "blank",
            icon: "bubble.left.and.text.bubble.right",
            name: "Blank Chat",
            description: "Start a fresh conversation"
        ),
        OnboardingTemplate(
            id: "code-review",
            icon: "doc.text.magnifyingglass",
            name: "Code Review",
            description: "Review code in a project"
        ),
        OnboardingTemplate(
            id: "debug",
            icon: "ant.fill",
            name: "Debug Session",
            description: "Fix bugs and errors"
        ),
        OnboardingTemplate(
            id: "architecture",
            icon: "building.columns",
            name: "Architecture Planning",
            description: "Design a new feature"
        ),
    ]
}

// MARK: - Wizard Step

private enum FirstSessionStep: CaseIterable {
    case template
    case project
}

// MARK: - FirstSessionWizardView

/// Two-step wizard presented as a sheet after onboarding completes (first successful connection only).
///
/// **Step 1** — Pick a session template: Blank Chat, Code Review, Debug Session, or Architecture Planning.
/// **Step 2** — Optionally pick a project from the fetched project list.
///
/// Shows a **Start Session** CTA and a **Skip for now** option. On completion, calls
/// `onStart(templateName:projectPath:)` so the parent can trigger session creation.
/// Calls `onboardingViewModel.markFirstSessionWizardShown()` on appear.
struct FirstSessionWizardView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onboardingViewModel: OnboardingViewModel
    var onStart: (_ templateName: String, _ projectPath: String?) -> Void

    @State private var currentStep: FirstSessionStep = .template
    @State private var selectedTemplate: OnboardingTemplate = OnboardingTemplate.all[0]
    @State private var selectedProject: Project?
    @State private var projectsViewModel = ProjectsViewModel()
    @State private var isAnimatingIn = false

    var body: some View {
        VStack(spacing: 0) {
            wizardHeader

            Divider().overlay(theme.divider)

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    switch currentStep {
                    case .template:
                        templateStep
                    case .project:
                        projectStep
                    }

                    actionButtons
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingMD)
            }
        }
        .background(theme.bgPrimary)
        .task {
            projectsViewModel.configure(client: appState.apiClient)
            onboardingViewModel.markFirstSessionWizardShown()
        }
        .task {
            await projectsViewModel.loadProjects()
        }
        .onAppear {
            if reduceMotion {
                isAnimatingIn = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    isAnimatingIn = true
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Header

    @ViewBuilder
    private var wizardHeader: some View {
        VStack(spacing: theme.spacingSM) {
            HStack {
                Spacer()
                Button {
                    HapticManager.selection()
                    dismiss()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.vertical, theme.spacingXS)
                        .padding(.horizontal, theme.spacingSM)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip first session wizard")
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)

            VStack(spacing: 4) {
                Text("Start Your First Session")
                    .font(.system(size: theme.fontTitle2, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(currentStep == .template ? "Choose a session template" : "Select a project (optional)")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentStep)
            }
            .padding(.bottom, theme.spacingXS)

            stepDotsIndicator
                .padding(.bottom, theme.spacingSM)
        }
    }

    // MARK: - Step Dots Indicator

    @ViewBuilder
    private var stepDotsIndicator: some View {
        HStack(spacing: theme.spacingSM) {
            ForEach(Array(FirstSessionStep.allCases.enumerated()), id: \.offset) { _, step in
                Capsule()
                    .fill(step == currentStep ? theme.accent : theme.textTertiary.opacity(0.4))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentStep == .template ? "Step 1 of 2: Choose template" : "Step 2 of 2: Choose project")
    }

    // MARK: - Template Step

    @ViewBuilder
    private var templateStep: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(OnboardingTemplate.all) { template in
                templateRow(template)
            }
        }
        .opacity(isAnimatingIn ? 1.0 : 0.0)
        .offset(y: isAnimatingIn ? 0 : 12)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: isAnimatingIn)
    }

    @ViewBuilder
    private func templateRow(_ template: OnboardingTemplate) -> some View {
        let isSelected = selectedTemplate.id == template.id
        Button {
            HapticManager.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                selectedTemplate = template
            }
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: template.icon)
                    .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .fill(isSelected ? theme.accent.opacity(0.15) : theme.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(template.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.glassBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        isSelected ? theme.accent.opacity(0.5) : theme.glassBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name): \(template.description)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Project Step

    @ViewBuilder
    private var projectStep: some View {
        VStack(spacing: theme.spacingSM) {
            noProjectRow

            if projectsViewModel.isLoading && projectsViewModel.projects.isEmpty {
                ProgressView("Loading projects…")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            } else if projectsViewModel.projects.isEmpty && !projectsViewModel.isLoading {
                Text("No projects found")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
            } else {
                LazyVStack(spacing: theme.spacingXS) {
                    ForEach(projectsViewModel.projects) { project in
                        projectRow(project)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noProjectRow: some View {
        let isSelected = selectedProject == nil
        Button {
            HapticManager.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                selectedProject = nil
            }
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .fill(isSelected ? theme.accent.opacity(0.15) : theme.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("No project")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Start without a project context")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.glassBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        isSelected ? theme.accent.opacity(0.5) : theme.glassBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("No project: Start without a project context")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        let isSelected = selectedProject?.id == project.id
        Button {
            HapticManager.selection()
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                selectedProject = project
            }
        } label: {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                            .fill(isSelected ? theme.accent.opacity(0.15) : theme.bgSecondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(project.path)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.glassBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        isSelected ? theme.accent.opacity(0.5) : theme.glassBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(project.name): \(project.path)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: theme.spacingSM) {
            if currentStep == .template {
                Button {
                    HapticManager.impact(.medium)
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                        currentStep = .project
                    }
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Text("Choose Project")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        Image(systemName: "chevron.right")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundColor(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 4)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue to project selection")

                Button {
                    HapticManager.selection()
                    startSession()
                } label: {
                    Text("Start Without Project")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start session without a project")

            } else {
                HStack(spacing: theme.spacingSM) {
                    Button {
                        HapticManager.impact(.light)
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                            currentStep = .template
                        }
                    } label: {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            Text("Back")
                                .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        }
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM + 4)
                        .background(theme.glassBackground)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                .stroke(theme.glassBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to template selection")

                    Button {
                        HapticManager.impact(.medium)
                        startSession()
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Text("Start Session")
                                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                            Image(systemName: "play.fill")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        }
                        .foregroundColor(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM + 4)
                        .background(theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start session with selected template and project")
                }
            }
        }
        .padding(.top, theme.spacingXS)
    }

    // MARK: - Actions

    private func startSession() {
        let templateName = selectedTemplate.name
        let projectPath = selectedProject?.path
        dismiss()
        onStart(templateName, projectPath)
    }
}

// MARK: - Preview

#Preview {
    FirstSessionWizardView(
        onboardingViewModel: OnboardingViewModel(),
        onStart: { _, _ in }
    )
    .environment(AppState())
}
