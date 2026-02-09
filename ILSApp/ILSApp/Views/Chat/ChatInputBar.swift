import SwiftUI
import ILSShared

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isDisabled: Bool = false
    var hasCustomOptions: Bool = false
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCommandPalette: () -> Void
    let onAdvancedOptions: () -> Void
    @State private var sendButtonPressed = false
    @State private var resetTask: Task<Void, Never>?

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            theme.divider.frame(height: 0.5)

            HStack(spacing: theme.spacingSM) {
                commandPaletteButton
                optionsButton
                textField
                if isStreaming {
                    cancelButton
                } else {
                    sendButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(theme.bgSecondary)
        .accessibilityIdentifier("chat-input-bar")
        .onDisappear { resetTask?.cancel() }
    }

    private var commandPaletteButton: some View {
        Button(action: onCommandPalette) {
            Image(systemName: "command")
                .foregroundStyle(isDisabled ? theme.textTertiary : theme.accent)
        }
        .disabled(isDisabled)
        .accessibilityLabel("Command palette")
    }

    private var optionsButton: some View {
        Button(action: onAdvancedOptions) {
            Image(systemName: hasCustomOptions ? "slider.horizontal.2.gobackward" : "slider.horizontal.3")
                .foregroundStyle(hasCustomOptions ? theme.accent : (isDisabled ? theme.textTertiary : theme.textSecondary))
        }
        .disabled(isDisabled)
        .accessibilityLabel("Advanced options")
        .accessibilityIdentifier("advanced-options-button")
    }

    private var textField: some View {
        TextField("Message Claude...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...5)
            .disabled(isDisabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
            )
            .accessibilityIdentifier("chat-input-field")
            .accessibilityLabel("Message input field")
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(theme.error)
        }
        .accessibilityIdentifier("cancel-button")
        .accessibilityLabel("Stop streaming")
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
                .foregroundStyle(text.isEmpty || isDisabled ? theme.textTertiary : theme.accent)
                .scaleEffect(sendButtonPressed ? 0.85 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: sendButtonPressed)
        }
        .disabled(text.isEmpty || isDisabled)
        .accessibilityIdentifier("send-button")
        .accessibilityLabel("Send message")
    }
}
