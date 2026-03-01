import SwiftUI
import ILSShared

/// A row displaying a single in-session message search result.
///
/// Shows a role icon (person.fill for user, sparkles for assistant), a two-line
/// content preview, and a formatted timestamp. Used inside the ChatView search
/// results list.
struct MessageSearchResultRow: View {
    let result: MessageSearchResult

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            // Role icon
            Image(systemName: roleIconName)
                .font(.system(size: 14, design: theme.fontDesign))
                .foregroundStyle(roleIconColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                // Role label + timestamp
                HStack(spacing: theme.spacingXS) {
                    Text(roleName)
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign).leading(.tight))
                        .foregroundStyle(roleIconColor)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                    Spacer()

                    Text(formattedTimestamp(result.createdAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign).leading(.tight))
                        .foregroundStyle(theme.textTertiary)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }

                // Content preview — capped at 2 lines
                Text(result.content)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityLabel("\(roleName): \(result.content.prefix(100))")
    }

    // MARK: - Helpers

    private var roleIconName: String {
        switch result.role {
        case .user:
            return "person.fill"
        case .assistant:
            return "sparkles"
        case .system:
            return "gearshape.fill"
        }
    }

    private var roleIconColor: Color {
        switch result.role {
        case .user:
            return theme.textSecondary
        case .assistant:
            return theme.accent
        case .system:
            return theme.textTertiary
        }
    }

    private var roleName: String {
        switch result.role {
        case .user:
            return "You"
        case .assistant:
            return "Claude"
        case .system:
            return "System"
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return DateFormatters.time.string(from: date)
        } else {
            return DateFormatters.dateTime.string(from: date)
        }
    }
}
