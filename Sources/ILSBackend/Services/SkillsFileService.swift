import Foundation
import Vapor
import ILSShared
import Yams

/// Service for skills file system operations in `~/.claude/skills`.
///
/// Supports both directory-based skills (skill-name/SKILL.md) and standalone markdown files (skill-name.md).
/// Parses YAML frontmatter for metadata (description, version, tags).
struct SkillsFileService {
    private let fileManager = FileManager.default

    /// Cache TTL in seconds (default: 30s)
    var cacheTTL: TimeInterval = 30

    /// Home directory path
    var homeDirectory: String {
        fileManager.homeDirectoryForCurrentUser.path
    }

    /// Claude configuration directory path (`~/.claude`)
    var claudeDirectory: String {
        "\(homeDirectory)/.claude"
    }

    /// Skills directory path (`~/.claude/skills`)
    var skillsDirectory: String {
        "\(claudeDirectory)/skills"
    }

    // MARK: - Skills

    /// List all skills from the skills directory with caching.
    /// - Parameter bypassCache: If true, forces fresh scan from disk
    /// - Returns: Array of Skill objects
    func listSkills(bypassCache: Bool = false) async throws -> [Skill] {
        // Check cache first unless bypassed
        if !bypassCache, let cached = await FileSystemCache.shared.getCachedSkills(ttl: cacheTTL) {
            return cached
        }

        let skills = try scanSkills()

        // Update cache
        await FileSystemCache.shared.setCachedSkills(skills)

        return skills
    }

    /// Scan all skills from disk without using cache.
    /// - Returns: Array of Skill objects
    func scanSkills() throws -> [Skill] {
        var skills: [Skill] = []

        guard fileManager.fileExists(atPath: skillsDirectory) else {
            return skills
        }

        // Recursively scan for all .md files in the skills directory
        skills = try scanSkillsRecursively(at: skillsDirectory, basePath: skillsDirectory)

        return skills
    }

    /// Recursively scan directory for skill .md files (both SKILL.md in dirs and standalone .md files).
    /// - Parameters:
    ///   - path: Current directory path to scan
    ///   - basePath: Original base path (skills directory)
    /// - Returns: Array of Skill objects
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

    /// Invalidate skills cache, forcing next read to scan from disk.
    func invalidateSkillsCache() async {
        await FileSystemCache.shared.invalidateSkills()
    }

    /// Parse a SKILL.md file or standalone .md skill file with YAML frontmatter.
    /// - Parameters:
    ///   - path: File path to parse
    ///   - name: Skill name (from directory or filename)
    /// - Returns: Skill object
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

    /// Get a specific skill by name (searches directory-based and standalone formats).
    /// - Parameter name: Skill name
    /// - Returns: Skill if found, nil otherwise
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

    /// Create a new skill (directory-based format with SKILL.md).
    /// - Parameters:
    ///   - name: Skill name (becomes directory name)
    ///   - content: Markdown content with optional YAML frontmatter
    /// - Returns: Created Skill object
    func createSkill(name: String, content: String) throws -> Skill {
        let skillPath = "\(skillsDirectory)/\(name)"
        let skillMdPath = "\(skillPath)/SKILL.md"

        // Create directory
        try fileManager.createDirectory(atPath: skillPath, withIntermediateDirectories: true)

        // Write SKILL.md
        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Update an existing skill's content.
    /// - Parameters:
    ///   - name: Skill name
    ///   - content: New markdown content
    /// - Returns: Updated Skill object
    func updateSkill(name: String, content: String) throws -> Skill {
        let skillMdPath = "\(skillsDirectory)/\(name)/SKILL.md"

        guard fileManager.fileExists(atPath: skillMdPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try content.write(toFile: skillMdPath, atomically: true, encoding: .utf8)

        return try parseSkillFile(at: skillMdPath, name: name)
    }

    /// Delete a skill (removes entire directory).
    /// - Parameter name: Skill name to delete
    func deleteSkill(name: String) throws {
        let skillPath = "\(skillsDirectory)/\(name)"

        guard fileManager.fileExists(atPath: skillPath) else {
            throw Abort(.notFound, reason: "Skill not found")
        }

        try fileManager.removeItem(atPath: skillPath)
    }
}
