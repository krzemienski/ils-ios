import Foundation

// MARK: - Config Profile Requests

/// Request payload for creating a new configuration profile.
public struct CreateConfigProfileRequest: Codable, Sendable {
    /// Human-readable name for the profile (e.g., "Work", "Personal").
    public let name: String
    /// Whether this profile should be the default profile applied to new sessions.
    public let isDefault: Bool?
    /// Claude model to use (e.g., "claude-opus-4", "claude-sonnet-4").
    public let model: String?
    /// Permission configuration for tool execution.
    public let permissions: ProfilePermissions?
    /// Custom system prompt instructions appended to Claude's context.
    public let customInstructions: String?
    /// Names of MCP servers to enable for sessions using this profile.
    public let mcpServerNames: [String]?
    /// File system paths to projects linked to this profile.
    public let linkedProjectPaths: [String]?

    /// Creates a new config profile creation request.
    /// - Parameters:
    ///   - name: Display name. Must not be empty.
    ///   - isDefault: Whether this is the default profile.
    ///   - model: Optional model override.
    ///   - permissions: Optional permission configuration.
    ///   - customInstructions: Optional custom system prompt text.
    ///   - mcpServerNames: Optional list of MCP server names to enable.
    ///   - linkedProjectPaths: Optional list of project paths linked to this profile.
    public init(
        name: String,
        isDefault: Bool? = nil,
        model: String? = nil,
        permissions: ProfilePermissions? = nil,
        customInstructions: String? = nil,
        mcpServerNames: [String]? = nil,
        linkedProjectPaths: [String]? = nil
    ) {
        self.name = name
        self.isDefault = isDefault
        self.model = model
        self.permissions = permissions
        self.customInstructions = customInstructions
        self.mcpServerNames = mcpServerNames
        self.linkedProjectPaths = linkedProjectPaths
    }
}

/// Request payload for updating an existing configuration profile.
///
/// All fields are optional; only non-nil values are applied.
public struct UpdateConfigProfileRequest: Codable, Sendable {
    /// New display name for the profile, or `nil` to leave unchanged.
    public let name: String?
    /// Whether this profile should be the default profile, or `nil` to leave unchanged.
    public let isDefault: Bool?
    /// New Claude model override, or `nil` to leave unchanged.
    public let model: String?
    /// New permission configuration, or `nil` to leave unchanged.
    public let permissions: ProfilePermissions?
    /// New custom system prompt text, or `nil` to leave unchanged.
    public let customInstructions: String?
    /// New list of MCP server names to enable, or `nil` to leave unchanged.
    public let mcpServerNames: [String]?
    /// New list of project paths linked to this profile, or `nil` to leave unchanged.
    public let linkedProjectPaths: [String]?

    /// Creates an update config profile request.
    /// - Parameters:
    ///   - name: New display name for the profile.
    ///   - isDefault: Whether this is the default profile.
    ///   - model: New model override.
    ///   - permissions: New permission configuration.
    ///   - customInstructions: New custom system prompt text.
    ///   - mcpServerNames: New list of MCP server names to enable.
    ///   - linkedProjectPaths: New list of project paths linked to this profile.
    public init(
        name: String? = nil,
        isDefault: Bool? = nil,
        model: String? = nil,
        permissions: ProfilePermissions? = nil,
        customInstructions: String? = nil,
        mcpServerNames: [String]? = nil,
        linkedProjectPaths: [String]? = nil
    ) {
        self.name = name
        self.isDefault = isDefault
        self.model = model
        self.permissions = permissions
        self.customInstructions = customInstructions
        self.mcpServerNames = mcpServerNames
        self.linkedProjectPaths = linkedProjectPaths
    }
}

// MARK: - Config Profile Responses

/// Response containing a list of configuration profiles and the active profile ID.
public struct ConfigProfileListResponse: Codable, Sendable {
    /// All available configuration profiles.
    public let profiles: [ConfigProfile]
    /// ID of the currently active profile, or `nil` if no profile is active.
    public let activeProfileId: UUID?

    /// Creates a config profile list response.
    /// - Parameters:
    ///   - profiles: All available configuration profiles.
    ///   - activeProfileId: ID of the currently active profile.
    public init(profiles: [ConfigProfile], activeProfileId: UUID? = nil) {
        self.profiles = profiles
        self.activeProfileId = activeProfileId
    }
}
