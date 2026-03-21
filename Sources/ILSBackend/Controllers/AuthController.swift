import Vapor
import CryptoKit
import ILSShared
import Foundation

/// Controller for authentication management endpoints.
///
/// Routes (all under `/api/v1/auth`):
/// - `GET  /auth/status`    — current authentication status and configuration
/// - `POST /auth/rotate`    — rotate the API key with optional grace period
/// - `GET  /auth/audit`     — retrieve security audit log entries
/// - `POST /auth/challenge` — issue a challenge for remote tunnel verification
/// - `POST /auth/challenge/verify` — verify a challenge response
struct AuthController: RouteCollection {
    // MARK: - State

    /// In-memory security audit log.
    private static let auditLog = SecurityAuditLog()

    /// In-memory pending challenges for remote verification.
    private static let challengeStore = ChallengeStore()

    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("auth")

        auth.get("status", use: status)
        auth.post("rotate", use: rotate)
        auth.get("audit", use: audit)
        auth.post("challenge", use: challenge)
        auth.post("challenge", "verify", use: verifyChallenge)
    }

    // MARK: - Endpoints

    /// GET /auth/status — returns the current authentication status.
    ///
    /// Reports whether an API key is configured, the caller's authorization level,
    /// whether the request is remote, and whether a key rotation is in progress.
    @Sendable
    func status(req: Request) async throws -> APIResponse<AuthStatusResponse> {
        let storage = apiKeyStorage(req: req)
        let isConfigured = await storage.currentKey() != nil
        let masked = await storage.maskedKey()
        let authLevel = req.storage[AuthLevelKey.self]
        let isRemote = req.headers.first(name: "cf-connecting-ip") != nil
        let rotationInProgress = await storage.isRotationInProgress

        let response = AuthStatusResponse(
            isConfigured: isConfigured,
            maskedKey: masked,
            authorizationLevel: authLevel,
            isRemote: isRemote,
            rotationInProgress: rotationInProgress
        )

        return APIResponse(success: true, data: response)
    }

    /// POST /auth/rotate — rotate the API key.
    ///
    /// Accepts an optional `KeyRotationRequest` body with a custom grace period.
    /// Returns the new key (shown only once), masked key, expiration of the old key,
    /// and new scoped tokens.
    @Sendable
    func rotate(req: Request) async throws -> APIResponse<KeyRotationResponse> {
        let storage = apiKeyStorage(req: req)
        let input = try? req.content.decode(KeyRotationRequest.self)

        do {
            let rotationResponse = try await storage.rotateKey(
                gracePeriodSeconds: input?.gracePeriodSeconds
            )

            // Record audit event.
            let sourceIP = req.peerAddress?.description ?? "unknown"
            await Self.auditLog.append(SecurityAuditEntry(
                sourceIP: sourceIP,
                path: "\(req.method.rawValue) \(req.url.path)",
                eventType: .keyRotated,
                reason: "API key rotated successfully"
            ))

            return APIResponse(success: true, data: rotationResponse)
        } catch let error as APIKeyStorageError {
            throw Abort(.conflict, reason: error.description)
        }
    }

    /// GET /auth/audit — retrieve security audit log entries.
    ///
    /// Query parameters:
    /// - `limit`: Maximum entries to return (default 50, max 500).
    /// - `offset`: Pagination offset (default 0).
    /// - `eventType`: Filter by event type (e.g., "invalid_token").
    @Sendable
    func audit(req: Request) async throws -> APIResponse<SecurityAuditResponse> {
        let limit = min((req.query["limit"] as Int?) ?? 50, 500)
        let offset = max((req.query["offset"] as Int?) ?? 0, 0)
        let eventTypeFilter: String? = req.query["eventType"]

        var entries = await Self.auditLog.entries()

        // Filter by event type if specified.
        if let filter = eventTypeFilter, let eventType = SecurityEventType(rawValue: filter) {
            entries = entries.filter { $0.eventType == eventType }
        }

        let totalCount = entries.count
        let end = min(offset + limit, totalCount)
        let start = min(offset, totalCount)
        let paged = Array(entries[start..<end])

        return APIResponse(
            success: true,
            data: SecurityAuditResponse(
                entries: paged,
                totalCount: totalCount,
                hasMore: end < totalCount
            )
        )
    }

    /// POST /auth/challenge — issue a challenge for remote tunnel verification.
    ///
    /// Returns a nonce that the remote client must sign with HMAC-SHA256
    /// using their API key to prove possession.
    @Sendable
    func challenge(req: Request) async throws -> APIResponse<AuthChallengeResponse> {
        let challengeId = UUID().uuidString
        let nonceBytes = SymmetricKey(size: .bits256)
        let nonceData = nonceBytes.withUnsafeBytes { Data($0) }
        let nonce = nonceData
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let expiresAt = Date(timeIntervalSinceNow: 60) // 60-second expiry

        let challengeResponse = AuthChallengeResponse(
            challengeId: challengeId,
            nonce: nonce,
            expiresAt: expiresAt
        )

        await Self.challengeStore.store(
            PendingChallenge(id: challengeId, nonce: nonce, expiresAt: expiresAt)
        )

        return APIResponse(success: true, data: challengeResponse)
    }

    /// POST /auth/challenge/verify — verify a challenge response.
    ///
    /// The client sends the challenge ID and an HMAC-SHA256 signature of the nonce.
    /// On success, returns a session token for subsequent requests.
    @Sendable
    func verifyChallenge(req: Request) async throws -> APIResponse<AuthChallengeResult> {
        let input = try req.content.decode(AuthChallengeVerification.self)

        // Look up the pending challenge.
        guard let pending = await Self.challengeStore.consume(id: input.challengeId) else {
            let sourceIP = req.peerAddress?.description ?? "unknown"
            await Self.auditLog.append(SecurityAuditEntry(
                sourceIP: sourceIP,
                path: "\(req.method.rawValue) \(req.url.path)",
                eventType: .challengeFailed,
                reason: "Challenge not found or expired: \(input.challengeId)"
            ))
            return APIResponse(
                success: true,
                data: AuthChallengeResult(verified: false, error: "Challenge not found or expired")
            )
        }

        // Check expiry.
        guard Date() < pending.expiresAt else {
            let sourceIP = req.peerAddress?.description ?? "unknown"
            await Self.auditLog.append(SecurityAuditEntry(
                sourceIP: sourceIP,
                path: "\(req.method.rawValue) \(req.url.path)",
                eventType: .challengeFailed,
                reason: "Challenge expired: \(input.challengeId)"
            ))
            return APIResponse(
                success: true,
                data: AuthChallengeResult(verified: false, error: "Challenge has expired")
            )
        }

        // Verify signature against the master key.
        let storage = apiKeyStorage(req: req)
        guard let masterKey = await storage.currentKey() else {
            throw Abort(.internalServerError, reason: "No API key configured")
        }

        let expectedMAC = HMAC<SHA256>.authenticationCode(
            for: Data(pending.nonce.utf8),
            using: SymmetricKey(data: Data(masterKey.utf8))
        )
        let expectedSignature = Data(expectedMAC)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let sourceIP = req.peerAddress?.description ?? "unknown"

        guard constantTimeEqual(input.signature, expectedSignature) else {
            await Self.auditLog.append(SecurityAuditEntry(
                sourceIP: sourceIP,
                path: "\(req.method.rawValue) \(req.url.path)",
                eventType: .challengeFailed,
                reason: "Invalid signature for challenge: \(input.challengeId)",
                isRemote: true
            ))
            return APIResponse(
                success: true,
                data: AuthChallengeResult(verified: false, error: "Invalid signature")
            )
        }

        // Success — issue a session token (valid for 1 hour).
        let sessionToken = UUID().uuidString
        let tokenExpiry = Date(timeIntervalSinceNow: 3600)

        await Self.auditLog.append(SecurityAuditEntry(
            sourceIP: sourceIP,
            path: "\(req.method.rawValue) \(req.url.path)",
            eventType: .authSuccess,
            reason: "Challenge verified successfully",
            isRemote: true
        ))

        return APIResponse(
            success: true,
            data: AuthChallengeResult(
                verified: true,
                sessionToken: sessionToken,
                expiresAt: tokenExpiry
            )
        )
    }

    // MARK: - Helpers

    /// Retrieve the `APIKeyStorageService` from the application storage.
    private func apiKeyStorage(req: Request) -> APIKeyStorageService {
        guard let storage = req.application.storage[APIKeyStorageKey.self] else {
            return APIKeyStorageService.shared
        }
        return storage
    }

    /// Constant-time string comparison to prevent timing side-channel attacks.
    private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }
        return result == 0
    }
}

