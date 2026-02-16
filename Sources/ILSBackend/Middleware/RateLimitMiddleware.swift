import Vapor

/// Rate limiting middleware using a sliding window algorithm.
///
/// Tracks requests per client IP address with configurable limits.
/// Returns 429 Too Many Requests with `Retry-After` header when exceeded.
/// Expired entries are cleaned up periodically to prevent memory growth.
actor RateLimitStorage {
    struct RequestRecord {
        var timestamps: [Date]
    }

    private var records: [String: RequestRecord] = [:]
    private var lastCleanup: Date = Date()
    private let cleanupInterval: TimeInterval = 300 // 5 minutes

    /// Record a request and check if it exceeds the limit.
    /// Returns the number of requests in the current window, or nil if cleanup was performed.
    func checkAndRecord(key: String, limit: Int, windowSeconds: TimeInterval) -> (allowed: Bool, currentCount: Int, retryAfter: Int?) {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowSeconds)

        // Clean up expired entries periodically
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            cleanupExpiredEntries(before: windowStart)
            lastCleanup = now
        }

        // Get or create record for this key
        var record = records[key] ?? RequestRecord(timestamps: [])

        // Remove timestamps outside the window
        record.timestamps = record.timestamps.filter { $0 > windowStart }

        let currentCount = record.timestamps.count

        if currentCount >= limit {
            // Calculate when the oldest request in window will expire
            if let oldest = record.timestamps.first {
                let retryAfter = Int(ceil(oldest.timeIntervalSince(windowStart)))
                return (allowed: false, currentCount: currentCount, retryAfter: max(1, retryAfter))
            }
            return (allowed: false, currentCount: currentCount, retryAfter: 1)
        }

        // Record this request
        record.timestamps.append(now)
        records[key] = record

        return (allowed: true, currentCount: currentCount + 1, retryAfter: nil)
    }

    private func cleanupExpiredEntries(before cutoff: Date) {
        var keysToRemove: [String] = []
        for (key, record) in records {
            let validTimestamps = record.timestamps.filter { $0 > cutoff }
            if validTimestamps.isEmpty {
                keysToRemove.append(key)
            } else {
                records[key] = RequestRecord(timestamps: validTimestamps)
            }
        }
        for key in keysToRemove {
            records.removeValue(forKey: key)
        }
    }
}

/// Rate limiting middleware that enforces per-IP request limits.
///
/// Default limits:
/// - General routes: 100 requests/minute
/// - Chat send routes (`POST /api/v1/chat`): 10 requests/minute
struct RateLimitMiddleware: AsyncMiddleware {
    private let storage: RateLimitStorage
    private let generalLimit: Int
    private let chatLimit: Int
    private let windowSeconds: TimeInterval

    init(
        storage: RateLimitStorage = RateLimitStorage(),
        generalLimit: Int = 100,
        chatLimit: Int = 10,
        windowSeconds: TimeInterval = 60
    ) {
        self.storage = storage
        self.generalLimit = generalLimit
        self.chatLimit = chatLimit
        self.windowSeconds = windowSeconds
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Health endpoint is exempt from rate limiting
        if request.url.path == "/health" || request.url.path == "/health/" {
            return try await next.respond(to: request)
        }

        let clientIP = request.remoteAddress?.description ?? "unknown"
        let isChatSend = request.method == .POST && request.url.path.contains("/chat")
        let limit = isChatSend ? chatLimit : generalLimit
        let rateLimitKey = isChatSend ? "\(clientIP):chat" : clientIP

        let result = await storage.checkAndRecord(
            key: rateLimitKey,
            limit: limit,
            windowSeconds: windowSeconds
        )

        guard result.allowed else {
            request.logger.warning("Rate limit exceeded for \(clientIP) on \(request.url.path)")
            var headers = HTTPHeaders()
            headers.add(name: .retryAfter, value: String(result.retryAfter ?? 1))
            headers.add(name: "X-RateLimit-Limit", value: String(limit))
            headers.add(name: "X-RateLimit-Remaining", value: "0")
            throw Abort(.tooManyRequests, headers: headers, reason: "Rate limit exceeded. Try again in \(result.retryAfter ?? 1) seconds.")
        }

        let response = try await next.respond(to: request)

        // Add rate limit headers to successful responses
        response.headers.add(name: "X-RateLimit-Limit", value: String(limit))
        response.headers.add(name: "X-RateLimit-Remaining", value: String(max(0, limit - result.currentCount)))

        return response
    }
}
