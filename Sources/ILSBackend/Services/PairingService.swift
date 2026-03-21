import Foundation
import ILSShared

/// Actor managing in-memory QR pairing tokens.
///
/// Tokens are valid for 5 minutes and encode the backend connection URL,
/// API key, and backend version so an iOS device can pair in a single scan.
actor PairingService {
    // MARK: - Constants

    private let tokenTTL: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - State

    private struct StoredToken {
        let payload: QRPairingPayload
        let expiresAt: Date
    }

    private var tokens: [UUID: StoredToken] = [:]

    // MARK: - Singleton

    static let shared = PairingService()

    private init() {}

    // MARK: - Public API

    /// Generate a new QR pairing token and return the response payload.
    ///
    /// The `qrData` field in the response is the JSON-encoded `QRPairingPayload`
    /// string ready to be encoded into a QR image. Includes scoped read/write tokens
    /// from `APIKeyStorageService` when available, allowing paired devices to use
    /// least-privilege authentication.
    func generateToken() async throws -> QRPairingTokenResponse {
        // Evict expired tokens before generating a new one.
        evictExpiredTokens()

        let tokenUUID = UUID()
        let expiresAt = Date(timeIntervalSinceNow: tokenTTL)

        // Fetch scoped tokens from APIKeyStorageService if available.
        let scopedTokens = try? await APIKeyStorageService.shared.scopedTokens()

        let payload = QRPairingPayload(
            url: backendURL(),
            apiKey: apiKey(),
            backendVersion: backendVersion(),
            expiresAt: expiresAt,
            tunnelURL: nil,
            readToken: scopedTokens?.readToken,
            writeToken: scopedTokens?.writeToken
        )

        // Encode the payload to JSON — this becomes the QR code data.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(payload)
        guard let qrData = String(data: payloadData, encoding: .utf8) else {
            throw PairingError.encodingFailed
        }

        tokens[tokenUUID] = StoredToken(payload: payload, expiresAt: expiresAt)

        return QRPairingTokenResponse(
            token: tokenUUID.uuidString,
            expiresAt: expiresAt,
            qrData: qrData
        )
    }

    /// Validate a token UUID string and return the associated payload if still valid.
    ///
    /// Returns `nil` if the token does not exist or has expired.
    func validateToken(_ uuidString: String) -> QRPairingPayload? {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        guard let stored = tokens[uuid] else { return nil }
        guard stored.expiresAt > Date() else {
            tokens.removeValue(forKey: uuid)
            return nil
        }
        return stored.payload
    }

    /// Explicitly invalidate a token, e.g. after successful pairing.
    func invalidateToken(_ uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return }
        tokens.removeValue(forKey: uuid)
    }

    // MARK: - Private Helpers

    /// Remove all tokens whose expiry has passed.
    private func evictExpiredTokens() {
        let now = Date()
        tokens = tokens.filter { $0.value.expiresAt > now }
    }

    /// Resolve the backend base URL from the environment or fall back to localhost.
    private func backendURL() -> String {
        if let url = ProcessInfo.processInfo.environment["ILS_BASE_URL"], !url.isEmpty {
            return url
        }
        return "http://localhost:9999"
    }

    /// Resolve the API key from the environment or return an empty string.
    private func apiKey() -> String {
        ProcessInfo.processInfo.environment["ILS_API_KEY"] ?? ""
    }

    /// Return the current backend version from the bundle, or a default.
    private func backendVersion() -> String {
        // Bundle version is not available in a command-line tool; use a hardcoded default.
        ProcessInfo.processInfo.environment["ILS_BACKEND_VERSION"] ?? "1.0.0"
    }
}

// MARK: - Errors

enum PairingError: Error {
    case encodingFailed
}
