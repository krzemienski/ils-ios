import SwiftUI
import ILSShared

/// A single row in the agent task queue list.
///
/// Displays the task title, a color-coded status chip, a priority badge when priority > 0,
/// an indeterminate progress indicator for actively running tasks, and contextual swipe
/// actions to pause, resume, cancel, or delete the item.
///
/// ## Swipe Actions
/// - **Leading (pause/resume):** Pause a running task; resume a paused task.
/// - **Trailing (cancel/delete):** Cancel active tasks; delete finished tasks.
struct QueueTaskRow: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    let item: AgentQueueItem
    let viewModel: AgentQueueViewModel

    var body: some View {
        rowContent
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                leadingSwipeActions
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                trailingSwipeActions
            }
    }

    // MARK: - Row Content

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                titleAndProgress

                Spacer()

                HStack(spacing: theme.spacingSM) {
                    if item.priority > 0 {
                        priorityBadge
                    }
                    statusChip(for: item.status)
                }
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            if let errorMessage = item.errorMessage, !errorMessage.isEmpty {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    Text(errorMessage)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .lineLimit(2)
                }
                .foregroundStyle(theme.error)
            }

            HStack(spacing: theme.spacingSM) {
                Image(systemName: "list.number")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                Text("Position \(item.position + 1)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            }
            .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    private var titleAndProgress: some View {
        HStack(spacing: theme.spacingSM) {
            if item.status == .running {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(theme.accent)
            }

            Text(item.title)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
        }
    }

    // MARK: - Status Chip

    private func statusChip(for status: AgentQueueStatus) -> some View {
        let (color, text) = statusInfo(for: status)

        return Text(text)
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(color)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(theme.cornerRadius)
    }

    private func statusInfo(for status: AgentQueueStatus) -> (Color, String) {
        switch status {
        case .queued:
            return (theme.textTertiary, "Queued")
        case .running:
            return (theme.accent, "Running")
        case .paused:
            return (.yellow, "Paused")
        case .completed:
            return (theme.success, "Completed")
        case .failed:
            return (theme.error, "Failed")
        case .cancelled:
            return (theme.textTertiary, "Cancelled")
        }
    }

    // MARK: - Priority Badge

    private var priorityBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            Text("P\(item.priority)")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
        }
        .foregroundStyle(priorityColor)
        .padding(.horizontal, theme.spacingSM)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.15))
        .cornerRadius(theme.cornerRadius)
    }

    private var priorityColor: Color {
        switch item.priority {
        case 1:
            return .orange
        case 2...:
            return theme.error
        default:
            return theme.textTertiary
        }
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private var leadingSwipeActions: some View {
        switch item.status {
        case .running:
            Button {
                Task { await viewModel.pauseItem(id: item.id) }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .tint(theme.warning)

        case .paused:
            Button {
                Task { await viewModel.resumeItem(id: item.id) }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
            .tint(theme.success)

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingSwipeActions: some View {
        switch item.status {
        case .queued, .running, .paused:
            Button(role: .destructive) {
                Task { await viewModel.cancelItem(id: item.id) }
            } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
            }

        case .completed, .failed, .cancelled:
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(id: item.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
