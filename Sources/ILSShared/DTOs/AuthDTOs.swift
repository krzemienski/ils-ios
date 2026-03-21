import Foundation

// MARK: - Authorization Level

/// Defines the scope of access granted by an authentication token.
///
/// Tokens are derived from the master API key using HMAC-SHA256:
/// - `read`: Can access read-only endpoints (sessions list, project info, stats).
/// - `write`: Can access read and write endpoints (create sessions, send messages).
/// - `admin`: Full access including configuration, key rotation, and system management.
public enum AuthorizationLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case read
    case write
    case admin

    /// Whether this level grants at least the specified level of access.
    /// - Parameter required: The minimum required authorization level.
    /// - Returns: `true` if this level meets or exceeds the required level.
    public func satisfies(_ required: AuthorizationLevel) -> Bool {
        return self >= required
    }

    // MARK: Comparable

    private var rank: Int {
        switch self {
        case .read: return 0
        case .write: return 1
        case .admin: return 2
        }
    }

    public static func < (lhs: AuthorizationLevel, rhs: AuthorizationLevel) -> Bool {
        return lhs.rank < rhs.rank
    }
}

// MARK: - Auth Status Response

/// Response describing the current authentication status of the backend.
public struct AuthStatusResponse: Codable, Sendable {
    /// Whether an API key is configured and authentication is active.
    public let isConfigured: Bool
    /// Masked representation of the active key for display (e.g., "ils_...ABCD").
    public let maskedKey: String?
    /// The authorization level of the current request's token.
    public let authorizationLevel: AuthorizationLevel?
    /// Whether the request originated from a remote connection (e.g., Cloudflare tunnel).
    public let isRemote: Bool
    /// Whether key rotation is currently in progress (grace period active).
    public let rotationInProgress: Bool

    /// Creates a new auth status response.
    /// - Parameters:
    ///   - isConfigured: Whether an API key is configured.
    ///   - maskedKey: Masked key for display purposes.
    ///   - authorizationLevel: The authorization level of the current token.
    ///   - isRemote: Whether the request is from a remote connection.
    ///   - rotationInProgress: Whether key rotation grace period is active.
    public init(
        isConfigured: Bool,
        maskedKey: String? = nil,
        authorizationLevel: AuthorizationLevel? = nil,
        isRemote: Bool = false,
        rotationInProgress: Bool = false
    ) {
        self.isConfigured = isConfigured
        self.maskedKey = maskedKey
        self.authorizationLevel = authorizationLevel
        self.isRemote = isRemote
        self.rotationInProgress = rotationInProgress
    }
}

// MARK: - Key Rotation

/// Request payload for rotating the backend API key.
public struct KeyRotationRequest: Codable, Sendable {
    /// Grace period in seconds during which the old key remains valid.
    /// Defaults to 300 (5 minutes) if not specified.
    public let gracePeriodSeconds: Int?

    /// Creates a new key rotation request.
    /// - Parameter gracePeriodSeconds: Grace period for the old key (default 300s).
    public init(gracePeriodSeconds: Int? = nil) {
        self.gracePeriodSeconds = gracePeriodSeconds
    }
}

/// Response from a successful key rotation.
public struct KeyRotationResponse: Codable, Sendable {
    /// The new API key (only returned once — store securely).
    public let newKey: String
    /// Masked representation of the new key for display.
    public let maskedNewKey: String
    /// When the old key will stop being accepted (ISO 8601).
    public let oldKeyExpiresAt: Date
    /// Scoped tokens derived from the new key.
    public let scopedTokens: ScopedTokens

    /// Creates a new key rotation response.
    /// - Parameters:
    ///   - newKey: The new API key.
    ///   - maskedNewKey: Masked new key for display.
    ///   - oldKeyExpiresAt: When the old key expires.
    ///   - scopedTokens: Derived scoped tokens for the new key.
    public init(newKey: String, maskedNewKey: String, oldKeyExpiresAt: Date, scopedTokens: ScopedTokens) {
        self.newKey = newKey
        self.maskedNewKey = maskedNewKey
        self.oldKeyExpiresAt = oldKeyExpiresAt
        self.scopedTokens = scopedTokens
    }
}

/// Scoped authentication tokens derived from the master API key.
public struct ScopedTokens: Codable, Sendable {
    /// Token granting read-only access.
    public let readToken: String
    /// Token granting read-write access.
    public let writeToken: String
    /// Token granting full admin access (same as master key).
    public let adminToken: String

