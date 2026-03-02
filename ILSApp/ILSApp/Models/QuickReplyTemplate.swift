import Foundation

enum QuickReplyCategory: String, Codable, CaseIterable {
    case permissions = "permissions"
    case coding = "coding"
    case review = "review"
    case debugging = "debugging"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .permissions: return "Permissions"
        case .coding: return "Coding"
        case .review: return "Review"
        case .debugging: return "Debugging"
        case .custom: return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .permissions: return "checkmark.shield"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .review: return "magnifyingglass"
        case .debugging: return "ant"
        case .custom: return "star"
        }
    }
}

struct QuickReplyVariable: Codable, Identifiable {
    let id: UUID
    var name: String
    var defaultValue: String
    var placeholder: String

    init(
        id: UUID = UUID(),
        name: String,
        defaultValue: String = "",
        placeholder: String = ""
    ) {
        self.id = id
        self.name = name
        self.defaultValue = defaultValue
        self.placeholder = placeholder
    }
}

struct QuickReplyUsageStats: Codable {
    var useCount: Int
    var lastUsedAt: Date?
    var projectUsageCounts: [String: Int]

    init(
        useCount: Int = 0,
        lastUsedAt: Date? = nil,
        projectUsageCounts: [String: Int] = [:]
    ) {
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.projectUsageCounts = projectUsageCounts
    }

    mutating func recordUse(projectId: String? = nil) {
        useCount += 1
        lastUsedAt = Date()
        if let projectId {
            projectUsageCounts[projectId, default: 0] += 1
        }
    }
}

struct QuickReplyProjectOverride: Codable, Identifiable {
    let id: UUID
    var projectId: String
    var content: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        projectId: String,
        content: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.projectId = projectId
        self.content = content
        self.isEnabled = isEnabled
    }
}

