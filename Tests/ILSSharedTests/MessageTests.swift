import Testing
import Foundation
@testable import ILSShared

@Suite("Message")
struct MessageTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let id = UUID()
        let sessionId = UUID()
        let now = Date(timeIntervalSince1970: 1700000000)
        let message = TestFactory.makeMessage(
            id: id,
            sessionId: sessionId,
            role: .assistant,
            content: "Hello, I'm Claude",
            toolCalls: "{\"name\":\"read_file\"}",
            toolResults: "{\"output\":\"contents\"}",
            createdAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Message.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.role == .assistant)
        #expect(decoded.content == "Hello, I'm Claude")
        #expect(decoded.toolCalls == "{\"name\":\"read_file\"}")
        #expect(decoded.toolResults == "{\"output\":\"contents\"}")
    }

    @Test("Message with nil toolCalls round-trips correctly")
    func nilToolCallsRoundTrip() throws {
        let message = TestFactory.makeMessage(
            role: .user,
            content: "Simple message"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Message.self, from: data)

        #expect(decoded.toolCalls == nil)
        #expect(decoded.toolResults == nil)
        #expect(decoded.content == "Simple message")
    }

    @Test("Default factory values")
    func defaultFactoryValues() {
        let message = TestFactory.makeMessage()
        #expect(message.role == .user)
        #expect(message.content == "Hello, Claude")
        #expect(message.toolCalls == nil)
        #expect(message.toolResults == nil)
    }
}

@Suite("MessageRole")
struct MessageRoleTests {

    @Test("Decodes known values", arguments: [
        ("\"user\"", MessageRole.user),
        ("\"assistant\"", MessageRole.assistant),
        ("\"system\"", MessageRole.system),
    ])
    func decodesKnownValues(json: String, expected: MessageRole) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(MessageRole.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Throws for unrecognized value")
    func throwsForUnrecognizedValue() throws {
        let data = Data("\"unknown_role\"".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MessageRole.self, from: data)
        }
    }
}
