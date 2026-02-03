import Foundation
import Vapor
import ILSShared
import Yams

/// Cache entry with timestamp for TTL-based invalidation
private struct CacheEntry<T> {
    let value: T
    let timestamp: Date

    func isValid(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) < ttl
    }
}

/// Actor for thread-safe cache management
private actor SkillsCache {
    private var skillsCache: CacheEntry<[Skill]>?

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

    func invalidateSkills() {
        skillsCache = nil
    }
}

/// Shared cache instance
private let sharedCache = SkillsCache()

/// Service for skills management operations
struct SkillsService {
    private let fileManager = FileManager.default

    /// Cache TTL in seconds (configurable)
    var cacheTTL: TimeInterval = 30

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude directory path
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// Skills directory path
    var skillsDirectory: String {
        "\(claudeDirectory)/skills"
    }

    // MARK: - Skills

    /// List all skills from the skills directory (with caching)
    func listSkills(bypassCache: Bool = false) async throws -> [Skill] {
        // Check cache first unless bypassed
        if !bypassCache, let cached = await sharedCache.getCachedSkills(ttl: cacheTTL) {
            return cached
        }

        let skills = try scanSkills()

        // Update cache
        await sharedCache.setCachedSkills(skills)

        return skills
    }

    /// Scan all skills from the skills directory (no caching)
    func scanSkills() throws -> [Skill] {
        var skills: [Skill] = []

        guard fileManager.fileExists(atPath: skillsDirectory) else {
            return skills
        }

        // Recursively scan for all .md files in the skills directory
        skills = try scanSkillsRecursively(at: skillsDirectory, basePath: skillsDirectory)

        return skills
    }

    /// Recursively scan directory for skill .md files
    private func scanSkillsRecursively(at path: String, basePath: String) throws -> [Skill] {
        var skills: [Skill] = []

        let contents = try fileManager.contentsOfDirectory(atPath: path)

        for item in contents {
            let itemPath = "\(path)/\(item)"
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Check for SKILL.md in this directory (traditional format)
                    let skillMdPath = "\(itemPath)/SKILL.md"
                    if fileManager.fileExists(atPath: skillMdPath) {
                        if let skill = try? parseSkillFile(at: skillMdPath, name: item) {
                            skills.append(skill)
                        }
                    }

                    // Recursively scan subdirectory for more skills
                    let subSkills = try scanSkillsRecursively(at: itemPath, basePath: basePath)
                    skills.append(contentsOf: subSkills)
                } else if item.hasSuffix(".md") && item != "SKILL.md" {
                    // Parse standalone .md files as skills
                    let skillName = String(item.dropLast(3)) // Remove .md extension
                    if let skill = try? parseSkillFile(at: itemPath, name: skillName) {
                        skills.append(skill)
                    }
                }
            }
        }

        return skills
    }

    /// Invalidate skills cache (call after modifications)
    func invalidateSkillsCache() async {
        await sharedCache.invalidateSkills()
    }

    /// Parse a SKILL.md file or standalone .md skill file
    private func parseSkillFile(at path: String, name: String) throws -> Skill {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var description: String?
        var version: String?
        var tags: [String] = []
        var parsedName = name

        // Parse YAML frontmatter if present
        if content.hasPrefix("---") {
            let parts = content.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count >= 2 {
                let yamlContent = String(parts[1])
                if let yaml = try? Yams.load(yaml: yamlContent) as? [String: Any] {
                    description = yaml["description"] as? String
                    version = yaml["version"] as? String

                    // Parse tags - can be array or comma-separated string
                    if let tagArray = yaml["tags"] as? [String] {
                        tags = tagArray
                    } else if let tagString = yaml["tags"] as? String {
                        tags = tagString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }

                    // Use name from frontmatter if available
                    if let frontmatterName = yaml["name"] as? String {
                        parsedName = frontmatterName
                    }
                }
            }
        }

        // Determine the skill path (directory for SKILL.md, file path for standalone)
        let skillPath: String
        if path.hasSuffix("/SKILL.md") {
            skillPath = path.replacingOccurrences(of: "/SKILL.md", with: "")
        } else {
            skillPath = path
        }

        return Skill(
            name: parsedName,
            description: description,
            version: version,
            tags: tags,
            isActive: true,
            path: skillPath,
            source: .local,
            content: content
        )
    }

    /// Get a specific skill by name
    func getSkill(name: String) throws -> Skill? {
        // Try directory-based skill first (name/SKILL.md)
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        if fileManager.fileExists(atPath: skillMdPath) {
            return try parseSkillFile(at: skillMdPath, name: name)
        }

        // Try standalone .md file (name.md)
        let standalonePath = "\(skillsDirectory)/\(name).md"
        if fileManager.fileExists(atPath: standalonePath) {
            return try parseSkillFile(at: standalonePath, name: name)
        }

        // Search recursively for the skill by name
        let allSkills = try scanSkills()
        return allSkills.first { $0.name == name }
    }

    /// Create a new skill
    func createSkill(name: String, content: String) throws -> Skill {
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        // Create directory
        try fileManager.createDirectory(atPath: skillPath, withIntermediateDirectories: true)

        // Write SKILL.md
        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Update a skill's content
    func updateSkill(name: String, content: String) throws -> Skill {
        let skillMdPath = "\(skillsDirectory)/\(name)/SKILL.md"

        guard fileManager.fileExists(atPath: skillMdPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Delete a skill
    func deleteSkill(name: String) throws {
        let skillPath = "\(skillsDirectory)/\(name)"

        guard fileManager.fileExists(atPath: skillPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try fileManager.removeItem(atPath: skillPath)
    }
}
