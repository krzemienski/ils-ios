import SwiftUI
import ILSShared

struct SkillsListView: View {
    @StateObject private var viewModel = SkillsViewModel()
    @State private var showingNewSkill = false
    @State private var selectedSkill: SkillItem?

    var body: some View {
        List {
            if viewModel.skills.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    "No Skills",
                    systemImage: "star",
                    description: Text("Create custom skills to extend Claude's capabilities")
                )
            } else {
                ForEach(viewModel.skills) { skill in
                    SkillRowView(skill: skill)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSkill = skill
                        }
                }
                .onDelete(perform: deleteSkill)
            }
        }
        .navigationTitle("Skills")
        .refreshable {
            await viewModel.loadSkills()
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
        .sheet(item: $selectedSkill) { skill in
            SkillEditorView(mode: .edit(skill), viewModel: viewModel) { _ in }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadSkills()
        }
    }

    private func deleteSkill(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let skill = viewModel.skills[index]
                await viewModel.deleteSkill(skill)
            }
        }
    }
}

struct SkillRowView: View {
    let skill: SkillItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("/\(skill.name)")
                    .font(ILSTheme.headlineFont)

                Spacer()

                if skill.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ILSTheme.success)
                }
            }

            if let description = skill.description {
                Text(description)
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
                    .lineLimit(2)
            }

            Text(skill.path)
                .font(ILSTheme.captionFont)
                .foregroundColor(ILSTheme.tertiaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
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
                    if let skill = response.data {
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
