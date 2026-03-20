import Vapor
import ILSShared

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

/// Endpoint rate limit group determining which rate limit tier applies.
///
/// Groups are resolved from the request path and method. Each group maps
/// to a rate limit tier defined in `SecurityConfigService`.
///
/// Tiers (default limits):
/// - `health`: Unlimited — health/readiness probes are exempt
/// - `standard`: 100 req/min — most API endpoints
/// - `elevated`: 30 req/min — sensitive endpoints (SSH, terminal, permissions)
/// - `admin`: 20 req/min — admin endpoints (config, system, tunnel)
/// - `chatSend`: 10 req/min — POST chat message sends (stricter to prevent abuse)
enum RateLimitGroup: String, Sendable {
    case health
    case standard
    case elevated
    case admin
    case chatSend = "chat_send"

    /// Resolve the rate limit group for a given request.
    ///
    /// SEC-009: Uses specific path prefix matching (not substring) to avoid
    /// false positives on unrelated routes like /api/v1/chatbots.
    static func resolve(for request: Request) -> RateLimitGroup {
        let path = request.url.path

        // Health endpoints are exempt
        if path.hasPrefix("/health") {
            return .health
        }

        // SEC-009: Chat send is POST to /api/v1/chat/ (not substring match)
        if request.method == .POST && path.hasPrefix("/api/v1/chat/") {
            return .chatSend
        }

        // Admin endpoints
        if path.hasPrefix("/api/v1/config") ||
           path.hasPrefix("/api/v1/system") ||
           path.hasPrefix("/api/v1/tunnel") ||
           path.hasPrefix("/api/v1/erasure") {
            return .admin
        }

        // Elevated endpoints
        if path.hasPrefix("/api/v1/ssh") ||
           path.hasPrefix("/api/v1/terminal") ||
           path.hasPrefix("/api/v1/permissions") ||
           path.hasPrefix("/api/v1/automation") ||
           path.hasPrefix("/api/v1/agent-queue") ||
           path.hasPrefix("/api/v1/process") {
            return .elevated
        }

        return .standard
    }
}

/// Rate limiting middleware that enforces per-IP, per-endpoint-group request limits.
///
/// Uses `SecurityConfigService` for configurable rate limit tiers when available,
/// falling back to hardened defaults. Each endpoint group has its own rate limit
/// bucket keyed by `<clientIP>:<group>`.
///
/// Default limits (configurable via SecurityConfigService or env vars):
/// - Health: Unlimited (exempt from rate limiting)
/// - Standard: 100 requests/minute (general API endpoints)
/// - Elevated: 30 requests/minute (sensitive endpoints)
/// - Admin: 20 requests/minute (admin endpoints)
/// - Chat send: 10 requests/minute (POST chat messages)
///
/// All responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`,
/// and `X-RateLimit-Group` headers. Rate-limited responses additionally
/// include `Retry-After` and a structured `RateLimitErrorResponse` body.
struct RateLimitMiddleware: AsyncMiddleware {
    private let storage: RateLimitStorage
    private let windowSeconds: TimeInterval

    // Fallback defaults when SecurityConfigService is unavailable
    private let defaultStandardLimit: Int
    private let defaultElevatedLimit: Int
    private let defaultAdminLimit: Int
    private let defaultChatSendLimit: Int

