import SwiftUI

// MARK: - Spec 186: Enhanced Command Palette & Keyboard Navigation

/// Settings screen for customising keyboard shortcut bindings and palette navigation options.
///
/// Displays all registered `GlobalCommand` entries grouped by `CommandCategory`,
/// showing the active shortcut hint (custom override if present, otherwise the command's
/// default). Provides toggles and actions for:
///
/// - **Vim Navigation** — enables `j`/`k` key navigation inside `GlobalCommandPaletteView`.
/// - **Export / Import** — serialises the `KeyboardShortcutStore` binding dictionary as
///   JSON so users can back up or share their shortcut configurations.
/// - **Reset to Defaults** — clears all custom overrides in one tap.
///
/// Accepts `CommandRegistry` and `KeyboardShortcutStore` as constructor parameters so
/// both can be created once in the parent view and shared across the settings hierarchy
/// without rebuilding state on every navigation push.
///
/// ## Topics
/// ### Input
/// - ``commandRegistry`` - Source of all registered commands grouped by category
/// - ``shortcutStore`` - Reads and writes custom shortcut bindings
///
/// ### Persisted Options
/// - ``vimModeEnabled`` - AppStorage flag shared with `GlobalCommandPaletteView`
///
/// ### Export / Import
/// - ``showExportSheet`` - Controls `ShareLink` sheet presentation
/// - ``exportData`` - JSON payload produced by `KeyboardShortcutStore.exportAsJSON()`
/// - ``showImportPicker`` - Controls `fileImporter` presentation
struct KeyboardShortcutsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let commandRegistry: CommandRegistry
    let shortcutStore: KeyboardShortcutStore

    @AppStorage("commandPaletteVimMode") private var vimModeEnabled: Bool = false

    @State private var showExportSheet = false
    @State private var exportData: Data? = nil
    @State private var showImportPicker = false
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {

                // MARK: Vim Navigation
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("Navigation")

                    VStack(spacing: theme.spacingSM) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vim Navigation")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Text("Use j and k keys to move in the command palette")
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: $vimModeEnabled)
                                .labelsHidden()
                                .tint(theme.accent)
                        }
                        .accessibilityLabel("Vim navigation mode")
                        .onChange(of: vimModeEnabled) {
                            HapticManager.selection()
                        }
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // MARK: Commands by Category
                ForEach(CommandCategory.allCases, id: \.rawValue) { category in
                    let commands = commandRegistry.allCommands.filter { $0.category == category }
                    if !commands.isEmpty {
                        commandCategorySection(category: category, commands: commands)
                    }
                }

                // MARK: Export / Import / Reset
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("Configuration")

                    VStack(spacing: 0) {
                        actionRow(
                            title: "Export Shortcuts",
                            icon: "square.and.arrow.up",
                            color: theme.accent
                        ) {
                            exportData = shortcutStore.exportAsJSON()
                            showExportSheet = true
                        }

                        Divider().background(theme.bgTertiary)

                        actionRow(
                            title: "Import Shortcuts",
                            icon: "square.and.arrow.down",
                            color: theme.accent
                        ) {
                            showImportPicker = true
                        }

                        Divider().background(theme.bgTertiary)

                        actionRow(
                            title: "Reset to Defaults",
                            icon: "arrow.counterclockwise",
                            color: Color.red.opacity(0.8)
                        ) {
                            showResetConfirmation = true
                        }
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // MARK: Info footer
                Text("Custom shortcuts are stored locally and can be exported as JSON for backup or sharing.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingXS)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Keyboard Shortcuts")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .sheet(isPresented: $showExportSheet) {
            if let data = exportData {
                ShareLink(
                    item: data,
                    preview: SharePreview("shortcuts.json", image: Image(systemName: "keyboard"))
                )
                .presentationDetents([.medium])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json]
        ) { result in
            if case .success(let url) = result,
               let data = try? Data(contentsOf: url) {
                _ = shortcutStore.importFromJSON(data)
                HapticManager.selection()
            }
        }
        .confirmationDialog(
            "Reset to Defaults",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All Shortcuts", role: .destructive) {
                shortcutStore.resetToDefaults()
                HapticManager.selection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all custom keyboard shortcut bindings and restore the defaults.")
        }
    }

    // MARK: - Command Category Section

    @ViewBuilder
    private func commandCategorySection(category: CommandCategory, commands: [GlobalCommand]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: category.icon)
                    .font(.system(size: theme.fontCaption, weight: .semibold))
                    .foregroundStyle(theme.accent)
                sectionLabel(category.displayName)
            }

            VStack(spacing: 0) {
                ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                    commandRow(command)
                    if index < commands.count - 1 {
                        Divider().background(theme.bgTertiary)
                    }
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    // MARK: - Command Row

    @ViewBuilder
    private func commandRow(_ command: GlobalCommand) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: command.icon)
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(command.subtitle)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            shortcutBadge(for: command)
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(command.title): \(shortcutDisplayText(for: command))")
    }

    // MARK: - Shortcut Badge

    @ViewBuilder
    private func shortcutBadge(for command: GlobalCommand) -> some View {
        let label = shortcutDisplayText(for: command)
        Text(label)
            .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
            .foregroundStyle(label == "None" ? theme.textTertiary.opacity(0.5) : theme.textSecondary)
            .padding(.horizontal, theme.spacingXS)
            .padding(.vertical, 2)
            .background(
                label == "None"
                    ? Color.clear
                    : theme.bgTertiary.opacity(0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func shortcutDisplayText(for command: GlobalCommand) -> String {
        if let custom = shortcutStore.binding(for: command.id) {
            return custom.displayString
        }
        return command.defaultShortcutDisplay ?? "None"
    }

    // MARK: - Action Row

    @ViewBuilder
    private func actionRow(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody))
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(title == "Reset to Defaults" ? Color.red.opacity(0.8) : theme.textPrimary)
                Spacer()
            }
            .padding(.vertical, theme.spacingXS)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Section Label

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }
}

#Preview {
    NavigationStack {
        KeyboardShortcutsView(
            commandRegistry: CommandRegistry(),
            shortcutStore: KeyboardShortcutStore()
        )
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
