import Foundation
import ILSShared

/// Actor responsible for reading/writing Claude Code team and task files from the filesystem.
/// Follows the Claude Code file structure: ~/.claude/teams/{name}/config.json and ~/.claude/tasks/{name}/
actor TeamsFileService {
    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init() {
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = .prettyPrinted
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Directory Helpers

    private func teamsBaseDir() -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/teams"
    }

    private func tasksBaseDir() -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/tasks"
    }

    private func teamDir(name: String) -> String {
        "\(teamsBaseDir())/\(name)"
    }

    private func teamConfigPath(name: String) -> String {
        "\(teamDir(name: name))/config.json"
    }

    private func taskDir(team: String) -> String {
        "\(tasksBaseDir())/\(team)"
    }

    private func messagesPath(team: String) -> String {
        "\(teamDir(name: team))/messages.json"
    }

    // MARK: - Validation

    private func validateName(_ name: String) throws {
        guard !name.isEmpty else {
            throw TeamsFileServiceError.invalidName("Team name cannot be empty")
        }

        guard !name.contains("/") && !name.contains("..") else {
            throw TeamsFileServiceError.invalidName("Team name cannot contain '/' or '..'")
        }

        let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard name.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            throw TeamsFileServiceError.invalidName("Team name can only contain letters, numbers, and hyphens")
        }
    }

    // MARK: - Team Operations

    func listTeams() throws -> [AgentTeam] {
        let teamsDir = teamsBaseDir()

        guard fileManager.fileExists(atPath: teamsDir) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: teamsDir)
        var teams: [AgentTeam] = []

        for item in contents {
            let configPath = "\(teamsDir)/\(item)/config.json"
            if fileManager.fileExists(atPath: configPath) {
                if let team = try? getTeam(name: item) {
                    teams.append(team)
                }
            }
        }

        return teams
    }

    func getTeam(name: String) throws -> AgentTeam? {
        try validateName(name)

        let configPath = teamConfigPath(name: name)

        guard fileManager.fileExists(atPath: configPath) else {
            return nil
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let config = try jsonDecoder.decode(TeamConfig.self, from: data)

        return AgentTeam(
            name: config.teamName,
            description: config.description,
            members: config.members
        )
    }

    func createTeam(name: String, description: String?) throws -> AgentTeam {
        try validateName(name)

        let teamPath = teamDir(name: name)
        let taskPath = taskDir(team: name)

        // Check if team already exists
        if fileManager.fileExists(atPath: teamPath) {
            throw TeamsFileServiceError.teamAlreadyExists(name)
        }

        // Create team directory
        try fileManager.createDirectory(
            atPath: teamPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create task directory
        try fileManager.createDirectory(
            atPath: taskPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create team config
        let config = TeamConfig(
            teamName: name,
            description: description,
            members: []
        )

        let configData = try jsonEncoder.encode(config)
        let configPath = teamConfigPath(name: name)
        try atomicWrite(data: configData, to: configPath)

        // Create empty messages array
        let messagesData = try jsonEncoder.encode([TeamMessage]())
        try atomicWrite(data: messagesData, to: messagesPath(team: name))

        return AgentTeam(
            name: config.teamName,
            description: config.description,
            members: config.members
        )
    }

    func deleteTeam(name: String) throws {
        try validateName(name)

        let teamPath = teamDir(name: name)
        let taskPath = taskDir(team: name)

        // Remove team directory
        if fileManager.fileExists(atPath: teamPath) {
            try fileManager.removeItem(atPath: teamPath)
        }

        // Remove task directory
        if fileManager.fileExists(atPath: taskPath) {
            try fileManager.removeItem(atPath: taskPath)
        }
    }

    // MARK: - Task Operations

    func listTasks(team: String) throws -> [TeamTask] {
        try validateName(team)

        let taskPath = taskDir(team: team)

        guard fileManager.fileExists(atPath: taskPath) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: taskPath)
        var tasks: [TeamTask] = []

        for file in contents where file.hasSuffix(".json") {
            let filePath = "\(taskPath)/\(file)"
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let task = try jsonDecoder.decode(TeamTask.self, from: data)
            tasks.append(task)
        }

        return tasks.sorted { $0.id < $1.id }
    }

    func createTask(team: String, subject: String, description: String?) throws -> TeamTask {
        try validateName(team)

        let taskPath = taskDir(team: team)

        // Ensure task directory exists
        if !fileManager.fileExists(atPath: taskPath) {
            try fileManager.createDirectory(
                atPath: taskPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        // Find next task ID
        let existingTasks = try listTasks(team: team)
        let maxId = existingTasks.compactMap { Int($0.id) }.max() ?? 0
        let nextId = maxId + 1

        let task = TeamTask(
            id: String(nextId),
            subject: subject,
            description: description,
            status: .pending,
            owner: nil
        )

        let taskData = try jsonEncoder.encode(task)
        let taskFilePath = "\(taskPath)/\(nextId).json"
        try atomicWrite(data: taskData, to: taskFilePath)

        return task
    }

    func updateTask(team: String, id: String, status: TeamTaskStatus?, owner: String?) throws -> TeamTask {
        try validateName(team)

        let taskPath = taskDir(team: team)
        let taskFilePath = "\(taskPath)/\(id).json"

        guard fileManager.fileExists(atPath: taskFilePath) else {
            throw TeamsFileServiceError.taskNotFound(id)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: taskFilePath))
        var task = try jsonDecoder.decode(TeamTask.self, from: data)

        // Update fields
        if let status = status {
            task.status = status
        }
        if let owner = owner {
            task.owner = owner
        }

        let updatedData = try jsonEncoder.encode(task)
        try atomicWrite(data: updatedData, to: taskFilePath)

        return task
    }

    // MARK: - Atomic File Write

    /// Write data atomically: write to temp file then rename to prevent partial writes on crash/concurrent access.
    private func atomicWrite(data: Data, to path: String) throws {
        let tempPath = path + ".tmp.\(UUID().uuidString)"
        let tempURL = URL(fileURLWithPath: tempPath)
        let targetURL = URL(fileURLWithPath: path)

        do {
            try data.write(to: tempURL, options: .atomic)
            // If target exists, remove before rename
            if fileManager.fileExists(atPath: path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.moveItem(at: tempURL, to: targetURL)
        } catch {
            // Clean up temp file on failure
            try? fileManager.removeItem(at: tempURL)
            throw TeamsFileServiceError.fileOperationFailed(error.localizedDescription)
        }
    }

    // MARK: - Message Operations

    func listMessages(team: String) throws -> [TeamMessage] {
        try validateName(team)

        let messagesFilePath = messagesPath(team: team)

        guard fileManager.fileExists(atPath: messagesFilePath) else {
            return []
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: messagesFilePath))
        let messages = try jsonDecoder.decode([TeamMessage].self, from: data)

        return messages
    }

    func sendMessage(team: String, message: TeamMessage) throws {
        try validateName(team)

        let messagesFilePath = messagesPath(team: team)

        var messages: [TeamMessage] = []
        if fileManager.fileExists(atPath: messagesFilePath) {
            let data = try Data(contentsOf: URL(fileURLWithPath: messagesFilePath))
            messages = try jsonDecoder.decode([TeamMessage].self, from: data)
        }

        messages.append(message)

        let messagesData = try jsonEncoder.encode(messages)
        try atomicWrite(data: messagesData, to: messagesFilePath)
    }
}

// MARK: - Supporting Types

private struct TeamConfig: Codable {
    let teamName: String
    let description: String?
    let members: [TeamMember]

    enum CodingKeys: String, CodingKey {
        case teamName = "team_name"
        case description
        case members
    }
}

// MARK: - Errors

enum TeamsFileServiceError: Error, LocalizedError {
    case invalidName(String)
    case teamAlreadyExists(String)
    case teamNotFound(String)
    case taskNotFound(String)
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid team name: \(reason)"
        case .teamAlreadyExists(let name):
            return "Team '\(name)' already exists"
        case .teamNotFound(let name):
            return "Team '\(name)' not found"
        case .taskNotFound(let id):
            return "Task '\(id)' not found"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}
