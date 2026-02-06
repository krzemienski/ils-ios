import Foundation
import Vapor
import ILSShared

/// Cache entry with timestamp for TTL-based invalidation
struct CacheEntry<T> {
    let value: T
    let timestamp: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

/// Actor for thread-safe cache management
actor FileSystemCache {
    static let shared = FileSystemCache()

    private var skillsCache: CacheEntry<[Skill]>?
    private var mcpServersCache: CacheEntry<[MCPServer]>?

    /// Default TTL: 30 seconds
    private let defaultTTL: TimeInterval = 30

    func getCachedSkills(ttl: TimeInterval? = nil) -> [Skill]? {
        guard let cache = skillsCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedSkills(_ skills: [Skill]) {
        skillsCache = CacheEntry(value: skills, timestamp: Date())
    }

    func getCachedMCPServers(ttl: TimeInterval? = nil) -> [MCPServer]? {
        guard let cache = mcpServersCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedMCPServers(_ servers: [MCPServer]) {
        mcpServersCache = CacheEntry(value: servers, timestamp: Date())
    }

    func invalidateAll() {
        skillsCache = nil
        mcpServersCache = nil
    }

    func invalidateSkills() {
        skillsCache = nil
    }

    func invalidateMCPServers() {
        mcpServersCache = nil
    }
}

/// Facade service that delegates file system operations to specialized domain services.
///
/// This service maintains backward compatibility while internally routing operations to focused sub-services:
/// - `skills`: Skill file scanning and management
/// - `mcp`: MCP server configuration
/// - `config`: Claude settings
/// - `sessions`: External session scanning and transcript reading
struct FileSystemService {
    /// Service for skills directory operations
    let skills: SkillsFileService
    /// Service for MCP configuration operations
    let mcp: MCPFileService
    /// Service for Claude configuration operations
    let config: ConfigFileService
    /// Service for session scanning and transcript reading
    let sessions: SessionFileService

    init() {
        self.skills = SkillsFileService()
        self.mcp = MCPFileService()
        self.config = ConfigFileService()
        self.sessions = SessionFileService()
    }

    // MARK: - Type Aliases (exposed for backward compatibility)

    typealias SessionsIndex = SessionFileService.SessionsIndex
    typealias SessionEntry = SessionFileService.SessionEntry

    // MARK: - Path Properties (exposed for backward compatibility)

    /// User's home directory path (e.g., `/Users/username`)
    var homeDirectory: String {
        config.homeDirectory
    }

    /// Claude configuration directory path (`~/.claude`)
    var claudeDirectory: String {
        config.claudeDirectory
    }

    /// Skills directory path (`~/.claude/skills`)
    var skillsDirectory: String {
        skills.skillsDirectory
    }

    /// User settings file path (`~/.claude/settings.json`)
    var userSettingsPath: String {
        config.userSettingsPath
    }

    /// Legacy Claude.json file path (`~/.claude.json`)
    var userClaudeJsonPath: String {
        mcp.userClaudeJsonPath
    }

    /// MCP configuration file path (`~/.mcp.json`)
    var userMCPConfigPath: String {
        mcp.userMCPConfigPath
    }

    /// Claude projects directory path (`~/.claude/projects`)
    var claudeProjectsPath: String {
        sessions.claudeProjectsPath
    }

    // MARK: - Skills (delegate to SkillsFileService)

    /// List all skills from `~/.claude/skills`, with optional caching.
    /// - Parameter bypassCache: If true, forces a fresh scan from disk
    /// - Returns: Array of Skill objects
    func listSkills(bypassCache: Bool = false) async throws -> [Skill] {
        try await skills.listSkills(bypassCache: bypassCache)
    }

    /// Scan all skills from disk without using cache.
    /// - Returns: Array of Skill objects
    func scanSkills() throws -> [Skill] {
        try skills.scanSkills()
    }

    /// Invalidate the skills cache, forcing next read to scan from disk.
    func invalidateSkillsCache() async {
        await skills.invalidateSkillsCache()
    }

    /// Get a specific skill by name.
    /// - Parameter name: The skill name (directory name or file name without .md)
    /// - Returns: Skill if found, nil otherwise
    func getSkill(name: String) throws -> Skill? {
        try skills.getSkill(name: name)
    }

    /// Create a new skill with the given name and content.
    /// - Parameters:
    ///   - name: Skill name (becomes directory name)
    ///   - content: Markdown content with optional YAML frontmatter
    /// - Returns: Created Skill object
    func createSkill(name: String, content: String) throws -> Skill {
        try skills.createSkill(name: name, content: content)
    }

    /// Update an existing skill's content.
    /// - Parameters:
    ///   - name: Skill name
    ///   - content: New markdown content
    /// - Returns: Updated Skill object
    func updateSkill(name: String, content: String) throws -> Skill {
        try skills.updateSkill(name: name, content: content)
    }

    /// Delete a skill by name.
    /// - Parameter name: Skill name to delete
    func deleteSkill(name: String) throws {
        try skills.deleteSkill(name: name)
    }

    // MARK: - MCP Servers (delegate to MCPFileService)

    /// Read MCP servers from configuration files, with optional caching.
    /// - Parameters:
    ///   - scope: Optional scope filter (user or project)
    ///   - bypassCache: If true, forces fresh scan from disk
    /// - Returns: Array of MCPServer objects
    func readMCPServers(scope: MCPScope? = nil, bypassCache: Bool = false) async throws -> [MCPServer] {
        try await mcp.readMCPServers(scope: scope, bypassCache: bypassCache)
    }

    /// Scan MCP servers from disk without using cache.
    /// - Parameter scope: Optional scope filter
    /// - Returns: Array of MCPServer objects
    func scanMCPServers(scope: MCPScope? = nil) throws -> [MCPServer] {
        try mcp.scanMCPServers(scope: scope)
    }

    /// Invalidate the MCP servers cache.
    func invalidateMCPServersCache() async {
        await mcp.invalidateMCPServersCache()
    }

    /// Add a new MCP server to `~/.mcp.json`.
    /// - Parameter server: MCPServer object to add
    func addMCPServer(_ server: MCPServer) throws {
        try mcp.addMCPServer(server)
    }

    /// Remove an MCP server from configuration.
    /// - Parameters:
    ///   - name: Server name
    ///   - scope: Configuration scope (user or project)
    func removeMCPServer(name: String, scope: MCPScope) throws {
        try mcp.removeMCPServer(name: name, scope: scope)
    }

    // MARK: - Config (delegate to ConfigFileService)

    /// Read Claude configuration for a given scope.
    /// - Parameter scope: Configuration scope ("user", "project", or "local")
    /// - Returns: ConfigInfo with content and metadata
    func readConfig(scope: String) throws -> ConfigInfo {
        try config.readConfig(scope: scope)
    }

    /// Write Claude configuration to a given scope.
    /// - Parameters:
    ///   - scope: Configuration scope ("user" only currently supported for writes)
    ///   - content: ClaudeConfig object to write
    /// - Returns: ConfigInfo with updated content
    func writeConfig(scope: String, content: ClaudeConfig) throws -> ConfigInfo {
        try config.writeConfig(scope: scope, content: content)
    }

    // MARK: - Sessions (delegate to SessionFileService)

    /// Scan for external Claude Code sessions from `~/.claude/projects/`.
    /// - Returns: Array of ExternalSession objects
    func scanExternalSessions() throws -> [ExternalSession] {
        try sessions.scanExternalSessions()
    }

    /// Read messages from a session's JSONL transcript file.
    /// - Parameters:
    ///   - encodedProjectPath: URL-encoded project directory name
    ///   - sessionId: Session UUID
    ///   - limit: Maximum number of messages to return
    ///   - offset: Number of messages to skip
    /// - Returns: Array of Message objects
    func readTranscriptMessages(encodedProjectPath: String, sessionId: String, limit: Int = 100, offset: Int = 0) throws -> [Message] {
        try sessions.readTranscriptMessages(encodedProjectPath: encodedProjectPath, sessionId: sessionId, limit: limit, offset: offset)
    }
}
