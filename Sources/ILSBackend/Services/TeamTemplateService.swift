import Foundation
import ILSShared

/// Actor responsible for managing team templates in the filesystem.
/// Stores templates in ~/.claude/team-templates/{id}.json
actor TeamTemplateService {
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

    private func templatesBaseDir() -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/team-templates"
    }

    private func templatePath(id: String) -> String {
        "\(templatesBaseDir())/\(id).json"
    }

    private func ensureTemplatesDirectory() throws {
        let templatesDir = templatesBaseDir()
        if !fileManager.fileExists(atPath: templatesDir) {
            try fileManager.createDirectory(
                atPath: templatesDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - Validation

    private func validateId(_ id: String) throws {
        guard !id.isEmpty else {
            throw TeamTemplateServiceError.invalidId("Template ID cannot be empty")
        }

        guard !id.contains("/") && !id.contains("..") else {
            throw TeamTemplateServiceError.invalidId("Template ID cannot contain '/' or '..'")
        }

        let validCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard id.unicodeScalars.allSatisfy({ validCharacters.contains($0) }) else {
            throw TeamTemplateServiceError.invalidId("Template ID can only contain letters, numbers, hyphens, and underscores")
        }
    }

    private func validateTemplate(_ template: TeamTemplate) throws {
        guard !template.name.isEmpty else {
            throw TeamTemplateServiceError.invalidTemplate("Template name cannot be empty")
        }
    }

    // MARK: - Atomic Write

    private func atomicWrite(data: Data, to path: String) throws {
        let tempPath = "\(path).tmp"
        try data.write(to: URL(fileURLWithPath: tempPath), options: .atomic)
        try fileManager.moveItem(atPath: tempPath, toPath: path)
    }

    // MARK: - Template CRUD Operations

    func listTemplates() throws -> [TeamTemplate] {
        try ensureTemplatesDirectory()

        let templatesDir = templatesBaseDir()
        let contents = try fileManager.contentsOfDirectory(atPath: templatesDir)
        var templates: [TeamTemplate] = []

        for file in contents where file.hasSuffix(".json") {
            let filePath = "\(templatesDir)/\(file)"
            if let template = try? loadTemplate(from: filePath) {
                templates.append(template)
            }
        }

        return templates.sorted { t1, t2 in
            // Built-in templates first, then by creation date (newest first), then by name
            if t1.isBuiltIn != t2.isBuiltIn {
                return t1.isBuiltIn
            }
            if let d1 = t1.createdAt, let d2 = t2.createdAt {
                return d1 > d2
            }
            return t1.name < t2.name
        }
    }

    func getTemplate(id: String) throws -> TeamTemplate? {
        try validateId(id)

        let path = templatePath(id: id)
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }

        return try loadTemplate(from: path)
    }

    func createTemplate(
        id: String,
        name: String,
        description: String?,
        category: String?,
        members: [TemplateMember],
        tasks: [TemplateTask]
    ) throws -> TeamTemplate {
        try validateId(id)
        try ensureTemplatesDirectory()

        let path = templatePath(id: id)

        // Check if template already exists
        if fileManager.fileExists(atPath: path) {
            throw TeamTemplateServiceError.templateAlreadyExists(id)
        }

        let template = TeamTemplate(
            id: id,
            name: name,
            description: description,
            category: category,
            members: members,
            tasks: tasks,
            isBuiltIn: false,
            createdAt: Date()
        )

        try validateTemplate(template)

        let data = try jsonEncoder.encode(template)
        try atomicWrite(data: data, to: path)

        return template
    }

    func updateTemplate(
        id: String,
        name: String?,
        description: String?,
        category: String?,
        members: [TemplateMember]?,
        tasks: [TemplateTask]?
    ) throws -> TeamTemplate {
        try validateId(id)

        guard var template = try getTemplate(id: id) else {
            throw TeamTemplateServiceError.templateNotFound(id)
        }

        // Built-in templates cannot be modified
        if template.isBuiltIn {
            throw TeamTemplateServiceError.cannotModifyBuiltIn(id)
        }

        // Update fields
        if let name = name {
            template = TeamTemplate(
                id: template.id,
                name: name,
                description: description ?? template.description,
                category: category ?? template.category,
                members: members ?? template.members,
                tasks: tasks ?? template.tasks,
                isBuiltIn: template.isBuiltIn,
                createdAt: template.createdAt
            )
        } else {
            template = TeamTemplate(
                id: template.id,
                name: template.name,
                description: description ?? template.description,
                category: category ?? template.category,
                members: members ?? template.members,
                tasks: tasks ?? template.tasks,
                isBuiltIn: template.isBuiltIn,
                createdAt: template.createdAt
            )
        }

        try validateTemplate(template)

        let path = templatePath(id: id)
        let data = try jsonEncoder.encode(template)
        try atomicWrite(data: data, to: path)

        return template
    }

    func deleteTemplate(id: String) throws {
        try validateId(id)

        guard let template = try getTemplate(id: id) else {
            throw TeamTemplateServiceError.templateNotFound(id)
        }

        // Built-in templates cannot be deleted
        if template.isBuiltIn {
            throw TeamTemplateServiceError.cannotDeleteBuiltIn(id)
        }

        let path = templatePath(id: id)
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }

    // MARK: - Private Helpers

    private func loadTemplate(from path: String) throws -> TeamTemplate {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try jsonDecoder.decode(TeamTemplate.self, from: data)
    }
}

// MARK: - Errors

enum TeamTemplateServiceError: Error, LocalizedError {
    case invalidId(String)
    case invalidTemplate(String)
    case templateAlreadyExists(String)
    case templateNotFound(String)
    case cannotModifyBuiltIn(String)
    case cannotDeleteBuiltIn(String)

    var errorDescription: String? {
        switch self {
        case .invalidId(let message):
            return "Invalid template ID: \(message)"
        case .invalidTemplate(let message):
            return "Invalid template: \(message)"
        case .templateAlreadyExists(let id):
            return "Template already exists: \(id)"
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .cannotModifyBuiltIn(let id):
            return "Cannot modify built-in template: \(id)"
        case .cannotDeleteBuiltIn(let id):
            return "Cannot delete built-in template: \(id)"
        }
    }
}
