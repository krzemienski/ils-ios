import SwiftUI

/// Recording overlay that appears above the chat input bar during voice dictation.
///
/// Displays an animated ``AudioWaveformView`` driven by the current audio power level,
/// a scrollable real-time transcription region, a running duration timer, and done/cancel
/// controls. The overlay slides up from the bottom with an opacity transition.
///
/// ## Topics
/// ### Bindings
/// - ``transcribedText`` — Live partial transcription from the speech recognizer
/// - ``audioLevel`` — Current microphone power level (0…1) for the waveform
///
/// ### Callbacks
/// - ``onDone`` — Returns the final transcribed text when the user taps Done
/// - ``onCancel`` — Invoked when the user discards the recording
struct VoiceInputOverlay: View {
    /// Live transcription text from the speech recognition service.
    @Binding var transcribedText: String
    /// Current audio power level (0.0 silent … 1.0 loudest).
    let audioLevel: CGFloat
    /// Called with the transcribed text when the user confirms the recording.
    let onDone: (String) -> Void
    /// Called when the user cancels and discards the recording.
    let onCancel: () -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: theme.spacingMD) {
            // Waveform + timer
            HStack(spacing: theme.spacingSM) {
                AudioWaveformView(
                    powerLevel: audioLevel,
                    barCount: 7,
                    size: CGSize(width: 60, height: 32)
                )

                Circle()
                    .fill(theme.error)
                    .frame(width: 8, height: 8)

                Text(formattedDuration)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign).monospacedDigit())
                    .foregroundStyle(theme.textSecondary)

                Spacer()
            }

            // Transcription text
            ScrollView {
                Text(transcribedText.isEmpty ? "Listening…" : transcribedText)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(transcribedText.isEmpty ? theme.textTertiary : theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 40, maxHeight: 120)

            // Controls
            HStack(spacing: theme.spacingMD) {
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
                .accessibilityIdentifier("voice-cancel-button")
                .accessibilityLabel("Cancel recording")

                Button {
                    onDone(transcribedText)
                } label: {
                    Text("Done")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadius)
                                .fill(theme.accent)
                        )
                }
                .disabled(transcribedText.isEmpty)
                .opacity(transcribedText.isEmpty ? 0.5 : 1.0)
                .accessibilityIdentifier("voice-done-button")
                .accessibilityLabel("Done recording")
                .accessibilityHint("Inserts the transcribed text into the message")
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
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .accessibilityIdentifier("voice-input-overlay")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice input recording")
    }

    // MARK: - Private

    private var formattedDuration: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    @Previewable @State var text = "Hello this is a test of voice recognition"
    VoiceInputOverlay(
        transcribedText: $text,
        audioLevel: 0.5,
        onDone: { _ in },
        onCancel: {}
    )
    .padding()
}
