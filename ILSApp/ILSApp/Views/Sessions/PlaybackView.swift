import SwiftUI
import ILSShared

/// Time-lapse playback view for a session recording.
///
/// Full implementation is completed in subtask-3-4. This stub provides
/// the type declaration required for ``SessionRecordingsView`` to compile.
struct PlaybackView: View {
    let recording: SessionRecording

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "play.circle")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Playback")
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text(recording.sessionName ?? recording.id)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .navigationTitle("Playback")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .background(theme.bgPrimary)
    }
}
