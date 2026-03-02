import SwiftUI
import ILSShared

/// A self-contained session pane showing a compact header and embedded chat content.
///
/// - Note: Full implementation provided by subtask-2-2. This stub satisfies
///   compile-time references from ``MultiSessionSplitView``.
struct SessionPaneView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var session: ChatSession
    var isActive: Bool
    var onUnpin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Pane header
            HStack(spacing: theme.spacingSM) {
                Text(session.name ?? "Session")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button(action: onUnpin) {
                    Image(systemName: "xmark")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                .accessibilityLabel("Unpin session")
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(isActive ? theme.accent.opacity(0.1) : theme.bgSecondary)

            Divider().overlay(theme.divider)

            // Chat content placeholder — replaced by full ChatView in subtask-2-2
            ChatView(session: session)
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(isActive ? theme.accent : theme.divider, lineWidth: isActive ? 2 : 0.5)
        )
    }
}
