import Foundation

// MARK: - Security Policy (Endpoint Tier)

/// Security tier classification for API endpoints.
///
/// Endpoints are grouped into tiers that determine the level of
/// authentication and authorization required. Higher tiers require
/// stricter access controls, especially when LAN or tunnel access
/// is enabled.
public enum SecurityTier: String, Codable, Sendable, CaseIterable {
    /// No authentication required (e.g., health check).
    case `public` = "public"
    /// Standard authentication required (e.g., sessions, projects, themes).
    case standard = "standard"
    /// Elevated privileges required (e.g., SSH, terminal, permissions, automation).
    case elevated = "elevated"
    /// Full admin access required (e.g., config, system, tunnel, data erasure).
    case admin = "admin"
}

/// Security policy for an endpoint or endpoint group.
///
/// Defines the access control requirements including the security tier,
/// whether authentication is enforced, and whether the endpoint is
/// rate-limited.
public struct SecurityPolicy: Codable, Sendable {
    /// The security tier for this endpoint.
    public let tier: SecurityTier
    /// Whether authentication is required regardless of deployment mode.
    public let requiresAuth: Bool
    /// Whether rate limiting is applied to this endpoint.
    public let rateLimited: Bool
    /// Optional description of the policy for documentation purposes.
    public let description: String?

    public init(
        tier: SecurityTier,
        requiresAuth: Bool = false,
        rateLimited: Bool = true,
        description: String? = nil
    ) {
        self.tier = tier
        self.requiresAuth = requiresAuth
        self.rateLimited = rateLimited
        self.description = description
    }
}

// MARK: - Rate Limit Tier

/// Configurable rate limit tier for an endpoint group.
///
/// Each tier defines the maximum number of requests allowed within
/// a time window. Violations trigger a 429 Too Many Requests response
/// with a consistent error schema.
public struct RateLimitTier: Codable, Sendable, Identifiable {
    /// Unique identifier for this rate limit tier.
    public let id: String
    /// Human-readable name for the tier (e.g., "standard", "burst", "strict").
    public let name: String
    /// Maximum number of requests allowed in the window.
    public let maxRequests: Int
    /// Time window in seconds over which requests are counted.
    public let windowSeconds: Int
    /// Optional retry-after hint in seconds returned on violation.
    public let retryAfterSeconds: Int?

    public init(
        id: String,
        name: String,
        maxRequests: Int,
        windowSeconds: Int,
        retryAfterSeconds: Int? = nil
    ) {
        precondition(!id.isEmpty, "RateLimitTier id must not be empty")
        precondition(!name.isEmpty, "RateLimitTier name must not be empty")
        precondition(maxRequests > 0, "RateLimitTier maxRequests must be positive")
        precondition(windowSeconds > 0, "RateLimitTier windowSeconds must be positive")
        self.id = id
        self.name = name
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
        self.retryAfterSeconds = retryAfterSeconds
    }
}

// MARK: - Security Audit Event

/// Category of security audit events for tracking and telemetry.
public enum SecurityAuditCategory: String, Codable, Sendable, CaseIterable {
    /// Authentication failure (invalid or missing credentials).
    case authFailure = "auth_failure"
    /// Authorization denial (insufficient privileges for the endpoint tier).
    case authzDenial = "authz_denial"
    /// Rate limit violation.
    case rateLimitViolation = "rate_limit_violation"
    /// Invalid or malformed request (bad content-type, unparseable body).
    case requestValidation = "request_validation"
    /// CORS policy violation.
    case corsViolation = "cors_violation"
    /// Suspicious activity detected (oversized query strings, suspicious headers).
    case suspiciousActivity = "suspicious_activity"
    /// Configuration misconfiguration warning (e.g., wildcard CORS, missing API key).
    case configWarning = "config_warning"
}

/// Severity level for security audit events.
public enum SecurityAuditSeverity: String, Codable, Sendable, CaseIterable {
    /// Informational event, no action required.
    case info = "info"
    /// Warning that may indicate a misconfiguration or minor issue.
    case warning = "warning"
    /// Error requiring attention (e.g., repeated auth failures).
    case error = "error"
    /// Critical security event requiring immediate attention.
    case critical = "critical"
}

