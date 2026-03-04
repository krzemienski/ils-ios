import Foundation

/// HTTP API client for the ILS backend.
///
/// Thread-safe actor providing type-safe REST methods (`get`, `post`, `put`, `delete`)
/// with automatic JSON encoding/decoding, response caching (NSCache with per-endpoint TTL),
/// and request batching for rapid navigation. All paths are automatically prefixed with `/api/v1`.
///
/// Supports optional Bearer-token authentication via Keychain-persisted API key.
/// Supports HTTP conditional requests: stores ETags and sends If-None-Match headers
/// so the server can return 304 Not Modified when content is unchanged, saving bandwidth.
actor APIClient {
    let baseURL: String
    private let session: URLSession
    nonisolated private let decoder: JSONDecoder
    nonisolated private let encoder: JSONEncoder
    private let cache = NSCache<NSString, CacheEntryObject>()
    private let defaultCacheTTL: TimeInterval = 30 // 30 seconds

    /// In-flight GET tasks keyed by path. Actor isolation makes this thread-safe.
    /// Concurrent GET requests to the same path share a single network call.
    private var inFlightGETs: [String: Task<any Sendable, Error>] = [:]

    /// ETag backing store for conditional HTTP requests.
    ///
    /// Stores the last successful response body (Data) and its ETag per path.
    /// Unlike NSCache, this dictionary is never evicted by memory pressure, ensuring
    /// that a 304 Not Modified response always has backing data to decode from.
    /// Entries are cleared on mutations (POST/PUT/DELETE) via invalidateCacheForMutation.
    /// Total byte footprint is bounded by `conditionalCacheByteLimit`.
    private var conditionalCache: [String: (data: Data, etag: String)] = [:]

    /// Running total of bytes stored across all `conditionalCache` entries.
    private var conditionalCacheByteCount: Int = 0

    /// Maximum bytes stored in `conditionalCache` before a full eviction (10 MB).
    /// Mirrors the `totalCostLimit` applied to the NSCache above.
    private let conditionalCacheByteLimit = 10 * 1024 * 1024

    /// Optional API key for authenticated requests.
    /// When set, all /api/v1 requests include `Authorization: Bearer <key>`.
    private var apiKey: String?

    /// Keychain key for persisting the API key (migrated from UserDefaults).
    private static let apiKeyKeychainKey = "ils_api_key"

    /// NSCache-backed entry storing the decoded value to avoid re-decoding on cache hits.
    private final class CacheEntryObject: NSObject {
        let value: Any
        let timestamp: Date

        init(value: Any, timestamp: Date) {
            self.value = value
            self.timestamp = timestamp
        }

        func isValid(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
    }

    /// Per-endpoint TTL: reference data lives longer than session/volatile data.
    private func ttl(for path: String) -> TimeInterval {
        if path.hasPrefix("/skills") || path.hasPrefix("/mcp") || path.hasPrefix("/plugins") || path.hasPrefix("/themes") {
            return 300 // 5 minutes for static reference data
        }
        if path.hasPrefix("/stats") || path.hasPrefix("/sessions") || path.hasPrefix("/usage") {
            return 15 // 15 seconds for frequently-changing data
        }
        if path.hasPrefix("/config") {
            return 60 // 1 minute for configuration
        }
        return defaultCacheTTL
    }

    init(baseURL: String = AppConstants.defaultServerURL) {
        self.baseURL = baseURL
        // Cap cache to prevent unbounded memory growth
        cache.countLimit = 100
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB memory budget
        // Load API key from Keychain (migrate from UserDefaults if legacy key exists)
        if let keychainKey = KeychainService.loadSync(key: APIClient.apiKeyKeychainKey) {
            self.apiKey = keychainKey
        } else if let legacyKey = UserDefaults.standard.string(forKey: APIClient.apiKeyKeychainKey), !legacyKey.isEmpty {
            // One-time migration from UserDefaults to Keychain
            KeychainService.saveSync(key: APIClient.apiKeyKeychainKey, value: legacyKey)
            UserDefaults.standard.removeObject(forKey: APIClient.apiKeyKeychainKey)
            self.apiKey = legacyKey
        } else {
            self.apiKey = nil
        }

        // Configure session with reasonable timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // 10 seconds per request
        config.timeoutIntervalForResource = 30 // 30 seconds total
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        // PLAT-04: Respect user preference for cellular data access (defaults to true).
        config.allowsCellularAccess = UserDefaults.standard.object(forKey: "allowsCellularAccess") as? Bool ?? true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - API Key Management

    /// Update the stored API key. Pass `nil` to clear.
    func setAPIKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalKey = (trimmed?.isEmpty == true) ? nil : trimmed
        self.apiKey = finalKey
        if let finalKey = finalKey {
            KeychainService.saveSync(key: APIClient.apiKeyKeychainKey, value: finalKey)
        } else {
            KeychainService.deleteSync(key: APIClient.apiKeyKeychainKey)
        }
    }

    /// Returns the current API key (masked for display).
    func maskedAPIKey() -> String? {
        guard let key = apiKey, !key.isEmpty else { return nil }
        if key.count <= 8 {
            return String(repeating: "*", count: key.count)
        }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)****\(suffix)"
    }

    /// Whether an API key is currently configured.
    func hasAPIKey() -> Bool {
        return apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    /// Apply authorization header to a request if an API key is configured.
    private func applyAuth(to request: inout URLRequest) {
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }

    // MARK: - Health Check

    func healthCheck() async throws -> String {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw APIError.invalidURL("\(baseURL)/health")
        }
        let (data, _) = try await session.data(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Fetch structured health info (enhanced endpoint)
    func getHealth() async throws -> HealthResponse {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw APIError.invalidURL("\(baseURL)/health")
        }
        let (data, response) = try await session.data(from: url)
        try validateResponse(response, data: data)
        return try decoder.decode(HealthResponse.self, from: data)
    }

    // MARK: - Cost Estimation

    /// Approximate memory cost for NSCache eviction priority.
    /// Uses MemoryLayout.stride as a relative measure -- absolute accuracy
    /// is unnecessary since NSCache treats cost as a priority signal.
    private func estimatedCost<T>(for value: T) -> Int {
        let baseStride = MemoryLayout<T>.stride
        if let array = value as? any RandomAccessCollection {
            return max(baseStride, baseStride * array.count)
        }
        return baseStride
    }

    // MARK: - Generic Request Methods
    //
    // SP-MED-4: Generic methods (get<T>, post<T,B>, etc.) are NOT manually specialized with
    // @_specialize. The Swift compiler performs generic specialization automatically when
    // Whole-Module Optimization (WMO) is enabled (Release builds). Debug builds pay a small
    // witness-table cost (~5ns/call) which is negligible vs. network latency. Manual
    // @_specialize is reserved for hot-loop generics (>10K calls/sec), not RPC wrappers.

    func get<T: Decodable & Sendable>(_ path: String, cacheTTL: TimeInterval? = nil) async throws -> T {
        let cacheKey = path as NSString
        let effectiveTTL = cacheTTL ?? ttl(for: path)

        // ENRG-06: Request deduplication/batching — rapid navigation reuses in-flight cached
        // responses via NSCache. Multiple concurrent GET requests to the same endpoint within
        // the TTL window share a single decoded result without additional network calls.
        // Reference data (skills, mcp, plugins, themes) TTL = 5 min; volatile data TTL = 15s.
        // Return the already-decoded value on cache hit — no JSON re-parsing
        if let entry = cache.object(forKey: cacheKey),
           entry.isValid(ttl: effectiveTTL),
           let cached = entry.value as? T {
            return cached
        }

        // In-flight coalescing: if a GET for this path is already running, share its result
        if let existingTask = inFlightGETs[path] {
            if let result = try await existingTask.value as? T {
                return result
            }
            // Type mismatch — fall through to a new request
        }

        // Wrap the network call in a Task stored in inFlightGETs so concurrent callers share it
        let task = Task<any Sendable, Error> { [baseURL, decoder] in
            defer { self.inFlightGETs[path] = nil }

            guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
                throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            self.applyAuth(to: &request)

            // Attach stored ETag for conditional request (If-None-Match).
            // If server content is unchanged it will respond 304 Not Modified,
            // saving bandwidth by skipping the full response body.
            let cachedEntry = self.conditionalCache[path]
            if let etag = cachedEntry?.etag {
                request.addValue(etag, forHTTPHeaderField: "If-None-Match")
            }

            let (data, response) = try await self.performWithRetry(request: request)

            // Single downcast — reused for both 304 check and ETag header extraction below.
            let httpResponse = response as? HTTPURLResponse

            // Handle 304 Not Modified — server confirmed content is unchanged.
            // Decode from the backed-up response body in conditionalCache and
            // refresh the NSCache entry so the TTL resets without re-downloading.
            if httpResponse?.statusCode == 304 {
                guard let entry = cachedEntry else {
                    // 304 with no backing data (stale ETag sent by mistake).
                    // Clear the bad ETag so next request goes unconditional.
                    self.conditionalCache.removeValue(forKey: path)
                    throw APIError.httpError(statusCode: 304)
                }
                let decoded: T = try decoder.decode(T.self, from: entry.data)
                let cost = self.estimatedCost(for: decoded)
                self.cache.setObject(
                    CacheEntryObject(value: decoded, timestamp: Date()),
                    forKey: cacheKey,
                    cost: cost
                )
                return decoded as any Sendable
            }

            try self.validateResponse(response, data: data)

            let decoded: T = try decoder.decode(T.self, from: data)
            // Store decoded value with estimated cost for memory-bounded eviction
            let cost = self.estimatedCost(for: decoded)
            self.cache.setObject(
                CacheEntryObject(value: decoded, timestamp: Date()),
                forKey: cacheKey,
                cost: cost
            )

            // Store ETag and raw body for future conditional requests.
            // Evict all entries when total byte footprint would exceed the 10 MB limit.
            if let etag = httpResponse?.value(forHTTPHeaderField: "ETag") {
                let incomingSize = data.count
                let existingSize = self.conditionalCache[path]?.data.count ?? 0
                let delta = incomingSize - existingSize
                if self.conditionalCacheByteCount + delta > self.conditionalCacheByteLimit {
                    self.conditionalCache.removeAll()
                    self.conditionalCacheByteCount = 0
                }
                self.conditionalCache[path] = (data: data, etag: etag)
                self.conditionalCacheByteCount += delta
            }

            return decoded as any Sendable
        }
        inFlightGETs[path] = task

        let result = try await task.value
        // Safe downcast — created as T above via `decoded as any Sendable`. Fall through handles edge cases.
        guard let typed = result as? T else {
            throw APIError.decodingError(
                DecodingError.typeMismatch(T.self, .init(codingPath: [], debugDescription: "In-flight result type mismatch"))
            )
        }
        return typed
    }

    func post<T: Decodable & Sendable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)
        applyAuth(to: &request)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response, data: data)

        // Invalidate cache for exact resource + list endpoint
        invalidateCacheForMutation(path: path)

        return try decoder.decode(T.self, from: data)
    }

    func put<T: Decodable & Sendable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)
        applyAuth(to: &request)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response, data: data)

        // Invalidate cache for exact resource + list endpoint
        invalidateCacheForMutation(path: path)

        return try decoder.decode(T.self, from: data)
    }

    func patch<T: Decodable & Sendable, B: Encodable & Sendable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)
        applyAuth(to: &request)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response, data: data)

        invalidateCacheForMutation(path: path)

        return try decoder.decode(T.self, from: data)
    }

    func delete<T: Decodable & Sendable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        applyAuth(to: &request)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response, data: data)

        // Invalidate cache for exact resource + list endpoint
        invalidateCacheForMutation(path: path)

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Raw Request (for SyncCoordinator replay)

    /// Execute a raw HTTP request without decoding the response.
    /// Used by SyncCoordinator to replay queued operations.
    func rawRequest(method: String, endpoint: String, body: Data?) async throws {
        guard let url = URL(string: "\(baseURL)/api/v1\(endpoint)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(endpoint)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        applyAuth(to: &request)

        let (_, response) = try await performWithRetry(request: request)
        try validateResponse(response)

        invalidateCacheForMutation(path: endpoint)
    }

    /// Execute a GET request and return the raw `Data` without JSON decoding.
    /// Useful for endpoints that return plain text or binary content.
    func getRawData(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/api/v1\(path)") else {
            throw APIError.invalidURL("\(baseURL)/api/v1\(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(to: &request)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - Session Helpers

    private struct RenameBody: Encodable {
        let name: String
    }

    func renameSession<T: Decodable & Sendable>(id: UUID, name: String) async throws -> T {
        let body = RenameBody(name: name)
        return try await put("/sessions/\(id.uuidString)", body: body)
    }

    // MARK: - Live Activity Push Token

    private struct LiveActivityTokenBody: Encodable {
        let pushToken: String
    }

    /// Register an APNs push token for Live Activity updates on a specific session.
    ///
    /// When the iOS app is backgrounded, the backend uses this token to push
    /// Live Activity content-state updates via APNs, keeping the Dynamic Island
    /// and Lock Screen widget current without an active SSE connection.
    ///
    /// - Parameters:
    ///   - token: Hex-encoded APNs push token from `Activity.pushTokenUpdates`
    ///   - sessionId: Lowercase UUID string identifying the session
    func registerLiveActivityToken(_ token: String, forSession sessionId: String) async throws {
        let body = LiveActivityTokenBody(pushToken: token)
        let bodyData = try encoder.encode(body)
        try await rawRequest(
            method: "POST",
            endpoint: "/sessions/\(sessionId)/live-activity-token",
            body: bodyData
        )
    }

    // MARK: - Checkpoint & Export Helpers

    private struct CreateCheckpointBody: Encodable {
        let name: String
        let isAutomatic: Bool?
    }

    private struct BulkExportBody: Encodable {
        let sessionIds: [UUID]
        let format: String
        let includeMessages: Bool?
    }

    private struct EmptyRequestBody: Encodable {}

    /// List all checkpoints for a session, sorted by creation date descending.
    func listCheckpoints<T: Decodable>(sessionId: UUID) async throws -> T {
        return try await get("/sessions/\(sessionId.uuidString)/checkpoints", cacheTTL: 0)
    }

    /// Create a named checkpoint for a session at the current message count.
    func createCheckpoint<T: Decodable>(sessionId: UUID, name: String, isAutomatic: Bool = false) async throws -> T {
        let body = CreateCheckpointBody(name: name, isAutomatic: isAutomatic)
        return try await post("/sessions/\(sessionId.uuidString)/checkpoints", body: body)
    }

    /// Delete a checkpoint by ID.
    func deleteCheckpoint<T: Decodable>(id: UUID) async throws -> T {
        return try await delete("/sessions/checkpoints/\(id.uuidString)")
    }

    /// Restore (fork) a session from a checkpoint by its ID.
    func restoreCheckpoint<T: Decodable>(id: UUID) async throws -> T {
        return try await post("/sessions/checkpoints/\(id.uuidString)/restore", body: EmptyRequestBody())
    }

    /// Import a previously exported session. Pass an `ImportSessionRequest` as the body.
    func importSession<T: Decodable, B: Encodable>(export: B) async throws -> T {
        return try await post("/sessions/import", body: export)
    }

    /// Bulk-export multiple sessions as a JSON array of `ChatExport` objects.
    /// - Parameters:
    ///   - sessionIds: Session UUIDs to include in the export.
    ///   - format: Export format string ("json", "markdown", or "text"). Defaults to "json".
    ///   - includeMessages: Whether to include full message content. Defaults to `nil` (server default).
    func bulkExport<T: Decodable>(sessionIds: [UUID], format: String = "json", includeMessages: Bool? = nil) async throws -> T {
        let body = BulkExportBody(sessionIds: sessionIds, format: format, includeMessages: includeMessages)
        return try await post("/sessions/bulk-export", body: body)
    }

    /// Run an integrity check verifying session `messageCount` against stored messages.
    /// - Parameter fix: If `true`, the backend repairs inconsistencies in place.
    func runIntegrityCheck<T: Decodable>(fix: Bool = false) async throws -> T {
        let path = fix ? "/sessions/integrity-check?fix=true" : "/sessions/integrity-check"
        return try await get(path, cacheTTL: 0)
    }

    /// Invalidate cache entries affected by a mutation (POST/PUT/DELETE).
    /// Removes the exact resource path and its parent list endpoint from both
    /// the NSCache (TTL cache) and conditionalCache (ETag backing store).
    /// Also cancels any in-flight GETs for affected paths to prevent stale cache repopulation.
    private func invalidateCacheForMutation(path: String) {
        // Cancel in-flight GET for exact path to prevent stale data from repopulating cache
        inFlightGETs[path]?.cancel()
        inFlightGETs.removeValue(forKey: path)

        // Remove exact path (e.g. /sessions/abc-123)
        cache.removeObject(forKey: path as NSString)
        removeConditionalEntry(forKey: path)

        // Remove list endpoint (e.g. /sessions) and cancel its in-flight GET
        let components = path.split(separator: "/")
        if components.count >= 1 {
            let listPath = "/\(components[0])"
            inFlightGETs[listPath]?.cancel()
            inFlightGETs.removeValue(forKey: listPath)
            cache.removeObject(forKey: listPath as NSString)
            removeConditionalEntry(forKey: listPath)
        }
    }

    func invalidateCache(for path: String? = nil) {
        if let path = path {
            cache.removeObject(forKey: path as NSString)
            removeConditionalEntry(forKey: path)
        } else {
            cache.removeAllObjects()
            conditionalCache.removeAll()
            conditionalCacheByteCount = 0
        }
    }

    /// Remove a single `conditionalCache` entry and update the byte counter.
    private func removeConditionalEntry(forKey key: String) {
        if let entry = conditionalCache.removeValue(forKey: key) {
            conditionalCacheByteCount -= entry.data.count
        }
    }

    // MARK: - Retry Logic

    private func performWithRetry(request: URLRequest, maxAttempts: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                return (data, response)
            } catch {
                lastError = error
                let nsError = error as NSError
                let isTransient = nsError.domain == NSURLErrorDomain && [
                    NSURLErrorTimedOut,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorCannotConnectToHost
                ].contains(nsError.code)

                if !isTransient || attempt == maxAttempts {
                    throw APIError.networkError(error)
                }
                // Exponential backoff: 0.5s, 1s, 2s
                let delay = 0.5 * pow(2.0, Double(attempt - 1))
                try await Task.sleep(for: .seconds(delay))
            }
        }
        throw APIError.networkError(lastError ?? URLError(.unknown))
    }

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Surface 401 as a specific unauthorized error for UI handling
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            // CODBL-01: try? is intentional — error body decode is best-effort fallback when HTTP status != 2xx.
            // If body doesn't match ServerErrorBody, we fall through to httpError(statusCode:).
            if let data = data,
               let errorBody = try? decoder.decode(ServerErrorBody.self, from: data),
               errorBody.error {
                throw APIError.serverError(code: errorBody.code, reason: errorBody.reason)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Types

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorDetail?
}
// CONC-19: @unchecked Sendable — struct has `let` properties only, so value semantics
// make it safe to send across concurrency boundaries regardless of T's Sendable status.
// Unconditional (vs conditional `where T: Sendable`) so callers using non-Sendable T
// (e.g. PaginatedResponse<ChatSession> before ChatSession gets Sendable) don't warn.
extension APIResponse: @unchecked Sendable {}

/// App-side error detail from backend responses (Decodable only).
/// Separate from ILSShared's APIError which requires Codable & Sendable.
struct APIErrorDetail: Decodable, Sendable {
    let code: String
    let message: String
}

struct ListResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
}
// CONC-19: @unchecked Sendable — same reasoning as APIResponse above.
extension ListResponse: @unchecked Sendable {}

