import SwiftUI

/// Horizontally centered caption that surfaces system-level events within the chat timeline.
///
/// Used for non-conversational status lines such as "Session started", "Session forked",
/// or "Context window cleared". Rendered in `theme.textTertiary` at caption font size,
/// centered between leading and trailing `Spacer`s so it floats independently of the
/// message bubble alignment used by user and assistant turns.
///
/// The view carries no interactive elements; its accessibility label prefixes the raw
/// string with "System message:" to distinguish it from user or assistant content when
/// read aloud by VoiceOver.
///
/// ## Topics
/// ### Input Properties
/// - ``message`` - The system event string to display (e.g. "Session started")
struct SystemMessageView: View {
    /// The system event string to display in the timeline (e.g. "Session started").
    let message: String

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack {
            Spacer()
            Text(message)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.vertical, theme.spacingXS)
            Spacer()
        }
        .accessibilityLabel("System message: \(message)")
    }
}
