import Foundation

struct SessionTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var model: String
    var permissionMode: String
    var systemPrompt: String
    var maxBudget: String
    var maxTurns: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        model: String = "sonnet",
        permissionMode: String = "default",
        systemPrompt: String = "",
        maxBudget: String = "",
        maxTurns: String = "",
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.permissionMode = permissionMode
        self.systemPrompt = systemPrompt
        self.maxBudget = maxBudget
        self.maxTurns = maxTurns
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    /// Default templates for common workflows
    static let defaults: [SessionTemplate] = [
        SessionTemplate(
            name: "Code Review",
            description: "Review code for bugs, style, and best practices",
            model: "sonnet",
            permissionMode: "plan",
            systemPrompt: "You are a code reviewer. Analyze the code for bugs, security issues, performance problems, and style violations. Provide actionable feedback."
        ),
        SessionTemplate(
            name: "Documentation",
            description: "Generate or improve documentation",
            model: "haiku",
            permissionMode: "acceptEdits",
            systemPrompt: "Help write clear, concise documentation. Focus on explaining the why, not just the what."
        ),
        SessionTemplate(
            name: "Bug Fix",
            description: "Debug and fix issues in code",
            model: "sonnet",
            permissionMode: "acceptEdits",
            systemPrompt: "Help diagnose and fix bugs. Start by understanding the expected vs actual behavior, then trace the root cause."
        ),
        SessionTemplate(
            name: "Refactor",
            description: "Improve code structure without changing behavior",
            model: "opus",
            permissionMode: "acceptEdits",
            systemPrompt: "Refactor the code to improve readability, maintainability, and performance while preserving all existing behavior."
        )
    ]
}
