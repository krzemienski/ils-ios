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

@Suite("APIError Codable")
struct APIErrorCodableTests {

    @Test("Decodes all canonical fields including optional reason")
    func decodesAllFields() throws {
        let json = """
        {"code":"validation_error","message":"Field is required","reason":"name cannot be empty"}
        """
        let decoded = try JSONDecoder().decode(APIError.self, from: Data(json.utf8))
        #expect(decoded.code == "validation_error")
        #expect(decoded.message == "Field is required")
        #expect(decoded.reason == "name cannot be empty")
    }

    @Test("Decodes without optional reason field")
    func decodesWithoutReason() throws {
        let json = """
        {"code":"not_found","message":"Resource not found"}
        """
        let decoded = try JSONDecoder().decode(APIError.self, from: Data(json.utf8))
        #expect(decoded.code == "not_found")
        #expect(decoded.message == "Resource not found")
        #expect(decoded.reason == nil)
    }

    @Test("Round-trips with all fields")
    func roundTripAllFields() throws {
        let original = APIError(code: "server_error", message: "Internal error", reason: "database unavailable")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIError.self, from: data)
        #expect(decoded.code == original.code)
        #expect(decoded.message == original.message)
        #expect(decoded.reason == original.reason)
    }

    @Test("Round-trips with nil reason")
    func roundTripNilReason() throws {
        let original = APIError(code: "unauthorized", message: "Not authorized")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIError.self, from: data)
        #expect(decoded.code == original.code)
        #expect(decoded.message == original.message)
        #expect(decoded.reason == nil)
    }
}

@Suite("APIResponse Codable")
struct APIResponseCodableTests {

    @Test("Decodes success response with data")
    func decodesSuccessResponse() throws {
        let json = """
        {"success":true,"data":"hello","error":null}
        """
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: Data(json.utf8))
        #expect(decoded.success == true)
        #expect(decoded.data == "hello")
        #expect(decoded.error == nil)
    }

    @Test("Decodes error response with APIError and no data")
    func decodesErrorResponse() throws {
        let json = """
        {"success":false,"data":null,"error":{"code":"not_found","message":"Resource not found"}}
        """
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: Data(json.utf8))
        #expect(decoded.success == false)
        #expect(decoded.data == nil)
        #expect(decoded.error?.code == "not_found")
        #expect(decoded.error?.message == "Resource not found")
    }

    @Test("Decodes success response with missing optional fields")
    func decodesSuccessResponseMinimal() throws {
        let json = """
        {"success":true}
        """
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: Data(json.utf8))
        #expect(decoded.success == true)
        #expect(decoded.data == nil)
        #expect(decoded.error == nil)
    }

    @Test("Round-trips success response")
    func roundTripSuccessResponse() throws {
        let original = APIResponse<Int>(success: true, data: 42, error: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIResponse<Int>.self, from: data)
        #expect(decoded.success == original.success)
        #expect(decoded.data == original.data)
        #expect(decoded.error == nil)
    }

    @Test("Round-trips error response")
    func roundTripErrorResponse() throws {
        let apiError = APIError(code: "validation_error", message: "Invalid input", reason: "field required")
        let original = APIResponse<String>(success: false, data: nil, error: apiError)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(APIResponse<String>.self, from: data)
        #expect(decoded.success == false)
        #expect(decoded.data == nil)
        #expect(decoded.error?.code == "validation_error")
        #expect(decoded.error?.message == "Invalid input")
        #expect(decoded.error?.reason == "field required")
    }
}

@Suite("PaginatedResponse Codable")
struct PaginatedResponseCodableTests {

    @Test("Decodes all canonical fields")
    func decodesAllFields() throws {
        let json = """
        {"items":["a","b","c"],"total":100,"hasMore":true,"page":2,"limit":3}
        """
        let decoded = try JSONDecoder().decode(PaginatedResponse<String>.self, from: Data(json.utf8))
        #expect(decoded.items == ["a", "b", "c"])
        #expect(decoded.total == 100)
        #expect(decoded.hasMore == true)
        #expect(decoded.page == 2)
        #expect(decoded.limit == 3)
    }

    @Test("Decodes empty items list")
    func decodesEmptyItems() throws {
        let json = """
        {"items":[],"total":0,"hasMore":false,"page":1,"limit":50}
        """
        let decoded = try JSONDecoder().decode(PaginatedResponse<String>.self, from: Data(json.utf8))
        #expect(decoded.items.isEmpty)
        #expect(decoded.total == 0)
        #expect(decoded.hasMore == false)
        #expect(decoded.page == 1)
        #expect(decoded.limit == 50)
    }

    @Test("Round-trips with String items")
    func roundTripStringItems() throws {
        let original = PaginatedResponse(items: ["x", "y"], total: 10, hasMore: true, page: 1, limit: 2)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaginatedResponse<String>.self, from: data)
        #expect(decoded.items == original.items)
        #expect(decoded.total == original.total)
        #expect(decoded.hasMore == original.hasMore)
        #expect(decoded.page == original.page)
        #expect(decoded.limit == original.limit)
    }

    @Test("Round-trips with Int items")
    func roundTripIntItems() throws {
        let original = PaginatedResponse(items: [1, 2, 3], total: 3, hasMore: false, page: 1, limit: 50)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: data)
        #expect(decoded.items == original.items)
        #expect(decoded.total == original.total)
        #expect(decoded.hasMore == original.hasMore)
    }

    @Test("Default page and limit values are correct")
    func defaultValues() {
        let response = PaginatedResponse(items: [String](), total: 0, hasMore: false)
        #expect(response.page == 1)
        #expect(response.limit == 50)
    }
}
