import Foundation
import Vapor
import ILSShared

/// Service for installing skills from GitHub repositories
struct SkillInstallationService {
    private let fileManager = FileManager.default
    private let fileSystemService: FileSystemService

    init(fileSystemService: FileSystemService = FileSystemService()) {
        self.fileSystemService = fileSystemService
    }

    /// Install a skill from a GitHub repository
    /// - Parameters:
    ///   - owner: GitHub repository owner
    ///   - repo: GitHub repository name
    /// - Returns: The installed Skill object
    /// - Throws: Vapor.Abort on installation errors
    func installFromGitHub(owner: String, repo: String) async throws -> Skill {
        // Validate input
        guard !owner.isEmpty, !repo.isEmpty else {
            throw Abort(.badRequest, reason: "Owner and repository name are required")
        }

        // Construct GitHub URL
        let githubUrl = "https://github.com/\(owner)/\(repo).git"

        // Determine installation directory
        let skillsDirectory = fileSystemService.skillsDirectory
        let installPath = "\(skillsDirectory)/\(repo)"

        // Check if skill already exists
        if fileManager.fileExists(atPath: installPath) {
            throw Abort(.conflict, reason: "Skill '\(repo)' is already installed")
        }

        // Ensure skills directory exists
        try createSkillsDirectoryIfNeeded()

        // Execute git clone
        try await cloneRepository(from: githubUrl, to: installPath)

        // Validate SKILL.md exists
        try validateSkillStructure(at: installPath)

        // Invalidate cache so new skill appears in list
        await fileSystemService.invalidateSkillsCache()

        // Parse and return the installed skill
        guard let skill = try fileSystemService.getSkill(name: repo) else {
            throw Abort(.internalServerError, reason: "Failed to load installed skill")
        }

        return skill
    }

    /// Ensure the skills directory exists
    private func createSkillsDirectoryIfNeeded() throws {
        let skillsDirectory = fileSystemService.skillsDirectory
        if !fileManager.fileExists(atPath: skillsDirectory) {
            try fileManager.createDirectory(
                atPath: skillsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// Clone a GitHub repository using git
    /// - Parameters:
    ///   - url: GitHub repository URL
    ///   - path: Destination path for cloning
    /// - Throws: Vapor.Abort on git clone failure
    private func cloneRepository(from url: String, to path: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", "--depth", "1", url, path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            if exitCode != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw Abort(.internalServerError, reason: "Git clone failed: \(errorMessage)")
            }
        } catch let error as Abort {
            throw error
        } catch {
            throw Abort(.internalServerError, reason: "Failed to execute git clone: \(error.localizedDescription)")
        }
    }

    /// Validate that the cloned repository has a valid skill structure
    /// - Parameter path: Path to the cloned repository
    /// - Throws: Vapor.Abort if SKILL.md is missing
    private func validateSkillStructure(at path: String) throws {
        let skillMdPath = "\(path)/SKILL.md"

        guard fileManager.fileExists(atPath: skillMdPath) else {
            // Clean up the invalid installation
            try? fileManager.removeItem(atPath: path)
            throw Abort(.badRequest, reason: "Invalid skill: SKILL.md not found in repository")
        }

        // Validate that SKILL.md is readable
        guard let content = try? String(contentsOfFile: skillMdPath, encoding: .utf8),
              !content.isEmpty else {
            // Clean up the invalid installation
            try? fileManager.removeItem(atPath: path)
            throw Abort(.badRequest, reason: "Invalid skill: SKILL.md is empty or unreadable")
        }
    }

    /// Uninstall a GitHub-sourced skill
    /// - Parameter name: Name of the skill to uninstall
    /// - Throws: Vapor.Abort if skill not found or not a GitHub skill
    func uninstall(name: String) async throws {
        let skillPath = "\(fileSystemService.skillsDirectory)/\(name)"

        // Verify skill exists
        guard fileManager.fileExists(atPath: skillPath) else {
            throw Abort(.notFound, reason: "Skill '\(name)' not found")
        }

        // Check if this is a git repository (has .git directory)
        let gitPath = "\(skillPath)/.git"
        guard fileManager.fileExists(atPath: gitPath) else {
            throw Abort(.badRequest, reason: "Skill '\(name)' is not a GitHub-sourced skill")
        }

        // Remove the skill directory
        try fileManager.removeItem(atPath: skillPath)

        // Invalidate cache
        await fileSystemService.invalidateSkillsCache()
    }
}