    /// Creates a new set of scoped tokens.
    /// - Parameters:
    ///   - readToken: Token for read-only access.
    ///   - writeToken: Token for read-write access.
    ///   - adminToken: Token for admin access.
    public init(readToken: String, writeToken: String, adminToken: String) {
        self.readToken = readToken
        self.writeToken = writeToken
        self.adminToken = adminToken
    }
}

// MARK: - Challenge-Response Authentication

/// Challenge issued by the backend for remote connection verification.
///
/// Remote clients (via Cloudflare tunnel) must prove possession of the API key
/// by computing HMAC-SHA256 over the nonce using the master key.
public struct AuthChallengeResponse: Codable, Sendable {
    /// Unique challenge identifier for correlating request/response.
    public let challengeId: String
    /// Random nonce that the client must sign (base64url-encoded).
    public let nonce: String
    /// When this challenge expires (ISO 8601). Challenges are single-use.
    public let expiresAt: Date

    /// Creates a new auth challenge.
    /// - Parameters:
    ///   - challengeId: Unique identifier for this challenge.
    ///   - nonce: Random nonce to sign.
    ///   - expiresAt: When the challenge expires.
    public init(challengeId: String, nonce: String, expiresAt: Date) {
        self.challengeId = challengeId
        self.nonce = nonce
        self.expiresAt = expiresAt
    }
}

/// Client's response to an authentication challenge.
public struct AuthChallengeVerification: Codable, Sendable {
    /// The challenge ID from the original challenge.
    public let challengeId: String
    /// HMAC-SHA256 signature of the nonce using the client's API key (base64url-encoded).
    public let signature: String

    /// Creates a new challenge verification.
    /// - Parameters:
    ///   - challengeId: The challenge ID being responded to.
    ///   - signature: HMAC-SHA256 of the nonce.
    public init(challengeId: String, signature: String) {
        self.challengeId = challengeId
        self.signature = signature
    }
}

/// Result of a challenge-response verification attempt.
public struct AuthChallengeResult: Codable, Sendable {
    /// Whether the challenge was verified successfully.
    public let verified: Bool
    /// Session token issued on successful verification (for subsequent requests).
    public let sessionToken: String?
    /// When the session token expires (ISO 8601).
    public let expiresAt: Date?
    /// Error message if verification failed.
    public let error: String?

    /// Creates a new challenge result.
    /// - Parameters:
    ///   - verified: Whether verification succeeded.
    ///   - sessionToken: Token for subsequent requests.
    ///   - expiresAt: When the session token expires.
    ///   - error: Error message on failure.
    public init(verified: Bool, sessionToken: String? = nil, expiresAt: Date? = nil, error: String? = nil) {
        self.verified = verified
        self.sessionToken = sessionToken
        self.expiresAt = expiresAt
        self.error = error
    }
}

// MARK: - Security Audit Log

/// A single entry in the security audit log recording authentication events.
public struct SecurityAuditEntry: Codable, Sendable {
    /// Unique identifier for this audit entry.
    public let id: UUID
    /// When the event occurred (ISO 8601).
    public let timestamp: Date
    /// Source IP address of the request.
    public let sourceIP: String
    /// HTTP method and path of the request (e.g., "GET /api/v1/sessions").
    public let path: String
    /// Type of security event.
    public let eventType: SecurityEventType
    /// Human-readable reason or details about the event.
    public let reason: String
    /// Whether the request was from a remote connection.
    public let isRemote: Bool

    /// Creates a new security audit entry.
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - timestamp: When the event occurred.
    ///   - sourceIP: Source IP address.
    ///   - path: HTTP method and path.
    ///   - eventType: Type of security event.
    ///   - reason: Details about the event.
    ///   - isRemote: Whether from a remote connection.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourceIP: String,
        path: String,
        eventType: SecurityEventType,
        reason: String,
        isRemote: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceIP = sourceIP
        self.path = path
        self.eventType = eventType
        self.reason = reason
        self.isRemote = isRemote
    }
}

/// Types of security events recorded in the audit log.
public enum SecurityEventType: String, Codable, Sendable {
    /// Request with missing authentication credentials.
    case missingAuth = "missing_auth"
    /// Request with an invalid or expired token.
    case invalidToken = "invalid_token"
    /// Request with insufficient authorization level.
    case insufficientAuth = "insufficient_auth"
    /// Client exceeded rate limit.
    case rateLimited = "rate_limited"
    /// Failed challenge-response verification.
    case challengeFailed = "challenge_failed"
    /// Successful key rotation event.
    case keyRotated = "key_rotated"
    /// Successful authentication (logged for remote connections).
    case authSuccess = "auth_success"
}
