import SwiftUI
import ILSShared

/// Searchable modal presenting three command sections: built-in slash commands, loaded skills, and model switching.
///
/// Built-in commands are a static list of 16 `CommandItem` entries. Skills are fetched
/// asynchronously from the `/skills` API endpoint on appearance. The "Switch Model" section
/// is always static. All three sections are filtered by a single ``searchText`` binding
/// via `.searchable` using ``FuzzyMatcher`` for fuzzy matching and relevance-ranked results.
/// Toolbar and navigation-bar styling differs between iOS and macOS via `#if os(iOS)` guards.
///
/// Selecting any entry calls ``onSelect`` with the formatted command string and dismisses the sheet.
///
/// ## Topics
/// ### State
/// - ``searchText`` - Live search query that filters all three list sections
/// - ``skills`` - Skills fetched from the `/skills` endpoint
/// - ``isLoading`` - True while the skills API call is in flight
///
/// ### Callbacks
/// - ``onSelect`` - Receives the formatted command string (e.g. `/compact`, `--model opus`)
///
/// ### Debounced Filtering
/// - ``debouncedBuiltInCommands`` - Built-in commands filtered by search via `.task(id:)`
/// - ``debouncedFilteredSkills`` - Skills filtered by search via `.task(id:)`
///
/// ### Async Loading
/// - ``loadSkills()`` - Fetches skills from the API and populates ``skills``
/// - ``selectCommand(_:)`` - Forwards the chosen command to ``onSelect`` and dismisses
///
/// ### Sub-Views
/// - ``CommandRow`` - Styled list row for a built-in `CommandItem`
/// - ``SkillRow`` - Styled list row for an API-loaded `Skill`
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) var appState
    /// Live search text used to filter all three command sections.
    @State private var searchText = ""
    /// Skills loaded from the `/skills` API endpoint.
    @State private var skills: [Skill] = Self.cachedSkills
    /// True while the initial skills API call is in flight.
    @State private var isLoading = Self.cachedSkills.isEmpty

    // SPERF-MED-5: Static cache avoids re-fetching skills on every sheet presentation.
    // Skills rarely change during a session, so caching across presentations is safe.
    @MainActor private static var cachedSkills: [Skill] = []
    /// Debounced filtered built-in commands.
    @State private var debouncedBuiltInCommands: [CommandItem] = Self.allBuiltInCommands
    /// Debounced filtered skills.
    @State private var debouncedFilteredSkills: [Skill] = []

    /// Called with the formatted command string when the user selects an entry.
    let onSelect: (String) -> Void

    var body: some View {
        List {
            if isLoading {
                ProgressView()
            } else {
                // Built-in commands
                Section("Built-in") {
                    ForEach(debouncedBuiltInCommands) { command in
                        CommandRow(command: command, onSelect: selectCommand)
                    }
                }

                // Skills
                if !debouncedFilteredSkills.isEmpty {
                    Section("Skills") {
                        ForEach(debouncedFilteredSkills) { skill in
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
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .searchable(text: $searchText, prompt: "Search commands...")
        .navigationTitle("Commands")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        #if os(iOS)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(theme.bgPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        // SPERF-MED-5: Only fetch skills once — cache across presentations.
        .task {
            if skills.isEmpty {
                await loadSkills()
            } else {
                isLoading = false
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            if searchText.isEmpty {
                debouncedBuiltInCommands = Self.allBuiltInCommands
                debouncedFilteredSkills = skills
            } else {
                // Fuzzy-filter built-in commands and rank by best score across name and description
                debouncedBuiltInCommands = Self.allBuiltInCommands
                    .compactMap { command -> (CommandItem, Double)? in
                        let nameScore = FuzzyMatcher.score(query: searchText, in: command.name)
                        let descScore = FuzzyMatcher.score(query: searchText, in: command.description)
                        let best = max(nameScore, descScore)
                        return best > 0.1 ? (command, best) : nil
                    }
                    .sorted { $0.1 > $1.1 }
                    .map(\.0)

                // Fuzzy-filter skills and rank by score
                debouncedFilteredSkills = skills
                    .compactMap { skill -> (Skill, Double)? in
                        let nameScore = FuzzyMatcher.score(query: searchText, in: skill.name)
                        let descScore = skill.description.map { FuzzyMatcher.score(query: searchText, in: $0) } ?? 0.0
                        let best = max(nameScore, descScore)
                        return best > 0.1 ? (skill, best) : nil
                    }
                    .sorted { $0.1 > $1.1 }
                    .map(\.0)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// The complete set of 16 supported slash commands, shown unfiltered when search is empty.
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
        CommandItem(name: "/terminal-setup", description: "Install shell integration for enhanced terminal support", icon: "terminal")
    ]

    /// Forwards the selected command string to ``onSelect`` and dismisses the sheet.
    private func selectCommand(_ command: String) {
        onSelect(command)
        dismiss()
    }

    /// Fetches available skills from the `/skills` endpoint and populates ``skills``.
    ///
    /// Errors are logged via `AppLogger` and result in an empty skills section rather
    /// than surfacing an error to the user.
    private func loadSkills() async {
        isLoading = true
        do {
            let client = appState.apiClient
            let response: APIResponse<ListResponse<Skill>> = try await client.get("/skills")
            if let data = response.data {
                skills = data.items
                Self.cachedSkills = data.items
            }
        } catch {
            AppLogger.shared.error("Failed to load skills: \(error)", category: "ui")
        }
        isLoading = false
    }
}

/// Value type representing a single built-in slash command entry in the command palette.
struct CommandItem: Identifiable {
    let id = UUID()
    /// The slash command string, e.g. `/compact`.
    let name: String
    /// Short human-readable description shown below the command name.
    let description: String
    /// SF Symbol name used as the row icon.
    let icon: String
}

/// Styled list row displaying a `CommandItem` with its icon, name, and description.
struct CommandRow: View {
    /// The command to display.
    let command: CommandItem
    /// Called with `command.name` when the row is tapped.
    let onSelect: (String) -> Void
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button {
            onSelect(command.name)
        } label: {
            Label {
                VStack(alignment: .leading) {
                    Text(command.name)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    Text(command.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            } icon: {
                Image(systemName: command.icon)
                    .foregroundStyle(theme.accent)
            }
        }
    }
}

/// Styled list row displaying an API-loaded `Skill` with its name and optional description.
struct SkillRow: View {
    /// The skill to display.
    let skill: Skill
    /// Called when the row is tapped.
    let onSelect: () -> Void
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: onSelect) {
            Label {
                VStack(alignment: .leading) {
                    Text("/\(skill.name)")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    if let desc = skill.description {
                        Text(desc)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            } icon: {
                Image(systemName: "star")
                    .foregroundStyle(theme.accent)
            }
        }
    }
}

#Preview {
    CommandPaletteView { command in
        AppLogger.shared.info("Selected: \(command)", category: "ui")
    }
}
