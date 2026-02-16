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

    static var placeholder: ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isConnected: true,
            sessionCount: 41,
            backendVersion: "1.0.0",
            isPlaceholder: true
        )
    }

    static var disconnected: ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isConnected: false,
            sessionCount: 0,
            backendVersion: "--",
            isPlaceholder: false
        )
    }
}

// MARK: - Widget Data Provider

/// Fetches data from the ILS backend or UserDefaults cache for widget timeline updates.
@available(iOS 17.0, *)
struct WidgetDataProvider {
    private let defaults = UserDefaults(suiteName: widgetAppGroupSuite)

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let serverURL = "widget_server_url"
        static let cachedSessions = "widget_cached_sessions"
        static let cachedServerStatus = "widget_cached_server_connected"
        static let cachedSessionCount = "widget_cached_session_count"
        static let cachedBackendVersion = "widget_cached_backend_version"
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

        let (data, response) = try await URLSession.shared.data(for: request)

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
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults?.set(data, forKey: Keys.cachedSessions)
    }

    private func loadCachedSessions() -> [WidgetSessionInfo] {
        guard let data = defaults?.data(forKey: Keys.cachedSessions),
              let sessions = try? JSONDecoder().decode([WidgetSessionInfo].self, from: data) else {
            return []
        }
        return sessions
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        let health = try decoder.decode(WidgetHealthResponse.self, from: data)

        // Also fetch session count
        let sessionCount = await fetchSessionCount()

        return ServerStatusEntry(
            date: Date(),
            isConnected: health.status == "ok" || health.status == "healthy",
            sessionCount: sessionCount,
            backendVersion: health.version ?? "1.0.0",
            isPlaceholder: false
        )
    }

    private func fetchSessionCount() async -> Int {
        let urlString = "\(serverURL)/api/v1/sessions?limit=1"
        guard let url = URL(string: urlString) else { return 0 }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
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
    }

    private func loadCachedServerStatus() -> ServerStatusEntry {
        ServerStatusEntry(
            date: Date(),
            isConnected: false,
            sessionCount: defaults?.integer(forKey: Keys.cachedSessionCount) ?? 0,
            backendVersion: defaults?.string(forKey: Keys.cachedBackendVersion) ?? "--",
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
#endif
