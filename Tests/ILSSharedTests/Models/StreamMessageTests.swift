import XCTest
@testable import ILSShared

final class StreamMessageTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // MARK: - SystemMessage Tests

    func testSystemMessageEncodeDecode() throws {
        let systemData = SystemData(
            sessionId: "test-session-123",
            plugins: ["plugin1", "plugin2"],
            slashCommands: ["/help", "/commit"],
            tools: ["tool1", "tool2"]
        )
        let systemMessage = SystemMessage(type: "system", subtype: "init", data: systemData)
        let message = StreamMessage.system(systemMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .system(let decodedMessage) = decoded else {
            XCTFail("Expected system message")
            return
        }

        XCTAssertEqual(decodedMessage.type, "system")
        XCTAssertEqual(decodedMessage.subtype, "init")
        XCTAssertEqual(decodedMessage.data.sessionId, "test-session-123")
        XCTAssertEqual(decodedMessage.data.plugins, ["plugin1", "plugin2"])
        XCTAssertEqual(decodedMessage.data.slashCommands, ["/help", "/commit"])
        XCTAssertEqual(decodedMessage.data.tools, ["tool1", "tool2"])
    }

    func testSystemMessageWithMinimalData() throws {
        let systemData = SystemData(sessionId: "minimal-session")
        let systemMessage = SystemMessage(data: systemData)
        let message = StreamMessage.system(systemMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .system(let decodedMessage) = decoded else {
            XCTFail("Expected system message")
            return
        }

        XCTAssertEqual(decodedMessage.data.sessionId, "minimal-session")
        XCTAssertNil(decodedMessage.data.plugins)
        XCTAssertNil(decodedMessage.data.slashCommands)
        XCTAssertNil(decodedMessage.data.tools)
    }

    // MARK: - AssistantMessage Tests

    func testAssistantMessageWithTextBlock() throws {
        let textBlock = TextBlock(text: "Hello, world!")
        let content = [ContentBlock.text(textBlock)]
        let assistantMessage = AssistantMessage(content: content)
        let message = StreamMessage.assistant(assistantMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .assistant(let decodedMessage) = decoded else {
            XCTFail("Expected assistant message")
            return
        }

        XCTAssertEqual(decodedMessage.type, "assistant")
        XCTAssertEqual(decodedMessage.content.count, 1)

        guard case .text(let decodedBlock) = decodedMessage.content[0] else {
            XCTFail("Expected text block")
            return
        }

        XCTAssertEqual(decodedBlock.text, "Hello, world!")
    }

    func testAssistantMessageWithMultipleContentBlocks() throws {
        let textBlock = TextBlock(text: "Processing...")
        let thinkingBlock = ThinkingBlock(thinking: "Let me think about this...")
        let content = [
            ContentBlock.text(textBlock),
            ContentBlock.thinking(thinkingBlock)
        ]
        let assistantMessage = AssistantMessage(content: content)
        let message = StreamMessage.assistant(assistantMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .assistant(let decodedMessage) = decoded else {
            XCTFail("Expected assistant message")
            return
        }

        XCTAssertEqual(decodedMessage.content.count, 2)

        guard case .text(let decodedText) = decodedMessage.content[0] else {
            XCTFail("Expected text block at index 0")
            return
        }
        XCTAssertEqual(decodedText.text, "Processing...")

        guard case .thinking(let decodedThinking) = decodedMessage.content[1] else {
            XCTFail("Expected thinking block at index 1")
            return
        }
        XCTAssertEqual(decodedThinking.thinking, "Let me think about this...")
    }

    // MARK: - ContentBlock Tests

    func testTextBlockEncodeDecode() throws {
        let textBlock = TextBlock(type: "text", text: "Test content")
        let content = [ContentBlock.text(textBlock)]
        let assistantMessage = AssistantMessage(content: content)

        let encoded = try encoder.encode(assistantMessage)
        let decoded = try decoder.decode(AssistantMessage.self, from: encoded)

        guard case .text(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected text block")
            return
        }

        XCTAssertEqual(decodedBlock.type, "text")
        XCTAssertEqual(decodedBlock.text, "Test content")
    }

    func testToolUseBlockEncodeDecode() throws {
        let input = AnyCodable(["command": "ls -la", "path": "/tmp"])
        let toolUseBlock = ToolUseBlock(
            type: "toolUse",
            id: "tool-123",
            name: "bash",
            input: input
        )
        let content = [ContentBlock.toolUse(toolUseBlock)]
        let assistantMessage = AssistantMessage(content: content)

        let encoded = try encoder.encode(assistantMessage)
        let decoded = try decoder.decode(AssistantMessage.self, from: encoded)

        guard case .toolUse(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected tool use block")
            return
        }

        XCTAssertEqual(decodedBlock.type, "toolUse")
        XCTAssertEqual(decodedBlock.id, "tool-123")
        XCTAssertEqual(decodedBlock.name, "bash")

        guard let inputDict = decodedBlock.input.value as? [String: Any] else {
            XCTFail("Expected dictionary input")
            return
        }
        XCTAssertEqual(inputDict["command"] as? String, "ls -la")
        XCTAssertEqual(inputDict["path"] as? String, "/tmp")
    }

    func testToolUseBlockWithCamelCaseType() throws {
        let json = """
        {
            "type": "assistant",
            "content": [{
                "type": "tool_use",
                "id": "tool-456",
                "name": "read",
                "input": {"file": "test.txt"}
            }]
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(AssistantMessage.self, from: json)

        guard case .toolUse(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected tool use block")
            return
        }

        XCTAssertEqual(decodedBlock.id, "tool-456")
        XCTAssertEqual(decodedBlock.name, "read")
    }

    func testToolResultBlockEncodeDecode() throws {
        let toolResultBlock = ToolResultBlock(
            type: "toolResult",
            toolUseId: "tool-123",
            content: "Command output here",
            isError: false
        )
        let content = [ContentBlock.toolResult(toolResultBlock)]
        let assistantMessage = AssistantMessage(content: content)

        let encoded = try encoder.encode(assistantMessage)
        let decoded = try decoder.decode(AssistantMessage.self, from: encoded)

        guard case .toolResult(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected tool result block")
            return
        }

        XCTAssertEqual(decodedBlock.type, "toolResult")
        XCTAssertEqual(decodedBlock.toolUseId, "tool-123")
        XCTAssertEqual(decodedBlock.content, "Command output here")
        XCTAssertFalse(decodedBlock.isError)
    }

    func testToolResultBlockWithError() throws {
        let toolResultBlock = ToolResultBlock(
            toolUseId: "tool-789",
            content: "Error: Command failed",
            isError: true
        )
        let content = [ContentBlock.toolResult(toolResultBlock)]
        let assistantMessage = AssistantMessage(content: content)

        let encoded = try encoder.encode(assistantMessage)
        let decoded = try decoder.decode(AssistantMessage.self, from: encoded)

        guard case .toolResult(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected tool result block")
            return
        }

        XCTAssertTrue(decodedBlock.isError)
        XCTAssertEqual(decodedBlock.content, "Error: Command failed")
    }

    func testThinkingBlockEncodeDecode() throws {
        let thinkingBlock = ThinkingBlock(
            type: "thinking",
            thinking: "I need to analyze this carefully..."
        )
        let content = [ContentBlock.thinking(thinkingBlock)]
        let assistantMessage = AssistantMessage(content: content)

        let encoded = try encoder.encode(assistantMessage)
        let decoded = try decoder.decode(AssistantMessage.self, from: encoded)

        guard case .thinking(let decodedBlock) = decoded.content[0] else {
            XCTFail("Expected thinking block")
            return
        }

        XCTAssertEqual(decodedBlock.type, "thinking")
        XCTAssertEqual(decodedBlock.thinking, "I need to analyze this carefully...")
    }

    func testContentBlockUnknownTypeDefaultsToText() throws {
        let json = """
        {
            "type": "assistant",
            "content": [{
                "type": "unknown_type",
                "text": "Some content"
            }]
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(AssistantMessage.self, from: json)

        // Unknown type should default to text block with empty text
        guard case .text(let textBlock) = decoded.content[0] else {
            XCTFail("Expected text block for unknown type")
            return
        }

        XCTAssertEqual(textBlock.text, "")
    }

    // MARK: - ResultMessage Tests

    func testResultMessageWithFullData() throws {
        let usage = UsageInfo(
            inputTokens: 1000,
            outputTokens: 500,
            cacheReadInputTokens: 200,
            cacheCreationInputTokens: 100
        )
        let resultMessage = ResultMessage(
            type: "result",
            subtype: "success",
            sessionId: "session-456",
            durationMs: 5000,
            durationApiMs: 4500,
            isError: false,
            numTurns: 3,
            totalCostUSD: 0.025,
            usage: usage
        )
        let message = StreamMessage.result(resultMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .result(let decodedMessage) = decoded else {
            XCTFail("Expected result message")
            return
        }

        XCTAssertEqual(decodedMessage.type, "result")
        XCTAssertEqual(decodedMessage.subtype, "success")
        XCTAssertEqual(decodedMessage.sessionId, "session-456")
        XCTAssertEqual(decodedMessage.durationMs, 5000)
        XCTAssertEqual(decodedMessage.durationApiMs, 4500)
        XCTAssertFalse(decodedMessage.isError)
        XCTAssertEqual(decodedMessage.numTurns, 3)
        XCTAssertEqual(decodedMessage.totalCostUSD, 0.025)

        XCTAssertNotNil(decodedMessage.usage)
        XCTAssertEqual(decodedMessage.usage?.inputTokens, 1000)
        XCTAssertEqual(decodedMessage.usage?.outputTokens, 500)
        XCTAssertEqual(decodedMessage.usage?.cacheReadInputTokens, 200)
        XCTAssertEqual(decodedMessage.usage?.cacheCreationInputTokens, 100)
    }

    func testResultMessageWithMinimalData() throws {
        let resultMessage = ResultMessage(sessionId: "session-789")
        let message = StreamMessage.result(resultMessage)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .result(let decodedMessage) = decoded else {
            XCTFail("Expected result message")
            return
        }

        XCTAssertEqual(decodedMessage.sessionId, "session-789")
        XCTAssertNil(decodedMessage.durationMs)
        XCTAssertNil(decodedMessage.durationApiMs)
        XCTAssertFalse(decodedMessage.isError)
        XCTAssertNil(decodedMessage.numTurns)
        XCTAssertNil(decodedMessage.totalCostUSD)
        XCTAssertNil(decodedMessage.usage)
    }

    func testUsageInfoEncodeDecode() throws {
        let usage = UsageInfo(
            inputTokens: 2000,
            outputTokens: 1000
        )

        let encoded = try encoder.encode(usage)
        let decoded = try decoder.decode(UsageInfo.self, from: encoded)

        XCTAssertEqual(decoded.inputTokens, 2000)
        XCTAssertEqual(decoded.outputTokens, 1000)
        XCTAssertNil(decoded.cacheReadInputTokens)
        XCTAssertNil(decoded.cacheCreationInputTokens)
    }

    // MARK: - PermissionRequest Tests

    func testPermissionRequestEncodeDecode() throws {
        let toolInput = AnyCodable([
            "command": "git commit -m 'test'",
            "dangerous": true
        ])
        let permissionRequest = PermissionRequest(
            type: "permission",
            requestId: "req-123",
            toolName: "bash",
            toolInput: toolInput
        )
        let message = StreamMessage.permission(permissionRequest)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .permission(let decodedMessage) = decoded else {
            XCTFail("Expected permission message")
            return
        }

        XCTAssertEqual(decodedMessage.type, "permission")
        XCTAssertEqual(decodedMessage.requestId, "req-123")
        XCTAssertEqual(decodedMessage.toolName, "bash")

        guard let inputDict = decodedMessage.toolInput.value as? [String: Any] else {
            XCTFail("Expected dictionary input")
            return
        }
        XCTAssertEqual(inputDict["command"] as? String, "git commit -m 'test'")
        XCTAssertEqual(inputDict["dangerous"] as? Bool, true)
    }

    // MARK: - StreamError Tests

    func testStreamErrorEncodeDecode() throws {
        let streamError = StreamError(
            type: "error",
            code: "TIMEOUT",
            message: "Request timed out after 30 seconds"
        )
        let message = StreamMessage.error(streamError)

        let encoded = try encoder.encode(message)
        let decoded = try decoder.decode(StreamMessage.self, from: encoded)

        guard case .error(let decodedMessage) = decoded else {
            XCTFail("Expected error message")
            return
        }

        XCTAssertEqual(decodedMessage.type, "error")
        XCTAssertEqual(decodedMessage.code, "TIMEOUT")
        XCTAssertEqual(decodedMessage.message, "Request timed out after 30 seconds")
    }

    // MARK: - AnyCodable Tests

    func testAnyCodableWithString() throws {
        let anyCodable = AnyCodable("test string")

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        XCTAssertEqual(decoded.value as? String, "test string")
    }

    func testAnyCodableWithInt() throws {
        let anyCodable = AnyCodable(42)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        XCTAssertEqual(decoded.value as? Int, 42)
    }

    func testAnyCodableWithDouble() throws {
        let anyCodable = AnyCodable(3.14159)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        XCTAssertEqual(decoded.value as? Double, 3.14159)
    }

    func testAnyCodableWithBool() throws {
        let anyCodable = AnyCodable(true)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        XCTAssertEqual(decoded.value as? Bool, true)
    }

    func testAnyCodableWithArray() throws {
        let anyCodable = AnyCodable(["item1", "item2", "item3"])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let array = decoded.value as? [String] else {
            XCTFail("Expected array of strings")
            return
        }

        XCTAssertEqual(array, ["item1", "item2", "item3"])
    }

    func testAnyCodableWithDictionary() throws {
        let anyCodable = AnyCodable([
            "key1": "value1",
            "key2": 123,
            "key3": true
        ] as [String: Any])

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let dict = decoded.value as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }

        XCTAssertEqual(dict["key1"] as? String, "value1")
        XCTAssertEqual(dict["key2"] as? Int, 123)
        XCTAssertEqual(dict["key3"] as? Bool, true)
    }

    func testAnyCodableWithNestedStructure() throws {
        let nestedData: [String: Any] = [
            "user": [
                "name": "John Doe",
                "age": 30,
                "active": true
            ],
            "items": ["item1", "item2"]
        ]
        let anyCodable = AnyCodable(nestedData)

        let encoded = try encoder.encode(anyCodable)
        let decoded = try decoder.decode(AnyCodable.self, from: encoded)

        guard let dict = decoded.value as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }

        guard let user = dict["user"] as? [String: Any] else {
            XCTFail("Expected user dictionary")
            return
        }

        XCTAssertEqual(user["name"] as? String, "John Doe")
        XCTAssertEqual(user["age"] as? Int, 30)
        XCTAssertEqual(user["active"] as? Bool, true)

        guard let items = dict["items"] as? [String] else {
            XCTFail("Expected items array")
            return
        }

        XCTAssertEqual(items, ["item1", "item2"])
    }

    func testAnyCodableWithNull() throws {
        let json = "null".data(using: .utf8)!
        let decoded = try decoder.decode(AnyCodable.self, from: json)

        XCTAssertTrue(decoded.value is NSNull)
    }

    // MARK: - Error Cases

    func testStreamMessageWithUnknownType() throws {
        let json = """
        {
            "type": "unknown_message_type"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(StreamMessage.self, from: json)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Expected dataCorrupted error")
                return
            }

            XCTAssertTrue(context.debugDescription.contains("Unknown message type"))
        }
    }

    func testStreamMessageSystemType() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "data": {
                "sessionId": "test-123"
            }
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(StreamMessage.self, from: json)

        guard case .system(let message) = decoded else {
            XCTFail("Expected system message")
            return
        }

        XCTAssertEqual(message.data.sessionId, "test-123")
    }

    func testStreamMessageAssistantType() throws {
        let json = """
        {
            "type": "assistant",
            "content": [
                {
                    "type": "text",
                    "text": "Hello"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(StreamMessage.self, from: json)

        guard case .assistant(let message) = decoded else {
            XCTFail("Expected assistant message")
            return
        }

        XCTAssertEqual(message.content.count, 1)
    }

    func testStreamMessageResultType() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "sessionId": "test-456",
            "isError": false
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(StreamMessage.self, from: json)

        guard case .result(let message) = decoded else {
            XCTFail("Expected result message")
            return
        }

        XCTAssertEqual(message.sessionId, "test-456")
        XCTAssertFalse(message.isError)
    }

    func testStreamMessagePermissionType() throws {
        let json = """
        {
            "type": "permission",
            "requestId": "req-789",
            "toolName": "bash",
            "toolInput": {"command": "ls"}
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(StreamMessage.self, from: json)

        guard case .permission(let message) = decoded else {
            XCTFail("Expected permission message")
            return
        }

        XCTAssertEqual(message.requestId, "req-789")
        XCTAssertEqual(message.toolName, "bash")
    }

    func testStreamMessageErrorType() throws {
        let json = """
        {
            "type": "error",
            "code": "INVALID_REQUEST",
            "message": "The request was invalid"
        }
        """.data(using: .utf8)!

        let decoded = try decoder.decode(StreamMessage.self, from: json)

        guard case .error(let message) = decoded else {
            XCTFail("Expected error message")
            return
        }

        XCTAssertEqual(message.code, "INVALID_REQUEST")
        XCTAssertEqual(message.message, "The request was invalid")
    }
}
