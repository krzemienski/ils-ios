import SwiftUI
import ILSShared

struct ChatInputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var isDisabled: Bool = false
    let onSend: () -> Void
    let onCancel: () -> Void
    let onCommandPalette: () -> Void
    @State private var sendButtonPressed = false
    @State private var resetTask: Task<Void, Never>?

    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: theme.spacingSM) {
            commandPaletteButton

            textField

            if isStreaming {
                cancelButton
            } else {
                sendButton
            }
        }
        .padding()
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
    }

    private var textField: some View {
        TextField("Message Claude...", text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .lineLimit(1...5)
            .disabled(isDisabled)
            .accessibilityIdentifier("chat-input-field")
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(theme.error)
        }
        .accessibilityIdentifier("cancel-button")
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
    }
}
