import Foundation
@testable import ILSShared

/// Test data factories for common ILSShared model objects.
/// Each factory provides sensible defaults; pass parameters to override specific fields.
enum TestFactory {
    static func makeSession(
        id: UUID = UUID(),
        claudeSessionId: String? = nil,
        name: String? = "Test Session",
        projectId: UUID? = nil,
        projectName: String? = nil,
        model: String = "sonnet",
        permissionMode: PermissionMode = .default,
        status: SessionStatus = .active,
        messageCount: Int = 5,
        totalCostUSD: Double? = nil,
        source: SessionSource = .ils,
        forkedFrom: UUID? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        encodedProjectPath: String? = nil,
        firstPrompt: String? = nil
    ) -> ChatSession {
        ChatSession(
            id: id, claudeSessionId: claudeSessionId,
            name: name, projectId: projectId,
            projectName: projectName, model: model,
            permissionMode: permissionMode, status: status,
            messageCount: messageCount, totalCostUSD: totalCostUSD,
            source: source, forkedFrom: forkedFrom,
            createdAt: createdAt, lastActiveAt: lastActiveAt,
            encodedProjectPath: encodedProjectPath,
            firstPrompt: firstPrompt
        )
    }

    static func makeProject(
        id: UUID = UUID(),
        name: String = "Test Project",
        path: String = "/tmp/test-project",
        defaultModel: String = "sonnet",
        description: String? = nil,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        sessionCount: Int? = nil,
        encodedPath: String? = nil
    ) -> Project {
        Project(
            id: id, name: name, path: path,
            defaultModel: defaultModel, description: description,
            createdAt: createdAt, lastAccessedAt: lastAccessedAt,
            sessionCount: sessionCount, encodedPath: encodedPath
        )
    }

    static func makeMessage(
        id: UUID = UUID(),
        sessionId: UUID = UUID(),
        role: MessageRole = .user,
        content: String = "Hello, Claude",
        toolCalls: String? = nil,
        toolResults: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Message {
        Message(
            id: id, sessionId: sessionId, role: role,
            content: content, toolCalls: toolCalls,
            toolResults: toolResults, createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func makeExternalSession(
        claudeSessionId: String = "ext-session-001",
        name: String? = "External Session",
        projectPath: String? = "/tmp/ext-project",
        encodedProjectPath: String? = nil,
        projectName: String? = nil,
        source: SessionSource = .external,
        lastActiveAt: Date? = nil,
        createdAt: Date? = nil,
        messageCount: Int? = nil,
        firstPrompt: String? = nil,
        summary: String? = nil,
        gitBranch: String? = nil
    ) -> ExternalSession {
        ExternalSession(
            claudeSessionId: claudeSessionId, name: name,
            projectPath: projectPath, encodedProjectPath: encodedProjectPath,
            projectName: projectName, source: source,
            lastActiveAt: lastActiveAt, createdAt: createdAt,
            messageCount: messageCount, firstPrompt: firstPrompt,
            summary: summary, gitBranch: gitBranch
        )
    }
}
