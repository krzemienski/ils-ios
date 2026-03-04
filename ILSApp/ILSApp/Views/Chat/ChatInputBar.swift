import SwiftUI
import ILSShared

/// Multi-control input bar for composing and sending messages to Claude.
///
/// Renders a horizontal row containing a command-palette trigger, an advanced-options button,
/// a documentation help button, an expandable text field, and either a send button or a
/// cancel button depending on ``isStreaming``. The send button uses a Task-based debounce
/// to briefly animate a "pressed" spring scale effect before resetting, bypassed when
/// reduce-motion is enabled.
///
/// ## Topics
/// ### Bindings
/// - ``text`` - Two-way binding to the current input text
///
/// ### Input Properties
/// - ``isStreaming`` - When true, the send button is replaced by the cancel button
/// - ``isDisabled`` - Disables all controls while processing or during an error state
/// - ``hasCustomOptions`` - Drives an alternative icon on the options button to signal non-default settings
///
/// ### Callbacks
/// - ``onSend`` - Invoked when the user taps the send button
/// - ``onCancel`` - Invoked when the user taps the cancel/stop button during streaming
/// - ``onCommandPalette`` - Invoked to open the command palette sheet
/// - ``onAdvancedOptions`` - Invoked to open the advanced chat options sheet
///
/// ### Button Views
/// - ``commandPaletteButton`` - Slash-command launcher (⌘ icon)
/// - ``optionsButton`` - Advanced options toggle; adapts icon when custom options are active
/// - ``helpButton`` - Documentation quick-access; opens DocumentationView filtered for commands
/// - ``textField`` - Vertically expandable text input (1–5 lines)
/// - ``cancelButton`` - Stop button shown during streaming
/// - ``sendButton`` - Spring-animated send button with haptic feedback
struct ChatInputBar: View {
    /// Two-way binding to the message text being composed.
    @Binding var text: String
    /// When true, replaces the send button with the cancel/stop button.
    let isStreaming: Bool
    /// Disables all input controls while the view is in a non-interactive state.
    var isDisabled: Bool = false
    /// When true, changes the options button icon to indicate non-default settings are active.
    var hasCustomOptions: Bool = false
    /// Called when the user sends the composed message.
    let onSend: () -> Void
    /// Called when the user cancels an active streaming response.
    let onCancel: () -> Void
    /// Called to open the command palette sheet.
    let onCommandPalette: () -> Void
    /// Called to open the advanced chat options sheet.
    let onAdvancedOptions: () -> Void
    /// Number of outgoing messages currently queued while offline.
    /// When > 0, a `QueuedMessageBadge` is shown above the input row.
    var pendingCount: Int = 0
    /// Drives the spring scale animation on the send button when tapped.
    @State private var sendButtonPressed = false
    /// Debounce task that resets ``sendButtonPressed`` after the animation completes.
    @State private var resetTask: Task<Void, Never>?
    /// When true, the documentation sheet is presented pre-filtered for slash commands.
    @State private var showDocumentation = false
    @FocusState private var isInputFocused: Bool

    /// Dynamic horizontal padding for the text field, scales with text size preference.
    @ScaledMetric(relativeTo: .body) private var inputPaddingH: CGFloat = 12
    /// Dynamic vertical padding for the text field, scales with text size preference.
    @ScaledMetric(relativeTo: .body) private var inputPaddingV: CGFloat = 8

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            theme.divider.frame(height: 0.5)

            // Offline queue badge — shown when messages are waiting for connectivity.
            if pendingCount > 0 {
                HStack {
                    QueuedMessageBadge(pendingCount: pendingCount)
                    Spacer()
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingXS)
            }

            HStack(spacing: theme.spacingSM) {
                commandPaletteButton
                optionsButton
                helpButton
                textField
                if isStreaming {
                    cancelButton
                } else {
                    sendButton
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgSecondary)
        .accessibilityIdentifier("chat-input-bar")
        .onDisappear { resetTask?.cancel() }
        .sheet(isPresented: $showDocumentation) {
            NavigationStack {
                DocumentationView(contextHint: "commands")
            }
        }
    }

    private var commandPaletteButton: some View {
        Button(action: onCommandPalette) {
            Image(systemName: "command")
                .font(.system(size: 20))
                .foregroundStyle(isDisabled ? theme.textTertiary : theme.accent)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .accessibilityLabel("Command palette")
        .accessibilityHint("Opens the command palette for slash commands")
    }

    private var optionsButton: some View {
        Button(action: onAdvancedOptions) {
            Image(systemName: hasCustomOptions ? "slider.horizontal.2.gobackward" : "slider.horizontal.3")
                .font(.system(size: 20))
                .foregroundStyle(hasCustomOptions ? theme.accent : (isDisabled ? theme.textTertiary : theme.textSecondary))
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .accessibilityLabel("Advanced options")
        .accessibilityIdentifier("advanced-options-button")
        .accessibilityHint("Opens advanced chat options")
    }

    /// Documentation quick-access button that opens ``DocumentationView`` pre-filtered for commands.
    private var helpButton: some View {
        Button {
            showDocumentation = true
        } label: {
            Image(systemName: "book.circle")
                .font(.system(size: 20))
                .foregroundStyle(isDisabled ? theme.textTertiary : theme.textSecondary)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isDisabled)
        .accessibilityLabel("Documentation")
        .accessibilityHint("Opens Claude Code documentation for slash commands")
        .accessibilityIdentifier("documentation-button")
    }

    private var textField: some View {
        TextField("Message Claude...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...5)
            .disabled(isDisabled)
            .focused($isInputFocused)
            .padding(.horizontal, inputPaddingH)
            .padding(.vertical, inputPaddingV)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
            )
            .focusRing(isFocused: isInputFocused, cornerRadius: theme.cornerRadius)
            .accessibilityIdentifier("chat-input-field")
            .accessibilityLabel("Message input field")
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(theme.error)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("cancel-button")
        .accessibilityLabel("Stop streaming")
        .accessibilityHint("Cancels the current response from Claude")
    }

    private var sendButton: some View {
        Button {
            HapticManager.notification(.success)

            if !reduceMotion {
                sendButtonPressed = true
            }
            onSend()

            if !reduceMotion {
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    sendButtonPressed = false
                }
            }
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(text.isEmpty || isDisabled ? theme.textTertiary : theme.accent)
                .scaleEffect(sendButtonPressed ? 0.85 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: sendButtonPressed)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(text.isEmpty || isDisabled)
        .accessibilityIdentifier("send-button")
        .accessibilityLabel("Send message")
        .accessibilityHint("Sends the current message to Claude")
    }
}
