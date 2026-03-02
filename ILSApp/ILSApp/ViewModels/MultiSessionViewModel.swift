import Foundation
import Observation
import ILSShared

/// Layout mode for the multi-session split view.
enum SplitViewLayout: String, CaseIterable {
    case twoPane
    case threePane
    case fourPane

    /// Maximum number of simultaneous session panes for this layout.
    var paneCount: Int {
        switch self {
        case .twoPane: return 2
        case .threePane: return 3
        case .fourPane: return 4
        }
    }

    var displayName: String {
        switch self {
        case .twoPane: return "2 Panes"
        case .threePane: return "3 Panes"
        case .fourPane: return "4 Panes"
        }
    }
}

/// View model that manages an ordered list of pinned session IDs for multi-session split view.
///
/// Pinned session IDs are persisted to UserDefaults and capped at 4 slots.
/// Provides methods to pin, unpin, and reorder sessions as well as resolve
/// pinned IDs to ``ChatSession`` objects from a given session array.
@Observable
@MainActor
class MultiSessionViewModel: BaseViewModel {
    /// Maximum number of sessions that may be pinned simultaneously.
    private static let maxPinnedCount = 4
    private static let pinnedSessionsKey = "multiSession.pinnedSessionIds"
    private static let selectedLayoutKey = "multiSession.selectedLayout"

    /// Ordered array of pinned session IDs, persisted to UserDefaults.
    private(set) var pinnedSessionIds: [UUID] = []

    /// The current split view layout selection.
    var selectedLayout: SplitViewLayout = .twoPane {
        didSet {
            UserDefaults.standard.set(selectedLayout.rawValue, forKey: Self.selectedLayoutKey)
        }
    }

    override init() {
        super.init()
        loadFromUserDefaults()
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() {
        if let rawLayout = UserDefaults.standard.string(forKey: Self.selectedLayoutKey),
           let layout = SplitViewLayout(rawValue: rawLayout) {
            selectedLayout = layout
        }

        guard let stored = UserDefaults.standard.array(forKey: Self.pinnedSessionsKey) as? [String] else {
            return
        }
        pinnedSessionIds = stored.compactMap { UUID(uuidString: $0) }
    }

    private func saveToUserDefaults() {
        let strings = pinnedSessionIds.map(\.uuidString)
        UserDefaults.standard.set(strings, forKey: Self.pinnedSessionsKey)
    }

    // MARK: - Public API

    /// Whether the given session is currently pinned.
    func isPinned(_ session: ChatSession) -> Bool {
        pinnedSessionIds.contains(session.id)
    }

    /// Pin a session. No-op if already pinned or if the 4-slot limit is reached.
    func pinSession(_ session: ChatSession) {
        guard !isPinned(session), pinnedSessionIds.count < Self.maxPinnedCount else { return }
        pinnedSessionIds.append(session.id)
        saveToUserDefaults()
    }

    /// Unpin a session. No-op if the session is not currently pinned.
    func unpinSession(_ session: ChatSession) {
        pinnedSessionIds.removeAll { $0 == session.id }
        saveToUserDefaults()
    }

    /// Move a pinned session from one index to another (for drag-to-reorder).
    func moveSession(from source: IndexSet, to destination: Int) {
        pinnedSessionIds.move(fromOffsets: source, toOffset: destination)
        saveToUserDefaults()
    }

    /// Resolve pinned IDs to ``ChatSession`` objects from the provided array.
    ///
    /// IDs that no longer correspond to an existing session are silently skipped.
    /// The result preserves the pinned order.
    func pinnedSessions(from sessions: [ChatSession]) -> [ChatSession] {
        let sessionMap = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        return pinnedSessionIds.compactMap { sessionMap[$0] }
    }
}
