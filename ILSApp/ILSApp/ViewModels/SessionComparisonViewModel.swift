import Foundation
import Observation
import ILSShared

/// View model for the session comparison feature.
///
/// Manages the two sessions being compared, their message histories,
/// the recently-compared list persisted in UserDefaults, and Markdown export.
///
/// Calls `GET /sessions/compare?a=id&b=id` to load side-by-side session data
/// and persists up to five recently-compared pairs in UserDefaults for quick re-comparison.
///
/// ## Topics
/// ### Properties
/// - ``sessionA`` - First session being compared
/// - ``sessionB`` - Second session being compared
/// - ``messagesA`` - Messages from session A in chronological order
/// - ``messagesB`` - Messages from session B in chronological order
/// - ``isLoading`` - Whether the comparison is currently loading
/// - ``error`` - Current error, if any
/// - ``recentlyCompared`` - Recently compared session pairs
///
/// ### Operations
/// - ``configure(client:)`` - Inject the API client
/// - ``loadComparison(a:b:)`` - Load a side-by-side comparison of two sessions
/// - ``addToRecentlyCompared(a:b:)`` - Persist a pair to the recently-compared list
/// - ``loadRecentlyCompared()`` - Reload the recently-compared list from UserDefaults
/// - ``exportComparisonMarkdown()`` - Generate a Markdown export of the current comparison
@Observable
@MainActor
class SessionComparisonViewModel {

    // MARK: - Comparison State

    /// First session being compared.
    var sessionA: ChatSession?

    /// Second session being compared.
    var sessionB: ChatSession?

    /// Messages from the first session in chronological order.
    var messagesA: [Message] = []

    /// Messages from the second session in chronological order.
    var messagesB: [Message] = []

    /// Whether a comparison is currently loading.
    var isLoading = false

    /// Current error, if any.
    var error: Error?

    // MARK: - Recently Compared

    /// Recently compared session pairs, sorted newest-first (max 5).
    var recentlyCompared: [RecentlyComparedPair] = []

    // MARK: - Private

    private static let recentlyComparedKey = "ils_recentlyCompared"
    private static let maxRecentlyCompared = 5

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private var client: APIClient?

    init() {}

    // MARK: - Configuration

    /// Configure the view model with an API client.
    /// - Parameter client: The API client to use for requests
    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - Comparison Operations

    /// Load a side-by-side comparison of two sessions from the API.
    ///
    /// On success, populates ``sessionA``, ``sessionB``, ``messagesA``, ``messagesB``
    /// and appends the pair to the recently-compared list.
    /// - Parameters:
    ///   - a: ID of the first session
    ///   - b: ID of the second session
    func loadComparison(a: UUID, b: UUID) async {
        guard let client else { return }
        isLoading = true
        error = nil

        let path = "/sessions/compare?a=\(a.uuidString.lowercased())&b=\(b.uuidString.lowercased())"
        do {
            let response: APIResponse<SessionComparisonResult> = try await client.get(path, cacheTTL: 0)
            if let result = response.data {
                sessionA = result.sessionA
                sessionB = result.sessionB
                messagesA = result.messagesA
                messagesB = result.messagesB
                addToRecentlyCompared(a: result.sessionA, b: result.sessionB)
            } else if let apiError = response.error {
                error = NSError(
                    domain: "SessionComparison",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: apiError.message]
                )
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Export

    /// Generate a Markdown export of the current comparison.
    ///
    /// Returns an empty string if either session has not been loaded.
    /// - Returns: Formatted Markdown with session headers, a metrics table, and parallel message pairs
    func exportComparisonMarkdown() -> String {
        guard let sessionA, let sessionB else { return "" }

        var md = "# Session Comparison\n\n"

        // Session headers
        md += "## Sessions\n\n"
        md += "**Session A:** \(sessionA.name ?? "Unnamed")\n"
        md += "**Session B:** \(sessionB.name ?? "Unnamed")\n\n"

        // Metrics table
        md += "## Metrics\n\n"
        md += "| Metric | Session A | Session B |\n"
        md += "|--------|-----------|----------|\n"
        md += "| Messages | \(messagesA.count) | \(messagesB.count) |\n"
        md += "| Model | \(sessionA.model.capitalized) | \(sessionB.model.capitalized) |\n"
        md += "| Status | \(sessionA.status.rawValue.capitalized) | \(sessionB.status.rawValue.capitalized) |\n"
        if let costA = sessionA.totalCostUSD, let costB = sessionB.totalCostUSD {
            md += "| Cost | $\(String(format: "%.4f", costA)) | $\(String(format: "%.4f", costB)) |\n"
        }
        md += "\n---\n\n"

        // Parallel message pairs
        md += "## Messages\n\n"
        let maxCount = max(messagesA.count, messagesB.count)
        for index in 0..<maxCount {
            md += "### Turn \(index + 1)\n\n"
            if index < messagesA.count {
                let msg = messagesA[index]
                let role = msg.role.rawValue.capitalized
                md += "**A — \(role):** \(msg.content)\n\n"
            } else {
                md += "**A:** _(no message)_\n\n"
            }
            if index < messagesB.count {
                let msg = messagesB[index]
                let role = msg.role.rawValue.capitalized
                md += "**B — \(role):** \(msg.content)\n\n"
            } else {
                md += "**B:** _(no message)_\n\n"
            }
        }

        return md
    }

    // MARK: - Recently Compared Persistence

    /// Reload the recently-compared list from UserDefaults.
    func loadRecentlyCompared() {
        guard let data = UserDefaults.standard.data(forKey: Self.recentlyComparedKey) else {
            recentlyCompared = []
            return
        }
        do {
            recentlyCompared = try Self.decoder.decode([RecentlyComparedPair].self, from: data)
        } catch {
            AppLogger.shared.error(
                "SessionComparisonViewModel: failed to decode recentlyCompared: \(error.localizedDescription)",
                category: "comparison"
            )
            recentlyCompared = []
        }
    }

    /// Add a session pair to the recently-compared list (LIFO, max 5).
    ///
    /// Any existing entry for the same pair (in either order) is removed before inserting
    /// the new entry at the front. The list is trimmed to five entries.
    /// - Parameters:
    ///   - a: First session in the pair
    ///   - b: Second session in the pair
    func addToRecentlyCompared(a: ChatSession, b: ChatSession) {
        var pairs = recentlyCompared

        // Remove existing entry for the same pair (either order)
        pairs.removeAll {
            ($0.sessionAId == a.id && $0.sessionBId == b.id) ||
            ($0.sessionAId == b.id && $0.sessionBId == a.id)
        }

        // Insert new entry at front (LIFO)
        let newPair = RecentlyComparedPair(
            sessionAId: a.id,
            sessionBId: b.id,
            sessionAName: a.name,
            sessionBName: b.name
        )
        pairs.insert(newPair, at: 0)

        // Enforce max-entries cap
        if pairs.count > Self.maxRecentlyCompared {
            pairs = Array(pairs.prefix(Self.maxRecentlyCompared))
        }

        recentlyCompared = pairs
        persistRecentlyCompared(pairs)
    }

    private func persistRecentlyCompared(_ pairs: [RecentlyComparedPair]) {
        do {
            let data = try Self.encoder.encode(pairs)
            UserDefaults.standard.set(data, forKey: Self.recentlyComparedKey)
        } catch {
            AppLogger.shared.error(
                "SessionComparisonViewModel: failed to persist recentlyCompared: \(error.localizedDescription)",
                category: "comparison"
            )
        }
    }
}
