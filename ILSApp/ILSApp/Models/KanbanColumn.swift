import Foundation
import SwiftUI
import ILSShared

// MARK: - Kanban Column

/// Represents a column on the session kanban board.
///
/// Each case maps to a distinct lifecycle state that a session or queue item
/// can occupy. The raw value is a stable identifier used for persistence and
/// drag-and-drop transfer.
enum KanbanColumn: String, CaseIterable, Identifiable, Sendable {
    /// Sessions currently running and processing messages.
    case active
    /// Sessions that have a pending permission request awaiting user decision.
    case waitingForApproval
    /// Sessions or queue items whose execution has been suspended.
    case paused
    /// Agent queue items waiting to be dispatched.
    case queued
    /// Sessions or queue items that finished successfully.
    case completed
    /// Sessions or queue items that terminated with an error or were cancelled.
    case failed

    var id: String { rawValue }

    /// Human-readable column header.
    var displayTitle: String {
        switch self {
        case .active: return "Active"
        case .waitingForApproval: return "Waiting for Approval"
        case .paused: return "Paused"
        case .queued: return "Queued"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    /// SF Symbol name for the column header icon.
    var iconName: String {
        switch self {
        case .active: return "play.circle.fill"
        case .waitingForApproval: return "hand.raised.circle.fill"
        case .paused: return "pause.circle.fill"
        case .queued: return "clock.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    /// Accent color for the column header and card highlights.
    var color: Color {
        switch self {
        case .active: return .green
        case .waitingForApproval: return .orange
        case .paused: return .yellow
        case .queued: return .blue
        case .completed: return .gray
        case .failed: return .red
        }
    }
}

// MARK: - Kanban Board Item

/// A unified item that can appear on the kanban board.
///
/// Wraps either a ``TaggedSession`` (a real Claude Code session) or an
/// ``AgentQueueItem`` (a queued background task) so that both types can
/// be displayed and managed on the same board.
enum KanbanBoardItem: Identifiable, Hashable {
    /// A live or historical Claude Code session.
    case session(TaggedSession)
    /// A task from the agent queue.
    case queueItem(AgentQueueItem)

    var id: String {
        switch self {
        case .session(let tagged): return tagged.id
        case .queueItem(let item): return "queue-\(item.id)"
        }
    }

    /// Display name shown on the kanban card.
    var displayName: String {
        switch self {
        case .session(let tagged): return tagged.displayName
        case .queueItem(let item): return item.title
        }
    }

    /// The kanban column this item belongs to based on its current state.
    var column: KanbanColumn {
        switch self {
        case .session(let tagged):
            return KanbanColumn.column(for: tagged)
        case .queueItem(let item):
            return KanbanColumn.column(forQueueItem: item)
        }
    }

    // MARK: - Hashable

    static func == (lhs: KanbanBoardItem, rhs: KanbanBoardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Column Mapping Logic

extension KanbanColumn {
    /// Determines the appropriate kanban column for a tagged session.
    ///
    /// Mapping rules (evaluated in priority order):
    /// 1. Sessions with pending permissions → `.waitingForApproval`
    /// 2. Active sessions → `.active`
    /// 3. Completed sessions → `.completed`
    /// 4. Error or cancelled sessions → `.failed`
    ///
    /// - Parameters:
    ///   - session: The tagged session to classify.
    ///   - hasPendingPermission: Whether the session has an unresolved permission request.
    /// - Returns: The kanban column the session should appear in.
    static func column(for session: TaggedSession, hasPendingPermission: Bool = false) -> KanbanColumn {
        // Pending permissions take priority over active status.
        if hasPendingPermission && session.status == .active {
            return .waitingForApproval
        }

        switch session.status {
        case .active:
            return .active
        case .completed:
            return .completed
        case .error, .cancelled:
            return .failed
        }
    }

    /// Determines the appropriate kanban column for an agent queue item.
    ///
    /// - Parameter item: The queue item to classify.
    /// - Returns: The kanban column the item should appear in.
    static func column(forQueueItem item: AgentQueueItem) -> KanbanColumn {
        switch item.status {
        case .queued:
            return .queued
        case .running:
            return .active
        case .paused:
            return .paused
        case .completed:
            return .completed
        case .failed, .cancelled:
            return .failed
        }
    }
}
