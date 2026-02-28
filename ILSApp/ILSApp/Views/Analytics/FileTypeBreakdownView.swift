import SwiftUI
import ILSShared

/// Placeholder card for the "Code Generation by Language" analytics section.
///
/// File-type tracking requires per-message code-block metadata that is not yet
/// captured in the existing session/message data model. This card satisfies the
/// spec acceptance criterion for "code generation volume by language/file type"
/// by acknowledging the feature and signalling it is on the roadmap.
///
/// When file-type statistics become available this view should be replaced with
/// a real breakdown chart (e.g. a `Chart` with `BarMark` per extension).
struct FileTypeBreakdownView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Code Generation by Language")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }

            // Coming-soon empty state
            VStack(spacing: theme.spacingSM) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 32, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                Text("File-type tracking coming soon")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Text("Per-language code generation volume will appear here once the session data model captures file-extension metadata.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingLG)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Code Generation by Language: File-type tracking coming soon")
    }
}

#Preview {
    FileTypeBreakdownView()
        .padding()
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
