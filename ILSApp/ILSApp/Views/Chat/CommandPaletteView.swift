import SwiftUI
import ILSShared

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var skills: [SkillItem] = []
    @State private var isLoading = true

    let onSelect: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                } else {
                    // Built-in commands
                    Section("Built-in") {
                        ForEach(builtInCommands) { command in
                            CommandRow(command: command, onSelect: selectCommand)
                        }
                    }

                    // Skills
                    if !filteredSkills.isEmpty {
                        Section("Skills") {
                            ForEach(filteredSkills) { skill in
                                SkillRow(skill: skill) {
                                    selectCommand("/\(skill.name)")
                                }
                            }
                        }
                    }

                    // Model switching
                    Section("Switch Model") {
                        ForEach(["sonnet", "opus", "haiku"], id: \.self) { model in
                            Button {
                                selectCommand("--model \(model)")
                            } label: {
                                Label(model.capitalized, systemImage: "cpu")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search commands...")
            .navigationTitle("Commands")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadSkills()
            }
        }
    }

    private var builtInCommands: [CommandItem] {
        [
            CommandItem(name: "/help", description: "Show help", icon: "questionmark.circle"),
            CommandItem(name: "/compact", description: "Compact conversation", icon: "arrow.down.right.and.arrow.up.left"),
            CommandItem(name: "/clear", description: "Clear conversation", icon: "trash"),
            CommandItem(name: "/config", description: "Show configuration", icon: "gear"),
        ].filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSkills: [SkillItem] {
        skills.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func selectCommand(_ command: String) {
        onSelect(command)
        dismiss()
    }

    private func loadSkills() async {
        isLoading = true
        do {
            let client = APIClient()
            let response: APIResponse<ListResponse<SkillItem>> = try await client.get("/skills")
            if let data = response.data {
                skills = data.items
            }
        } catch {
            print("Failed to load skills: \(error)")
        }
        isLoading = false
    }
}

struct CommandItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
}

struct CommandRow: View {
    let command: CommandItem
    let onSelect: (String) -> Void

    var body: some View {
        Button {
            onSelect(command.name)
        } label: {
            Label {
                VStack(alignment: .leading) {
                    Text(command.name)
                        .font(ILSTheme.bodyFont)
                    Text(command.description)
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
            } icon: {
                Image(systemName: command.icon)
                    .foregroundColor(ILSTheme.accent)
            }
        }
    }
}

struct SkillItem: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let version: String?
    let tags: [String]
    let isActive: Bool
    let path: String
    let source: String?
    let content: String?

    // Provide default values for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        path = try container.decode(String.self, forKey: .path)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        content = try container.decodeIfPresent(String.self, forKey: .content)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, version, tags, isActive, path, source, content
    }

    // Hashable conformance (hash by id only for navigation)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SkillItem, rhs: SkillItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct SkillRow: View {
    let skill: SkillItem
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Label {
                VStack(alignment: .leading) {
                    Text("/\(skill.name)")
                        .font(ILSTheme.bodyFont)
                    if let desc = skill.description {
                        Text(desc)
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: "star")
                    .foregroundColor(ILSTheme.accent)
            }
        }
    }
}

#Preview {
    CommandPaletteView { command in
        print("Selected: \(command)")
    }
}