// MARK: - Security Audit Response

struct SecurityAuditResponse: Content {
    /// Audit log entries for the requested page.
    let entries: [SecurityAuditEntry]
    /// Total number of entries matching the filter.
    let totalCount: Int
    /// Whether more entries exist beyond this page.
    let hasMore: Bool
}

// MARK: - In-Memory Audit Log

/// Thread-safe in-memory store for security audit entries.
private actor SecurityAuditLog {
    private var log: [SecurityAuditEntry] = []

    /// Maximum entries retained in memory.
    private let maxEntries = 10_000

    func append(_ entry: SecurityAuditEntry) {
        log.append(entry)
        // Trim oldest entries if over capacity.
        if log.count > maxEntries {
            log.removeFirst(log.count - maxEntries)
        }
    }

    func entries() -> [SecurityAuditEntry] {
        return log.reversed() // Most recent first.
    }
}

// MARK: - Challenge Store

/// Represents a pending challenge awaiting verification.
private struct PendingChallenge {
    let id: String
    let nonce: String
    let expiresAt: Date
}

/// Thread-safe in-memory store for pending authentication challenges.
private actor ChallengeStore {
    private var challenges: [String: PendingChallenge] = [:]

    func store(_ challenge: PendingChallenge) {
        // Clean expired challenges opportunistically.
        let now = Date()
        challenges = challenges.filter { $0.value.expiresAt > now }
        challenges[challenge.id] = challenge
    }

    /// Consume a challenge (single-use). Returns `nil` if not found or expired.
    func consume(id: String) -> PendingChallenge? {
        guard let challenge = challenges.removeValue(forKey: id) else {
            return nil
        }
        return challenge
    }
}

// MARK: - Vapor Content Conformance

extension AuthStatusResponse: Content {}
extension KeyRotationResponse: Content {}
extension AuthChallengeResponse: Content {}
extension AuthChallengeVerification: Content {}
extension AuthChallengeResult: Content {}
extension SecurityAuditEntry: Content {}
