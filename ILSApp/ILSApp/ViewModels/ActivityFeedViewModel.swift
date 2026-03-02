import Foundation
import Observation
import ILSShared

/// View model for the cross-session activity feed.
///
/// Fetches events from the backend REST endpoint (`GET /activity/events`), applies
/// client-side filtering by event type, session, project, and severity, groups events
/// into time buckets (Today / Yesterday / Earlier), and collapses rapid sequential
/// bursts of more than 3 same-type/same-session events within 60 seconds into a
/// single representative placeholder. Badge count tracks events newer than the
/// last-read timestamp, persisted in UserDefaults.
///
/// ## Topics
/// ### Properties
/// - ``events`` - All fetched activity events (newest first)
/// - ``unreadCount`` - Number of events newer than last-read date
/// - ``filter`` - Currently active filter criteria
/// - ``hiddenEventTypes`` - User-hidden event types (persisted to UserDefaults)
///
/// ### Computed
/// - ``filteredEvents`` - Events after applying ``filter`` and ``hiddenEventTypes``
/// - ``groupedEvents`` - Filtered events bucketed by time with burst collapsing
/// - ``collapsedGroupSizes`` - Collapse-count per representative event ID
///
/// ### Operations
/// - ``loadEvents(refresh:)`` - Fetch events from the API
/// - ``startPolling()`` - Begin 10-second polling for new events
/// - ``stopPolling()`` - Cancel active polling task
/// - ``markAllRead()`` - Record current time as last-read date
@Observable
@MainActor
class ActivityFeedViewModel {

    // MARK: - Observable Properties

    /// All fetched activity events, ordered newest-first.
    var events: [ActivityEvent] = []
    /// Whether an event fetch is currently in progress.
    var isLoading = false
    /// Most recent fetch error, if any.
    var error: Error?
    /// Active filter applied to the feed.
    var filter: ActivityFeedFilter = ActivityFeedFilter()
    /// Number of events newer than the last-read timestamp.
    var unreadCount: Int = 0
    /// Timestamp of the most recent successful data load from the API.
    var lastUpdated: Date?

    // MARK: - Hidden Event Types

    /// Backing store for hidden event types so the set is `@Observable`-tracked.
    private var _hiddenEventTypes: Set<ActivityEventType> = []

    /// Event types the user has hidden from the feed.
    /// Changes are persisted to UserDefaults under ``hiddenTypesKey``.
    var hiddenEventTypes: Set<ActivityEventType> {
        get { _hiddenEventTypes }
        set {
            _hiddenEventTypes = newValue
            UserDefaults.standard.set(newValue.map(\.rawValue), forKey: Self.hiddenTypesKey)
        }
    }

    // MARK: - Collapsed Group Metadata

    /// Maps a representative event's ``ActivityEvent/id`` to the total count of events
    /// it stands for. When the value exceeds 1, views should render a "+ N more" indicator.
    ///
    /// Updated as a side-effect of reading ``groupedEvents``. Writing is guarded by an
    /// equality check to prevent spurious `@Observable` notification cycles.
    private(set) var collapsedGroupSizes: [String: Int] = [:]

    // MARK: - Private State

    private var client: APIClient?
    nonisolated(unsafe) private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    // MARK: - UserDefaults Keys

    private static let lastReadDateKey = "activityFeedLastReadDate"
    private static let hiddenTypesKey  = "activityFeedHiddenTypes"

    // MARK: - Init

    init() {
        let raw = UserDefaults.standard.stringArray(forKey: Self.hiddenTypesKey) ?? []
        _hiddenEventTypes = Set(raw.compactMap { ActivityEventType(rawValue: $0) })
    }

    // MARK: - Configuration

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for all requests.
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Computed: Filtered Events

