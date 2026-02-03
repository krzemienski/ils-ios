import XCTest
@testable import ILSShared

final class RequestsTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // MARK: - APIResponse Tests

    func testAPIResponseSuccessWithData() throws {
        let response = APIResponse(success: true, data: "test data")

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(APIResponse<String>.self, from: encoded)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data, "test data")
        XCTAssertNil(decoded.error)
    }

    func testAPIResponseErrorWithoutData() throws {
        let error = APIError(code: "NOT_FOUND", message: "Resource not found")
        let response = APIResponse<String>(success: false, data: nil, error: error)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(APIResponse<String>.self, from: encoded)

        XCTAssertFalse(decoded.success)
        XCTAssertNil(decoded.data)
        XCTAssertNotNil(decoded.error)
        XCTAssertEqual(decoded.error?.code, "NOT_FOUND")
        XCTAssertEqual(decoded.error?.message, "Resource not found")
    }

    func testAPIResponseWithComplexData() throws {
        struct TestData: Codable, Sendable {
            let id: Int
            let name: String
        }

        let testData = TestData(id: 123, name: "Test")
        let response = APIResponse(success: true, data: testData)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(APIResponse<TestData>.self, from: encoded)

        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data?.id, 123)
        XCTAssertEqual(decoded.data?.name, "Test")
    }

    // MARK: - APIError Tests

    func testAPIErrorEncodeDecode() throws {
        let error = APIError(code: "VALIDATION_ERROR", message: "Invalid input provided")

        let encoded = try encoder.encode(error)
        let decoded = try decoder.decode(APIError.self, from: encoded)

        XCTAssertEqual(decoded.code, "VALIDATION_ERROR")
        XCTAssertEqual(decoded.message, "Invalid input provided")
    }

    // MARK: - ListResponse Tests

    func testListResponseWithItems() throws {
        let items = ["item1", "item2", "item3"]
        let response = ListResponse(items: items, total: 3)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(ListResponse<String>.self, from: encoded)

        XCTAssertEqual(decoded.items.count, 3)
        XCTAssertEqual(decoded.items, ["item1", "item2", "item3"])
        XCTAssertEqual(decoded.total, 3)
    }

    func testListResponseWithDefaultTotal() throws {
        let items = [1, 2, 3, 4, 5]
        let response = ListResponse(items: items)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(ListResponse<Int>.self, from: encoded)

        XCTAssertEqual(decoded.items.count, 5)
        XCTAssertEqual(decoded.total, 5)
    }

    func testListResponseEmpty() throws {
        let response = ListResponse<String>(items: [], total: 0)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(ListResponse<String>.self, from: encoded)

        XCTAssertEqual(decoded.items.count, 0)
        XCTAssertEqual(decoded.total, 0)
    }

    // MARK: - Project Request Tests

    func testCreateProjectRequestWithAllFields() throws {
        let request = CreateProjectRequest(
            name: "My Project",
            path: "/path/to/project",
            defaultModel: "sonnet",
            description: "A test project"
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateProjectRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "My Project")
        XCTAssertEqual(decoded.path, "/path/to/project")
        XCTAssertEqual(decoded.defaultModel, "sonnet")
        XCTAssertEqual(decoded.description, "A test project")
    }

    func testCreateProjectRequestMinimal() throws {
        let request = CreateProjectRequest(name: "Simple Project", path: "/path")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateProjectRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "Simple Project")
        XCTAssertEqual(decoded.path, "/path")
        XCTAssertNil(decoded.defaultModel)
        XCTAssertNil(decoded.description)
    }

    func testUpdateProjectRequestAllFields() throws {
        let request = UpdateProjectRequest(
            name: "Updated Name",
            defaultModel: "opus",
            description: "Updated description"
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(UpdateProjectRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "Updated Name")
        XCTAssertEqual(decoded.defaultModel, "opus")
        XCTAssertEqual(decoded.description, "Updated description")
    }

    func testUpdateProjectRequestPartial() throws {
        let request = UpdateProjectRequest(name: "New Name")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(UpdateProjectRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "New Name")
        XCTAssertNil(decoded.defaultModel)
        XCTAssertNil(decoded.description)
    }

    // MARK: - Session Request Tests

    func testCreateSessionRequestWithAllFields() throws {
        let projectId = UUID()
        let request = CreateSessionRequest(
            projectId: projectId,
            name: "Test Session",
            model: "sonnet",
            permissionMode: .default
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateSessionRequest.self, from: encoded)

        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertEqual(decoded.name, "Test Session")
        XCTAssertEqual(decoded.model, "sonnet")
        XCTAssertEqual(decoded.permissionMode, .default)
    }

    func testCreateSessionRequestMinimal() throws {
        let request = CreateSessionRequest()

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateSessionRequest.self, from: encoded)

        XCTAssertNil(decoded.projectId)
        XCTAssertNil(decoded.name)
        XCTAssertNil(decoded.model)
        XCTAssertNil(decoded.permissionMode)
    }

    func testSessionScanResponseWithData() throws {
        let externalSession = ExternalSession(
            claudeSessionId: "session-123",
            name: "External Session",
            projectPath: "/path/to/project"
        )
        let response = SessionScanResponse(
            items: [externalSession],
            scannedPaths: ["/path1", "/path2"],
            total: 1
        )

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(SessionScanResponse.self, from: encoded)

        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items[0].claudeSessionId, "session-123")
        XCTAssertEqual(decoded.items[0].name, "External Session")
        XCTAssertEqual(decoded.scannedPaths, ["/path1", "/path2"])
        XCTAssertEqual(decoded.total, 1)
    }

    func testSessionScanResponseEmpty() throws {
        let response = SessionScanResponse(items: [], scannedPaths: ["/path"])

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(SessionScanResponse.self, from: encoded)

        XCTAssertEqual(decoded.items.count, 0)
        XCTAssertEqual(decoded.scannedPaths, ["/path"])
        XCTAssertEqual(decoded.total, 0)
    }

    // MARK: - Chat Request Tests

    func testChatStreamRequestWithAllOptions() throws {
        let sessionId = UUID()
        let projectId = UUID()
        let options = ChatOptions(
            model: "opus",
            permissionMode: .acceptEdits,
            maxTurns: 10,
            maxBudgetUSD: 5.0,
            allowedTools: ["bash", "read"],
            disallowedTools: ["write"],
            resume: "agent-123",
            forkSession: true
        )
        let request = ChatStreamRequest(
            prompt: "Hello, Claude!",
            sessionId: sessionId,
            projectId: projectId,
            options: options
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(ChatStreamRequest.self, from: encoded)

        XCTAssertEqual(decoded.prompt, "Hello, Claude!")
        XCTAssertEqual(decoded.sessionId, sessionId)
        XCTAssertEqual(decoded.projectId, projectId)
        XCTAssertNotNil(decoded.options)
        XCTAssertEqual(decoded.options?.model, "opus")
        XCTAssertEqual(decoded.options?.permissionMode, .acceptEdits)
        XCTAssertEqual(decoded.options?.maxTurns, 10)
        XCTAssertEqual(decoded.options?.maxBudgetUSD, 5.0)
        XCTAssertEqual(decoded.options?.allowedTools, ["bash", "read"])
        XCTAssertEqual(decoded.options?.disallowedTools, ["write"])
        XCTAssertEqual(decoded.options?.resume, "agent-123")
        XCTAssertEqual(decoded.options?.forkSession, true)
    }

    func testChatStreamRequestMinimal() throws {
        let request = ChatStreamRequest(prompt: "Simple prompt")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(ChatStreamRequest.self, from: encoded)

        XCTAssertEqual(decoded.prompt, "Simple prompt")
        XCTAssertNil(decoded.sessionId)
        XCTAssertNil(decoded.projectId)
        XCTAssertNil(decoded.options)
    }

    func testChatOptionsMinimal() throws {
        let options = ChatOptions()

        let encoded = try encoder.encode(options)
        let decoded = try decoder.decode(ChatOptions.self, from: encoded)

        XCTAssertNil(decoded.model)
        XCTAssertNil(decoded.permissionMode)
        XCTAssertNil(decoded.maxTurns)
        XCTAssertNil(decoded.maxBudgetUSD)
        XCTAssertNil(decoded.allowedTools)
        XCTAssertNil(decoded.disallowedTools)
        XCTAssertNil(decoded.resume)
        XCTAssertNil(decoded.forkSession)
    }

    // MARK: - Permission Decision Tests

    func testPermissionDecisionAllow() throws {
        let decision = PermissionDecision(decision: "allow", reason: "Safe operation")

        let encoded = try encoder.encode(decision)
        let decoded = try decoder.decode(PermissionDecision.self, from: encoded)

        XCTAssertEqual(decoded.decision, "allow")
        XCTAssertEqual(decoded.reason, "Safe operation")
    }

    func testPermissionDecisionDenyWithoutReason() throws {
        let decision = PermissionDecision(decision: "deny")

        let encoded = try encoder.encode(decision)
        let decoded = try decoder.decode(PermissionDecision.self, from: encoded)

        XCTAssertEqual(decoded.decision, "deny")
        XCTAssertNil(decoded.reason)
    }

    // MARK: - WebSocket Client Message Tests

    func testWSClientMessageMessage() throws {
        let message = WSClientMessage.message(prompt: "Test prompt")

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSClientMessage.self, from: encoded)

        guard case .message(let prompt) = decoded else {
            XCTFail("Expected message case")
            return
        }

        XCTAssertEqual(prompt, "Test prompt")
    }

    func testWSClientMessagePermission() throws {
        let message = WSClientMessage.permission(
            requestId: "req-123",
            decision: "allow",
            reason: "Approved"
        )

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSClientMessage.self, from: encoded)

        guard case .permission(let requestId, let decision, let reason) = decoded else {
            XCTFail("Expected permission case")
            return
        }

        XCTAssertEqual(requestId, "req-123")
        XCTAssertEqual(decision, "allow")
        XCTAssertEqual(reason, "Approved")
    }

    func testWSClientMessagePermissionWithoutReason() throws {
        let message = WSClientMessage.permission(
            requestId: "req-456",
            decision: "deny",
            reason: nil
        )

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSClientMessage.self, from: encoded)

        guard case .permission(let requestId, let decision, let reason) = decoded else {
            XCTFail("Expected permission case")
            return
        }

        XCTAssertEqual(requestId, "req-456")
        XCTAssertEqual(decision, "deny")
        XCTAssertNil(reason)
    }

    func testWSClientMessageCancel() throws {
        let message = WSClientMessage.cancel

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSClientMessage.self, from: encoded)

        guard case .cancel = decoded else {
            XCTFail("Expected cancel case")
            return
        }
    }

    func testWSClientMessageInvalidTypeThrowsError() throws {
        let json = """
        {
            "type": "invalid_type"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(WSClientMessage.self, from: json)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted error")
                return
            }
        }
    }

    // MARK: - WebSocket Server Message Tests

    func testWSServerMessageStream() throws {
        let textBlock = TextBlock(text: "Hello")
        let assistantMessage = AssistantMessage(content: [ContentBlock.text(textBlock)])
        let streamMessage = StreamMessage.assistant(assistantMessage)
        let message = WSServerMessage.stream(streamMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSServerMessage.self, from: encoded)

        guard case .stream(let decodedStream) = decoded else {
            XCTFail("Expected stream case")
            return
        }

        guard case .assistant(let decodedAssistant) = decodedStream else {
            XCTFail("Expected assistant message")
            return
        }

        XCTAssertEqual(decodedAssistant.content.count, 1)
    }

    func testWSServerMessagePermission() throws {
        let toolInput = AnyCodable(["command": "ls"])
        let permissionRequest = PermissionRequest(
            requestId: "req-789",
            toolName: "bash",
            toolInput: toolInput
        )
        let message = WSServerMessage.permission(permissionRequest)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSServerMessage.self, from: encoded)

        guard case .permission(let decodedRequest) = decoded else {
            XCTFail("Expected permission case")
            return
        }

        XCTAssertEqual(decodedRequest.requestId, "req-789")
        XCTAssertEqual(decodedRequest.toolName, "bash")
    }

    func testWSServerMessageError() throws {
        let streamError = StreamError(code: "TIMEOUT", message: "Request timed out")
        let message = WSServerMessage.error(streamError)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSServerMessage.self, from: encoded)

        guard case .error(let decodedError) = decoded else {
            XCTFail("Expected error case")
            return
        }

        XCTAssertEqual(decodedError.code, "TIMEOUT")
        XCTAssertEqual(decodedError.message, "Request timed out")
    }

    func testWSServerMessageComplete() throws {
        let resultMessage = ResultMessage(sessionId: "session-abc")
        let message = WSServerMessage.complete(resultMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(WSServerMessage.self, from: encoded)

        guard case .complete(let decodedResult) = decoded else {
            XCTFail("Expected complete case")
            return
        }

        XCTAssertEqual(decodedResult.sessionId, "session-abc")
    }

    // MARK: - Skill Request Tests

    func testCreateSkillRequestWithDescription() throws {
        let request = CreateSkillRequest(
            name: "test-skill",
            description: "A test skill",
            content: "skill content here"
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateSkillRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "test-skill")
        XCTAssertEqual(decoded.description, "A test skill")
        XCTAssertEqual(decoded.content, "skill content here")
    }

    func testCreateSkillRequestWithoutDescription() throws {
        let request = CreateSkillRequest(name: "simple-skill", content: "content")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateSkillRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "simple-skill")
        XCTAssertNil(decoded.description)
        XCTAssertEqual(decoded.content, "content")
    }

    func testUpdateSkillRequest() throws {
        let request = UpdateSkillRequest(content: "updated content")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(UpdateSkillRequest.self, from: encoded)

        XCTAssertEqual(decoded.content, "updated content")
    }

    // MARK: - MCP Request Tests

    func testCreateMCPRequestWithAllFields() throws {
        let request = CreateMCPRequest(
            name: "test-mcp",
            command: "node",
            args: ["index.js", "--port", "3000"],
            env: ["NODE_ENV": "production"],
            scope: .project
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateMCPRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "test-mcp")
        XCTAssertEqual(decoded.command, "node")
        XCTAssertEqual(decoded.args, ["index.js", "--port", "3000"])
        XCTAssertEqual(decoded.env, ["NODE_ENV": "production"])
        XCTAssertEqual(decoded.scope, .project)
    }

    func testCreateMCPRequestMinimal() throws {
        let request = CreateMCPRequest(name: "simple-mcp", command: "python")

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(CreateMCPRequest.self, from: encoded)

        XCTAssertEqual(decoded.name, "simple-mcp")
        XCTAssertEqual(decoded.command, "python")
        XCTAssertNil(decoded.args)
        XCTAssertNil(decoded.env)
        XCTAssertNil(decoded.scope)
    }

    // MARK: - Plugin Request Tests

    func testInstallPluginRequest() throws {
        let request = InstallPluginRequest(
            pluginName: "test-plugin",
            marketplace: "npm"
        )

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(InstallPluginRequest.self, from: encoded)

        XCTAssertEqual(decoded.pluginName, "test-plugin")
        XCTAssertEqual(decoded.marketplace, "npm")
    }

    // MARK: - Config Request Tests

    func testUpdateConfigRequest() throws {
        let config = ClaudeConfig(model: "sonnet")
        let request = UpdateConfigRequest(scope: "project", content: config)

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(UpdateConfigRequest.self, from: encoded)

        XCTAssertEqual(decoded.scope, "project")
        XCTAssertEqual(decoded.content.model, "sonnet")
    }

    func testValidateConfigRequest() throws {
        let config = ClaudeConfig(
            model: "opus",
            alwaysThinkingEnabled: true
        )
        let request = ValidateConfigRequest(content: config)

        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(ValidateConfigRequest.self, from: encoded)

        XCTAssertEqual(decoded.content.model, "opus")
        XCTAssertEqual(decoded.content.alwaysThinkingEnabled, true)
    }

    func testConfigValidationResultValid() throws {
        let result = ConfigValidationResult(isValid: true, errors: [])

        let encoded = try encoder.encode(result)
        let decoded = try decoder.decode(ConfigValidationResult.self, from: encoded)

        XCTAssertTrue(decoded.isValid)
        XCTAssertEqual(decoded.errors.count, 0)
    }

    func testConfigValidationResultInvalid() throws {
        let result = ConfigValidationResult(
            isValid: false,
            errors: ["Invalid model name", "Missing required field"]
        )

        let encoded = try encoder.encode(result)
        let decoded = try decoder.decode(ConfigValidationResult.self, from: encoded)

        XCTAssertFalse(decoded.isValid)
        XCTAssertEqual(decoded.errors.count, 2)
        XCTAssertEqual(decoded.errors[0], "Invalid model name")
        XCTAssertEqual(decoded.errors[1], "Missing required field")
    }

    // MARK: - Stats Response Tests

    func testStatsResponseFull() throws {
        let projects = CountStat(total: 10, active: 5)
        let sessions = SessionStat(total: 20, active: 3)
        let skills = CountStat(total: 15)
        let mcpServers = MCPStat(total: 8, healthy: 6)
        let plugins = PluginStat(total: 12, enabled: 10)

        let stats = StatsResponse(
            projects: projects,
            sessions: sessions,
            skills: skills,
            mcpServers: mcpServers,
            plugins: plugins
        )

        let encoded = try encoder.encode(stats)
        let decoded = try decoder.decode(StatsResponse.self, from: encoded)

        XCTAssertEqual(decoded.projects.total, 10)
        XCTAssertEqual(decoded.projects.active, 5)
        XCTAssertEqual(decoded.sessions.total, 20)
        XCTAssertEqual(decoded.sessions.active, 3)
        XCTAssertEqual(decoded.skills.total, 15)
        XCTAssertNil(decoded.skills.active)
        XCTAssertEqual(decoded.mcpServers.total, 8)
        XCTAssertEqual(decoded.mcpServers.healthy, 6)
        XCTAssertEqual(decoded.plugins.total, 12)
        XCTAssertEqual(decoded.plugins.enabled, 10)
    }

    func testCountStatWithActive() throws {
        let stat = CountStat(total: 100, active: 25)

        let encoded = try encoder.encode(stat)
        let decoded = try decoder.decode(CountStat.self, from: encoded)

        XCTAssertEqual(decoded.total, 100)
        XCTAssertEqual(decoded.active, 25)
    }

    func testCountStatWithoutActive() throws {
        let stat = CountStat(total: 50)

        let encoded = try encoder.encode(stat)
        let decoded = try decoder.decode(CountStat.self, from: encoded)

        XCTAssertEqual(decoded.total, 50)
        XCTAssertNil(decoded.active)
    }

    func testSessionStat() throws {
        let stat = SessionStat(total: 42, active: 7)

        let encoded = try encoder.encode(stat)
        let decoded = try decoder.decode(SessionStat.self, from: encoded)

        XCTAssertEqual(decoded.total, 42)
        XCTAssertEqual(decoded.active, 7)
    }

    func testMCPStat() throws {
        let stat = MCPStat(total: 15, healthy: 12)

        let encoded = try encoder.encode(stat)
        let decoded = try decoder.decode(MCPStat.self, from: encoded)

        XCTAssertEqual(decoded.total, 15)
        XCTAssertEqual(decoded.healthy, 12)
    }

    func testPluginStat() throws {
        let stat = PluginStat(total: 20, enabled: 18)

        let encoded = try encoder.encode(stat)
        let decoded = try decoder.decode(PluginStat.self, from: encoded)

        XCTAssertEqual(decoded.total, 20)
        XCTAssertEqual(decoded.enabled, 18)
    }

    // MARK: - Simple Response Tests

    func testDeletedResponseTrue() throws {
        let response = DeletedResponse(deleted: true)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(DeletedResponse.self, from: encoded)

        XCTAssertTrue(decoded.deleted)
    }

    func testDeletedResponseDefault() throws {
        let response = DeletedResponse()

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(DeletedResponse.self, from: encoded)

        XCTAssertTrue(decoded.deleted)
    }

    func testAcknowledgedResponse() throws {
        let response = AcknowledgedResponse(acknowledged: true)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(AcknowledgedResponse.self, from: encoded)

        XCTAssertTrue(decoded.acknowledged)
    }

    func testAcknowledgedResponseDefault() throws {
        let response = AcknowledgedResponse()

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(AcknowledgedResponse.self, from: encoded)

        XCTAssertTrue(decoded.acknowledged)
    }

    func testCancelledResponse() throws {
        let response = CancelledResponse(cancelled: true)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(CancelledResponse.self, from: encoded)

        XCTAssertTrue(decoded.cancelled)
    }

    func testCancelledResponseDefault() throws {
        let response = CancelledResponse()

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(CancelledResponse.self, from: encoded)

        XCTAssertTrue(decoded.cancelled)
    }

    func testEnabledResponseTrue() throws {
        let response = EnabledResponse(enabled: true)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(EnabledResponse.self, from: encoded)

        XCTAssertTrue(decoded.enabled)
    }

    func testEnabledResponseFalse() throws {
        let response = EnabledResponse(enabled: false)

        let encoded = try encoder.encode(response)
        let decoded = try decoder.decode(EnabledResponse.self, from: encoded)

        XCTAssertFalse(decoded.enabled)
    }
}
