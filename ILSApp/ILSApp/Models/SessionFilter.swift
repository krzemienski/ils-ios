import Foundation
import ILSShared

// MARK: - FilterDateRange

/// A relative or absolute date window used to constrain session results.
enum FilterDateRange: Equatable {
    /// Sessions active since midnight today.
    case today
    /// Sessions active during the previous calendar day.
    case yesterday
    /// Sessions active since the start of the current calendar week.
    case thisWeek
    /// Sessions active during the previous calendar week.
    case lastWeek
    /// Sessions active since the start of the current calendar month.
    case thisMonth
    /// Sessions active during the previous calendar month.
    case lastMonth
    /// Sessions active within an arbitrary date window.
    case custom(Date, Date)

    /// Computes the concrete start/end interval for the range relative to *now*.
    /// - Parameter calendar: Calendar to use for date arithmetic (defaults to `.current`).
    func dateInterval(calendar: Calendar = .current) -> DateInterval {
        let now = Date()
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)

        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
            return DateInterval(start: yesterdayStart, end: todayStart)

        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            return DateInterval(start: weekStart, end: now)

        case .lastWeek:
            let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
            return DateInterval(start: lastWeekStart, end: thisWeekStart)

        case .thisMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)!.start
            return DateInterval(start: monthStart, end: now)

        case .lastMonth:
            let thisMonthStart = calendar.dateInterval(of: .month, for: now)!.start
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            return DateInterval(start: lastMonthStart, end: thisMonthStart)

        case .custom(let start, let end):
            return DateInterval(start: start, end: end)
        }
    }

    /// Short human-readable label suitable for displaying inside a search explanation chip.
    var displayName: String {
        switch self {
        case .today:      return "today"
        case .yesterday:  return "yesterday"
        case .thisWeek:   return "this week"
        case .lastWeek:   return "last week"
        case .thisMonth:  return "this month"
        case .lastMonth:  return "last month"
        case .custom(let start, let end):
            let s = DateFormatters.date.string(from: start)
            let e = DateFormatters.date.string(from: end)
            return "\(s) – \(e)"
        }
    }
}

// MARK: - ParsedQuery

/// The structured result of parsing a natural language search query on-device.
///
/// Produced by ``NaturalLanguageQueryParser`` and consumed by ``SessionFilter``
/// so that every filter application also carries a user-visible explanation.
struct ParsedQuery: Equatable {
    /// The raw, unmodified string the user typed.
    let originalQuery: String

    /// Topic/keyword tokens extracted for full-text matching.
    var searchTokens: [String]

    /// Temporal constraint detected in the query, if any.
    var dateRange: FilterDateRange?

    /// Model family keyword (e.g., "sonnet", "haiku") detected in the query, if any.
    var modelFilter: String?

    /// Session status constraint detected in the query, if any.
    var statusFilter: SessionStatus?

    /// Project name fragment detected in the query, if any.
    var projectFilter: String?

    /// Confidence in the structured interpretation (0.0–1.0).
    /// Values below a threshold should fall back to plain full-text search.
    var confidence: Double

    /// Human-readable explanation of the parsed interpretation, e.g.
    /// "Showing: project=React, date=last week, status=error".
    var explanation: String

    /// `true` when no structured predicates were found — only keyword tokens.
    /// The caller should use ``searchTokens`` for a plain full-text search.
    var isFullTextOnly: Bool {
        dateRange == nil && modelFilter == nil && statusFilter == nil && projectFilter == nil
    }
}

// MARK: - SessionFilter

/// A composed set of predicates for filtering ``ChatSession`` arrays.
///
/// All fields are optional/empty by default, meaning no filtering is applied.
/// Use ``applying(_:)`` on ``Array<ChatSession>`` to obtain matching sessions.
struct SessionFilter: Equatable {
    /// Plain-text search matched case-insensitively against session name,
    /// project name, and first user prompt.
    var searchText: String = ""

    /// Optional relative or absolute date window.  Sessions whose
    /// ``ChatSession/lastActiveAt`` falls outside this interval are excluded.
    var dateRange: FilterDateRange?

    /// Optional model name fragment (e.g., "haiku").  Matched case-insensitively
    /// against ``ChatSession/model``.
    var model: String?

    /// Set of allowed session statuses.  An empty set means any status is accepted.
    var statuses: Set<SessionStatus> = []

    /// Optional project name fragment matched case-insensitively against
    /// ``ChatSession/projectName``.
    var projectName: String?

    /// The ``ParsedQuery`` that produced this filter, when it originated from a
    /// natural language query.  `nil` for filters composed through the manual
    /// filter UI.
    var parsedQuery: ParsedQuery?

    /// `true` when no active predicate would change the full session list.
    var isEmpty: Bool {
        searchText.isEmpty
            && dateRange == nil
            && model == nil
            && statuses.isEmpty
            && projectName == nil
    }

    /// Short human-readable summary of the active predicates, suitable for
    /// display in the search bar explanation row.
    ///
    /// Returns the NL parser explanation verbatim when available, so phrasing
    /// matches the user's original intent rather than the raw filter values.
    var explanation: String {
        if let parsed = parsedQuery {
            return parsed.explanation
        }
        var parts: [String] = []
        if !searchText.isEmpty {
            parts.append("text: \"\(searchText)\"")
        }
        if let dr = dateRange {
            parts.append("date: \(dr.displayName)")
        }
        if let m = model {
            parts.append("model: \(m)")
        }
        if !statuses.isEmpty {
            let labels = statuses.map(\.rawValue).sorted().joined(separator: ", ")
            parts.append("status: \(labels)")
        }
        if let p = projectName {
            parts.append("project: \(p)")
        }
        return parts.isEmpty ? "" : "Showing: " + parts.joined(separator: " · ")
    }
}

// MARK: - Array<ChatSession> Filtering

extension Array where Element == ChatSession {
    /// Returns the sessions that satisfy every predicate in *filter*.
    ///
    /// - Complexity: O(*n*) where *n* is the number of sessions.
    /// - Parameter filter: The ``SessionFilter`` to apply.
    /// - Returns: A new array containing only the sessions that match all
    ///   active predicates, preserving the original order.
    func applying(_ filter: SessionFilter) -> [ChatSession] {
        guard !filter.isEmpty else { return self }
        return self.filter { session in
            // Date range predicate
            if let dateRange = filter.dateRange {
                let interval = dateRange.dateInterval()
                guard interval.contains(session.lastActiveAt) else { return false }
            }

            // Model predicate
            if let modelFragment = filter.model?.lowercased(), !modelFragment.isEmpty {
                guard session.model.lowercased().contains(modelFragment) else { return false }
            }

            // Status predicate
            if !filter.statuses.isEmpty {
                guard filter.statuses.contains(session.status) else { return false }
            }

            // Project name predicate
            if let projectFragment = filter.projectName?.lowercased(), !projectFragment.isEmpty {
                let sessionProject = session.projectName?.lowercased() ?? ""
                guard sessionProject.contains(projectFragment) else { return false }
            }

            // Full-text predicate (name · project · first prompt)
            if !filter.searchText.isEmpty {
                let query = filter.searchText.lowercased()
                let nameMatch    = session.displayName.lowercased().contains(query)
                let projectMatch = (session.projectName ?? "").lowercased().contains(query)
                let promptMatch  = (session.firstPrompt ?? "").lowercased().contains(query)
                guard nameMatch || projectMatch || promptMatch else { return false }
            }

            return true
        }
    }
}
