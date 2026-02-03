import SwiftUI
import ILSShared

struct SkillsListView: View {
    @StateObject private var viewModel = SkillsViewModel()
    @State private var showingNewSkill = false

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.skills.isEmpty {
                // Show skeleton rows during initial load
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonSkillRow()
                }
            } else if let error = viewModel.error {
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
                ForEach(viewModel.filteredSkills) { skill in
                    NavigationLink(value: skill) {
                        SkillRowView(skill: skill)
                    }
                }
                .onDelete(perform: deleteSkill)
            }
        }
        .navigationTitle("Skills")
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
            SkillEditorView(mode: .create) { skill in
                viewModel.skills.append(skill)
            }
        }
        .navigationDestination(for: SkillItem.self) { skill in
            SkillDetailView(skill: skill, viewModel: viewModel)
        }
        .task {
            await viewModel.loadSkills()
        }
    }

    private func deleteSkill(at offsets: IndexSet) {
        let skillsToDelete = offsets.map { viewModel.filteredSkills[$0] }
        Task {
            for skill in skillsToDelete {
                await viewModel.deleteSkill(skill)
            }
        }
    }
}

struct SkillRowView: View {
    let skill: SkillItem

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                Text("/\(skill.name)")
                    .font(ILSTheme.headlineFont)

                Spacer()

                if skill.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ILSTheme.success)
                        .font(.caption)
                }
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
                                .cornerRadius(ILSTheme.cornerRadiusS)
                        }
                    }
                }
            }

            // Source path
            HStack(spacing: ILSTheme.spacingXS) {
                if let source = skill.source {
                    Text(source)
                        .font(.caption2)
                        .foregroundColor(ILSTheme.tertiaryText)
                }
                Text(skill.path)
                    .font(.caption2)
                    .foregroundColor(ILSTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
    }
}

// MARK: - Skill Detail View

struct SkillDetailView: View {
    let skill: SkillItem
    @ObservedObject var viewModel: SkillsViewModel

    @State private var fullSkill: SkillItem?
    @State private var isLoading = true
    @State private var showingEditor = false
    @State private var showCopiedToast = false

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
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            SkillEditorView(mode: .edit(fullSkill ?? skill), viewModel: viewModel) { _ in }
        }
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(ILSTheme.captionFont)
                    .padding(.horizontal, ILSTheme.spacingM)
                    .padding(.vertical, ILSTheme.spacingS)
                    .background(ILSTheme.secondaryBackground)
                    .cornerRadius(ILSTheme.cornerRadiusM)
                    .shadow(color: ILSTheme.shadowLight, radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, ILSTheme.spacingL)
            }
        }
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
                                .cornerRadius(ILSTheme.cornerRadiusS)
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

                if let source = fullSkill?.source ?? skill.source {
                    Label(source, systemImage: "folder")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.tertiaryText)
                }
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
                .cornerRadius(ILSTheme.cornerRadiusM)
                .textSelection(.enabled)
        }
    }

    // MARK: - Actions

    private func loadFullSkill() async {
        isLoading = true
        do {
            let client = APIClient()
            let response: APIResponse<SkillItem> = try await client.get("/skills/\(skill.name)")
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
        case edit(SkillItem)
    }

    let mode: Mode
    var viewModel: SkillsViewModel?
    let onSave: (SkillItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var content = ""
    @State private var isSaving = false

    init(mode: Mode, viewModel: SkillsViewModel? = nil, onSave: @escaping (SkillItem) -> Void) {
        self.mode = mode
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
            let client = APIClient()
            let response: APIResponse<SkillItem> = try await client.get("/skills/\(name)")
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
            let client = APIClient()

            do {
                if case .create = mode {
                    let request = CreateSkillRequest(
                        name: name,
                        description: description.isEmpty ? nil : description,
                        content: content
                    )
                    let response: APIResponse<SkillItem> = try await client.post("/skills", body: request)
                    if let skill = response.data {
                        await MainActor.run {
                            onSave(skill)
                            dismiss()
                        }
                    }
                } else {
                    let request = UpdateSkillRequest(content: content)
                    let response: APIResponse<SkillItem> = try await client.put("/skills/\(name)", body: request)
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

// MARK: - Request Types

struct CreateSkillRequest: Encodable {
    let name: String
    let description: String?
    let content: String
}

struct UpdateSkillRequest: Encodable {
    let content: String
}

#Preview {
    NavigationStack {
        SkillsListView()
    }
}
