import Foundation
import CryptoKit
import ILSShared

/// Actor responsible for generating, storing, and managing API keys for backend authentication.
///
/// Keys are stored at `~/.ils/api_key` with `0o600` permissions. The master key format is
/// `ils_<base64url(32 random bytes)>`. Scoped tokens (read/write/admin) are derived via
/// HMAC-SHA256 from the master key. Key rotation supports a configurable grace period
/// during which the old key remains valid.
actor APIKeyStorageService {
    // MARK: - Constants

    /// Prefix for all generated API keys.
    private static let keyPrefix = "ils_"

    /// Number of random bytes used for key generation.
    private static let keyByteCount = 32

    /// Default grace period for key rotation (5 minutes).
    private static let defaultGracePeriod: TimeInterval = 5 * 60

    /// Directory name for ILS configuration.
    private static let configDirectoryName = ".ils"

    /// Filename for the stored API key.
    private static let keyFileName = "api_key"

    // MARK: - State

    /// The currently active master API key.
    private var masterKey: String?

    /// The previous master key during rotation (still valid until `oldKeyExpiresAt`).
    private var rotatingOldKey: String?

    /// When the old key expires during rotation.
    private var oldKeyExpiresAt: Date?

    // MARK: - Singleton

    static let shared = APIKeyStorageService()

    private init() {}

    // MARK: - Public API

    /// Load or generate the master API key.
    ///
    /// Priority:
    /// 1. `ILS_API_KEY` environment variable (backward compatibility)
    /// 2. Existing key from `~/.ils/api_key`
    /// 3. Newly generated key (written to `~/.ils/api_key`)
    ///
    /// - Returns: The active master API key.
    @discardableResult
    func loadOrGenerateKey() throws -> String {
        // Environment variable takes precedence for backward compatibility.
        if let envKey = ProcessInfo.processInfo.environment["ILS_API_KEY"], !envKey.isEmpty {
            masterKey = envKey
            return envKey
        }

        // Try to read existing key from file.
        let keyFilePath = Self.keyFilePath()
        if FileManager.default.fileExists(atPath: keyFilePath) {
            let storedKey = try String(contentsOfFile: keyFilePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            if !storedKey.isEmpty {
                masterKey = storedKey
                return storedKey
            }
        }

        // Generate and persist a new key.
        let newKey = try generateKey()
        try persistKey(newKey)
        masterKey = newKey
        return newKey
    }

    /// Returns the current master API key, or `nil` if not yet loaded.
    func currentKey() -> String? {
        return masterKey
    }

    /// Returns a masked version of the current key for display (e.g., "ils_...ABCD").
    func maskedKey() -> String? {
        guard let key = masterKey else { return nil }
        return maskKey(key)
    }

    /// Derive scoped tokens from the current master key.
    ///
    /// - Returns: `ScopedTokens` containing read, write, and admin tokens.
    /// - Throws: `APIKeyStorageError.noKeyLoaded` if no master key is available.
    func scopedTokens() throws -> ScopedTokens {
        guard let key = masterKey else {
            throw APIKeyStorageError.noKeyLoaded
        }
        return deriveScopedTokens(from: key)
    }

    /// Rotate the master key, generating a new one and keeping the old key valid
    /// for the specified grace period.
    ///
    /// - Parameter gracePeriodSeconds: How long the old key remains valid (default 300s).
    /// - Returns: A `KeyRotationResponse` with the new key details.
    /// - Throws: `APIKeyStorageError.noKeyLoaded` if no master key exists,
    ///           `APIKeyStorageError.rotationAlreadyInProgress` if a rotation is active.
    func rotateKey(gracePeriodSeconds: Int? = nil) throws -> KeyRotationResponse {
        guard let currentMasterKey = masterKey else {
            throw APIKeyStorageError.noKeyLoaded
        }

        guard rotatingOldKey == nil else {
            throw APIKeyStorageError.rotationAlreadyInProgress
        }

        let gracePeriod = TimeInterval(gracePeriodSeconds ?? Int(Self.defaultGracePeriod))
        let expiresAt = Date(timeIntervalSinceNow: gracePeriod)

        // Preserve old key for grace period.
        rotatingOldKey = currentMasterKey
        oldKeyExpiresAt = expiresAt

        // Generate and persist the new key.
        let newKey = try generateKey()
        try persistKey(newKey)
        masterKey = newKey

        let tokens = deriveScopedTokens(from: newKey)

        return KeyRotationResponse(
            newKey: newKey,
            maskedNewKey: maskKey(newKey),
            oldKeyExpiresAt: expiresAt,
            scopedTokens: tokens
        )
    }

    /// Whether a key rotation grace period is currently active.
    var isRotationInProgress: Bool {
        guard let expiresAt = oldKeyExpiresAt else { return false }
        if Date() >= expiresAt {
            // Grace period has expired; clean up.
            rotatingOldKey = nil
            oldKeyExpiresAt = nil
            return false
        }
        return true
    }

    /// Validate a provided token against the master key, scoped tokens, and (during rotation) the old key.
    ///
    /// - Parameter token: The bearer token to validate.
    /// - Returns: The `AuthorizationLevel` granted, or `nil` if the token is invalid.
    func validateToken(_ token: String) -> AuthorizationLevel? {
        // Check current master key (admin level).
        if let key = masterKey, constantTimeEqual(token, key) {
            return .admin
        }

        // Check scoped tokens derived from the current key.
        if let key = masterKey {
            let scoped = deriveScopedTokens(from: key)
            if constantTimeEqual(token, scoped.adminToken) { return .admin }
            if constantTimeEqual(token, scoped.writeToken) { return .write }
            if constantTimeEqual(token, scoped.readToken) { return .read }
        }

        // During rotation, also accept the old key and its scoped tokens.
        if let oldKey = rotatingOldKey, let expiresAt = oldKeyExpiresAt {
            if Date() < expiresAt {
                if constantTimeEqual(token, oldKey) { return .admin }
                let oldScoped = deriveScopedTokens(from: oldKey)
                if constantTimeEqual(token, oldScoped.adminToken) { return .admin }
                if constantTimeEqual(token, oldScoped.writeToken) { return .write }
                if constantTimeEqual(token, oldScoped.readToken) { return .read }
            } else {
                // Grace period expired; clean up.
                rotatingOldKey = nil
                oldKeyExpiresAt = nil
            }
        }

        return nil
    }

    // MARK: - Key Generation

    /// Generate a cryptographically secure API key with the `ils_` prefix.
    ///
    /// Format: `ils_<base64url(32 random bytes)>`
    private func generateKey() throws -> String {
        var bytes = [UInt8](repeating: 0, count: Self.keyByteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw APIKeyStorageError.randomGenerationFailed
        }

        let base64url = Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return Self.keyPrefix + base64url
    }

    // MARK: - Persistence

    /// Persist the API key to `~/.ils/api_key` with restricted permissions.
    private func persistKey(_ key: String) throws {
        let directoryPath = Self.configDirectoryPath()
        let filePath = Self.keyFilePath()
        let fm = FileManager.default

        // Ensure ~/.ils directory exists.
        if !fm.fileExists(atPath: directoryPath) {
            try fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
            // Set directory permissions to owner-only (0o700).
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryPath)
        }

        // Write the key file.
        guard let data = key.data(using: .utf8) else {
            throw APIKeyStorageError.encodingFailed
        }
        try data.write(to: URL(fileURLWithPath: filePath))

        // Set file permissions to owner read/write only (0o600).
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath)
    }

    // MARK: - Scoped Token Derivation

    /// Derive read, write, and admin scoped tokens from a master key using HMAC-SHA256.
    private func deriveScopedTokens(from key: String) -> ScopedTokens {
        let keyData = Data(key.utf8)
        let symmetricKey = SymmetricKey(data: keyData)

        let readToken = Self.keyPrefix + Self.hmacBase64url(key: symmetricKey, message: "scope:read")
        let writeToken = Self.keyPrefix + Self.hmacBase64url(key: symmetricKey, message: "scope:write")
        let adminToken = Self.keyPrefix + Self.hmacBase64url(key: symmetricKey, message: "scope:admin")

        return ScopedTokens(
            readToken: readToken,
            writeToken: writeToken,
            adminToken: adminToken
        )
    }

    /// Compute HMAC-SHA256 and return the result as a base64url-encoded string (no padding).
    private static func hmacBase64url(key: SymmetricKey, message: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return Data(mac)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Helpers

    /// Return the path to the ILS configuration directory (`~/.ils`).
    private static func configDirectoryPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent(configDirectoryName)
    }

    /// Return the path to the API key file (`~/.ils/api_key`).
    private static func keyFilePath() -> String {
        return (configDirectoryPath() as NSString).appendingPathComponent(keyFileName)
    }

    /// Mask a key for display, showing only the prefix and last 4 characters.
    ///
    /// Example: `ils_abc123xyz` → `ils_...xyz`
    private func maskKey(_ key: String) -> String {
        let prefix = Self.keyPrefix
        guard key.hasPrefix(prefix), key.count > prefix.count + 4 else {
            return String(repeating: "*", count: max(key.count, 4))
        }
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
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

// MARK: - Errors

enum APIKeyStorageError: Error, CustomStringConvertible {
    case randomGenerationFailed
    case encodingFailed
    case noKeyLoaded
    case rotationAlreadyInProgress

    var description: String {
        switch self {
        case .randomGenerationFailed:
            return "Failed to generate cryptographically secure random bytes."
        case .encodingFailed:
            return "Failed to encode API key to UTF-8."
        case .noKeyLoaded:
            return "No API key is loaded. Call loadOrGenerateKey() first."
        case .rotationAlreadyInProgress:
            return "Key rotation is already in progress. Wait for the grace period to expire."
        }
    }
}
