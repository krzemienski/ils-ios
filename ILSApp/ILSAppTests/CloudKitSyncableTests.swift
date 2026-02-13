import XCTest
@testable import ILSApp
@testable import ILSShared
import CloudKit

/// Unit tests for CloudKitSyncable protocol conformance
/// Tests model serialization to/from CKRecord for Session, Template, and Snippet
class CloudKitSyncableTests: XCTestCase {
    var testZoneID: CKRecordZone.ID!

    override func setUp() {
        testZoneID = CKRecordZone.ID(zoneName: "ILSAppZone", ownerName: CKCurrentUserDefaultName)
    }

    override func tearDown() {
        testZoneID = nil
    }

    // MARK: - Session Serialization Tests

    func testSession_ToCKRecord_AllFieldsSerialized() {
        // Create a session with all fields populated
        let sessionId = UUID()
        let projectId = UUID()
        let forkedFrom = UUID()
        let createdAt = Date()
        let lastActiveAt = Date()
        let modificationDate = Date()

        let session = ChatSession(
            id: sessionId,
            claudeSessionId: "claude-123",
            name: "Test Session",
            projectId: projectId,
            projectName: "Test Project",
            model: "sonnet",
            permissionMode: .acceptEdits,
            status: .active,
            messageCount: 42,
            totalCostUSD: 1.23,
            source: .ils,
            forkedFrom: forkedFrom,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            modificationDate: modificationDate
        )

        // Convert to CKRecord
        let record = session.toCKRecord(zoneID: testZoneID)

        // Verify record type
        XCTAssertEqual(record.recordType, "ChatSession")

        // Verify record ID
        XCTAssertEqual(record.recordID.recordName, sessionId.uuidString)
        XCTAssertEqual(record.recordID.zoneID, testZoneID)

        // Verify all fields are serialized correctly
        XCTAssertEqual(record["claudeSessionId"] as? String, "claude-123")
        XCTAssertEqual(record["name"] as? String, "Test Session")
        XCTAssertEqual(record["projectId"] as? String, projectId.uuidString)
        XCTAssertEqual(record["projectName"] as? String, "Test Project")
        XCTAssertEqual(record["model"] as? String, "sonnet")
        XCTAssertEqual(record["permissionMode"] as? String, "acceptEdits")
        XCTAssertEqual(record["status"] as? String, "active")
        XCTAssertEqual(record["messageCount"] as? Int, 42)
        XCTAssertEqual(record["totalCostUSD"] as? Double, 1.23)
        XCTAssertEqual(record["source"] as? String, "ils")
        XCTAssertEqual(record["forkedFrom"] as? String, forkedFrom.uuidString)
        XCTAssertEqual(record["createdAt"] as? Date, createdAt)
        XCTAssertEqual(record["lastActiveAt"] as? Date, lastActiveAt)
        XCTAssertEqual(record["modificationDate"] as? Date, modificationDate)
    }

