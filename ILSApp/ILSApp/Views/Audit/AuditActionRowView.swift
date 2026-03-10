import SwiftUI
import ILSShared

/// A single row in the audit trail list displaying one ``AuditAction`` entry.
///
/// Shows the action type icon, a short title (file name, command preview, or tool name),
/// a subtitle with the session name and timestamp, and a rollback-status badge.
/// A "rolled-back" overlay dims the row when the action has already been reversed.
struct AuditActionRowView: View {
    let action: AuditAction

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            actionTypeIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(action.displayTitle)
                    .font(.body)
                    .foregroundStyle(action.rollbackStatus == .rolledBack ? theme.textSecondary : theme.textPrimary)
                    .lineLimit(1)

                subtitleText
            }

            Spacer()

            trailingBadge
        }
        .padding(.vertical, 4)
        .opacity(action.rollbackStatus == .rolledBack ? 0.55 : 1.0)
    }

    // MARK: - Subviews

    /// Coloured icon reflecting the action category.
    private var actionTypeIcon: some View {
        Image(systemName: action.actionType.systemImageName)
            .font(.system(size: 16))
            .foregroundStyle(action.actionType.tintColor(theme: theme))
            .frame(width: 28, height: 28)
            .background(
                action.actionType.tintColor(theme: theme).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }

    /// Session name + formatted timestamp.
    private var subtitleText: some View {
        Group {
            if let sessionName = action.sessionName, !sessionName.isEmpty {
                Text("\(sessionName) · \(action.createdAt.formatted(date: .omitted, time: .shortened))")
            } else {
                Text(action.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .font(.caption)
        .foregroundStyle(theme.textSecondary)
        .lineLimit(1)
    }

    /// Right-side badge: rollback tag, rollback-eligible chevron, or nothing.
    @ViewBuilder
    private var trailingBadge: some View {
        switch action.rollbackStatus {
        case .rolledBack:
            Text("Rolled Back")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(theme.bgSecondary, in: Capsule())

        case .notRolledBack:
            if action.canRollback {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.accent)
            } else {
                EmptyView()
            }
        }
    }
}

// MARK: - AuditActionType Helpers

private extension AuditActionType {
    /// SF Symbol name that represents this action category.
    var systemImageName: String {
        switch self {
        case .fileWrite:          return "pencil"
        case .fileCreate:         return "plus.square"
        case .fileDelete:         return "trash"
        case .bashCommand:        return "terminal"
        case .toolUse:            return "wrench.and.screwdriver"
        case .permissionDecision: return "lock.shield"
        case .rollback:           return "arrow.uturn.backward"
        }
    }

    /// Tint colour appropriate for this action category.
    func tintColor(theme: ThemeSnapshot) -> Color {
        switch self {
        case .fileWrite:          return theme.accent
        case .fileCreate:         return theme.success
        case .fileDelete:         return theme.error
        case .bashCommand:        return theme.warning
        case .toolUse:            return theme.textSecondary
        case .permissionDecision: return theme.info
        case .rollback:           return theme.textSecondary
        }
    }
}
