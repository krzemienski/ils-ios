import Foundation

/// A named configuration profile for Claude Code settings.
/// Profiles allow users to switch between different Claude Code configurations
/// (e.g., "Work", "Personal", "Restricted") without manually editing settings.
public struct ConfigProfile: Codable, Identifiable, Hashable, Sendable {
    /// Unique identifier for this profile.
    public let id: UUID
    /// Human-readable name for the profile (e.g., "Work", "Personal").
    public var name: String
    /// Whether this profile is the default profile applied to new sessions.
    public var isDefault: Bool
    /// Whether this profile is currently active.
    public var isActive: Bool
    /// Claude model to use (e.g., "claude-opus-4", "claude-sonnet-4").
    public var model: String?
    /// Permission configuration for tool execution.
    public var permissions: ProfilePermissions?
    /// Custom system prompt instructions appended to Claude's context.
    public var customInstructions: String?
    /// Names of MCP servers to enable for sessions using this profile.
    public var mcpServerNames: [String]?
    /// File system paths to projects linked to this profile.
    public var linkedProjectPaths: [String]?
    /// Timestamp when this profile was created.
    public let createdAt: Date
    /// Timestamp when this profile was last updated.
    public var updatedAt: Date

    /// Creates a new configuration profile.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name. Must not be empty.
    ///   - isDefault: Whether this is the default profile.
    ///   - isActive: Whether this profile is currently active.
    ///   - model: Optional model override.
    ///   - permissions: Optional permission configuration.
    ///   - customInstructions: Optional custom system prompt text.
    ///   - mcpServerNames: Optional list of MCP server names to enable.
    ///   - linkedProjectPaths: Optional list of project paths linked to this profile.
    ///   - createdAt: Creation timestamp (defaults to now).
    ///   - updatedAt: Last update timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        isActive: Bool = false,
        model: String? = nil,
        permissions: ProfilePermissions? = nil,
        customInstructions: String? = nil,
        mcpServerNames: [String]? = nil,
        linkedProjectPaths: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isActive = isActive
        self.model = model
        self.permissions = permissions
        self.customInstructions = customInstructions
        self.mcpServerNames = mcpServerNames
        self.linkedProjectPaths = linkedProjectPaths
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Permission configuration specific to a configuration profile.
public struct ProfilePermissions: Codable, Hashable, Sendable {
    /// Tools or patterns explicitly allowed.
    public var allow: [String]?
    /// Tools or patterns explicitly denied.
    public var deny: [String]?
    /// Default permission mode: "ask", "allow", or "deny".
    public var defaultMode: String?

    public init(
        allow: [String]? = nil,
        deny: [String]? = nil,
        defaultMode: String? = nil
    ) {
        self.allow = allow
        self.deny = deny
        self.defaultMode = defaultMode
    }
}
