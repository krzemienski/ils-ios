import Foundation

/// HTTP API client for ILS backend
actor APIClient {
    let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var cache: [String: CacheEntry] = [:]
    private let defaultCacheTTL: TimeInterval = 30 // 30 seconds

    private struct CacheEntry {
        let data: Data
        let timestamp: Date

        func isValid(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
    }

    init(baseURL: String = "http://localhost:9090") {
        self.baseURL = baseURL
        
        // Configure session with reasonable timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10 // 10 seconds per request
        config.timeoutIntervalForResource = 30 // 30 seconds total
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Health Check

    func healthCheck() async throws -> String {
        let url = URL(string: "\(baseURL)/health")!
        let (data, _) = try await session.data(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Fetch structured health info (enhanced endpoint)
    func getHealth() async throws -> HealthResponse {
        let url = URL(string: "\(baseURL)/health")!
        let (data, response) = try await session.data(from: url)
        try validateResponse(response)
        return try decoder.decode(HealthResponse.self, from: data)
    }

    // MARK: - Generic Request Methods

    func get<T: Decodable>(_ path: String, cacheTTL: TimeInterval? = nil) async throws -> T {
        let cacheKey = path
        let ttl = cacheTTL ?? defaultCacheTTL

        // Check cache
        if let entry = cache[cacheKey], entry.isValid(ttl: ttl) {
            return try decoder.decode(T.self, from: entry.data)
        }

        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response)

        // Cache the raw data
        cache[cacheKey] = CacheEntry(data: data, timestamp: Date())

        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response)

        // Invalidate GET cache for the base path
        let basePath = path.split(separator: "/").prefix(2).joined(separator: "/")
        cache.removeValue(forKey: "/\(basePath)")

        return try decoder.decode(T.self, from: data)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response)

        // Invalidate GET cache for the base path
        let basePath = path.split(separator: "/").prefix(2).joined(separator: "/")
        cache.removeValue(forKey: "/\(basePath)")

        return try decoder.decode(T.self, from: data)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performWithRetry(request: request)
        try validateResponse(response)

        // Invalidate GET cache for the base path
        let basePath = path.split(separator: "/").prefix(2).joined(separator: "/")
        cache.removeValue(forKey: "/\(basePath)")

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Session Helpers

    private struct RenameBody: Encodable {
        let name: String
    }

    func renameSession<T: Decodable>(id: UUID, name: String) async throws -> T {
        let body = RenameBody(name: name)
        return try await put("/sessions/\(id.uuidString)", body: body)
    }

    func invalidateCache(for path: String? = nil) {
        if let path = path {
            cache.removeValue(forKey: path)
        } else {
            cache.removeAll()
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

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - API Response Types

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: APIErrorResponse?
}

struct APIErrorResponse: Decodable {
    let code: String
    let message: String
}

struct ListResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
}

// MARK: - Health Response

struct HealthResponse: Decodable {
    let status: String
    let version: String?
    let claudeAvailable: Bool?
    let claudeVersion: String?
    let port: Int?
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
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
        case .invalidResponse, .decodingError:
            // These indicate a fundamental problem, not retriable
            return false
        }
    }
}
