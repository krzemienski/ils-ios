import SwiftUI
import ILSShared

struct SidebarSessionRow: View {
    let session: ChatSession
    let onTap: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacingSM) {
                // Active indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 2) {
                    // Session name
                    Text(sessionDisplayName)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    // Relative time + message count
                    HStack(spacing: theme.spacingXS) {
                        Text(relativeTime)
                            .font(.system(size: 10, design: theme.fontDesign))
                            .foregroundStyle(theme.textTertiary)

                        if session.messageCount > 0 {
                            Text("·")
                                .foregroundStyle(theme.textTertiary)
                            Text("\(session.messageCount) msgs")
                                .font(.system(size: 10, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }

                        if session.source == .external {
                            Text("·")
                                .foregroundStyle(theme.textTertiary)
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 9, design: theme.fontDesign))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS + 2)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel("\(sessionDisplayName), \(relativeTime)")
        .accessibilityHint("Opens this chat session")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private var sessionDisplayName: String {
        if let name = session.name, !name.isEmpty {
            return name
        }
        if let prompt = session.firstPrompt, !prompt.isEmpty {
            return String(prompt.prefix(40))
        }
        return "Unnamed Session"
    }

    private var relativeTime: String {
        DateFormatters.relativeDateTime.localizedString(for: session.lastActiveAt, relativeTo: Date())
    }

    private var statusColor: Color {
        switch session.status {
        case .active:
            return theme.entitySession
        case .completed:
            return theme.success
        case .cancelled:
            return theme.warning
        case .error:
            return theme.error
        }
    }
}
