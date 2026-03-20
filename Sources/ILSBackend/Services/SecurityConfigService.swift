import Foundation
import Vapor
import ILSShared

/// Storage key for shared SecurityConfigService instance.
struct SecurityConfigServiceKey: StorageKey {
    typealias Value = SecurityConfigService
}

/// Provides runtime security configuration with hardened defaults.
///
/// Loads security settings from environment variables, classifies endpoints
/// by security tier, defines rate limit tier configs, validates CORS rules,
/// and emits startup warnings for insecure configurations.
///
/// Access via `app.storage[SecurityConfigServiceKey.self]` from middleware.
final class SecurityConfigService: Sendable {

    // MARK: - Configuration Properties

    /// Whether LAN access is enabled (ILS_LAN_ENABLED=true).
    let lanEnabled: Bool

    /// Whether an API key is configured (ILS_API_KEY is set and non-empty).
    let apiKeyConfigured: Bool

    /// Configured CORS origins (from ILS_CORS_ORIGINS env var).
    let corsOrigins: [String]

    /// Maximum request body size in megabytes.
    let maxBodyMB: Int

    /// Configuration warnings emitted at startup.
    let configWarnings: [String]

    // MARK: - Rate Limit Tiers

    /// Standard rate limit tier for most endpoints.
    let standardRateLimit: RateLimitTier

    /// Burst rate limit tier for high-frequency endpoints (e.g., chat streaming).
    let burstRateLimit: RateLimitTier

    /// Strict rate limit tier for sensitive endpoints (e.g., admin, auth).
    let strictRateLimit: RateLimitTier

    /// Public rate limit tier for unauthenticated endpoints (e.g., health).
    let publicRateLimit: RateLimitTier

    /// All configured rate limit tiers.
    var allRateLimitTiers: [RateLimitTier] {
        [publicRateLimit, standardRateLimit, burstRateLimit, strictRateLimit]
    }

    // MARK: - Endpoint Security Tier Map

    /// Path prefix to security tier classification.
    /// Ordered from most specific to least specific for matching.
    private static let endpointTierMap: [(prefix: String, tier: SecurityTier)] = [
        // Public — no authentication required
        ("/health", .public),
        ("/", .public),  // Root path only (exact match handled separately)

        // Admin — full admin access required
        ("/api/v1/config", .admin),
        ("/api/v1/system", .admin),
        ("/api/v1/tunnel", .admin),
        ("/api/v1/erasure", .admin),

        // Elevated — requires auth when network-exposed
        ("/api/v1/ssh", .elevated),
        ("/api/v1/terminal", .elevated),
        ("/api/v1/permissions", .elevated),
        ("/api/v1/automation", .elevated),
        ("/api/v1/agent-queue", .elevated),
        ("/api/v1/process", .elevated),

        // Standard — normal API access
        ("/api/v1/sessions", .standard),
        ("/api/v1/projects", .standard),
        ("/api/v1/themes", .standard),
        ("/api/v1/chat", .standard),
        ("/api/v1/skills", .standard),
        ("/api/v1/mcp", .standard),
        ("/api/v1/plugins", .standard),
        ("/api/v1/stats", .standard),
        ("/api/v1/teams", .standard),
        ("/api/v1/fleet", .standard),
        ("/api/v1/search", .standard),
        ("/api/v1/templates", .standard),
        ("/api/v1/checkpoints", .standard),
        ("/api/v1/recordings", .standard),
        ("/api/v1/versions", .standard),
        ("/api/v1/profiles", .standard),
        ("/api/v1/feedback", .standard),
        ("/api/v1/audit", .standard),
        ("/api/v1/messages", .standard),
        ("/api/v1/security", .standard),
    ]

    // MARK: - Initialization

