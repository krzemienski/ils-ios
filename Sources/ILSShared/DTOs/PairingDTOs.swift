import Foundation

// MARK: - QR Pairing Payload

/// Data encoded in the QR code for pairing an iOS device with the backend.
public struct QRPairingPayload: Codable, Sendable {
    /// The backend URL (e.g. http://192.168.1.10:9999).
    public let url: String
    /// The API key for authenticating with the backend.
    public let apiKey: String
    /// The backend version string.
    public let backendVersion: String
    /// When this pairing payload expires (ISO 8601).
    public let expiresAt: Date
    /// Optional tunnel URL if a tunnel is active.
    public let tunnelURL: String?
    /// Optional scoped read-only token (derived from master key via HMAC-SHA256).
    public let readToken: String?
    /// Optional scoped read-write token (derived from master key via HMAC-SHA256).
    public let writeToken: String?

    public init(
        url: String,
        apiKey: String,
        backendVersion: String,
        expiresAt: Date,
        tunnelURL: String? = nil,
        readToken: String? = nil,
        writeToken: String? = nil
    ) {
        self.url = url
        self.apiKey = apiKey
        self.backendVersion = backendVersion
        self.expiresAt = expiresAt
        self.tunnelURL = tunnelURL
        self.readToken = readToken
        self.writeToken = writeToken
    }
}

// MARK: - QR Pairing Token Response

/// Response from the backend when requesting a QR pairing token.
public struct QRPairingTokenResponse: Codable, Sendable {
    /// The one-time pairing token.
    public let token: String
    /// When the token expires (ISO 8601).
    public let expiresAt: Date
    /// Base64-encoded QR code data (JSON-encoded QRPairingPayload).
    public let qrData: String

    public init(token: String, expiresAt: Date, qrData: String) {
        self.token = token
        self.expiresAt = expiresAt
        self.qrData = qrData
    }
}
