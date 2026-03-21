import SwiftUI
import ILSShared

/// Compact card view for a ``KanbanBoardItem`` displayed within a kanban column.
///
/// Renders differently depending on whether the item wraps a session or a queue task:
///
/// **Sessions** show:
/// - Truncated display name
/// - Project badge pill (colored, matching ``UnifiedSessionsView/backendPill``)
/// - Duration timer (computed from `createdAt`)
/// - Message count with chat bubble icon
/// - Live status dot (green=active, yellow=waiting, gray=completed, red=failed)
/// - Model badge
///
/// **Queue items** show:
/// - Title and description
/// - Status badge
/// - Priority indicator
/// - Position number
///
/// Quick-action buttons are separated from the main tappable card area
/// to prevent accidental taps while navigating.
struct KanbanSessionCardView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let item: KanbanBoardItem

    /// Called when the user taps the card body (not a quick-action button).
    var onTap: (() -> Void)?
    /// Called when the user taps "Open Chat" on a session card.
    var onOpenChat: (() -> Void)?
    /// Called when the user taps "Approve" on a waiting-for-approval card.
    var onApprove: (() -> Void)?
    /// Called when the user taps "View Details".
    var onViewDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main tappable card area
            Button {
                HapticManager.selection()
                onTap?()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)

            // Quick-action buttons (separate tap target)
            quickActions
        }
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
    }

    // MARK: - Card Content

    @ViewBuilder
    private var cardContent: some View {
        switch item {
        case .session(let tagged):
            sessionCardContent(tagged)
        case .queueItem(let queueItem):
            queueCardContent(queueItem)
        }
    }

    // MARK: - Session Card

    private func sessionCardContent(_ tagged: TaggedSession) -> some View {
        let session = tagged.session
        return VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Row 1: Status dot + Name
            HStack(spacing: theme.spacingSM) {
                statusDot(for: tagged)

                Text(session.displayName)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }

            // Row 2: Project pill + Model badge
            HStack(spacing: theme.spacingSM) {
                if let projectName = session.projectName, !projectName.isEmpty {
                    projectPill(projectName, tagged: tagged)
                }

                modelBadge(session.model)

                Spacer(minLength: 0)
            }

            // Row 3: Duration + Message count
            HStack(spacing: theme.spacingMD) {
                // Duration timer
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text(durationText(from: session.createdAt))
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textTertiary)

                // Message count
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("\(session.messageCount)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textTertiary)

                Spacer(minLength: 0)
            }
        }
        .padding(theme.spacingSM)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.displayName), \(session.messageCount) messages")
    }

    // MARK: - Queue Card

    private func queueCardContent(_ queueItem: AgentQueueItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Row 1: Title + Status
            HStack(spacing: theme.spacingSM) {
                Text(queueItem.title)
                    .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                queueStatusChip(queueItem.status)
            }

            // Row 2: Priority + Position
            HStack(spacing: theme.spacingSM) {
                if queueItem.priority > 0 {
                    priorityBadge(queueItem.priority)
                }

                HStack(spacing: 4) {
                    Image(systemName: "list.number")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text("Position \(queueItem.position + 1)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }
                .foregroundStyle(theme.textTertiary)

                Spacer(minLength: 0)
            }

            // Row 3: Description (if present)
            if let description = queueItem.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            // Error message (if present)
            if let errorMessage = queueItem.errorMessage, !errorMessage.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text(errorMessage)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .lineLimit(2)
                }
                .foregroundStyle(theme.error)
            }
        }
        .padding(theme.spacingSM)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(queueItem.title), position \(queueItem.position + 1)")
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: theme.spacingSM) {
            switch item {
            case .session(let tagged):
                if tagged.status == .active {
                    quickActionButton("Open Chat", icon: "bubble.left.and.bubble.right", action: onOpenChat)
                }

                // Show Approve for sessions in the waitingForApproval column
                if item.column == .waitingForApproval {
                    quickActionButton("Approve", icon: "checkmark.circle", tint: .orange, action: onApprove)
                }

            case .queueItem:
                EmptyView()
            }

            Spacer(minLength: 0)

            quickActionButton("Details", icon: "info.circle", action: onViewDetails)
        }
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.bgSecondary.opacity(0.5))
    }

    // MARK: - Subviews

    /// Status dot matching the session's lifecycle state.
    private func statusDot(for tagged: TaggedSession) -> some View {
        let color: Color = {
            switch item.column {
            case .active: return .green
            case .waitingForApproval: return .orange
            case .paused: return .yellow
            case .completed: return .gray
            case .failed: return .red
            case .queued: return .blue
            }
        }()

        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    /// Project badge pill styled similarly to the backend pill in UnifiedSessionsView.
    private func projectPill(_ name: String, tagged: TaggedSession) -> some View {
        let pillColor = Color(hex: tagged.backendColorHex)
        return Text(String(name.prefix(12)))
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(pillColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pillColor.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    /// Compact model badge (e.g., "sonnet", "opus").
    private func modelBadge(_ model: String) -> some View {
        let displayName = ClaudeModel(rawValue: model).rawValue
        return Text(displayName)
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    /// Status chip for queue items, matching QueueTaskRow style.
    private func queueStatusChip(_ status: AgentQueueStatus) -> some View {
        let (color, text) = queueStatusInfo(status)
        return Text(text)
            .font(.system(size: theme.fontCaption - 2, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    /// Priority indicator for queue items, matching QueueTaskRow style.
    private func priorityBadge(_ priority: Int) -> some View {
        let color: Color = priority >= 2 ? theme.error : .orange
        return HStack(spacing: 2) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text("P\(priority)")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall / 2))
    }

    /// Reusable quick-action button with icon and label.
    private func quickActionButton(
        _ label: String,
        icon: String,
        tint: Color? = nil,
        action: (() -> Void)?
    ) -> some View {
        Button {
            HapticManager.selection()
            action?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
                Text(label)
                    .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(tint ?? theme.accent)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private func queueStatusInfo(_ status: AgentQueueStatus) -> (Color, String) {
        switch status {
        case .queued: return (theme.textTertiary, "Queued")
        case .running: return (theme.accent, "Running")
        case .paused: return (.yellow, "Paused")
        case .completed: return (theme.success, "Completed")
        case .failed: return (theme.error, "Failed")
        case .cancelled: return (theme.textTertiary, "Cancelled")
        }
    }

    /// Computes a human-readable duration string from a start date to now.
    private func durationText(from startDate: Date) -> String {
        let interval = Date().timeIntervalSince(startDate)
        if interval < 60 {
            return "<1m"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d"
        }
    }
}

// MARK: - Preview

#Preview("Session Card") {
    VStack(spacing: 12) {
        KanbanSessionCardView(
            item: .session(TaggedSession(
                session: ChatSession(
                    name: "Implement user authentication flow",
                    projectName: "MyApp",
                    model: "sonnet",
                    status: .active,
                    messageCount: 42
                ),
                backendId: UUID(),
                backendName: "Work Mac",
                backendColorHex: "#4A90E2"
            ))
        )

        KanbanSessionCardView(
            item: .session(TaggedSession(
                session: ChatSession(
                    name: "Fix login bug on staging",
                    projectName: "Backend API",
                    model: "opus",
                    status: .completed,
                    messageCount: 8
                ),
                backendId: UUID(),
                backendName: "Home Mac",
                backendColorHex: "#7ED321"
            ))
        )
    }
    .padding()
    .background(Color.black)
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