    init(
        storage: RateLimitStorage = RateLimitStorage(),
        standardLimit: Int = 100,
        elevatedLimit: Int = 30,
        adminLimit: Int = 20,
        chatSendLimit: Int = 10,
        windowSeconds: TimeInterval = 60
    ) {
        self.storage = storage
        self.defaultStandardLimit = standardLimit
        self.defaultElevatedLimit = elevatedLimit
        self.defaultAdminLimit = adminLimit
        self.defaultChatSendLimit = chatSendLimit
        self.windowSeconds = windowSeconds
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let group = RateLimitGroup.resolve(for: request)

        // Health endpoints are exempt from rate limiting
        if group == .health {
            return try await next.respond(to: request)
        }

        // Resolve rate limit and window from SecurityConfigService or fallback defaults
        let (limit, window, tierName) = resolveLimit(for: group, application: request.application)

        // SEC-001: Prefer X-Forwarded-For when behind a reverse proxy.
        // X-Forwarded-For is comma-separated; the FIRST entry is the original client IP.
        // Trim whitespace since proxies may add spaces after commas.
        let clientIP: String
        if let xff = request.headers.first(name: .xForwardedFor) {
            clientIP = xff.split(separator: ",").first
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                ?? request.peerAddress?.ipAddress
                ?? request.remoteAddress?.ipAddress
                ?? "unknown"
        } else {
            clientIP = request.peerAddress?.ipAddress
                ?? request.remoteAddress?.ipAddress
                ?? "unknown"
        }

        let rateLimitKey = "\(clientIP):\(group.rawValue)"

        let result = await storage.checkAndRecord(
            key: rateLimitKey,
            limit: limit,
            windowSeconds: window
        )

        guard result.allowed else {
            let retryAfter = result.retryAfter ?? 1
            request.logger.warning("Rate limit exceeded for \(clientIP) on \(request.url.path) [group=\(group.rawValue), tier=\(tierName)]")

            var headers = HTTPHeaders()
            headers.add(name: .retryAfter, value: String(retryAfter))
            headers.add(name: "X-RateLimit-Limit", value: String(limit))
            headers.add(name: "X-RateLimit-Remaining", value: "0")
            headers.add(name: "X-RateLimit-Group", value: group.rawValue)

            let errorBody = RateLimitErrorResponse(
                message: "Rate limit exceeded. Try again in \(retryAfter) seconds.",
                retryAfterSeconds: retryAfter,
                tier: tierName
            )

            let response = Response(status: .tooManyRequests, headers: headers)
            try response.content.encode(errorBody, as: .json)
            // Re-apply rate limit headers after encoding (encoding may reset headers)
            response.headers.replaceOrAdd(name: .retryAfter, value: String(retryAfter))
            response.headers.replaceOrAdd(name: "X-RateLimit-Limit", value: String(limit))
            response.headers.replaceOrAdd(name: "X-RateLimit-Remaining", value: "0")
            response.headers.replaceOrAdd(name: "X-RateLimit-Group", value: group.rawValue)
            return response
        }

        let response = try await next.respond(to: request)

        // Add rate limit headers to successful responses
        response.headers.add(name: "X-RateLimit-Limit", value: String(limit))
        response.headers.add(name: "X-RateLimit-Remaining", value: String(max(0, limit - result.currentCount)))
        response.headers.add(name: "X-RateLimit-Group", value: group.rawValue)

        return response
    }

    // MARK: - Private

    /// Resolve the rate limit, window, and tier name for a given group.
    ///
    /// Reads from `SecurityConfigService` when available, falling back to
    /// hardcoded defaults to ensure rate limiting is always active.
    private func resolveLimit(
        for group: RateLimitGroup,
        application: Application
    ) -> (limit: Int, window: TimeInterval, tierName: String) {
        // Try to get limits from SecurityConfigService
        if let config = application.storage[SecurityConfigServiceKey.self] {
            switch group {
            case .health:
                // Should not reach here — health is exempted before this call
                return (limit: Int.max, window: windowSeconds, tierName: "health")
            case .standard:
                let tier = config.standardRateLimit
                return (limit: tier.maxRequests, window: TimeInterval(tier.windowSeconds), tierName: tier.id)
            case .elevated:
                // Elevated uses strict tier capped at 30 req/min
                let tier = config.strictRateLimit
                return (limit: min(tier.maxRequests, 30), window: TimeInterval(tier.windowSeconds), tierName: "elevated")
            case .admin:
                // Admin uses strict tier capped at 20 req/min
                let tier = config.strictRateLimit
                return (limit: min(tier.maxRequests, 20), window: TimeInterval(tier.windowSeconds), tierName: "admin")
            case .chatSend:
                // Chat send uses strict tier capped at 10 req/min
                let tier = config.strictRateLimit
                return (limit: min(tier.maxRequests, 10), window: TimeInterval(tier.windowSeconds), tierName: "chat_send")
            }
        }

        // Fallback defaults when SecurityConfigService is not available
        switch group {
        case .health:
            return (limit: Int.max, window: windowSeconds, tierName: "health")
        case .standard:
            return (limit: defaultStandardLimit, window: windowSeconds, tierName: "standard")
        case .elevated:
            return (limit: defaultElevatedLimit, window: windowSeconds, tierName: "elevated")
        case .admin:
            return (limit: defaultAdminLimit, window: windowSeconds, tierName: "admin")
        case .chatSend:
            return (limit: defaultChatSendLimit, window: windowSeconds, tierName: "chat_send")
        }
    }
}
