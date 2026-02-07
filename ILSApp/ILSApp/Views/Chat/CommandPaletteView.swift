import SwiftUI
import ILSShared

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var skills: [Skill] = []
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
            .darkListStyle()
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

    private static let allBuiltInCommands: [CommandItem] = [
        CommandItem(name: "/compact", description: "Compact conversation history to reduce context usage", icon: "arrow.down.right.and.arrow.up.left"),
        CommandItem(name: "/clear", description: "Clear conversation history and start fresh", icon: "trash"),
        CommandItem(name: "/config", description: "View or modify Claude Code configuration", icon: "gear"),
        CommandItem(name: "/cost", description: "Show token usage and cost for this session", icon: "dollarsign.circle"),
        CommandItem(name: "/doctor", description: "Run diagnostics to check for common issues", icon: "stethoscope"),
        CommandItem(name: "/help", description: "Show available commands and usage information", icon: "questionmark.circle"),
        CommandItem(name: "/init", description: "Initialize a new CLAUDE.md project memory file", icon: "doc.badge.plus"),
        CommandItem(name: "/login", description: "Log in to your Anthropic account", icon: "person.crop.circle.badge.checkmark"),
        CommandItem(name: "/logout", description: "Log out of your Anthropic account", icon: "person.crop.circle.badge.xmark"),
        CommandItem(name: "/mcp", description: "View and manage MCP server connections", icon: "server.rack"),
        CommandItem(name: "/memory", description: "Edit CLAUDE.md project memory file", icon: "brain"),
        CommandItem(name: "/model", description: "Switch the active Claude model", icon: "cpu"),
        CommandItem(name: "/permissions", description: "View and manage tool permissions", icon: "lock.shield"),
        CommandItem(name: "/review", description: "Request a code review of recent changes", icon: "eye"),
        CommandItem(name: "/status", description: "Show current session status and connection info", icon: "info.circle"),
        CommandItem(name: "/terminal-setup", description: "Install shell integration for enhanced terminal support", icon: "terminal"),
    ]

    private var builtInCommands: [CommandItem] {
        Self.allBuiltInCommands.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSkills: [Skill] {
        skills.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func selectCommand(_ command: String) {
        onSelect(command)
        dismiss()
    }

    private func loadSkills() async {
        isLoading = true
        do {
            let client = appState.apiClient
            let response: APIResponse<ListResponse<Skill>> = try await client.get("/skills")
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

struct SkillRow: View {
    let skill: Skill
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
