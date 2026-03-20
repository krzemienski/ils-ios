#if os(iOS)
import SwiftUI

/// Overlay that displays voice command recognition results, confirmation prompts,
/// and execution feedback above the chat input bar.
///
/// Driven by `VoiceCommandExecutor.executionState`, this overlay adapts its content
/// to show the appropriate UI for each phase of the voice command lifecycle:
/// - **Confirming**: Shows the matched command with Confirm/Cancel buttons for destructive actions.
/// - **Executing**: Shows a progress indicator with the command being executed.
/// - **Completed**: Shows a success message that auto-dismisses after a short delay.
/// - **Failed**: Shows an error message with a Dismiss button.
///
/// For ambiguous matches, a separate `ambiguousView` lets the user pick from candidates.
/// For no-match results, a `noMatchView` displays contextual suggestions.
///
/// ## Topics
/// ### State
/// - ``executionState`` — Bound to `VoiceCommandExecutor.executionState`.
/// - ``matchResult`` — The most recent `VoiceCommandMatch` from the interpreter.
///
/// ### Callbacks
/// - ``onConfirm`` — Called when the user confirms a destructive command.
/// - ``onCancel`` — Called when the user cancels a pending confirmation.
/// - ``onDismiss`` — Called when the overlay should be hidden (after completion/failure).
/// - ``onSelectCommand`` — Called when the user picks a command from ambiguous/suggestion lists.
struct VoiceCommandOverlay: View {
    /// The current execution state from the command executor.
    let executionState: VoiceCommandExecutionState
    /// The most recent match result from the interpreter, if any.
    let matchResult: VoiceCommandMatch?
    /// Called when the user confirms a destructive command.
    let onConfirm: () -> Void
    /// Called when the user cancels a pending confirmation.
    let onCancel: () -> Void
    /// Called when the overlay should be dismissed.
    let onDismiss: () -> Void
    /// Called when the user selects a command from an ambiguous or suggestion list.
    let onSelectCommand: (VoiceCommand) -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: theme.spacingMD) {
            switch executionState {
            case .idle:
                idleMatchView
            case .confirming(let command):
                confirmingView(command)
            case .executing(let command):
                executingView(command)
            case .completed(let command, let message):
                completedView(command, message: message)
            case .failed(let command, let message):
                failedView(command, message: message)
            }
        }
        .padding(theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius * 2)
                .fill(theme.bgSecondary)
                .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        )
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
        .onDisappear {
            autoDismissTask?.cancel()
            autoDismissTask = nil
        }
        .accessibilityIdentifier("voice-command-overlay")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice command")
    }

    // MARK: - Idle / Match Result

    /// When the executor is idle but we have a match result from the interpreter,
    /// show ambiguous or no-match suggestions.
    @ViewBuilder
    private var idleMatchView: some View {
        if let matchResult {
            switch matchResult {
            case .ambiguous(let candidates):
                ambiguousView(candidates)
            case .noMatch(let suggestions):
                noMatchView(suggestions)
            case .exact, .fuzzy:
                // Handled by executor state transitions, not shown here
                EmptyView()
            }
        }
    }

    // MARK: - Confirming

    private func confirmingView(_ command: VoiceCommand) -> some View {
        VStack(spacing: theme.spacingMD) {
            // Header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(theme.warning)

                Text("Confirm Command")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()
            }

            // Command info
            commandCard(command)

            if command.isDestructive {
                Label("This action cannot be undone", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }

            // Confirm / Cancel buttons
            HStack(spacing: theme.spacingSM) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius)
                                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
                        )
                }
                .accessibilityIdentifier("voice-command-cancel")
                .accessibilityLabel("Cancel voice command")

                Button(action: onConfirm) {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm")
                    }
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius)
                            .fill(command.isDestructive ? theme.error : theme.accent)
                    )
                }
                .accessibilityIdentifier("voice-command-confirm")
                .accessibilityLabel("Confirm \(command.displayName)")
            }
        }
    }

    // MARK: - Executing

    private func executingView(_ command: VoiceCommand) -> some View {
        HStack(spacing: theme.spacingSM) {
            ProgressView()
                .tint(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Executing")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                Text(command.displayName)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()

            Image(systemName: command.icon)
                .font(.system(size: 20, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
        }
    }

    // MARK: - Completed

    private func completedView(_ command: VoiceCommand, message: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24, design: theme.fontDesign))
                .foregroundStyle(theme.success)

            VStack(alignment: .leading, spacing: 2) {
                Text(command.displayName)
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .onAppear { scheduleAutoDismiss() }
    }

    // MARK: - Failed

    private func failedView(_ command: VoiceCommand, message: String) -> some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24, design: theme.fontDesign))
                    .foregroundStyle(theme.error)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.displayName)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(message)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.error)
                        .lineLimit(3)
                }

                Spacer()
            }

            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadius)
                            .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
                    )
            }
            .accessibilityIdentifier("voice-command-dismiss")
            .accessibilityLabel("Dismiss error")
        }
    }

    // MARK: - Ambiguous

    private func ambiguousView(_ candidates: [VoiceCommand]) -> some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(theme.warning)

                Text("Did you mean?")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityLabel("Dismiss suggestions")
            }

            ForEach(candidates, id: \.id) { command in
                Button { onSelectCommand(command) } label: {
                    commandRow(command)
                }
            }
        }
    }

    // MARK: - No Match

    private func noMatchView(_ suggestions: [VoiceCommand]) -> some View {
        VStack(spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Text("Command not recognized")
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
                .accessibilityLabel("Dismiss")
            }

            if !suggestions.isEmpty {
                Text("Try one of these:")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(suggestions, id: \.id) { command in
                    Button { onSelectCommand(command) } label: {
                        commandRow(command)
                    }
                }
            }
        }
    }

    // MARK: - Shared Components

    /// A card showing the matched command's icon, name, and description.
    private func commandCard(_ command: VoiceCommand) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: command.icon)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 28, height: 28)
                .background(theme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(alignment: .leading, spacing: 2) {
                Text(command.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(command.description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if command.isDestructive {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
            }
        }
        .padding(theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(GlassCard())
    }

    /// A tappable row for command selection in ambiguous/suggestion lists.
    private func commandRow(_ command: VoiceCommand) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: command.icon)
                .font(.system(size: 14, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(command.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text(command.description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.bgTertiary.opacity(0.5))
        )
        .contentShape(Rectangle())
    }

    // MARK: - Auto-Dismiss

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Confirming") {
    let command = VoiceCommandCatalog.allCommands.first { $0.id == "voice-delete-session" }!
    VoiceCommandOverlay(
        executionState: .confirming(command),
        matchResult: nil,
        onConfirm: {},
        onCancel: {},
        onDismiss: {},
        onSelectCommand: { _ in }
    )
    .padding()
}

#Preview("Executing") {
    let command = VoiceCommandCatalog.allCommands.first { $0.id == "voice-approve" }!
    VoiceCommandOverlay(
        executionState: .executing(command),
        matchResult: nil,
        onConfirm: {},
        onCancel: {},
        onDismiss: {},
        onSelectCommand: { _ in }
    )
    .padding()
}

#Preview("Completed") {
    let command = VoiceCommandCatalog.allCommands.first { $0.id == "voice-approve" }!
    VoiceCommandOverlay(
        executionState: .completed(command, "Permission approved"),
        matchResult: nil,
        onConfirm: {},
        onCancel: {},
        onDismiss: {},
        onSelectCommand: { _ in }
    )
    .padding()
}

#Preview("Failed") {
    let command = VoiceCommandCatalog.allCommands.first { $0.id == "voice-approve" }!
    VoiceCommandOverlay(
        executionState: .failed(command, "No pending permission requests."),
        matchResult: nil,
        onConfirm: {},
        onCancel: {},
        onDismiss: {},
        onSelectCommand: { _ in }
    )
    .padding()
}

#Preview("Ambiguous") {
    let candidates = Array(VoiceCommandCatalog.allCommands.prefix(3))
    VoiceCommandOverlay(
        executionState: .idle,
        matchResult: .ambiguous(candidates),
        onConfirm: {},
        onCancel: {},
        onDismiss: {},
        onSelectCommand: { _ in }
    )
    .padding()
}
#endif