// MARK: - Health Response

struct HealthResponse: Decodable, Sendable {
    let status: String
    let version: String?
    let claudeAvailable: Bool?
    let claudeVersion: String?
    let port: Int?
}

/// Decoded structured error from backend
private struct ServerErrorBody: Decodable {
    let error: Bool
    let code: String
    let reason: String
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    case serverError(code: String, reason: String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL(let urlString):
            return "Invalid URL: \(urlString)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid or missing API key. Check your API key in Settings."
        case .httpError(let statusCode):
            let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
            switch statusCode {
            case 400:
                return "Bad request - please check your input"
            case 401:
                return "Authentication required"
            case 403:
                return "Access forbidden"
            case 404:
                return "Resource not found"
            case 500...599:
                return "Server error (\(statusCode)) - please try again later"
            default:
                return "HTTP error: \(statusCode) - \(statusText)"
            }
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let reason):
            switch code {
            case "VALIDATION_ERROR":
                return "Please check your input: \(reason)"
            case "NOT_FOUND":
                return "Resource not found"
            case "SERVICE_UNAVAILABLE":
                return "Service temporarily unavailable. Please try again."
            case "INTERNAL_ERROR":
                return "Something went wrong. Please try again."
            default:
                return reason
            }
        }
    }

    var isRetriable: Bool {
        switch self {
        case .httpError(let statusCode):
            // Retry on server errors (5xx) and rate limiting (429)
            return statusCode >= 500 || statusCode == 429
        case .networkError:
            // Network errors are generally retriable
            return true
        case .invalidURL, .invalidResponse, .decodingError, .unauthorized:
            // These indicate a fundamental problem, not retriable
            return false
        case .serverError(let code, _):
            return code == "INTERNAL_ERROR" || code == "SERVICE_UNAVAILABLE"
        }
    }

    var isNotFound: Bool {
        switch self {
        case .httpError(let statusCode):
            return statusCode == 404
        case .serverError(let code, _):
            return code == "NOT_FOUND"
        default:
            return false
        }
    }

    var isUnauthorized: Bool {
        switch self {
        case .unauthorized:
            return true
        case .httpError(let statusCode):
            return statusCode == 401
        case .serverError(let code, _):
            return code == "UNAUTHORIZED"
        default:
            return false
        }
    }
}
