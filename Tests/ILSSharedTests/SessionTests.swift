import Testing
import Foundation
@testable import ILSShared

@Suite("ChatSession")
struct ChatSessionTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let id = UUID()
        let projectId = UUID()
        let forkedFrom = UUID()
        let now = Date(timeIntervalSince1970: 1700000000) // fixed date for stability
        let session = TestFactory.makeSession(
            id: id,
            claudeSessionId: "claude-abc-123",
            name: "Round Trip Session",
            projectId: projectId,
            projectName: "My Project",
            model: "opus",
            permissionMode: .acceptEdits,
            status: .completed,
            messageCount: 42,
            totalCostUSD: 1.23,
            source: .external,
            forkedFrom: forkedFrom,
            createdAt: now,
            lastActiveAt: now,
            encodedProjectPath: "%2Ftmp%2Fproject",
            firstPrompt: "Hello world"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ChatSession.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.claudeSessionId == "claude-abc-123")
        #expect(decoded.name == "Round Trip Session")
        #expect(decoded.projectId == projectId)
        #expect(decoded.projectName == "My Project")
        #expect(decoded.model == "opus")
        #expect(decoded.permissionMode == .acceptEdits)
        #expect(decoded.status == .completed)
        #expect(decoded.messageCount == 42)
        #expect(decoded.totalCostUSD == 1.23)
        #expect(decoded.source == .external)
        #expect(decoded.forkedFrom == forkedFrom)
        #expect(decoded.encodedProjectPath == "%2Ftmp%2Fproject")
        #expect(decoded.firstPrompt == "Hello world")
    }

    @Test("Default init values")
    func defaultInitValues() {
        let session = TestFactory.makeSession()

        #expect(session.model == "sonnet")
        #expect(session.permissionMode == .default)
        #expect(session.status == .active)
        #expect(session.messageCount == 5)
        #expect(session.source == .ils)
        #expect(session.name == "Test Session")
        #expect(session.claudeSessionId == nil)
        #expect(session.projectId == nil)
        #expect(session.totalCostUSD == nil)
        #expect(session.forkedFrom == nil)
    }

    @Test("Identifiable id matches init id")
    func identifiableId() {
        let id = UUID()
        let session = TestFactory.makeSession(id: id)
        #expect(session.id == id)
    }
}

@Suite("ExternalSession")
struct ExternalSessionTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let now = Date(timeIntervalSince1970: 1700000000)
        let session = TestFactory.makeExternalSession(
            claudeSessionId: "ext-abc-789",
            name: "My External",
            projectPath: "/tmp/ext-project",
            encodedProjectPath: "%2Ftmp%2Fext-project",
            projectName: "Ext Project",
            source: .external,
            lastActiveAt: now,
            createdAt: now,
            messageCount: 10,
            firstPrompt: "Start here",
            summary: "A summary",
            gitBranch: "main"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExternalSession.self, from: data)

        #expect(decoded.claudeSessionId == "ext-abc-789")
        #expect(decoded.name == "My External")
        #expect(decoded.projectPath == "/tmp/ext-project")
        #expect(decoded.encodedProjectPath == "%2Ftmp%2Fext-project")
        #expect(decoded.projectName == "Ext Project")
        #expect(decoded.source == .external)
        #expect(decoded.messageCount == 10)
        #expect(decoded.firstPrompt == "Start here")
        #expect(decoded.summary == "A summary")
        #expect(decoded.gitBranch == "main")
    }

    @Test("id maps to claudeSessionId")
    func idMapsToClaudeSessionId() {
        let session = TestFactory.makeExternalSession(claudeSessionId: "my-session-id")
        #expect(session.id == "my-session-id")
        #expect(session.id == session.claudeSessionId)
    }

    @Test("Default source is .external")
    func defaultSourceIsExternal() {
        let session = TestFactory.makeExternalSession()
        #expect(session.source == .external)
    }
}
