import SwiftUI
import ILSShared

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SkillsViewModel()
    @State private var showingNewSkill = false

    var body: some View {
        List {
            if let error = viewModel.error {
                ErrorStateView(error: error) {
                    await viewModel.retryLoadSkills()
                }
            } else if viewModel.filteredSkills.isEmpty && !viewModel.isLoading {
                if viewModel.searchText.isEmpty {
                    EmptyStateView(
                        title: "No Skills",
                        systemImage: "star",
                        description: "Skills from ~/.claude/skills/ will appear here",
                        actionTitle: "Create Skill"
                    ) {
                        showingNewSkill = true
                    }
                } else {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            } else {
                // Installed skills
                Section {
                    ForEach(viewModel.filteredSkills) { skill in
                        NavigationLink(value: skill) {
                            SkillRowView(skill: skill) {
                                Task { await viewModel.toggleSkillActive(skill) }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteSkill(skill) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = skill.name
                            } label: {
                                Label("Copy Name", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive) {
                                Task { await viewModel.deleteSkill(skill) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Installed (\(viewModel.filteredSkills.count))")
                }

                // GitHub search section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ILSTheme.tertiaryText)
                        TextField("Search GitHub skills...", text: $viewModel.gitHubSearchText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                Task { await viewModel.searchGitHub(query: viewModel.gitHubSearchText) }
                            }
                    }
                    .padding(10)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusSmall)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

                    if viewModel.isSearchingGitHub {
                        HStack {
                            Spacer()
                            ProgressView("Searching GitHub...")
                            Spacer()
                        }
                    } else {
                        ForEach(viewModel.gitHubResults) { result in
                            GitHubSkillRow(result: result) {
                                Task {
                                    _ = await viewModel.installFromGitHub(result: result)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Discover from GitHub")
                }
            }
        }
        .darkListStyle()
        .navigationTitle("Skills")
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .searchable(text: $viewModel.searchText, prompt: "Search skills...")
        .refreshable {
            // Pull-to-refresh rescans ~/.claude directory
            await viewModel.refreshSkills()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingNewSkill = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewSkill) {
            SkillEditorView(mode: .create, apiClient: appState.apiClient) { skill in
                viewModel.skills.append(skill)
            }
            .presentationBackground(Color.black)
        }
        .navigationDestination(for: Skill.self) { skill in
            SkillDetailView(skill: skill, viewModel: viewModel, apiClient: appState.apiClient)
        }
        .overlay {
            if viewModel.isLoading && viewModel.skills.isEmpty {
                ProgressView("Loading skills...")
            }
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadSkills()
        }
        .onChange(of: appState.isConnected) { _, isConnected in
            if isConnected && viewModel.error != nil {
                Task { await viewModel.retryLoadSkills() }
            }
        }
    }
}

struct SkillRowView: View {
    let skill: Skill
    var onToggle: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                Text("/\(skill.name)")
                    .font(ILSTheme.headlineFont)

                Spacer()

                Image(systemName: skill.isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(skill.isActive ? ILSTheme.success : ILSTheme.tertiaryText)
                    .font(.caption)
                    .onTapGesture { onToggle?() }
            }

            if let description = skill.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
            }

            // Display tags if present
            if !skill.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingXS) {
                        ForEach(skill.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ILSTheme.accent.opacity(0.15))
                                .foregroundColor(ILSTheme.accent)
                                .cornerRadius(ILSTheme.cornerRadiusXS)
                        }
                    }
                }
            }

            // Source path
            HStack(spacing: ILSTheme.spacingXS) {
                Text(skill.source.rawValue)
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)
                Text(skill.path)
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("/\(skill.name), \(skill.isActive ? "active" : "inactive")\(skill.description.map { ", \($0)" } ?? "")")
        .accessibilityHint("Double tap to view skill details")
    }
}

// MARK: - Skill Detail View

struct SkillDetailView: View {
    let skill: Skill
    @ObservedObject var viewModel: SkillsViewModel
    let apiClient: APIClient

