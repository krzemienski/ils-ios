import Foundation

// MARK: - API Key Validation

/// Request payload for validating an Anthropic API key.
public struct ValidateAPIKeyRequest: Codable, Sendable {
    /// The API key to validate (e.g., "sk-ant-...").
    public let apiKey: String

    /// Creates a new API key validation request.
    /// - Parameter apiKey: The API key to validate.
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
}

/// Response from an API key validation attempt.
public struct ValidateAPIKeyResponse: Codable, Sendable {
    /// Whether the provided API key is valid.
    public let isValid: Bool
    /// Masked representation of the key for display (e.g., "sk-ant-...ABCD").
    public let maskedKey: String?
    /// Human-readable message describing the validation result.
    public let message: String?
    /// Error code if validation failed (e.g., "invalid_api_key", "network_error").
    public let errorCode: String?

    /// Creates a new API key validation response.
    /// - Parameters:
    ///   - isValid: Whether the key is valid.
    ///   - maskedKey: Masked key for display purposes.
    ///   - message: Optional descriptive message.
    ///   - errorCode: Optional error code on failure.
    public init(isValid: Bool, maskedKey: String? = nil, message: String? = nil, errorCode: String? = nil) {
        self.isValid = isValid
        self.maskedKey = maskedKey
        self.message = message
        self.errorCode = errorCode
    }
}

// MARK: - Config Export

/// Payload for exporting or importing the full Claude Code configuration,
/// including environment variables (API key) and settings.
public struct ConfigExportPayload: Codable, Sendable {
    /// The Anthropic API key to set in the backend environment.
    /// This is write-only — it is never returned in responses.
    public let apiKey: String?
    /// The Claude model identifier to use by default (e.g., "claude-sonnet-4").
    public let model: String?
    /// Whether to include co-authored-by attribution in commits.
    public let includeCoAuthoredBy: Bool?
    /// Auto-update channel preference ("stable", "beta", etc.).
    public let autoUpdatesChannel: String?
    /// Current API key status for display (read-only, masked).
    public let apiKeyStatus: APIKeyStatus?

    /// Creates a new config export payload.
    /// - Parameters:
    ///   - apiKey: The API key to configure.
    ///   - model: Default model identifier.
    ///   - includeCoAuthoredBy: Whether to include co-author attribution.
    ///   - autoUpdatesChannel: Auto-update channel preference.
    ///   - apiKeyStatus: Current API key status for display.
    public init(
        apiKey: String? = nil,
        model: String? = nil,
        includeCoAuthoredBy: Bool? = nil,
        autoUpdatesChannel: String? = nil,
        apiKeyStatus: APIKeyStatus? = nil
    ) {
        self.apiKey = apiKey
        self.model = model
        self.includeCoAuthoredBy = includeCoAuthoredBy
        self.autoUpdatesChannel = autoUpdatesChannel
        self.apiKeyStatus = apiKeyStatus
    }
}
