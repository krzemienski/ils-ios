#if canImport(WidgetKit)
import Foundation
import WidgetKit

// MARK: - Widget Color Constants

/// Dark theme colors matching the Cyberpunk theme for widget rendering.
/// Defined as constants since widgets cannot access the main app's ThemeManager.
enum WidgetColors {
    static let background = "#030306"
    static let backgroundSecondary = "#07070c"
    static let backgroundTertiary = "#0b0b12"
    static let accent = "#00D4FF"
    static let accentCyan = "#00fff2"
    static let accentMagenta = "#ff00ff"
    static let textPrimary = "#FFFFFF"
    static let textSecondary = "#a0a0b0"
    static let textTertiary = "#9595b8"
    static let success = "#00ff88"
    static let error = "#ff3366"
    static let warning = "#ffd000"
    static let border = "#1a1a2e"
    static let entitySession = "#3B82F6"
}

// MARK: - App Group Suite Name

/// Shared app group identifier for data exchange between the main app and widgets.
let widgetAppGroupSuite = "group.com.ils.app"

// MARK: - Widget Data Models

/// Timeline entry for the SessionWidget.
struct SessionWidgetEntry: TimelineEntry {
    let date: Date
    let sessions: [WidgetSessionInfo]
    let isPlaceholder: Bool

    static var placeholder: SessionWidgetEntry {
        SessionWidgetEntry(
            date: Date(),
            sessions: [
                WidgetSessionInfo(id: "1", name: "API Refactor", model: "opus", messageCount: 42, isActive: true),
                WidgetSessionInfo(id: "2", name: "Bug Fix #331", model: "sonnet", messageCount: 18, isActive: true),
                WidgetSessionInfo(id: "3", name: "Documentation", model: "haiku", messageCount: 7, isActive: false),
                WidgetSessionInfo(id: "4", name: "Code Review", model: "sonnet", messageCount: 25, isActive: true),
                WidgetSessionInfo(id: "5", name: "Architecture", model: "opus", messageCount: 63, isActive: false)
            ],
            isPlaceholder: true
        )
    }

    static var empty: SessionWidgetEntry {
        SessionWidgetEntry(date: Date(), sessions: [], isPlaceholder: false)
    }
}

/// Lightweight session info for widget display.
struct WidgetSessionInfo: Identifiable, Codable {
    let id: String
    let name: String
    let model: String
    let messageCount: Int
    let isActive: Bool
}

/// Timeline entry for the ServerStatusWidget.
struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let sessionCount: Int
    let backendVersion: String
    let isPlaceholder: Bool
    /// Rate limit messages used in the current window (nil if unavailable).
    let rateLimitUsed: Int?
    /// Rate limit messages allowed in the current window (nil if unavailable).
    let rateLimitLimit: Int?

    static var placeholder: ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isConnected: true,
            sessionCount: 41,
            backendVersion: "1.0.0",
            isPlaceholder: true,
            rateLimitUsed: 12,
            rateLimitLimit: 45
        )
    }

    static var disconnected: ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isConnected: false,
            sessionCount: 0,
            backendVersion: "--",
            isPlaceholder: false,
            rateLimitUsed: nil,
            rateLimitLimit: nil
        )
    }
}

/// Timeline entry for the RateLimitWidget.
struct RateLimitWidgetEntry: TimelineEntry {
    let date: Date
    let messagesUsed: Int
    let messagesLimit: Int
    /// ISO 8601 string for when the rate-limit window resets.
    let windowResetsAt: String?
    let isPlaceholder: Bool

    /// Fraction of the rate limit consumed (0.0–1.0).
    var consumptionFraction: Double {
        guard messagesLimit > 0 else { return 0.0 }
        return min(1.0, Double(messagesUsed) / Double(messagesLimit))
    }

    /// Messages remaining before hitting the rate limit.
    var messagesRemaining: Int { max(0, messagesLimit - messagesUsed) }

    static var placeholder: RateLimitWidgetEntry {
        RateLimitWidgetEntry(
            date: Date(),
            messagesUsed: 12,
            messagesLimit: 45,
            windowResetsAt: nil,
            isPlaceholder: true
        )
    }