    @Environment(\.dismiss) private var dismiss
    @State private var fullSkill: Skill?
    @State private var isLoading = true
    @State private var showingEditor = false
    @State private var showCopiedToast = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ILSTheme.spacingM) {
                // Header with metadata
                skillHeader

                Divider()

                // Content section
                if isLoading {
                    ProgressView("Loading skill content...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, ILSTheme.spacingXL)
                } else if let content = fullSkill?.content ?? skill.content {
                    skillContent(content)
                } else {
                    ContentUnavailableView(
                        "No Content",
                        systemImage: "doc.text",
                        description: Text("This skill has no content")
                    )
                }
            }
            .padding(ILSTheme.spacingM)
        }
        .background(ILSTheme.background)
        .navigationTitle("/\(skill.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy Content", systemImage: "doc.on.doc")
                    }

                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit Skill", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Skill", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            SkillEditorView(mode: .edit(fullSkill ?? skill), apiClient: apiClient, viewModel: viewModel) { _ in }
                .presentationBackground(Color.black)
        }
        .alert("Delete Skill?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSkill(skill)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \"/\(skill.name)\" from your skills.")
        }
        .toast(isPresented: $showCopiedToast, message: "Copied to clipboard")
        .task {
            await loadFullSkill()
        }
    }

    // MARK: - Subviews

    private var skillHeader: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            // Description
            if let description = fullSkill?.description ?? skill.description {
                Text(description)
                    .font(ILSTheme.bodyFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }

            // Tags
            let tags = fullSkill?.tags ?? skill.tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ILSTheme.spacingS) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(ILSTheme.captionFont)
                                .padding(.horizontal, ILSTheme.spacingS)
                                .padding(.vertical, ILSTheme.spacingXS)
                                .background(ILSTheme.accent.opacity(0.15))
                                .foregroundColor(ILSTheme.accent)
                                .cornerRadius(ILSTheme.cornerRadiusXS)
                        }
                    }
                }
            }

            // Metadata row
            HStack(spacing: ILSTheme.spacingM) {
                if let version = fullSkill?.version ?? skill.version {
                    Label(version, systemImage: "tag")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }

                Label((fullSkill?.source ?? skill.source).rawValue, systemImage: "folder")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.tertiaryText)
            }

            // File path
            Text(fullSkill?.path ?? skill.path)
                .font(.caption2)
                .foregroundColor(ILSTheme.tertiaryText)
                .lineLimit(2)
        }
    }

    private func skillContent(_ content: String) -> some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            Text("Content")
                .font(ILSTheme.headlineFont)

            Text(content)
                .font(ILSTheme.codeFont)
                .padding(ILSTheme.spacingM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ILSTheme.secondaryBackground)
                .cornerRadius(ILSTheme.cornerRadiusSmall)
                .textSelection(.enabled)
        }
    }

    // MARK: - Actions

    private func loadFullSkill() async {
        isLoading = true
        do {
            let response: APIResponse<Skill> = try await apiClient.get("/skills/\(skill.name)")
            if let loadedSkill = response.data {
                fullSkill = loadedSkill
            }
        } catch {
            print("Failed to load full skill: \(error)")
        }
        isLoading = false
    }

    private func copyToClipboard() {
        guard let content = fullSkill?.content ?? skill.content else { return }
        UIPasteboard.general.string = content

        withAnimation {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

struct SkillEditorView: View {
    enum Mode {
        case create
        case edit(Skill)
    }

    let mode: Mode
    let apiClient: APIClient
    var viewModel: SkillsViewModel?
    let onSave: (Skill) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var content = ""
    @State private var isSaving = false

    init(mode: Mode, apiClient: APIClient, viewModel: SkillsViewModel? = nil, onSave: @escaping (Skill) -> Void) {
        self.mode = mode
        self.apiClient = apiClient
        self.viewModel = viewModel
        self.onSave = onSave

        if case .edit(let skill) = mode {
            _name = State(initialValue: skill.name)
            _description = State(initialValue: skill.description ?? "")
            _content = State(initialValue: skill.content ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Skill Info") {
                    if case .create = mode {
                        TextField("Skill Name", text: $name)
                    } else {
                        LabeledContent("Name", value: name)
                    }
                    TextField("Description", text: $description)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .font(ILSTheme.codeFont)
                        .frame(minHeight: 300)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ILSTheme.background)
            .navigationTitle(isCreating ? "New Skill" : "Edit Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSkill()
                    }
                    .disabled(name.isEmpty || content.isEmpty || isSaving)
                }
            }
            .task {
                if case .edit(let skill) = mode, skill.content == nil {
                    await loadSkillContent(skill.name)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private func loadSkillContent(_ name: String) async {
        do {
            let response: APIResponse<Skill> = try await apiClient.get("/skills/\(name)")
            if let skill = response.data, let skillContent = skill.content {
                content = skillContent
            }
        } catch {
            print("Failed to load skill content: \(error)")
        }
    }

    private func saveSkill() {
        isSaving = true

        Task {
            do {
                if case .create = mode {
                    let request = CreateSkillRequest(
                        name: name,
                        description: description.isEmpty ? nil : description,
                        content: content
                    )
                    let response: APIResponse<Skill> = try await apiClient.post("/skills", body: request)
                    if let skill = response.data {
                        await MainActor.run {
                            onSave(skill)
                            dismiss()
                        }
                    }
                } else {
                    let request = UpdateSkillRequest(content: content)
                    let response: APIResponse<Skill> = try await apiClient.put("/skills/\(name)", body: request)
                    if response.data != nil {
                        await viewModel?.loadSkills()
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            } catch {
                print("Failed to save skill: \(error)")
            }

            isSaving = false
        }
    }
}

// MARK: - GitHub UI

struct GitHubSkillRow: View {
    let result: GitHubSearchResult
    let onInstall: () -> Void
    @State private var isInstalling = false
    @State private var isInstalled = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.repository)
                    .font(ILSTheme.headlineFont)
                    .foregroundColor(ILSTheme.primaryText)
                if let desc = result.description {
                    Text(desc)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(result.stars)")
                            .font(.caption2)
                    }
                    .foregroundColor(ILSTheme.warning)
                }
            }

            Spacer()

            if isInstalled {
                Text("Installed")
                    .font(.caption)
                    .foregroundColor(ILSTheme.success)
            } else {
                Button(action: {
                    isInstalling = true
                    onInstall()
                    // Optimistically show installed after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isInstalling = false
                        isInstalled = true
                    }
                }) {
                    if isInstalling {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Install")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(ILSTheme.accent)
                            .cornerRadius(ILSTheme.cornerRadiusXS)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.repository), \(result.stars) stars\(result.description.map { ", \($0)" } ?? "")")
        .accessibilityHint("Double tap to install from GitHub")
    }
}

#Preview {
    NavigationStack {
        SkillsListView()
    }
}
