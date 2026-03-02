import SwiftUI
import ILSShared

/// Sheet for adding a new task to the agent queue.
///
/// Presents fields for title, prompt, optional project association,
/// priority, execution mode, and a template picker.
struct AddQueueTaskView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    let viewModel: AgentQueueViewModel

    // SA-MED-2: Independent ProjectsViewModel so project list state is isolated from
    // any parent projects screen.
    @State private var projectsViewModel = ProjectsViewModel()

    // MARK: - Form State

    @State private var title = ""
    @State private var prompt = ""
    @State private var selectedProject: Project?
    @State private var priority: Double = 5
    @State private var executionMode: QueueExecutionMode = .sequential
    @State private var projectSearchText = ""
    @State private var isSubmitting = false
    @State private var showProjectPicker = false

    private enum FocusedField: Hashable {
        case title, prompt, projectSearch
    }
    @FocusState private var focusedField: FocusedField?

    // MARK: - Validation

    private var isTitleValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isPromptValid: Bool { !prompt.trimmingCharacters(in: .whitespaces).isEmpty }
    private var canSubmit: Bool { isTitleValid && isPromptValid && !isSubmitting }

    private var filteredProjects: [Project] {
        guard !projectSearchText.isEmpty else { return projectsViewModel.projects }
        let query = projectSearchText.lowercased()
        return projectsViewModel.projects.filter {
            $0.name.lowercased().contains(query) || $0.path.lowercased().contains(query)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(theme.divider)

            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    titleSection
                    promptSection
                    projectPickerSection
                    prioritySection
                    executionModeSection
                    if !viewModel.templates.isEmpty {
                        templatePickerSection
                    }
                    addButton
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingMD)
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Add Task")
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
            await projectsViewModel.loadProjects()
            await viewModel.loadTemplates()
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Title", required: true)

            TextField("e.g. Run tests on all projects", text: $title)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .padding(theme.spacingMD)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(
                            focusedField == .title ? theme.accent : theme.divider,
                            lineWidth: 1
                        )
                )
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .prompt }
        }
    }

    // MARK: - Prompt Section

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Prompt", required: true)

            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("Describe the task for the Claude Code agent…")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingMD)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $prompt)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.vertical, theme.spacingSM)
                    .focused($focusedField, equals: .prompt)
                    .frame(minHeight: 120, maxHeight: 200)
            }
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(
                        focusedField == .prompt ? theme.accent : theme.divider,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Project Picker Section

    private var projectPickerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Project", required: false)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showProjectPicker.toggle()
                }
            } label: {
                HStack {
                    if let project = selectedProject {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                            Text(project.path)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("None (optional)")
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)
                    }

                    Spacer()

                    Image(systemName: showProjectPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingMD)
                .background(theme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadius)
                        .stroke(theme.divider, lineWidth: 1)
                )
            }

            if showProjectPicker {
                projectListDropdown
            }
        }
    }

    private var projectListDropdown: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                TextField("Search projects…", text: $projectSearchText)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .focused($focusedField, equals: .projectSearch)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(theme.bgSecondary)

            Divider().overlay(theme.divider)

            // Clear selection row
            Button {
                selectedProject = nil
                withAnimation { showProjectPicker = false }
            } label: {
                HStack {
                    Text("None")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(selectedProject == nil ? theme.accent : theme.textSecondary)
                    Spacer()
                    if selectedProject == nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingSM)
            }

            Divider().overlay(theme.divider)

            if projectsViewModel.isLoading && projectsViewModel.projects.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(theme.accent)
                    Text("Loading…")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(theme.spacingMD)
            } else {
                ForEach(filteredProjects) { project in
                    Button {
                        selectedProject = project
                        withAnimation { showProjectPicker = false }
                        projectSearchText = ""
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Text(project.path)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)
                            }
                        }
                        .padding(.horizontal, theme.spacingMD)
                        .padding(.vertical, theme.spacingSM)
                    }

                    if project.id != filteredProjects.last?.id {
                        Divider().overlay(theme.divider)
                    }
                }

                if filteredProjects.isEmpty {
                    Text("No projects found")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(theme.spacingMD)
                }
            }
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.divider, lineWidth: 1)
        )
    }

    // MARK: - Priority Section

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                sectionLabel("Priority", required: false)
                Spacer()
                Text("\(Int(priority))")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(priorityColor)
                    .monospacedDigit()
            }

            Slider(value: $priority, in: 1...10, step: 1)
                .tint(priorityColor)

            HStack {
                Text("Low")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Text("High")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    }

    private var priorityColor: Color {
        switch Int(priority) {
        case 1...3: return theme.success
        case 4...6: return .yellow
        case 7...9: return .orange
        default: return theme.error
        }
    }

    // MARK: - Execution Mode Section

    private var executionModeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Execution Mode", required: false)

            HStack(spacing: 0) {
                ForEach(QueueExecutionMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            executionMode = mode
                        }
                    } label: {
                        HStack(spacing: theme.spacingSM) {
                            Image(systemName: mode == .sequential ? "list.number" : "square.grid.2x2")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            Text(mode.rawValue.capitalized)
                                .font(.system(
                                    size: theme.fontBody,
                                    weight: executionMode == mode ? .semibold : .regular,
                                    design: theme.fontDesign
                                ))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(executionMode == mode ? theme.textPrimary : theme.textSecondary)
                        .padding(.vertical, theme.spacingSM)
                        .background(executionMode == mode ? theme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                }
            }
            .padding(4)
            .background(theme.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))

            Text(executionMode == .sequential
                ? "Tasks run one at a time in order."
                : "Eligible tasks run concurrently.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Template Picker Section

    private var templatePickerSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Templates", required: false)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingSM) {
                    ForEach(viewModel.templates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                Text(template.description)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                if !template.tags.isEmpty {
                                    tagsRow(for: template.tags)
                                }
                            }
                            .frame(width: 200, alignment: .leading)
                            .padding(theme.spacingMD)
                            .background(theme.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadius)
                                    .stroke(theme.divider, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func tagsRow(for tags: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(3), id: \.self) { tag in
                Text(tag)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            Task { await submitTask() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Add to Queue")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingMD)
            .background(canSubmit ? theme.accent : theme.accent.opacity(0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
        .disabled(!canSubmit)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String, required: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
            if required {
                Text("*")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private func applyTemplate(_ template: QueueItemTemplate) {
        if title.isEmpty {
            title = template.title
        }
        if prompt.isEmpty {
            prompt = template.prompt
        }
    }

    // MARK: - Submit

    private func submitTask() async {
        guard canSubmit else { return }
        isSubmitting = true
        await viewModel.createItem(
            title: title.trimmingCharacters(in: .whitespaces),
            description: prompt.trimmingCharacters(in: .whitespaces),
            projectId: selectedProject.map { $0.id.uuidString },
            priority: Int(priority)
        )
        isSubmitting = false
        if viewModel.error == nil {
            dismiss()
        }
    }
}
