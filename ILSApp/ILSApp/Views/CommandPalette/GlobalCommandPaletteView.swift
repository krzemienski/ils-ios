import SwiftUI

/// Full-featured global command palette with fuzzy search, category grouping,
/// recently used commands, keyboard shortcut hints, keyboard navigation (arrow keys
/// and optional vim j/k), and type-ahead filtering.
///
/// Present this view as a sheet from a host view that owns `CommandRegistry` and
/// `KeyboardShortcutStore`. On macOS, consider wrapping in `.frame(minWidth:minHeight:)`
/// for a compact panel feel.
///
/// ## Topics
/// ### State
/// - ``searchText`` - Live query that drives debounced filtering via `.task(id:)`
/// - ``filteredCommands`` - Commands shown in the list, updated after a 100 ms debounce
/// - ``selectedIndex`` - Currently highlighted row index for keyboard navigation
/// - ``vimModeEnabled`` - Persisted via `@AppStorage`; enables j/k as Up/Down
/// - ``isSearchFocused`` - `FocusState` used to auto-focus the search field on appear
///
/// ### Callbacks
/// - ``onSelect`` - Receives the chosen `GlobalCommand`; called before dismiss
///
/// ### Sub-Views
/// - ``GlobalCommandRow`` - Single command row with icon, title, subtitle, and shortcut badge
struct GlobalCommandPaletteView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Dependencies

    /// Registry that owns `allCommands`, `recentCommands()`, and `search(query:)`.
    let registry: CommandRegistry
    /// Store that resolves custom shortcut bindings per command ID.
    let shortcutStore: KeyboardShortcutStore
    /// Called with the selected command before the view is dismissed.
    let onSelect: (GlobalCommand) -> Void

    // MARK: - State

    /// The current search query string.
    @State private var searchText = ""
    /// Commands shown in the results list; updated with a 100 ms debounce.
    @State private var filteredCommands: [GlobalCommand] = []
    /// Index of the currently highlighted row.
    @State private var selectedIndex: Int = 0
    /// When `true`, j/k keys move selection up and down.
    @AppStorage("commandPaletteVimMode") private var vimModeEnabled: Bool = false

    @FocusState private var isSearchFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
                .background(theme.border)
            resultsList
        }
        .background(theme.bgPrimary)
        .navigationTitle("Command Palette")
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
        // Auto-focus the search field when the palette appears.
        .task {
            isSearchFocused = true
            filteredCommands = registry.allCommands
        }
        // Debounce filtering: wait 100 ms after the user stops typing.
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            filteredCommands = registry.search(query: searchText)
            selectedIndex = 0
        }
        .preferredColorScheme(.dark)
        // Keyboard navigation
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        // Vim-style j/k navigation (only when vim mode is enabled and search field is empty,
        // so regular typing still works).
        .onKeyPress("j") {
            guard vimModeEnabled, searchText.isEmpty else { return .ignored }
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress("k") {
            guard vimModeEnabled, searchText.isEmpty else { return .ignored }
            moveSelection(by: -1)
            return .handled
        }
    }

    // MARK: - Sub-Views

    /// Styled search field with a magnifying glass leading icon and a clear button.
    private var searchField: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textSecondary)

            TextField("Search commands…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .focused($isSearchFocused)
                .onSubmit { executeSelected() }
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingMD)
        .background(theme.bgPrimary)
    }

    /// Scrollable list of command rows, grouped when search is empty.
    @ViewBuilder
    private var resultsList: some View {
        if searchText.isEmpty {
            emptySearchList
        } else {
            filteredList
        }
    }

    /// When search is empty: show recently used commands at top, then all commands
    /// grouped by category.
    private var emptySearchList: some View {
        List {
            let recent = registry.recentCommands()
            if !recent.isEmpty {
                Section("Recently Used") {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { offset, command in
                        commandRow(command, listOffset: offset)
                    }
                }
            }

            let recentIds = Set(recent.map(\.id))
            let baseOffset = recent.count

            ForEach(CommandCategory.allCases, id: \.self) { category in
                let commands = registry.allCommands.filter {
                    $0.category == category && !recentIds.contains($0.id)
                }
                if !commands.isEmpty {
                    Section(category.displayName) {
                        ForEach(Array(commands.enumerated()), id: \.element.id) { offset, command in
                            let absoluteIndex = baseOffset
                                + categoryOffset(for: category, recentIds: recentIds)
                                + offset
                            commandRowWithIndex(command, index: absoluteIndex)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
    }

    /// When search is not empty: flat list of fuzzy-matched results.
    private var filteredList: some View {
        List {
            Section(filteredCommands.isEmpty ? "No Results" : "Results") {
                ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                    commandRow(command, listOffset: index)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
    }

    /// Renders a `GlobalCommandRow` for a command at the given list offset, highlighting
    /// when `selectedIndex` matches.
    private func commandRow(_ command: GlobalCommand, listOffset: Int) -> some View {
        GlobalCommandRow(
            command: command,
            shortcutLabel: shortcutLabel(for: command),
            isSelected: selectedIndex == listOffset,
            onSelect: { selectCommand(command) }
        )
        .listRowBackground(
            selectedIndex == listOffset
                ? theme.accent.opacity(0.15)
                : Color.clear
        )
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { selectCommand(command) }
    }

    /// Overload that accepts an explicit absolute index for grouped sections.
    private func commandRowWithIndex(_ command: GlobalCommand, index: Int) -> some View {
        GlobalCommandRow(
            command: command,
            shortcutLabel: shortcutLabel(for: command),
            isSelected: selectedIndex == index,
            onSelect: { selectCommand(command) }
        )
        .listRowBackground(
            selectedIndex == index
                ? theme.accent.opacity(0.15)
                : Color.clear
        )
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { selectCommand(command) }
    }

    // MARK: - Helpers

    /// Total number of visible command rows across all currently shown sections.
    private var totalVisibleCount: Int {
        searchText.isEmpty
            ? registry.recentCommands().count + registry.allCommands.filter {
                !Set(registry.recentCommands().map(\.id)).contains($0.id)
              }.count
            : filteredCommands.count
    }

    /// Clamps `selectedIndex` and moves it by `delta`.
    private func moveSelection(by delta: Int) {
        let count = totalVisibleCount
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    /// Executes the command at `selectedIndex`, records usage, calls `onSelect`, and dismisses.
    private func executeSelected() {
        let commands: [GlobalCommand]
        if searchText.isEmpty {
            let recent = registry.recentCommands()
            let recentIds = Set(recent.map(\.id))
            let remaining = registry.allCommands.filter { !recentIds.contains($0.id) }
            commands = recent + remaining
        } else {
            commands = filteredCommands
        }
        guard selectedIndex < commands.count else { return }
        selectCommand(commands[selectedIndex])
    }

    /// Records usage, invokes the caller's `onSelect` closure, and dismisses.
    private func selectCommand(_ command: GlobalCommand) {
        registry.recordUsage(commandId: command.id)
        onSelect(command)
        dismiss()
    }

    /// Returns the display label for a command's keyboard shortcut.
    /// Prefers a custom binding from `shortcutStore`; falls back to `defaultShortcutDisplay`.
    private func shortcutLabel(for command: GlobalCommand) -> String? {
        shortcutStore.binding(for: command.id)?.displayString
            ?? command.defaultShortcutDisplay
    }

    /// Computes the absolute list index offset for a category in the "recently used empty"
    /// grouped view. Used to map `selectedIndex` to the correct command row.
    private func categoryOffset(for targetCategory: CommandCategory, recentIds: Set<String>) -> Int {
        var offset = 0
        for category in CommandCategory.allCases {
            if category == targetCategory { break }
            offset += registry.allCommands.filter {
                $0.category == category && !recentIds.contains($0.id)
            }.count
        }
        return offset
    }
}

// MARK: - GlobalCommandRow

/// A single row in the global command palette.
///
/// Displays the command icon, title, subtitle, and an optional keyboard shortcut badge.
/// The row uses a highlighted background when `isSelected` is `true`.
struct GlobalCommandRow: View {

    let command: GlobalCommand
    /// Shortcut display string (e.g. "⌘N"), or `nil` if no shortcut is assigned.
    let shortcutLabel: String?
    /// When `true`, the row's background is tinted with the accent color.
    let isSelected: Bool
    /// Called when the row is tapped.
    let onSelect: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: theme.spacingMD) {
                Image(systemName: command.icon)
                    .font(.system(size: theme.fontTitle3, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    Text(command.subtitle)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if let label = shortcutLabel {
                    Text(label)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, 2)
                        .background(theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                                .stroke(theme.border, lineWidth: 0.5)
                        )
                }
            }
            .padding(.vertical, theme.spacingSM)
            .padding(.horizontal, theme.spacingMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let registry = CommandRegistry()
    let store = KeyboardShortcutStore()
    return NavigationStack {
        GlobalCommandPaletteView(
            registry: registry,
            shortcutStore: store
        ) { command in
            AppLogger.shared.info("Selected: \(command.title)", category: "ui")
        }
    }
    .preferredColorScheme(.dark)
}
