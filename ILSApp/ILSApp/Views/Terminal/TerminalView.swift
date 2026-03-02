import SwiftUI
import ILSShared

/// Embedded terminal screen for running shell commands and Claude Code CLI operations.
///
/// Presents a scrollable ``TerminalOutputView``, a horizontal quick-actions bar for
/// common Claude Code CLI commands, and a text-field input row with a send button.
/// A `ProgressView` overlay is shown while a command is executing.
///
/// ## Topics
/// ### State
/// - ``viewModel`` - Manages command execution, output lines, and command history
///
/// ### View Components
/// - ``quickActionsBar`` - Horizontally scrollable row of pre-populated command chips
/// - ``inputBar`` - TextField + send button at the bottom of the screen
///
/// ### Quick Actions
/// Tapping a quick-action chip inserts the associated command into the input field and
/// executes it immediately, matching the power-user workflow targeted by this feature.
struct TerminalView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot

    @State private var viewModel = TerminalViewModel()

    /// Pre-populated Claude Code CLI quick actions.
    private let quickActions: [(label: String, icon: String, command: String)] = [
        ("Status",    "checkmark.circle",    "claude --version"),
        ("ls",        "folder",              "ls -la"),
        ("pwd",       "location",            "pwd"),
        ("Git Status","arrow.triangle.branch","git status"),
        ("Git Log",   "clock",               "git log --oneline -10"),
        ("Processes", "cpu",                 "ps aux | head -20"),
        ("Disk",      "internaldrive",       "df -h"),
        ("Memory",    "memorychip",          "free -h 2>/dev/null || vm_stat"),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Terminal output — fills all available space
                TerminalOutputView(lines: viewModel.outputLines)
                    .frame(maxHeight: .infinity)

                Divider()
                    .background(theme.bgTertiary)

                // Quick actions bar
                quickActionsBar

                Divider()
                    .background(theme.bgTertiary)

                // Input row
                inputBar
            }
            .background(theme.bgPrimary)

            // Running overlay
            if viewModel.isRunning {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                ProgressView()
                    .tint(theme.entitySystem)
                    .scaleEffect(1.4)
            }
        }
        .navigationTitle("Terminal")
        .inlineNavigationBarTitle()
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                clearButton
            }
            #else
            ToolbarItem(placement: .automatic) {
                clearButton
            }
            #endif
        }
        .task {
            viewModel.configure(client: appState.apiClient)
        }
    }

    // MARK: - Quick Actions Bar

    /// Horizontally scrollable row of one-tap command chips.
    private var quickActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingSM) {
                ForEach(quickActions, id: \.command) { action in
                    Button {
                        viewModel.commandInput = action.command
                        Task { await viewModel.executeCommand() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            Text(action.label)
                                .font(
                                    .system(
                                        size: theme.fontCaption,
                                        weight: .medium,
                                        design: theme.fontDesign
                                    )
                                )
                        }
                        .foregroundStyle(theme.entitySystem)
                        .padding(.horizontal, theme.spacingSM)
                        .padding(.vertical, 6)
                        .background(theme.entitySystem.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRunning)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgSecondary)
    }

    // MARK: - Input Bar

    /// Command text field with send button.
    private var inputBar: some View {
        HStack(spacing: theme.spacingSM) {
            // Working directory indicator
            Text(viewModel.currentDirectory)
                .font(.system(size: theme.fontCaption, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 80)

            // Command input field
            TextField("Enter command…", text: Binding(
                get: { viewModel.commandInput },
                set: { viewModel.commandInput = $0 }
            ))
            .font(.system(size: theme.fontBody, design: .monospaced))
            .foregroundStyle(theme.textPrimary)
            .tint(theme.entitySystem)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.send)
            .onSubmit {
                guard !viewModel.isRunning else { return }
                Task { await viewModel.executeCommand() }
            }

            // Send button
            Button {
                guard !viewModel.isRunning else { return }
                Task { await viewModel.executeCommand() }
            } label: {
                Image(systemName: viewModel.isRunning ? "stop.circle" : "arrow.up.circle.fill")
                    .font(.system(size: theme.fontTitle2, design: theme.fontDesign))
                    .foregroundStyle(
                        viewModel.commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? theme.textTertiary
                            : theme.entitySystem
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.commandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isRunning
            )
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .background(theme.bgSecondary)
    }

    // MARK: - Toolbar Items

    /// Toolbar button that clears all terminal output.
    private var clearButton: some View {
        Button {
            viewModel.clearOutput()
        } label: {
            Image(systemName: "trash")
                .foregroundStyle(theme.textSecondary)
        }
        .disabled(viewModel.outputLines.isEmpty)
        .accessibilityLabel("Clear terminal output")
    }
}

#Preview {
    NavigationStack {
        TerminalView()
            .environment(AppState())
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