    /// Events filtered by the active ``filter`` criteria and ``hiddenEventTypes``.
    var filteredEvents: [ActivityEvent] {
        var result = events

        let hidden = hiddenEventTypes
        if !hidden.isEmpty {
            result = result.filter { !hidden.contains($0.eventType) }
        }

        if let types = filter.eventTypes, !types.isEmpty {
            result = result.filter { types.contains($0.eventType) }
        }
        if let sessionId = filter.sessionId {
            result = result.filter { $0.sessionId == sessionId }
        }
        if let projectName = filter.projectName {
            result = result.filter { $0.projectName == projectName }
        }
        if let severity = filter.severity {
            result = result.filter { severityRank($0.severity) >= severityRank(severity) }
        }
        if let since = filter.since {
            result = result.filter { $0.timestamp >= since }
        }

        return result
    }

    // MARK: - Computed: Grouped Events

    /// Events bucketed by relative time (Today / Yesterday / Earlier).
    ///
    /// Within each bucket, runs of more than 3 consecutive events sharing the same
    /// `eventType` and `sessionId` within a 60-second window are collapsed to a
    /// single representative entry. The total run length is stored in
    /// ``collapsedGroupSizes`` for "+N more" rendering in the view layer.
    ///
    /// The `collapsedGroupSizes` write is equality-guarded to prevent infinite
    /// `@Observable` notification cycles when a view reads both properties.
    var groupedEvents: [(label: String, events: [ActivityEvent])] {
        let filtered = filteredEvents
        guard !filtered.isEmpty else {
            if !collapsedGroupSizes.isEmpty { collapsedGroupSizes = [:] }
            return []
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

        let reserveCount = max(8, filtered.count / 3)
        var todayBucket:     [ActivityEvent] = []
        var yesterdayBucket: [ActivityEvent] = []
        var earlierBucket:   [ActivityEvent] = []
        todayBucket.reserveCapacity(reserveCount)
        yesterdayBucket.reserveCapacity(reserveCount)
        earlierBucket.reserveCapacity(reserveCount)

        for event in filtered {
            if event.timestamp >= startOfToday {
                todayBucket.append(event)
            } else if event.timestamp >= startOfYesterday {
                yesterdayBucket.append(event)
            } else {
                earlierBucket.append(event)
            }
        }

        var newGroupSizes: [String: Int] = [:]
        var result: [(label: String, events: [ActivityEvent])] = []

        if !todayBucket.isEmpty {
            result.append((label: "Today",
                           events: collapseEvents(todayBucket, into: &newGroupSizes)))
        }
        if !yesterdayBucket.isEmpty {
            result.append((label: "Yesterday",
                           events: collapseEvents(yesterdayBucket, into: &newGroupSizes)))
        }
        if !earlierBucket.isEmpty {
            result.append((label: "Earlier",
                           events: collapseEvents(earlierBucket, into: &newGroupSizes)))
        }

        // Guard write to break potential @Observable cycle
        if collapsedGroupSizes != newGroupSizes {
            collapsedGroupSizes = newGroupSizes
        }

        return result
    }

    // MARK: - Data Loading

    /// Fetch activity events from the backend, applying the active ``filter``.
    ///
    /// - Parameter refresh: When `true`, clears the existing event list before fetching.
    func loadEvents(refresh: Bool = false) async {
        guard let client else { return }
        if refresh { events = [] }
        isLoading = true
        error = nil

        do {
            let path = buildQueryPath()
            let response: APIResponse<ActivityFeedResponse> = try await client.get(path, cacheTTL: 0)
            if let data = response.data {
                events = data.events
                computeUnreadCount()
                lastUpdated = Date()
                AppLogger.shared.info(
                    "Loaded \(data.events.count) activity events",
                    category: "activity"
                )
            }
        } catch {
            self.error = error
            AppLogger.shared.error(
                "Failed to load activity events: \(error.localizedDescription)",
                category: "activity"
            )
        }

        isLoading = false
    }

    // MARK: - Polling

    /// Begin polling for new events every 10 seconds.
    /// Any previously active polling task is cancelled first.
    func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            // Immediate initial load
            await self?.loadEvents()
            // Repeat at 10-second intervals
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.loadEvents()
            }
        }
    }

    /// Cancel the active polling task.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Read State

    /// Record the current date as the last-read timestamp and reset the unread badge.
    func markAllRead() {
        UserDefaults.standard.set(Date(), forKey: Self.lastReadDateKey)
        unreadCount = 0
    }

    // MARK: - Convenience

    /// Whether a non-default filter is currently active (used for toolbar badge indicator).
    var isFilterActive: Bool {
        filter.eventTypes != nil
            || filter.sessionId != nil
            || filter.projectName != nil
            || filter.severity != nil
            || !hiddenEventTypes.isEmpty
    }

    /// Formatted empty-state message for UI display.
    var emptyStateText: String {
        if isLoading { return "Loading activity..." }
        return events.isEmpty ? "No activity yet" : ""
    }

    // MARK: - Private Helpers

    /// Recompute ``unreadCount`` from the persisted last-read date.
    private func computeUnreadCount() {
        let cutoff = UserDefaults.standard.object(forKey: Self.lastReadDateKey) as? Date ?? .distantPast
        unreadCount = events.filter { $0.timestamp > cutoff }.count
    }

    /// Build the `/activity/events?...` query string from the active ``filter``.
    private func buildQueryPath() -> String {
        var items: [String] = ["limit=100"]

        if let types = filter.eventTypes, !types.isEmpty {
            items += types.map { "eventType=\($0.rawValue)" }
        }
        if let sid = filter.sessionId {
            items.append("sessionId=\(sid)")
        }
        if let proj = filter.projectName,
           let encoded = proj.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            items.append("projectName=\(encoded)")
        }
        if let sev = filter.severity {
            items.append("severity=\(sev.rawValue)")
        }
        if let since = filter.since {
            let iso = ISO8601DateFormatter().string(from: since)
            if let encoded = iso.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                items.append("since=\(encoded)")
            }
        }

        return "/activity/events?" + items.joined(separator: "&")
    }

    /// Collapse sequential event bursts within a single time bucket.
    ///
    /// Scans `events` linearly. A "run" is a maximal contiguous subsequence where every
    /// event shares the same `eventType` and `sessionId` as the first, and all fall within
    /// 60 seconds of the representative. Runs longer than 3 are collapsed to their first
    /// element; the run length is written into `groupSizes`. Shorter runs are kept as-is,
    /// each recorded with a size of 1.
    private func collapseEvents(
        _ events: [ActivityEvent],
        into groupSizes: inout [String: Int]
    ) -> [ActivityEvent] {
        guard events.count > 1 else {
            if let first = events.first { groupSizes[first.id] = 1 }
            return events
        }

        var result: [ActivityEvent] = []
        var i = 0

        while i < events.count {
            let representative = events[i]
            var runEnd = i + 1

            // Extend run while type, session, and 60s window match
            while runEnd < events.count {
                let next = events[runEnd]
                guard next.eventType == representative.eventType,
                      next.sessionId == representative.sessionId,
                      abs(next.timestamp.timeIntervalSince(representative.timestamp)) <= 60
                else { break }
                runEnd += 1
            }

            let runLength = runEnd - i
            if runLength > 3 {
                // Collapse: keep only the representative
                result.append(representative)
                groupSizes[representative.id] = runLength
            } else {
                // Keep each event individually
                for j in i..<runEnd {
                    let event = events[j]
                    result.append(event)
                    groupSizes[event.id] = 1
                }
            }

            i = runEnd
        }

        return result
    }

    /// Numeric rank for severity filtering (higher = more severe).
    private func severityRank(_ severity: ActivityEventSeverity) -> Int {
        switch severity {
        case .info:    return 0
        case .warning: return 1
        case .error:   return 2
        }
    }
}
