import Foundation

/// Represents a reusable session template with pre-configured prompts and settings.
public struct SessionTemplate: Codable, Identifiable, Sendable, Hashable {
    /// Unique identifier for the template.
    public let id: UUID
    /// Display name of the template.
    public var name: String
    /// Brief description of what this template is for.
    public var description: String
    /// Claude model to use (e.g., "sonnet", "opus").
    public var model: String
    /// Permission mode for the session (e.g., "default", "acceptEdits", "bypassPermissions").
    public var permissionMode: String
    /// System prompt pre-loaded into the session.
    public var systemPrompt: String
    /// Optional maximum budget in USD for the session.
    public var maxBudgetUSD: Double?
    /// Optional maximum number of turns for the session.
    public var maxTurns: Int?
    /// Whether this is a built-in template shipped with the app.
    public var isBuiltIn: Bool
    /// Whether the user has marked this template as a favourite.
    public var isFavorite: Bool
    /// When the template was created.
    public let createdAt: Date
    /// When the template was last modified.
    public var updatedAt: Date

    /// Creates a new session template.
    /// - Parameters:
    ///   - id: Unique identifier (auto-generated if omitted).
    ///   - name: Display name. Must not be empty.
    ///   - description: Brief description of the template's purpose.
    ///   - model: Claude model to use (default: "sonnet").
    ///   - permissionMode: Permission mode for the session (default: "default").
    ///   - systemPrompt: System prompt pre-loaded into the session.
    ///   - maxBudgetUSD: Optional maximum budget in USD.
    ///   - maxTurns: Optional maximum number of turns.
    ///   - isBuiltIn: Whether this is a built-in template (default: false).
    ///   - isFavorite: Whether the user has favourited this template (default: false).
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last-modified timestamp.
    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        model: String = "sonnet",
        permissionMode: String = "default",
        systemPrompt: String = "",
        maxBudgetUSD: Double? = nil,
        maxTurns: Int? = nil,
        isBuiltIn: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        precondition(!name.isEmpty, "SessionTemplate name must not be empty")
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.permissionMode = permissionMode
        self.systemPrompt = systemPrompt
        self.maxBudgetUSD = maxBudgetUSD
        self.maxTurns = maxTurns
        self.isBuiltIn = isBuiltIn
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Built-in Templates

    /// The built-in starter templates shipped with the app.
    public static let defaults: [SessionTemplate] = [
        SessionTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Code Review",
            description: "Thorough code review focusing on correctness, style, and best practices.",
            model: "sonnet",
            permissionMode: "default",
            systemPrompt: """
            You are an expert code reviewer. Your goal is to provide thorough, constructive feedback on the code I share with you.

            Focus on:
            - Correctness: logic errors, edge cases, and potential bugs
            - Code quality: readability, naming conventions, and structure
            - Best practices: idiomatic patterns, SOLID principles, and DRY
            - Performance: obvious inefficiencies or scalability concerns
            - Security: common vulnerabilities or unsafe patterns

            Be specific, cite line numbers where applicable, and suggest concrete improvements.
            """,
            isBuiltIn: true
        ),
        SessionTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Documentation",
            description: "Generate clear, comprehensive documentation for code and APIs.",
            model: "sonnet",
            permissionMode: "default",
            systemPrompt: """
            You are a technical writer specialising in developer documentation. Your goal is to produce clear, accurate, and useful documentation.

            When documenting code:
            - Write concise doc-comments for every public symbol
            - Include parameter descriptions, return values, and thrown errors
            - Add usage examples where helpful
            - Keep language plain and precise — avoid jargon where possible
            - Follow the conventions of the language/framework in use
            """,
            isBuiltIn: true
        ),
        SessionTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Bug Fix",
            description: "Systematic debugging and bug-fixing with root-cause analysis.",
            model: "sonnet",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are an expert debugger. Your goal is to identify the root cause of bugs and provide reliable fixes.

            Approach each problem by:
            1. Reproducing and confirming the bug
            2. Identifying the root cause (not just the symptom)
            3. Proposing a minimal, targeted fix
            4. Explaining why the fix resolves the issue
            5. Suggesting any related edge cases to test

            Prefer surgical fixes over large refactors unless the root cause demands it.
            """,
            isBuiltIn: true
        ),
        SessionTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "Refactor",
            description: "Improve code structure, readability, and maintainability without changing behaviour.",
            model: "sonnet",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are an expert software engineer focused on code quality. Your goal is to refactor code so that it is cleaner, more maintainable, and easier to understand — without changing its external behaviour.

            Refactoring principles to apply:
            - Eliminate duplication (DRY)
            - Improve naming for clarity
            - Break large functions into smaller, focused ones
            - Simplify complex conditionals
            - Improve code organisation and module boundaries
            - Ensure tests remain passing after each change

            Make incremental, reviewable changes and explain the motivation for each.
            """,
            isBuiltIn: true
        ),
        SessionTemplate(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "New Feature",
            description: "Scaffold and implement a new feature with clean architecture.",
            model: "sonnet",
            permissionMode: "acceptEdits",
            systemPrompt: """
            You are an expert software engineer helping design and implement a new feature.

            Approach each feature by:
            1. Clarifying requirements and defining the interface/API first
            2. Designing the data model and main types
            3. Implementing incrementally, starting with the happy path
            4. Adding error handling and edge cases
            5. Writing or updating tests to cover the new behaviour

            Favour clean architecture, small focused functions, and clear naming.
            Make incremental commits with descriptive messages.
            """,
            isBuiltIn: true
        )
    ]
}
