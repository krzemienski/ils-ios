import Fluent

struct SeedDefaultTemplates: AsyncMigration {
    func prepare(on database: Database) async throws {
        let templates = [
            SessionTemplateModel(
                name: "Code Review",
                description: "Review code changes with focus on quality and best practices",
                initialPrompt: """
                I need help reviewing code. Please analyze for:
                - Code quality and readability
                - Potential bugs or edge cases
                - Performance considerations
                - Security issues
                - Best practices
                """,
                model: "sonnet",
                permissionMode: .default,
                isFavorite: false,
                isDefault: true,
                tags: []
            ),
            SessionTemplateModel(
                name: "Documentation",
                description: "Generate comprehensive documentation for code",
                initialPrompt: """
                Help me create documentation for this code. Include:
                - Overview and purpose
                - API documentation
                - Usage examples
                - Edge cases and limitations
                """,
                model: "sonnet",
                permissionMode: .default,
                isFavorite: false,
                isDefault: true,
                tags: []
            ),
            SessionTemplateModel(
                name: "Testing Session",
                description: "Create comprehensive tests for code",
                initialPrompt: """
                I need to write tests. Please help me:
                - Identify test scenarios
                - Write unit tests
                - Create integration tests
                - Ensure edge case coverage
                """,
                model: "sonnet",
                permissionMode: .acceptEdits,
                isFavorite: false,
                isDefault: true,
                tags: []
            ),
            SessionTemplateModel(
                name: "Refactoring",
                description: "Refactor code for better quality and maintainability",
                initialPrompt: """
                I want to refactor this code. Focus on:
                - Improving readability
                - Reducing complexity
                - Following SOLID principles
                - Maintaining backward compatibility
                """,
                model: "opus",
                permissionMode: .plan,
                isFavorite: false,
                isDefault: true,
                tags: []
            )
        ]

        for template in templates {
            try await template.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        try await SessionTemplateModel.query(on: database)
            .filter(\.$isDefault == true)
            .delete()
    }
}