    /// Initialize SecurityConfigService from environment variables with hardened defaults.
    ///
    /// - Parameter logger: Logger for startup warnings and diagnostics.
    init(logger: Logger) {
        // Load environment configuration
        self.lanEnabled = Environment.get("ILS_LAN_ENABLED") == "true"
        self.apiKeyConfigured = {
            guard let key = Environment.get("ILS_API_KEY") else { return false }
            return !key.isEmpty
        }()

        // CORS origins
        if let originsEnv = Environment.get("ILS_CORS_ORIGINS"), !originsEnv.isEmpty {
            self.corsOrigins = originsEnv.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            self.corsOrigins = [
                "http://localhost:3000",
                "http://localhost:8080",
                "http://localhost:9999",
                "http://127.0.0.1:3000",
                "http://127.0.0.1:8080",
                "http://127.0.0.1:9999"
            ]
        }

        // Request body size
        self.maxBodyMB = Int(Environment.get("ILS_MAX_BODY_MB") ?? "10") ?? 10

        // Rate limit tiers (configurable via env vars with hardened defaults)
        self.publicRateLimit = RateLimitTier(
            id: "public",
            name: "Public",
            maxRequests: Int(Environment.get("ILS_RATE_PUBLIC_MAX") ?? "120") ?? 120,
            windowSeconds: Int(Environment.get("ILS_RATE_PUBLIC_WINDOW") ?? "60") ?? 60,
            retryAfterSeconds: 10
        )

        self.standardRateLimit = RateLimitTier(
            id: "standard",
            name: "Standard",
            maxRequests: Int(Environment.get("ILS_RATE_STANDARD_MAX") ?? "60") ?? 60,
            windowSeconds: Int(Environment.get("ILS_RATE_STANDARD_WINDOW") ?? "60") ?? 60,
            retryAfterSeconds: 15
        )

        self.burstRateLimit = RateLimitTier(
            id: "burst",
            name: "Burst",
            maxRequests: Int(Environment.get("ILS_RATE_BURST_MAX") ?? "200") ?? 200,
            windowSeconds: Int(Environment.get("ILS_RATE_BURST_WINDOW") ?? "60") ?? 60,
            retryAfterSeconds: 5
        )

        self.strictRateLimit = RateLimitTier(
            id: "strict",
            name: "Strict",
            maxRequests: Int(Environment.get("ILS_RATE_STRICT_MAX") ?? "10") ?? 10,
            windowSeconds: Int(Environment.get("ILS_RATE_STRICT_WINDOW") ?? "60") ?? 60,
            retryAfterSeconds: 30
        )

        // Startup migration checks — collect warnings
        var warnings: [String] = []

        // SEC-WARN-001: LAN enabled without API key is insecure
        if self.lanEnabled && !self.apiKeyConfigured {
            let msg = "SEC-WARN-001: ILS_LAN_ENABLED=true but ILS_API_KEY is not set. " +
                "Network-exposed endpoints lack authentication. Set ILS_API_KEY for production use."
            warnings.append(msg)
            logger.warning("\(msg)")
        }

        // SEC-WARN-002: Wildcard CORS origin detected
        if self.corsOrigins.contains("*") {
            let msg = "SEC-WARN-002: ILS_CORS_ORIGINS contains wildcard '*'. " +
                "This allows any origin to make cross-origin requests. " +
                "Use explicit origins for production."
            warnings.append(msg)
            logger.error("\(msg)")
        }

        // SEC-WARN-003: HTTP origins in production (non-localhost)
        let insecureOrigins = self.corsOrigins.filter { origin in
            origin.hasPrefix("http://") &&
            !origin.contains("localhost") &&
            !origin.contains("127.0.0.1")
        }
        if !insecureOrigins.isEmpty {
            let msg = "SEC-WARN-003: Non-localhost HTTP origins configured: " +
                "\(insecureOrigins.joined(separator: ", ")). " +
                "Use HTTPS for production origins."
            warnings.append(msg)
            logger.warning("\(msg)")
        }

        // SEC-WARN-004: Large max body size
        if self.maxBodyMB > 50 {
            let msg = "SEC-WARN-004: ILS_MAX_BODY_MB=\(self.maxBodyMB) exceeds recommended " +
                "maximum of 50 MB. Large request bodies increase memory pressure and DoS risk."
            warnings.append(msg)
            logger.warning("\(msg)")
        }

        self.configWarnings = warnings

        if warnings.isEmpty {
            logger.info("SecurityConfigService: All startup security checks passed")
        } else {
            logger.warning("SecurityConfigService: \(warnings.count) security warning(s) detected at startup")
        }
    }