    func testSession_FromCKRecord_AllFieldsDeserialized() throws {
        // Create a CKRecord with all fields
        let sessionId = UUID()
        let projectId = UUID()
        let forkedFrom = UUID()
        let createdAt = Date()
        let lastActiveAt = Date()
        let modificationDate = Date()

        let recordID = CKRecord.ID(recordName: sessionId.uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "ChatSession", recordID: recordID)

        record["claudeSessionId"] = "claude-456"
        record["name"] = "Deserialized Session"
        record["projectId"] = projectId.uuidString
        record["projectName"] = "Deserialized Project"
        record["model"] = "opus"
        record["permissionMode"] = "plan"
        record["status"] = "completed"
        record["messageCount"] = 99
        record["totalCostUSD"] = 5.67
        record["source"] = "external"
        record["forkedFrom"] = forkedFrom.uuidString
        record["createdAt"] = createdAt
        record["lastActiveAt"] = lastActiveAt
        record["modificationDate"] = modificationDate

        // Deserialize from CKRecord
        let session = try ChatSession(from: record)

        // Verify all fields are deserialized correctly
        XCTAssertEqual(session.id, sessionId)
        XCTAssertEqual(session.claudeSessionId, "claude-456")
        XCTAssertEqual(session.name, "Deserialized Session")
        XCTAssertEqual(session.projectId, projectId)
        XCTAssertEqual(session.projectName, "Deserialized Project")
        XCTAssertEqual(session.model, "opus")
        XCTAssertEqual(session.permissionMode, .plan)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.messageCount, 99)
        XCTAssertEqual(session.totalCostUSD, 5.67)
        XCTAssertEqual(session.source, .external)
        XCTAssertEqual(session.forkedFrom, forkedFrom)
        XCTAssertEqual(session.createdAt, createdAt)
        XCTAssertEqual(session.lastActiveAt, lastActiveAt)
        XCTAssertEqual(session.modificationDate, modificationDate)
    }

    func testSession_RoundTrip_PreservesData() throws {
        // Create original session
        let original = ChatSession(
            id: UUID(),
            claudeSessionId: "roundtrip-test",
            name: "Round Trip Test",
            projectId: UUID(),
            projectName: "Round Trip Project",
            model: "haiku",
            permissionMode: .bypassPermissions,
            status: .error,
            messageCount: 13,
            totalCostUSD: 2.34,
            source: .ils,
            forkedFrom: UUID(),
            createdAt: Date(),
            lastActiveAt: Date(),
            modificationDate: Date()
        )

        // Convert to CKRecord and back
        let record = original.toCKRecord(zoneID: testZoneID)
        let deserialized = try ChatSession(from: record)

        // Verify round-trip preserves all data
        XCTAssertEqual(deserialized.id, original.id)
        XCTAssertEqual(deserialized.claudeSessionId, original.claudeSessionId)
        XCTAssertEqual(deserialized.name, original.name)
        XCTAssertEqual(deserialized.projectId, original.projectId)
        XCTAssertEqual(deserialized.projectName, original.projectName)
        XCTAssertEqual(deserialized.model, original.model)
        XCTAssertEqual(deserialized.permissionMode, original.permissionMode)
        XCTAssertEqual(deserialized.status, original.status)
        XCTAssertEqual(deserialized.messageCount, original.messageCount)
        XCTAssertEqual(deserialized.totalCostUSD, original.totalCostUSD)
        XCTAssertEqual(deserialized.source, original.source)
        XCTAssertEqual(deserialized.forkedFrom, original.forkedFrom)
        XCTAssertEqual(deserialized.createdAt, original.createdAt)
        XCTAssertEqual(deserialized.lastActiveAt, original.lastActiveAt)
        XCTAssertEqual(deserialized.modificationDate, original.modificationDate)
    }

    func testSession_ModificationDate_Serialized() {
        // Create session with specific modification date
        let modDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00
        let session = ChatSession(
            id: UUID(),
            model: "sonnet",
            permissionMode: .default,
            status: .active,
            messageCount: 0,
            source: .ils,
            createdAt: Date(),
            lastActiveAt: Date(),
            modificationDate: modDate
        )

        // Convert to record
        let record = session.toCKRecord(zoneID: testZoneID)

        // Verify modification date is preserved
        XCTAssertEqual(record["modificationDate"] as? Date, modDate)
    }

    // MARK: - Template Serialization Tests

    func testTemplate_ToCKRecord_AllFieldsSerialized() {
        // Create a template with all fields
        let templateId = UUID()
        let createdAt = Date()
        let lastUsedAt = Date()
        let modificationDate = Date()

        let template = Template(
            id: templateId,
            name: "Test Template",
            content: "Template content goes here",
            description: "Test description",
            category: "Testing",
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            modificationDate: modificationDate
        )

        // Convert to CKRecord
        let record = template.toCKRecord(zoneID: testZoneID)

        // Verify record type
        XCTAssertEqual(record.recordType, "Template")

        // Verify record ID
        XCTAssertEqual(record.recordID.recordName, templateId.uuidString)

        // Verify all fields
        XCTAssertEqual(record["name"] as? String, "Test Template")
        XCTAssertEqual(record["content"] as? String, "Template content goes here")
        XCTAssertEqual(record["description"] as? String, "Test description")
        XCTAssertEqual(record["category"] as? String, "Testing")
        XCTAssertEqual(record["createdAt"] as? Date, createdAt)
        XCTAssertEqual(record["lastUsedAt"] as? Date, lastUsedAt)
        XCTAssertEqual(record["modificationDate"] as? Date, modificationDate)
    }

    func testTemplate_FromCKRecord_AllFieldsDeserialized() throws {
        // Create a CKRecord
        let templateId = UUID()
        let createdAt = Date()
        let lastUsedAt = Date()
        let modificationDate = Date()

        let recordID = CKRecord.ID(recordName: templateId.uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "Template", recordID: recordID)

        record["name"] = "Deserialized Template"
        record["content"] = "Deserialized content"
        record["description"] = "Deserialized description"
        record["category"] = "Deserialized"
        record["createdAt"] = createdAt
        record["lastUsedAt"] = lastUsedAt
        record["modificationDate"] = modificationDate

        // Deserialize
        let template = try Template(from: record)

        // Verify all fields
        XCTAssertEqual(template.id, templateId)
        XCTAssertEqual(template.name, "Deserialized Template")
        XCTAssertEqual(template.content, "Deserialized content")
        XCTAssertEqual(template.description, "Deserialized description")
        XCTAssertEqual(template.category, "Deserialized")
        XCTAssertEqual(template.createdAt, createdAt)
        XCTAssertEqual(template.lastUsedAt, lastUsedAt)
        XCTAssertEqual(template.modificationDate, modificationDate)
    }

    func testTemplate_RoundTrip_PreservesData() throws {
        // Create original template
        let original = Template(
            id: UUID(),
            name: "Round Trip Template",
            content: "Round trip content",
            description: "Round trip description",
            category: "RoundTrip",
            createdAt: Date(),
            lastUsedAt: Date(),
            modificationDate: Date()
        )

        // Round trip
        let record = original.toCKRecord(zoneID: testZoneID)
        let deserialized = try Template(from: record)

        // Verify preservation
        XCTAssertEqual(deserialized.id, original.id)
        XCTAssertEqual(deserialized.name, original.name)
        XCTAssertEqual(deserialized.content, original.content)
        XCTAssertEqual(deserialized.description, original.description)
        XCTAssertEqual(deserialized.category, original.category)
        XCTAssertEqual(deserialized.createdAt, original.createdAt)
        XCTAssertEqual(deserialized.lastUsedAt, original.lastUsedAt)
        XCTAssertEqual(deserialized.modificationDate, original.modificationDate)
    }

    // MARK: - Snippet Serialization Tests

    func testSnippet_ToCKRecord_AllFieldsSerialized() {
        // Create a snippet with all fields
        let snippetId = UUID()
        let createdAt = Date()
        let lastUsedAt = Date()
        let modificationDate = Date()

        let snippet = Snippet(
            id: snippetId,
            name: "Test Snippet",
            content: "print('Hello, World!')",
            description: "Test snippet description",
            language: "python",
            category: "Testing",
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            modificationDate: modificationDate
        )

        // Convert to CKRecord
        let record = snippet.toCKRecord(zoneID: testZoneID)

        // Verify record type
        XCTAssertEqual(record.recordType, "Snippet")

        // Verify record ID
        XCTAssertEqual(record.recordID.recordName, snippetId.uuidString)

        // Verify all fields
        XCTAssertEqual(record["name"] as? String, "Test Snippet")
        XCTAssertEqual(record["content"] as? String, "print('Hello, World!')")
        XCTAssertEqual(record["description"] as? String, "Test snippet description")
        XCTAssertEqual(record["language"] as? String, "python")
        XCTAssertEqual(record["category"] as? String, "Testing")
        XCTAssertEqual(record["createdAt"] as? Date, createdAt)
        XCTAssertEqual(record["lastUsedAt"] as? Date, lastUsedAt)
        XCTAssertEqual(record["modificationDate"] as? Date, modificationDate)
    }

    func testSnippet_FromCKRecord_AllFieldsDeserialized() throws {
        // Create a CKRecord
        let snippetId = UUID()
        let createdAt = Date()
        let lastUsedAt = Date()
        let modificationDate = Date()

        let recordID = CKRecord.ID(recordName: snippetId.uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "Snippet", recordID: recordID)

        record["name"] = "Deserialized Snippet"
        record["content"] = "console.log('Deserialized')"
        record["description"] = "Deserialized description"
        record["language"] = "javascript"
        record["category"] = "Deserialized"
        record["createdAt"] = createdAt
        record["lastUsedAt"] = lastUsedAt
        record["modificationDate"] = modificationDate

        // Deserialize
        let snippet = try Snippet(from: record)

        // Verify all fields
        XCTAssertEqual(snippet.id, snippetId)
        XCTAssertEqual(snippet.name, "Deserialized Snippet")
        XCTAssertEqual(snippet.content, "console.log('Deserialized')")
        XCTAssertEqual(snippet.description, "Deserialized description")
        XCTAssertEqual(snippet.language, "javascript")
        XCTAssertEqual(snippet.category, "Deserialized")
        XCTAssertEqual(snippet.createdAt, createdAt)
        XCTAssertEqual(snippet.lastUsedAt, lastUsedAt)
        XCTAssertEqual(snippet.modificationDate, modificationDate)
    }

    func testSnippet_RoundTrip_PreservesData() throws {
        // Create original snippet
        let original = Snippet(
            id: UUID(),
            name: "Round Trip Snippet",
            content: "func roundTrip() { return true }",
            description: "Round trip description",
            language: "swift",
            category: "RoundTrip",
            createdAt: Date(),
            lastUsedAt: Date(),
            modificationDate: Date()
        )

        // Round trip
        let record = original.toCKRecord(zoneID: testZoneID)
        let deserialized = try Snippet(from: record)

        // Verify preservation
        XCTAssertEqual(deserialized.id, original.id)
        XCTAssertEqual(deserialized.name, original.name)
        XCTAssertEqual(deserialized.content, original.content)
        XCTAssertEqual(deserialized.description, original.description)
        XCTAssertEqual(deserialized.language, original.language)
        XCTAssertEqual(deserialized.category, original.category)
        XCTAssertEqual(deserialized.createdAt, original.createdAt)
        XCTAssertEqual(deserialized.lastUsedAt, original.lastUsedAt)
        XCTAssertEqual(deserialized.modificationDate, original.modificationDate)
    }

    // MARK: - Error Cases (IMPORTANT)

    func testFromCKRecord_WrongRecordType_ThrowsError() {
        // Create a record with wrong type
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "WrongType", recordID: recordID)

        record["name"] = "Test"
        record["content"] = "Content"
        record["createdAt"] = Date()
        record["modificationDate"] = Date()

        // Attempt to deserialize as Template
        XCTAssertThrowsError(try Template(from: record)) { error in
            if case CloudKitSyncError.typeMismatch(let expected, let actual) = error {
                XCTAssertEqual(expected, "Template")
                XCTAssertEqual(actual, "WrongType")
            } else {
                XCTFail("Expected typeMismatch error, got \(error)")
            }
        }
    }

    func testFromCKRecord_MissingRequiredField_ThrowsError() {
        // Create a record missing required field (name)
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "Template", recordID: recordID)

        // Missing "name" field
        record["content"] = "Content"
        record["createdAt"] = Date()
        record["modificationDate"] = Date()

        // Attempt to deserialize
        XCTAssertThrowsError(try Template(from: record)) { error in
            if case CloudKitSyncError.missingRequiredField(let field) = error {
                XCTAssertEqual(field, "name")
            } else {
                XCTFail("Expected missingRequiredField error, got \(error)")
            }
        }
    }

    func testFromCKRecord_InvalidRecordID_ThrowsError() {
        // Create a record with invalid UUID in recordName
        let recordID = CKRecord.ID(recordName: "not-a-uuid", zoneID: testZoneID)
        let record = CKRecord(recordType: "Snippet", recordID: recordID)

        record["name"] = "Test"
        record["content"] = "Content"
        record["createdAt"] = Date()
        record["modificationDate"] = Date()

        // Attempt to deserialize
        XCTAssertThrowsError(try Snippet(from: record)) { error in
            if case CloudKitSyncError.invalidRecord = error {
                // Expected error
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected invalidRecord error, got \(error)")
            }
        }
    }

    func testSession_FromCKRecord_MissingModel_ThrowsError() {
        // Create session record missing required "model" field
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: testZoneID)
        let record = CKRecord(recordType: "ChatSession", recordID: recordID)

        // Missing "model" field
        record["permissionMode"] = "default"
        record["status"] = "active"
        record["messageCount"] = 0
        record["source"] = "ils"
        record["createdAt"] = Date()
        record["lastActiveAt"] = Date()
        record["modificationDate"] = Date()

        // Attempt to deserialize
        XCTAssertThrowsError(try ChatSession(from: record)) { error in
            if case CloudKitSyncError.missingRequiredField(let field) = error {
                XCTAssertEqual(field, "model")
            } else {
                XCTFail("Expected missingRequiredField(model) error, got \(error)")
            }
        }
    }
}
