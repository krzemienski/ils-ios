import SwiftUI
import ILSShared
import TipKit

// MARK: - Entry Mode

enum NewSessionMode: String, CaseIterable, Identifiable {
    case project = "Project"
    case fork = "Fork"
    case newProject = "New Project"

    var id: String { rawValue }
}

// MARK: - NewSessionView

struct NewSessionView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // SA-MED-2: Dedicated ProjectsViewModel is intentional — NewSessionView needs independent
    // search/filter state for project selection without affecting the main projects list.
    @State private var projectsViewModel = ProjectsViewModel()
    @State private var sessionViewModel = NewSessionViewModel()
    @State private var selectedMode: NewSessionMode = .project
    @State private var selectedProject: Project?
    @State private var selectedModel = "sonnet"
    @State private var permissionMode = "default"
    @State private var systemPrompt = ""
    @State private var maxBudget = ""
    @State private var maxTurns = ""
    @State private var sessionName = ""
    @State private var showConfig = false

    // Fork mode state
    // recentSessions and isLoadingSessions moved to NewSessionViewModel
    @State private var selectedSession: ChatSession?
    @State private var forkSearchText = ""
    @State private var debouncedForkResults: [ChatSession] = []

    // New Project mode state
    @State private var newProjectName = ""
    @State private var newProjectPath = ""

    private enum FocusedField: Hashable {
        case sessionName, systemPrompt, maxBudget, maxTurns
        case projectSearch, forkSearch, newProjectName, newProjectPath
    }
    @FocusState private var focusedField: FocusedField?

    let onCreated: (ChatSession) -> Void

    private let models = ["sonnet", "opus", "haiku"]
    private let permissionModes = [
        "default", "acceptEdits", "plan", "bypassPermissions", "delegate", "dontAsk"
    ]

    var body: some View {
        VStack(spacing: 0) {
            modePicker
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingSM)
                .padding(.bottom, theme.spacingSM)

            Divider().overlay(theme.divider)

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    switch selectedMode {
                    case .project:
                        projectPickerSection
                    case .fork:
                        forkSessionSection
                    case .newProject:
                        createProjectSection
                    }

                    if canShowConfig {
                        configurationSection
                    }

                    actionButton
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("New Session")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .task {
            projectsViewModel.configure(client: appState.apiClient)
            sessionViewModel.configure(client: appState.apiClient)
            await projectsViewModel.loadProjects()
        }
        .task {
            await sessionViewModel.loadRecentSessions()
            debouncedForkResults = sessionViewModel.recentSessions
        }
        .task(id: forkSearchText) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            if forkSearchText.isEmpty {
                debouncedForkResults = sessionViewModel.recentSessions
            } else {
                let query = forkSearchText.lowercased()
                debouncedForkResults = sessionViewModel.recentSessions.filter {
                    ($0.name ?? "").lowercased().contains(query)
                        || ($0.projectName ?? "").lowercased().contains(query)
                        || $0.model.lowercased().contains(query)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: - Can Show Config

    private var canShowConfig: Bool {
        switch selectedMode {
        case .project:
            return true
        case .fork:
            return selectedSession != nil
        case .newProject:
            return !newProjectName.isEmpty && !newProjectPath.isEmpty
        }
    }

    // MARK: - Mode Picker

    @ViewBuilder
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(NewSessionMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: theme.fontCaption, weight: selectedMode == mode ? .semibold : .regular, design: theme.fontDesign))
                        .foregroundStyle(selectedMode == mode ? theme.textPrimary : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(selectedMode == mode ? theme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .accessibilityIdentifier("mode-picker")
    }

    // MARK: - Project Picker Section

    @ViewBuilder
    private var projectPickerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Select Project")

            projectSearchBar

            noProjectRow

            if projectsViewModel.isLoading && projectsViewModel.projects.isEmpty {
                projectLoadingView
            } else if projectsViewModel.filteredProjects.isEmpty && !projectsViewModel.searchText.isEmpty {
                noResultsView(text: "No matching projects")
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(projectsViewModel.filteredProjects) { project in
                        projectRow(project)
                    }
                }
            }
        }
        .accessibilityIdentifier("project-list")
    }

    @ViewBuilder
    private var projectSearchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search projects...", text: $projectsViewModel.searchText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($focusedField, equals: .projectSearch)
            if !projectsViewModel.searchText.isEmpty {
                Button {
                    projectsViewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: focusedField == .projectSearch, cornerRadius: theme.cornerRadiusSmall)
    }

    @ViewBuilder
    private var noProjectRow: some View {
        Button {
            selectedProject = nil
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "house.fill")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("No Project (Home Directory)")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Start without project context")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if selectedProject == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(selectedProject == nil ? theme.accent.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        let isSelected = selectedProject?.id == project.id
        Button {
            selectedProject = project
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "folder.fill")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.entityProject)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        Text(truncatedPath(project.path))
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)

                        if let count = project.sessionCount, count > 0 {
                            Text("\u{00b7}")
                                .foregroundStyle(theme.textTertiary)
                            Text("\(count) sessions")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.accent.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(project.name), \(project.path)")
    }

    // MARK: - Fork Session Section

    @ViewBuilder
    private var forkSessionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Fork from Session")

            Text("Creates a copy of the selected session's conversation as a new starting point.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)

            forkSearchBar

            if sessionViewModel.isLoadingSessions {
                projectLoadingView
            } else if debouncedForkResults.isEmpty {
                noResultsView(text: forkSearchText.isEmpty ? "No recent sessions" : "No matching sessions")
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(debouncedForkResults) { session in
                        forkSessionRow(session)
                    }
                }
            }
        }
        .accessibilityIdentifier("session-list")
    }

    @ViewBuilder
    private var forkSearchBar: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            TextField("Search sessions...", text: $forkSearchText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($focusedField, equals: .forkSearch)
            if !forkSearchText.isEmpty {
                Button {
                    forkSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .focusRing(isFocused: focusedField == .forkSearch, cornerRadius: theme.cornerRadiusSmall)
    }

    @ViewBuilder
    private func forkSessionRow(_ session: ChatSession) -> some View {
        let isSelected = selectedSession?.id == session.id
        Button {
            selectedSession = session
        } label: {
            HStack(spacing: theme.spacingSM) {
                Circle()
                    .fill(session.status == .active ? theme.success : theme.textTertiary.opacity(0.3))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: theme.spacingXS) {
                        if let projectName = session.projectName {
                            Text(projectName)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.entityProject)
                        }

                        Text(session.model.capitalized)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.entitySession)

                        Text("\u{00b7}")
                            .foregroundStyle(theme.textTertiary)

                        Text("\(session.messageCount) msgs")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.accent.opacity(0.08) : theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .contentShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.displayName), \(session.model), \(session.messageCount) messages")
    }

    // MARK: - Create Project Section

    @ViewBuilder
    private var createProjectSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Create New Project")

            TextField("Project Name", text: $newProjectName)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .foregroundStyle(theme.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .focusRing(isFocused: focusedField == .newProjectName, cornerRadius: theme.cornerRadiusSmall)
                .focused($focusedField, equals: .newProjectName)
                .accessibilityIdentifier("new-project-name")

            HStack(spacing: theme.spacingSM) {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(theme.textTertiary)
                TextField("Directory Path (e.g. ~/projects/my-app)", text: $newProjectPath)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .focused($focusedField, equals: .newProjectPath)
            }
            .padding(theme.spacingSM)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .newProjectPath, cornerRadius: theme.cornerRadiusSmall)
            .accessibilityIdentifier("new-project-path")

            Text("Enter the full path to your project directory on the server.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .accessibilityIdentifier("create-project-form")
    }

    // MARK: - Configuration Section

    @ViewBuilder
    private var configurationSection: some View {
        DisclosureGroup(isExpanded: $showConfig) {
            VStack(spacing: theme.spacingMD) {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("Session Name")
                    TextField("Session Name (optional)", text: $sessionName)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .padding(theme.spacingSM)
                        .background(theme.bgTertiary)
                        .foregroundStyle(theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .focusRing(isFocused: focusedField == .sessionName, cornerRadius: theme.cornerRadiusSmall)
                        .focused($focusedField, equals: .sessionName)
                        .accessibilityIdentifier("session-name-field")
                }

                modelSection
                permissionsSection
                systemPromptSection
                limitsSection
            }
            .padding(.top, theme.spacingSM)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Configuration")
                if !showConfig {
                    Text(configurationSummary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .font(.system(size: theme.fontBody, design: theme.fontDesign))
        .foregroundStyle(theme.textSecondary)
        .tint(theme.textTertiary)
        .padding(theme.spacingSM)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }

    // MARK: - Model Selection

    @ViewBuilder
    private var modelSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Model")

            HStack(spacing: 0) {
                ForEach(models, id: \.self) { model in
                    Button {
                        selectedModel = model
                    } label: {
                        Text(model.capitalized)
                            .font(.system(size: theme.fontCaption, weight: selectedModel == model ? .semibold : .regular, design: theme.fontDesign))
                            .foregroundStyle(selectedModel == model ? theme.textPrimary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(selectedModel == model ? theme.accent.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .accessibilityLabel("Claude model selection")
        }
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Permissions")

            Picker("Permission Mode", selection: $permissionMode) {
                ForEach(permissionModes, id: \.self) { mode in
                    Text(formattedMode(mode)).tag(mode)
                }
            }
            .tint(theme.accent)
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            Text(permissionDescription)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - System Prompt

    @ViewBuilder
    private var systemPromptSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("System Prompt")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $systemPrompt)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 60)
                    .focused($focusedField, equals: .systemPrompt)

                if systemPrompt.isEmpty {
                    Text("Custom instructions for Claude (optional)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .systemPrompt, cornerRadius: theme.cornerRadiusSmall)
        }
    }

    // MARK: - Limits

    @ViewBuilder
    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Limits")

            HStack {
                Text("Max Budget (USD)")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                TextField("No limit", text: $maxBudget)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
                    .focused($focusedField, equals: .maxBudget)
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .maxBudget, cornerRadius: theme.cornerRadiusSmall)

            HStack {
                Text("Max Turns")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                TextField("1", text: $maxTurns)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 100)
                    .focused($focusedField, equals: .maxTurns)
            }
            .padding(theme.spacingSM)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            .focusRing(isFocused: focusedField == .maxTurns, cornerRadius: theme.cornerRadiusSmall)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        AccentButton(actionButtonTitle, icon: actionButtonIcon, isLoading: sessionViewModel.isCreating) {
            performAction()
        }
        .frame(maxWidth: .infinity)
        .disabled(!actionButtonEnabled)
        .padding(.top, theme.spacingSM)
        .accessibilityIdentifier("start-session-button")
    }

    private var actionButtonTitle: String {
        switch selectedMode {
        case .project: return "Start Session"
        case .fork: return "Fork & Start"
        case .newProject: return "Create Project & Start"
        }
    }

    private var actionButtonIcon: String {
        switch selectedMode {
        case .project: return "plus.circle.fill"
        case .fork: return "arrow.triangle.branch"
        case .newProject: return "folder.badge.plus"
        }
    }

    private var actionButtonEnabled: Bool {
        switch selectedMode {
        case .project:
            return true
        case .fork:
            return selectedSession != nil
        case .newProject:
            return !newProjectName.isEmpty && !newProjectPath.isEmpty
        }
    }

    // MARK: - Shared Sub-views

    @ViewBuilder
    private var projectLoadingView: some View {
        VStack(spacing: theme.spacingSM) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: theme.spacingSM) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.bgTertiary)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 120, height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.bgTertiary)
                            .frame(width: 180, height: 10)
                    }
                    Spacer()
                }
                .padding(theme.spacingSM)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .shimmer()
        }
    }

    @ViewBuilder
    private func noResultsView(text: String) -> some View {
        VStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
            Text(text)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingLG)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    private func truncatedPath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if components.count > 3 {
            return ".../" + components.suffix(2).joined(separator: "/")
        }
        return path
    }

    private func formattedMode(_ mode: String) -> String {
        switch mode {
        case "default": return "Default"
        case "acceptEdits": return "Accept Edits"
        case "plan": return "Plan Mode"
        case "bypassPermissions": return "Bypass All"
        case "delegate": return "Delegate"
        case "dontAsk": return "Don't Ask"
        default: return mode
        }
    }

    private var permissionDescription: String {
        switch permissionMode {
        case "default":
            return "Standard permission behavior -- Claude will ask before executing tools."
        case "acceptEdits":
            return "Automatically approve file edits without prompting."
        case "plan":
            return "Planning mode -- Claude will plan but not execute changes."
        case "bypassPermissions":
            return "Skip all permission checks. Use with caution."
        case "delegate":
            return "Delegate permission decisions to the calling process."
        case "dontAsk":
            return "Never prompt -- deny any action that requires permission."
        default:
            return ""
        }
    }

    private var configurationSummary: String {
        var parts: [String] = []
        parts.append(selectedModel.capitalized)
        parts.append(formattedMode(permissionMode))
        let hasBudget = !maxBudget.isEmpty
        let hasTurns = !maxTurns.isEmpty
        if hasBudget && hasTurns {
            parts.append("$\(maxBudget) \u{00b7} \(maxTurns) turns")
        } else if hasBudget {
            parts.append("$\(maxBudget)")
        } else if hasTurns {
            parts.append("\(maxTurns) turns")
        } else {
            parts.append("No limit")
        }
        return parts.joined(separator: " \u{00b7} ")
    }

    // MARK: - Actions

    private func performAction() {
        switch selectedMode {
        case .project:
            createSession()
        case .fork:
            forkSession()
        case .newProject:
            createProjectAndSession()
        }
    }

    // loadRecentSessions() moved to NewSessionViewModel

    // SA-MED-3: Button-triggered Tasks are correct — these are user-initiated actions,
    // not lifecycle-bound work. `.task` modifier is for view lifecycle; `Task {}` is
    // appropriate for fire-and-forget user actions like create/fork/submit.
    private func createSession() {
        Task {
            if let session = await sessionViewModel.createSession(
                projectId: selectedProject?.id,
                name: sessionName.isEmpty ? nil : sessionName,
                model: selectedModel,
                permissionMode: permissionMode,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                maxBudget: maxBudget,
                maxTurns: maxTurns
            ) {
                // Donate session creation for TipKit sequential unlock
                CommandPaletteTip.hasCreatedSession = true
                MCPBrowserTip.hasCreatedSession = true
                onCreated(session)
                dismiss()
            }
        }
    }

    private func forkSession() {
        guard let sourceSession = selectedSession else { return }
        Task {
            if let forkedSession = await sessionViewModel.forkSession(sourceSessionId: sourceSession.id) {
                onCreated(forkedSession)
                dismiss()
            }
        }
    }

    private func createProjectAndSession() {
        guard !newProjectName.isEmpty, !newProjectPath.isEmpty else { return }
        Task {
            if let session = await sessionViewModel.createProjectAndSession(
                projectName: newProjectName,
                projectPath: newProjectPath,
                sessionName: sessionName.isEmpty ? nil : sessionName,
                model: selectedModel,
                permissionMode: permissionMode,
                systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
                maxBudget: maxBudget,
                maxTurns: maxTurns,
                projectsViewModel: projectsViewModel
            ) {
                onCreated(session)
                dismiss()
            }
        }
    }

    private func buildChatOptions() -> ChatOptions {
        ChatOptions(
            model: selectedModel,
            permissionMode: PermissionMode(rawValue: permissionMode),
            maxTurns: Int(maxTurns),
            maxBudgetUSD: Double(maxBudget),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )
    }
}

#Preview {
    NewSessionView { _ in }
        .environment(AppState())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
