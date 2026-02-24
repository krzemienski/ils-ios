import Testing
import Foundation
@testable import ILSShared

@Suite("Project")
struct ProjectTests {

    @Test("Codable round-trip preserves all fields")
    func codableRoundTrip() throws {
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1700000000)
        let project = TestFactory.makeProject(
            id: id,
            name: "ILS Backend",
            path: "/tmp/ils-backend",
            defaultModel: "opus",
            description: "The main backend service",
            createdAt: now,
            lastAccessedAt: now,
            sessionCount: 15,
            encodedPath: "%2Ftmp%2Fils-backend"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Project.self, from: data)

        #expect(decoded.id == id)
        #expect(decoded.name == "ILS Backend")
        #expect(decoded.path == "/tmp/ils-backend")
        #expect(decoded.defaultModel == "opus")
        #expect(decoded.description == "The main backend service")
        #expect(decoded.sessionCount == 15)
        #expect(decoded.encodedPath == "%2Ftmp%2Fils-backend")
    }

    @Test("Default init values")
    func defaultInitValues() {
        let project = TestFactory.makeProject()
        #expect(project.name == "Test Project")
        #expect(project.path == "/tmp/test-project")
        #expect(project.defaultModel == "sonnet")
        #expect(project.description == nil)
        #expect(project.sessionCount == nil)
        #expect(project.encodedPath == nil)
    }

    @Test("Init with all optional fields populated")
    func initWithAllOptionalFields() {
        let project = TestFactory.makeProject(
            name: "Full Project",
            path: "/tmp/full",
            defaultModel: "haiku",
            description: "Fully configured",
            sessionCount: 99,
            encodedPath: "%2Ftmp%2Ffull"
        )

        #expect(project.name == "Full Project")
        #expect(project.defaultModel == "haiku")
        #expect(project.description == "Fully configured")
        #expect(project.sessionCount == 99)
        #expect(project.encodedPath == "%2Ftmp%2Ffull")
    }

    @Test("Project with nil optionals round-trips correctly")
    func nilOptionalsRoundTrip() throws {
        let project = TestFactory.makeProject()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(project)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Project.self, from: data)

        #expect(decoded.description == nil)
        #expect(decoded.sessionCount == nil)
        #expect(decoded.encodedPath == nil)
    }
}