    // MARK: - Endpoint Classification

    /// Classify a request path to its security tier.
    ///
    /// - Parameter path: The URL path (e.g., "/api/v1/sessions").
    /// - Returns: The security tier for the endpoint.
    func securityTier(for path: String) -> SecurityTier {
        // Exact match for root
        if path == "/" || path.isEmpty {
            return .public
        }

        // Match against tier map (most specific prefixes first)
        for entry in Self.endpointTierMap {
            if path.hasPrefix(entry.prefix) && entry.prefix != "/" {
                return entry.tier
            }
        }

        // Default: standard tier for unknown API paths
        if path.hasPrefix("/api/") {
            return .standard
        }

        // Non-API paths are public (e.g., static assets)
        return .public
    }

    /// Get the security policy for a given request path.
    ///
    /// - Parameter path: The URL path.
    /// - Returns: A `SecurityPolicy` describing the access requirements.
    func securityPolicy(for path: String) -> SecurityPolicy {
        let tier = securityTier(for: path)

        switch tier {
        case .public:
            return SecurityPolicy(
                tier: .public,
                requiresAuth: false,
                rateLimited: true,
                description: "Public endpoint — no authentication required"
            )
        case .standard:
            return SecurityPolicy(
                tier: .standard,
                requiresAuth: false,
                rateLimited: true,
                description: "Standard endpoint — authentication via API key when configured"
            )
        case .elevated:
            return SecurityPolicy(
                tier: .elevated,
                requiresAuth: lanEnabled,
                rateLimited: true,
                description: "Elevated endpoint — requires authentication when network-exposed"
            )
        case .admin:
            return SecurityPolicy(
                tier: .admin,
                requiresAuth: true,
                rateLimited: true,
                description: "Admin endpoint — always requires authentication"
            )
        }
    }

    /// Get the rate limit tier for a given endpoint path.
    ///
    /// - Parameter path: The URL path.
    /// - Returns: The appropriate `RateLimitTier` for the endpoint.
    func rateLimitTier(for path: String) -> RateLimitTier {
        let tier = securityTier(for: path)

        switch tier {
        case .public:
            return publicRateLimit
        case .standard:
            return standardRateLimit
        case .elevated:
            return strictRateLimit
        case .admin:
            return strictRateLimit
        }
    }

    // MARK: - CORS Validation

    /// Validate whether an origin is allowed by the current CORS configuration.
    ///
    /// - Parameter origin: The origin to validate.
    /// - Returns: `true` if the origin is allowed.
    func isOriginAllowed(_ origin: String) -> Bool {
        // Wildcard allows everything (but triggers startup warning)
        if corsOrigins.contains("*") {
            return true
        }
        return corsOrigins.contains(origin)
    }

    // MARK: - Configuration Response

    /// Generate a `SecurityConfigResponse` for the admin API.
    ///
    /// - Returns: Current security configuration summary.
    func configResponse() -> SecurityConfigResponse {
        SecurityConfigResponse(
            lanEnabled: lanEnabled,
            tunnelActive: false, // Tunnel state is dynamic; checked at request time
            apiKeyConfigured: apiKeyConfigured,
            corsOrigins: corsOrigins,
            rateLimitTiers: allRateLimitTiers,
            configWarnings: configWarnings
        )
    }
}