/// A security audit event for abuse detection and violation tracking.
///
/// Events are emitted by security middleware and collected for
/// telemetry, alerting, and abuse pattern detection.
public struct SecurityAuditEvent: Codable, Sendable, Identifiable {
    /// Unique event identifier.
    public let id: String
    /// Event category.
    public let category: SecurityAuditCategory
    /// Event severity level.
    public let severity: SecurityAuditSeverity
    /// Human-readable event message.
    public let message: String
    /// The endpoint path that triggered the event.
    public let endpoint: String?
    /// Source IP address or identifier.
    public let sourceIP: String?
    /// When the event occurred (UTC).
    public let timestamp: Date
    /// Additional context metadata.
    public let metadata: [String: String]?

    public init(
        id: String,
        category: SecurityAuditCategory,
        severity: SecurityAuditSeverity,
        message: String,
        endpoint: String? = nil,
        sourceIP: String? = nil,
        timestamp: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        precondition(!id.isEmpty, "SecurityAuditEvent id must not be empty")
        precondition(!message.isEmpty, "SecurityAuditEvent message must not be empty")
        self.id = id
        self.category = category
        self.severity = severity
        self.message = message
        self.endpoint = endpoint
        self.sourceIP = sourceIP
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Security Config Response

/// Response for the security configuration endpoint.
///
/// Provides the current security configuration including endpoint
/// policies, rate limit tiers, and deployment mode flags.
public struct SecurityConfigResponse: Codable, Sendable {
    /// Whether LAN access is enabled.
    public let lanEnabled: Bool
    /// Whether tunnel access is active.
    public let tunnelActive: Bool
    /// Whether API key authentication is configured.
    public let apiKeyConfigured: Bool
    /// CORS allowed origins (empty if unrestricted).
    public let corsOrigins: [String]
    /// Rate limit tiers currently configured.
    public let rateLimitTiers: [RateLimitTier]
    /// Active configuration warnings from startup checks.
    public let configWarnings: [String]

    public init(
        lanEnabled: Bool,
        tunnelActive: Bool,
        apiKeyConfigured: Bool,
        corsOrigins: [String] = [],
        rateLimitTiers: [RateLimitTier] = [],
        configWarnings: [String] = []
    ) {
        self.lanEnabled = lanEnabled
        self.tunnelActive = tunnelActive
        self.apiKeyConfigured = apiKeyConfigured
        self.corsOrigins = corsOrigins
        self.rateLimitTiers = rateLimitTiers
        self.configWarnings = configWarnings
    }
}

// MARK: - Security Audit Events Response

/// Paginated list of security audit events for the admin dashboard.
public struct SecurityAuditEventsResponse: Codable, Sendable {
    /// Ordered list of audit events (newest first).
    public let items: [SecurityAuditEvent]
    /// Total number of matching events.
    public let total: Int
    /// Whether additional pages of results are available.
    public let hasMore: Bool

    public init(items: [SecurityAuditEvent], total: Int, hasMore: Bool = false) {
        precondition(total >= 0, "SecurityAuditEventsResponse total must be non-negative")
        self.items = items
        self.total = total
        self.hasMore = hasMore
    }
}

// MARK: - Rate Limit Error Response

/// Error response returned when a rate limit is exceeded.
///
/// Conforms to the consistent error schema used throughout ILS.
public struct RateLimitErrorResponse: Codable, Sendable {
    /// Error code, always "rate_limit_exceeded".
    public let code: String
    /// Human-readable error message.
    public let message: String
    /// Seconds until the client may retry.
    public let retryAfterSeconds: Int
    /// The rate limit tier that was violated.
    public let tier: String

    public init(
        message: String = "Rate limit exceeded. Please retry later.",
        retryAfterSeconds: Int,
        tier: String
    ) {
        precondition(retryAfterSeconds > 0, "RateLimitErrorResponse retryAfterSeconds must be positive")
        precondition(!tier.isEmpty, "RateLimitErrorResponse tier must not be empty")
        self.code = "rate_limit_exceeded"
        self.message = message
        self.retryAfterSeconds = retryAfterSeconds
        self.tier = tier
    }
}
