import Foundation

/// HTTP API client for ILS backend
actor APIClient {
    let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let cacheTTL: TimeInterval
    private var cache: [String: CacheEntry] = [:]

    init(baseURL: String = "http://localhost:8080", cacheTTL: TimeInterval = 60) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.cacheTTL = cacheTTL

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

    // MARK: - Generic Request Methods

    /// Performs a GET request with optional cache bypass
    /// - Parameters:
    ///   - path: The API endpoint path
    ///   - clearCache: If true, clears cache and bypasses it for this request. Use for pull-to-refresh operations.
    /// - Returns: Decoded response of type T
    func get<T: Decodable>(_ path: String, clearCache: Bool = false) async throws -> T {
        // Clear cache if requested (for pull-to-refresh operations)
        if clearCache {
            self.clearCache()
        }

        // Check cache first (unless clearCache was requested)
        if !clearCache, let entry = cache[path] {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age < cacheTTL {
                // Cache hit - return cached data
                if let cachedData = entry.data as? T {
                    return cachedData
                }
            }
        }

        // Cache miss or expired - make network request
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try decoder.decode(T.self, from: data)

        // Store in cache
        cache[path] = CacheEntry(data: decoded, timestamp: Date())

        return decoded
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try decoder.decode(T.self, from: data)

        // Invalidate cache after mutation
        clearCache()

        return decoded
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try decoder.decode(T.self, from: data)

        // Invalidate cache after mutation
        clearCache()

        return decoded
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: "\(baseURL)/api/v1\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoded = try decoder.decode(T.self, from: data)

        // Invalidate cache after mutation
        clearCache()

        return decoded
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ API Error: Invalid response from server")
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ API Error: HTTP \(httpResponse.statusCode) - \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    /// Manually clears all cached responses
    /// Call this method to force fresh data on the next GET request
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Cache Support

private struct CacheEntry {
    let data: Any
    let timestamp: Date
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