    static var empty: RateLimitWidgetEntry {
        RateLimitWidgetEntry(
            date: Date(),
            messagesUsed: 0,
            messagesLimit: 45,
            windowResetsAt: nil,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget Data Provider

/// Fetches data from the ILS backend or UserDefaults cache for widget timeline updates.
@available(iOS 17.0, *)
struct WidgetDataProvider {
    private let defaults = UserDefaults(suiteName: widgetAppGroupSuite)

    /// Configured URLSession for background widget fetches.
    /// `isDiscretionary = true` lets the system defer requests to save energy.
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.isDiscretionary = true
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let serverURL = "widget_server_url"
        static let cachedSessions = "widget_cached_sessions"
        static let cachedServerStatus = "widget_cached_server_connected"
        static let cachedSessionCount = "widget_cached_session_count"
        static let cachedBackendVersion = "widget_cached_backend_version"
        static let cachedRateLimitUsed = "widget_cached_rate_limit_used"
        static let cachedRateLimitLimit = "widget_cached_rate_limit_limit"
        static let cachedRateLimitResetsAt = "widget_cached_rate_limit_resets_at"
    }

    /// The base URL for the ILS backend, read from shared UserDefaults.
    var serverURL: String {
        defaults?.string(forKey: Keys.serverURL) ?? "http://localhost:9999"
    }

    // MARK: - Session Data

    /// Fetches recent sessions from the backend API.
    /// Falls back to cached data if the network request fails.
    func fetchRecentSessions() async -> [WidgetSessionInfo] {
        do {
            let sessions = try await fetchSessionsFromAPI()
            cacheSessions(sessions)
            return sessions
        } catch {
            return loadCachedSessions()
        }
    }

    private func fetchSessionsFromAPI() async throws -> [WidgetSessionInfo] {
        let urlString = "\(serverURL)/api/v1/sessions?limit=5&sort=lastActiveAt&order=desc"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await Self.urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Decode the APIResponse wrapper
        let apiResponse = try decoder.decode(WidgetAPIResponse<WidgetListResponse>.self, from: data)

        guard let listData = apiResponse.data else {
            return []
        }

        return listData.items.prefix(5).map { session in
            WidgetSessionInfo(
                id: session.id.uuidString.lowercased(),
                name: session.name ?? session.firstPrompt?.prefix(30).description ?? "Unnamed Session",
                model: session.model,
                messageCount: session.messageCount,
                isActive: session.status == "active"
            )
        }
    }

    private func cacheSessions(_ sessions: [WidgetSessionInfo]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            defaults?.set(data, forKey: Keys.cachedSessions)
        } catch {
            // Widget context has no AppLogger; silently skip caching on encode failure
        }
    }

    private func loadCachedSessions() -> [WidgetSessionInfo] {
        guard let data = defaults?.data(forKey: Keys.cachedSessions) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([WidgetSessionInfo].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Server Status

    /// Fetches server health status from the backend.
    /// Falls back to cached data if the network request fails.
    func fetchServerStatus() async -> ServerStatusEntry {
        do {
            let entry = try await fetchHealthFromAPI()
            cacheServerStatus(entry)
            return entry
        } catch {
            return loadCachedServerStatus()
        }
    }

    private func fetchHealthFromAPI() async throws -> ServerStatusEntry {
        let urlString = "\(serverURL)/health"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (data, response) = try await Self.urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let health = try decoder.decode(WidgetHealthResponse.self, from: data)

        // Fetch session count and rate limit concurrently
        async let sessionCountTask = fetchSessionCount()
        async let rateLimitTask = fetchRateLimitInfo()
        let (sessionCount, rateLimitInfo) = await (sessionCountTask, rateLimitTask)

        return ServerStatusEntry(
            date: Date(),
            isConnected: health.status == "ok" || health.status == "healthy",
            sessionCount: sessionCount,
            backendVersion: health.version ?? "1.0.0",
            isPlaceholder: false,
            rateLimitUsed: rateLimitInfo?.messagesUsed,
            rateLimitLimit: rateLimitInfo?.messagesLimit
        )
    }

    /// Fetches minimal rate limit info to augment the server status entry.
    private func fetchRateLimitInfo() async -> (messagesUsed: Int, messagesLimit: Int)? {
        let urlString = "\(serverURL)/api/v1/usage?period=day"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        do {
            let (data, _) = try await Self.urlSession.data(for: request)
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(WidgetAPIResponse<WidgetUsageMetrics>.self, from: data)
            guard let metrics = apiResponse.data else { return nil }
            return (metrics.rateLimitStatus.messagesUsed, metrics.rateLimitStatus.messagesLimit)
        } catch {
            return nil
        }
    }

    private func fetchSessionCount() async -> Int {
        let urlString = "\(serverURL)/api/v1/sessions?limit=1"
        guard let url = URL(string: urlString) else { return 0 }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        do {
            let (data, _) = try await Self.urlSession.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let apiResponse = try decoder.decode(WidgetAPIResponse<WidgetListResponse>.self, from: data)
            return apiResponse.data?.total ?? 0
        } catch {
            return defaults?.integer(forKey: Keys.cachedSessionCount) ?? 0
        }
    }

    private func cacheServerStatus(_ entry: ServerStatusEntry) {
        defaults?.set(entry.isConnected, forKey: Keys.cachedServerStatus)
        defaults?.set(entry.sessionCount, forKey: Keys.cachedSessionCount)
        defaults?.set(entry.backendVersion, forKey: Keys.cachedBackendVersion)
        if let used = entry.rateLimitUsed {
            defaults?.set(used, forKey: Keys.cachedRateLimitUsed)
        }
        if let limit = entry.rateLimitLimit {
            defaults?.set(limit, forKey: Keys.cachedRateLimitLimit)
        }
    }

    private func loadCachedServerStatus() -> ServerStatusEntry {
        let cachedUsed = defaults?.integer(forKey: Keys.cachedRateLimitUsed)
        let cachedLimit = defaults?.integer(forKey: Keys.cachedRateLimitLimit)
        // Only surface rate limit if we have both values cached and limit is positive
        let rateLimitUsed = (cachedUsed != nil && (cachedLimit ?? 0) > 0) ? cachedUsed : nil
        let rateLimitLimit = (cachedLimit ?? 0) > 0 ? cachedLimit : nil

        return ServerStatusEntry(
            date: Date(),
            isConnected: false,
            sessionCount: defaults?.integer(forKey: Keys.cachedSessionCount) ?? 0,
            backendVersion: defaults?.string(forKey: Keys.cachedBackendVersion) ?? "--",
            isPlaceholder: false,
            rateLimitUsed: rateLimitUsed,
            rateLimitLimit: rateLimitLimit
        )
    }

    // MARK: - Rate Limit Data

    /// Fetches current rate limit status from the backend.
    /// Falls back to cached data if the network request fails.
    func fetchRateLimit() async -> RateLimitWidgetEntry {
        do {
            let entry = try await fetchRateLimitFromAPI()
            cacheRateLimit(entry)
            return entry
        } catch {
            return loadCachedRateLimit()
        }
    }

    private func fetchRateLimitFromAPI() async throws -> RateLimitWidgetEntry {
        let urlString = "\(serverURL)/api/v1/usage?period=day"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await Self.urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(WidgetAPIResponse<WidgetUsageMetrics>.self, from: data)

        guard let metrics = apiResponse.data else {
            throw URLError(.cannotParseResponse)
        }

        return RateLimitWidgetEntry(
            date: Date(),
            messagesUsed: metrics.rateLimitStatus.messagesUsed,
            messagesLimit: metrics.rateLimitStatus.messagesLimit,
            windowResetsAt: metrics.rateLimitStatus.windowResetsAt,
            isPlaceholder: false
        )
    }

    private func cacheRateLimit(_ entry: RateLimitWidgetEntry) {
        defaults?.set(entry.messagesUsed, forKey: Keys.cachedRateLimitUsed)
        defaults?.set(entry.messagesLimit, forKey: Keys.cachedRateLimitLimit)
        if let resetsAt = entry.windowResetsAt {
            defaults?.set(resetsAt, forKey: Keys.cachedRateLimitResetsAt)
        }
    }

    private func loadCachedRateLimit() -> RateLimitWidgetEntry {
        let used = defaults?.integer(forKey: Keys.cachedRateLimitUsed) ?? 0
        let limit = defaults?.integer(forKey: Keys.cachedRateLimitLimit) ?? 45
        let resetsAt = defaults?.string(forKey: Keys.cachedRateLimitResetsAt)
        return RateLimitWidgetEntry(
            date: Date(),
            messagesUsed: used,
            messagesLimit: max(1, limit),
            windowResetsAt: resetsAt,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget-Local Decodable Models

/// Minimal API response wrapper matching the backend's `APIResponse<T>` shape.
private struct WidgetAPIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
}

/// Minimal list response matching the backend's `ListResponse<T>` shape.
private struct WidgetListResponse: Decodable {
    let items: [WidgetSessionDTO]
    let total: Int
}

/// Minimal session DTO for widget decoding (avoids importing ILSShared).
private struct WidgetSessionDTO: Decodable {
    let id: UUID
    let name: String?
    let model: String
    let status: String
    let messageCount: Int
    let firstPrompt: String?
}

/// Minimal health response matching the backend's `/health` endpoint.
private struct WidgetHealthResponse: Decodable {
    let status: String
    let version: String?
}

/// Minimal usage metrics response for widget rate limit display.
private struct WidgetUsageMetrics: Decodable {
    let rateLimitStatus: WidgetRateLimitStatus
}

/// Minimal rate limit status matching `RateLimitStatus` in ILSShared.
private struct WidgetRateLimitStatus: Decodable {
    let messagesUsed: Int
    let messagesLimit: Int
    let windowResetsAt: String?
}
#endif
