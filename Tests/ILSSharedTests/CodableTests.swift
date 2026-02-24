import Testing
import Foundation
@testable import ILSShared

@Suite("SessionStatus Codable")
struct SessionStatusCodableTests {

    @Test("Decodes all known values", arguments: [
        ("\"active\"", SessionStatus.active),
        ("\"completed\"", SessionStatus.completed),
        ("\"cancelled\"", SessionStatus.cancelled),
        ("\"error\"", SessionStatus.error),
    ])
    func decodesKnownValues(json: String, expected: SessionStatus) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SessionStatus.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Throws for unrecognized value")
    func throwsForUnrecognizedValue() throws {
        let data = Data("\"pending\"".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SessionStatus.self, from: data)
        }
    }
}

@Suite("PermissionMode Codable")
struct PermissionModeCodableTests {

    @Test("Decodes all 6 known values", arguments: [
        ("\"default\"", PermissionMode.default),
        ("\"acceptEdits\"", PermissionMode.acceptEdits),
        ("\"plan\"", PermissionMode.plan),
        ("\"bypassPermissions\"", PermissionMode.bypassPermissions),
        ("\"delegate\"", PermissionMode.delegate),
        ("\"dontAsk\"", PermissionMode.dontAsk),
    ])
    func decodesKnownValues(json: String, expected: PermissionMode) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(PermissionMode.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Throws for unrecognized value")
    func throwsForUnrecognizedValue() throws {
        let data = Data("\"superAdmin\"".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PermissionMode.self, from: data)
        }
    }
}

@Suite("ClaudeModel Codable")
struct ClaudeModelCodableTests {

    @Test("Decodes known values", arguments: [
        ("\"haiku\"", ClaudeModel.haiku),
        ("\"sonnet\"", ClaudeModel.sonnet),
        ("\"opus\"", ClaudeModel.opus),
    ])
    func decodesKnownValues(json: String, expected: ClaudeModel) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ClaudeModel.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Decodes unknown string into .unknown case (does NOT throw)")
    func decodesUnknownString() throws {
        let data = Data("\"claude-4-future\"".utf8)
        let decoded = try JSONDecoder().decode(ClaudeModel.self, from: data)
        #expect(decoded == .unknown("claude-4-future"))
        #expect(decoded.rawValue == "claude-4-future")
    }

    @Test("Round-trips .unknown preserving original string")
    func unknownRoundTrip() throws {
        let original = ClaudeModel.unknown("claude-next-gen")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClaudeModel.self, from: data)
        #expect(decoded == original)
        #expect(decoded.rawValue == "claude-next-gen")
    }

    @Test("Known model rawValues are correct")
    func knownRawValues() {
        #expect(ClaudeModel.haiku.rawValue == "haiku")
        #expect(ClaudeModel.sonnet.rawValue == "sonnet")
        #expect(ClaudeModel.opus.rawValue == "opus")
    }

    @Test("displayName returns human-readable names")
    func displayNames() {
        #expect(ClaudeModel.haiku.displayName == "Claude Haiku")
        #expect(ClaudeModel.sonnet.displayName == "Claude Sonnet")
        #expect(ClaudeModel.opus.displayName == "Claude Opus")
        #expect(ClaudeModel.unknown("test").displayName == "test")
    }
}

@Suite("SessionSource Codable")
struct SessionSourceCodableTests {

    @Test("Decodes known values", arguments: [
        ("\"ils\"", SessionSource.ils),
        ("\"external\"", SessionSource.external),
    ])
    func decodesKnownValues(json: String, expected: SessionSource) throws {
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SessionSource.self, from: data)
        #expect(decoded == expected)
    }

    @Test("Throws for unrecognized value")
    func throwsForUnrecognizedValue() throws {
        let data = Data("\"imported\"".utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SessionSource.self, from: data)
        }
    }
}
