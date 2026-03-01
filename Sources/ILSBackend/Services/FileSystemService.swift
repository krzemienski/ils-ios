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
    private var externalSessionsCache: CacheEntry<[ChatSession]>?
    private var pluginsCache: CacheEntry<[Plugin]>?

    /// Default TTL: 30 seconds
    private let defaultTTL: TimeInterval = 30

    /// Extended TTL for expensive operations: 60 seconds
    private let extendedTTL: TimeInterval = 60

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

    func getCachedExternalSessions() -> [ChatSession]? {
        guard let cache = externalSessionsCache, cache.isValid(ttl: extendedTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedExternalSessions(_ sessions: [ChatSession]) {
        externalSessionsCache = CacheEntry(value: sessions, timestamp: Date())
    }

    func invalidateExternalSessions() {
        externalSessionsCache = nil
    }

    func getCachedPlugins(ttl: TimeInterval? = nil) -> [Plugin]? {
        guard let cache = pluginsCache, cache.isValid(ttl: ttl ?? defaultTTL) else {
            return nil
        }
        return cache.value
    }

    func setCachedPlugins(_ plugins: [Plugin]) {
        pluginsCache = CacheEntry(value: plugins, timestamp: Date())
    }

    func invalidatePlugins() {
        pluginsCache = nil
    }

    func invalidateAll() {
        skillsCache = nil
        mcpServersCache = nil
        externalSessionsCache = nil
        pluginsCache = nil
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

    /// User's home directory path (resolves `~` to absolute path)
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

    // MARK: - Skills Management

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

    // MARK: - MCP Server Configuration

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

    // MARK: - Claude Config Settings

    /// Read Claude configuration for a given scope.
    /// - Parameter scope: Configuration scope (user, project, or local)
    /// - Returns: ConfigInfo with content and metadata
    func readConfig(scope: ConfigScope) throws -> ConfigInfo {
        try config.readConfig(scope: scope)
    }

    /// Write Claude configuration to a given scope.
    /// - Parameters:
    ///   - scope: Configuration scope (currently only .user is supported for writes)
    ///   - content: ClaudeConfig object to write
    /// - Returns: ConfigInfo with updated content
    func writeConfig(scope: ConfigScope, content: ClaudeConfig) throws -> ConfigInfo {
        try config.writeConfig(scope: scope, content: content)
    }

    /// Read effective (merged) configuration across all scopes.
    /// - Returns: EffectiveConfig with merged values and per-key scope annotations
    func readEffectiveConfig() -> EffectiveConfig {
        config.readEffectiveConfig()
    }

    // MARK: - Session Scanning

    /// Scan for external Claude Code sessions from `~/.claude/projects/`.
    /// - Returns: Array of ExternalSession objects
    func scanExternalSessions() throws -> [ExternalSession] {
        try sessions.scanExternalSessions()
    }

    /// List external sessions as ChatSession objects with caching.
    /// - Parameter bypassCache: If true, forces a fresh scan from disk
    /// - Returns: Array of ChatSession objects with deterministic IDs
    func listExternalSessionsAsChatSessions(bypassCache: Bool = false) async throws -> [ChatSession] {
        if !bypassCache, let cached = await FileSystemCache.shared.getCachedExternalSessions() {
            return cached
        }
        let converted = try sessions.scanExternalSessionsAsChatSessions()
        // Pre-sort at cache time (once) so callers can merge without re-sorting 22K+ items per request
        let sorted = converted.sorted { $0.lastActiveAt > $1.lastActiveAt }
        await FileSystemCache.shared.setCachedExternalSessions(sorted)
        return sorted
    }

    /// Invalidate the external sessions cache.
    func invalidateExternalSessionsCache() async {
        await FileSystemCache.shared.invalidateExternalSessions()
    }

    // MARK: - Plugins Management

    /// List all installed plugins from `~/.claude/plugins/installed_plugins.json`, with optional caching.
    ///
    /// Reads installed plugin entries and augments each with enabled status from
    /// `~/.claude/settings.json`, manifest description, and discovered commands/agents.
    ///
    /// - Parameter bypassCache: If true, forces a fresh scan from disk
    /// - Returns: Array of Plugin objects sorted by name
    func listPlugins(bypassCache: Bool = false) async throws -> [Plugin] {
        if !bypassCache, let cached = await FileSystemCache.shared.getCachedPlugins() {
            return cached
        }

        let plugins = try scanPlugins()
        await FileSystemCache.shared.setCachedPlugins(plugins)
        return plugins
    }

    /// Scan all installed plugins from disk without using cache.
    /// - Returns: Array of Plugin objects sorted by name
    func scanPlugins() throws -> [Plugin] {
        let fm = FileManager.default
        let installedPluginsPath = "\(claudeDirectory)/plugins/installed_plugins.json"
        let settingsPath = userSettingsPath

        var plugins: [Plugin] = []

        // Read enabled status from settings.json
        var enabledPlugins: [String: Bool] = [:]
        if fm.fileExists(atPath: settingsPath),
           let settingsData = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let settingsJson = try? JSONSerialization.jsonObject(with: settingsData) as? [String: Any],
           let enabled = settingsJson["enabledPlugins"] as? [String: Bool] {
            enabledPlugins = enabled
        }

        // Read installed plugins from installed_plugins.json
        guard fm.fileExists(atPath: installedPluginsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: installedPluginsPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pluginsDict = json["plugins"] as? [String: Any] else {
            return plugins
        }

        // Parse each plugin entry
        for (pluginKey, value) in pluginsDict {
            // pluginKey format: "plugin-name@marketplace"
            guard let installsArray = value as? [[String: Any]],
                  let latestInstall = installsArray.first else {
                continue
            }

            // Parse plugin key to get name and marketplace
            let parts = pluginKey.split(separator: "@", maxSplits: 1)
            let pluginName = String(parts.first ?? Substring(pluginKey))
            let marketplace = parts.count > 1 ? String(parts[1]) : nil

            // Extract install info
            let installPath = latestInstall["installPath"] as? String
            var version = latestInstall["version"] as? String

            // Check enabled status (default to true if not specified)
            let isEnabled = enabledPlugins[pluginKey] ?? true

            // Try to read plugin manifest for description, commands, agents, dependencies
            var description: String?
            var commands: [String] = []
            var agents: [String] = []
            var dependencies: [String] = []

            if let path = installPath {
                // Try to read plugin.json or manifest
                let manifestPath = "\(path)/.claude-plugin/plugin.json"
                let altManifestPath = "\(path)/plugin.json"

                if let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
                   let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] {
                    description = manifest["description"] as? String
                    // Extract version from manifest (more accurate than installed_plugins.json)
                    if let manifestVersion = manifest["version"] as? String {
                        version = manifestVersion
                    }
                    // Extract dependencies -- support both [String] and [{"name": String}] formats
                    if let depsArray = manifest["dependencies"] as? [String] {
                        dependencies = depsArray
                    } else if let depsObjects = manifest["dependencies"] as? [[String: Any]] {
                        dependencies = depsObjects.compactMap { $0["name"] as? String }
                    }
                } else if let manifestData = try? Data(contentsOf: URL(fileURLWithPath: altManifestPath)),
                          let manifest = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any] {
                    description = manifest["description"] as? String
                    if let manifestVersion = manifest["version"] as? String {
                        version = manifestVersion
                    }
                    if let depsArray = manifest["dependencies"] as? [String] {
                        dependencies = depsArray
                    } else if let depsObjects = manifest["dependencies"] as? [[String: Any]] {
                        dependencies = depsObjects.compactMap { $0["name"] as? String }
                    }
                }

                // Check for commands directory
                let commandsPath = "\(path)/commands"
                if let cmdContents = try? fm.contentsOfDirectory(atPath: commandsPath) {
                    commands = cmdContents.filter { $0.hasSuffix(".md") }
                        .map { "/\(pluginName):\($0.replacingOccurrences(of: ".md", with: ""))" }
                }

                // Check for agents directory
                let agentsPath = "\(path)/agents"
                if let agentContents = try? fm.contentsOfDirectory(atPath: agentsPath) {
                    agents = agentContents.filter { $0.hasSuffix(".md") }
                        .map { $0.replacingOccurrences(of: ".md", with: "") }
                }
            }

            plugins.append(Plugin(
                name: pluginName,
                description: description,
                marketplace: marketplace,
                isInstalled: true,
                isEnabled: isEnabled,
                version: version,
                commands: commands.isEmpty ? nil : commands,
                agents: agents.isEmpty ? nil : agents,
                path: installPath,
                dependencies: dependencies.isEmpty ? nil : dependencies
            ))
        }

        // Sort by name for consistent ordering
        plugins.sort { $0.name.lowercased() < $1.name.lowercased() }

        return plugins
    }

    /// Invalidate the plugins cache, forcing next read to scan from disk.
    func invalidatePluginsCache() async {
        await FileSystemCache.shared.invalidatePlugins()
    }

    /// Read messages from a session's JSONL transcript file.
    /// - Parameters:
    ///   - encodedProjectPath: URL-encoded project directory name
    ///   - sessionId: Session UUID
    ///   - limit: Maximum number of messages to return
    ///   - offset: Number of messages to skip
    /// - Returns: TranscriptResult containing paginated messages and total count
    func readTranscriptMessages(encodedProjectPath: String, sessionId: String, limit: Int = 100, offset: Int = 0) throws -> SessionFileService.TranscriptResult {
        try sessions.readTranscriptMessages(encodedProjectPath: encodedProjectPath, sessionId: sessionId, limit: limit, offset: offset)
    }
}