struct QuickReplyTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var content: String
    var category: QuickReplyCategory
    var variables: [QuickReplyVariable]
    var usageStats: QuickReplyUsageStats
    var projectOverrides: [QuickReplyProjectOverride]
    var isFavorite: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        content: String,
        category: QuickReplyCategory = .custom,
        variables: [QuickReplyVariable] = [],
        usageStats: QuickReplyUsageStats = QuickReplyUsageStats(),
        projectOverrides: [QuickReplyProjectOverride] = [],
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.category = category
        self.variables = variables
        self.usageStats = usageStats
        self.projectOverrides = projectOverrides
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.tags = tags
    }

    /// Returns content with variables resolved using their default values or project-specific overrides
    func resolvedContent(for projectId: String? = nil, variableValues: [String: String] = [:]) -> String {
        var text = content
        if let projectId, let override = projectOverrides.first(where: { $0.projectId == projectId && $0.isEnabled }) {
            text = override.content
        }
        for variable in variables {
            let value = variableValues[variable.name] ?? variable.defaultValue
            text = text.replacingOccurrences(of: "{{\(variable.name)}}", with: value)
        }
        return text
    }

    /// Returns true if this template has unresolved variables
    var hasVariables: Bool {
        !variables.isEmpty
    }

    /// Built-in template library with 20+ common responses
    static let builtIns: [QuickReplyTemplate] = [
        // MARK: - Permissions
        QuickReplyTemplate(
            name: "Approve All",
            content: "Yes, approve all actions and proceed.",
            category: .permissions,
            isBuiltIn: true,
            tags: ["approve", "yes", "proceed"]
        ),
        QuickReplyTemplate(
            name: "Deny with Explanation",
            content: "No, don't do that. {{reason}}",
            category: .permissions,
            variables: [QuickReplyVariable(name: "reason", placeholder: "Explain why...")],
            isBuiltIn: true,
            tags: ["deny", "no", "stop"]
        ),
        QuickReplyTemplate(
            name: "Approve This Step Only",
            content: "Approve this step only, then pause and wait for my confirmation before continuing.",
            category: .permissions,
            isBuiltIn: true,
            tags: ["approve", "pause", "step"]
        ),
        QuickReplyTemplate(
            name: "Stop and Revert",
            content: "Stop immediately and revert all changes you've made.",
            category: .permissions,
            isBuiltIn: true,
            tags: ["stop", "revert", "undo"]
        ),
        QuickReplyTemplate(
            name: "Continue in Plan Mode",
            content: "Switch to plan mode. Show me the plan before making any changes.",
            category: .permissions,
            isBuiltIn: true,
            tags: ["plan", "review", "safe"]
        ),

        // MARK: - Coding
        QuickReplyTemplate(
            name: "Run Tests",
            content: "Run the tests and show me the results.",
            category: .coding,
            isBuiltIn: true,
            tags: ["test", "run", "verify"]
        ),
        QuickReplyTemplate(
            name: "Run Tests in Project",
            content: "Run the tests in {{project}} and show me the results.",
            category: .coding,
            variables: [QuickReplyVariable(name: "project", placeholder: "project name")],
            isBuiltIn: true,
            tags: ["test", "project"]
        ),
        QuickReplyTemplate(
            name: "Explain the Changes",
            content: "Explain the changes you just made in simple terms.",
            category: .coding,
            isBuiltIn: true,
            tags: ["explain", "summary", "changes"]
        ),
        QuickReplyTemplate(
            name: "Show Diff",
            content: "Show me a diff of all changes made so far.",
            category: .coding,
            isBuiltIn: true,
            tags: ["diff", "changes", "git"]
        ),
        QuickReplyTemplate(
            name: "Commit Changes",
            content: "Commit all staged changes with a descriptive commit message.",
            category: .coding,
            isBuiltIn: true,
            tags: ["commit", "git", "save"]
        ),
        QuickReplyTemplate(
            name: "Implement in {{language}}",
            content: "Implement this in {{language}}.",
            category: .coding,
            variables: [QuickReplyVariable(name: "language", defaultValue: "Swift", placeholder: "language")],
            isBuiltIn: true,
            tags: ["implement", "language"]
        ),

        // MARK: - Review
        QuickReplyTemplate(
            name: "Code Review",
            content: "Review this code for bugs, security issues, and best practices.",
            category: .review,
            isBuiltIn: true,
            tags: ["review", "bugs", "security"]
        ),
        QuickReplyTemplate(
            name: "Check for Edge Cases",
            content: "Check for edge cases and potential failure scenarios I may have missed.",
            category: .review,
            isBuiltIn: true,
            tags: ["edge cases", "review", "qa"]
        ),
        QuickReplyTemplate(
            name: "Looks Good",
            content: "Looks good to me. Continue with the implementation.",
            category: .review,
            isBuiltIn: true,
            tags: ["approve", "lgtm", "continue"]
        ),
        QuickReplyTemplate(
            name: "Add Tests",
            content: "Add comprehensive unit tests for this code.",
            category: .review,
            isBuiltIn: true,
            tags: ["tests", "unit", "coverage"]
        ),
        QuickReplyTemplate(
            name: "Add Documentation",
            content: "Add clear documentation and code comments.",
            category: .review,
            isBuiltIn: true,
            tags: ["docs", "comments", "documentation"]
        ),

        // MARK: - Debugging
        QuickReplyTemplate(
            name: "Debug This Error",
            content: "Debug this error and tell me the root cause before fixing it.",
            category: .debugging,
            isBuiltIn: true,
            tags: ["debug", "error", "root cause"]
        ),
        QuickReplyTemplate(
            name: "Add Logging",
            content: "Add logging to help debug this issue.",
            category: .debugging,
            isBuiltIn: true,
            tags: ["logging", "debug", "trace"]
        ),
        QuickReplyTemplate(
            name: "Check Logs",
            content: "Check the logs for relevant errors or warnings.",
            category: .debugging,
            isBuiltIn: true,
            tags: ["logs", "errors", "warnings"]
        ),
        QuickReplyTemplate(
            name: "Reproduce the Bug",
            content: "Write a test case that reproduces this bug.",
            category: .debugging,
            isBuiltIn: true,
            tags: ["bug", "reproduce", "test"]
        ),
        QuickReplyTemplate(
            name: "Try a Different Approach",
            content: "That approach isn't working. Try a completely different approach.",
            category: .debugging,
            isBuiltIn: true,
            tags: ["alternative", "different", "approach"]
        )
    ]
}
