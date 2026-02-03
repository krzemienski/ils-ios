import XCTest
import XCTVapor
@testable import ILSBackend
@testable import ILSShared

final class ProjectsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        try await super.setUp()

        app = try await Application.make(.testing)

        // Configure database (in-memory SQLite for testing)
        app.databases.use(.sqlite(.memory), as: .sqlite)

        // Run migrations
        app.migrations.add(CreateProjects())
        app.migrations.add(CreateSessions())
        try await app.autoMigrate()

        // Register routes
        try routes(app)
    }

    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
        app = nil
        try await super.tearDown()
    }

    // MARK: - Index Tests (GET /api/v1/projects)

    func testIndex_ReturnsProjectsList() async throws {
        try await app.test(.GET, "/api/v1/projects", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<ListResponse<Project>>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            // Note: This returns projects from the real ~/.claude/projects directory
            // so we can't assert on exact count, just that it's non-nil
            XCTAssertGreaterThanOrEqual(response.data?.items.count ?? 0, 0)
        })
    }

    func testIndex_ReturnsSuccessResponse() async throws {
        try await app.test(.GET, "/api/v1/projects", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<ListResponse<Project>>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
        })
    }

    // MARK: - Create Tests (POST /api/v1/projects)

    func testCreate_Success() async throws {
        let request = CreateProjectRequest(
            name: "Test Project",
            path: "/path/to/project",
            defaultModel: "sonnet",
            description: "A test project"
        )

        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.name, "Test Project")
            XCTAssertEqual(response.data?.path, "/path/to/project")
            XCTAssertEqual(response.data?.defaultModel, "sonnet")
            XCTAssertEqual(response.data?.description, "A test project")
        })
    }

    func testCreate_WithMinimalFields() async throws {
        let request = CreateProjectRequest(
            name: "Minimal Project",
            path: "/path/to/minimal"
        )

        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.name, "Minimal Project")
            XCTAssertEqual(response.data?.path, "/path/to/minimal")
            XCTAssertEqual(response.data?.defaultModel, "sonnet")
            XCTAssertNil(response.data?.description)
        })
    }

    func testCreate_DuplicatePath_ReturnsExisting() async throws {
        let request = CreateProjectRequest(
            name: "Duplicate Project",
            path: "/path/to/duplicate"
        )

        // Create first project
        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        // Try to create duplicate
        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.path, "/path/to/duplicate")
        })
    }

    func testCreate_WithCustomModel() async throws {
        let request = CreateProjectRequest(
            name: "Custom Model Project",
            path: "/path/to/custom",
            defaultModel: "opus"
        )

        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertEqual(response.data?.defaultModel, "opus")
        })
    }

    // MARK: - Show Tests (GET /api/v1/projects/:id)

    func testShow_Success() async throws {
        // Create a project first
        let project = ProjectModel(
            name: "Show Test Project",
            path: "/path/to/show",
            defaultModel: "sonnet",
            description: "For show test"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        try await app.test(.GET, "/api/v1/projects/\(projectId)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.id, projectId)
            XCTAssertEqual(response.data?.name, "Show Test Project")
            XCTAssertEqual(response.data?.path, "/path/to/show")
        })
    }

    func testShow_NotFound() async throws {
        let randomId = UUID()

        try await app.test(.GET, "/api/v1/projects/\(randomId)") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testShow_InvalidUUID() async throws {
        try await app.test(.GET, "/api/v1/projects/invalid-uuid") { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    func testShow_WithSessionCount() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Project with Sessions",
            path: "/path/to/sessions",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        // Create some sessions for the project
        let session1 = SessionModel(projectId: projectId, model: "sonnet")
        let session2 = SessionModel(projectId: projectId, model: "haiku")
        try await session1.save(on: app.db)
        try await session2.save(on: app.db)

        try await app.test(.GET, "/api/v1/projects/\(projectId)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertEqual(response.data?.sessionCount, 2)
        })
    }

    // MARK: - Update Tests (PUT /api/v1/projects/:id)

    func testUpdate_Success() async throws {
        // Create a project first
        let project = ProjectModel(
            name: "Original Name",
            path: "/path/to/update",
            defaultModel: "sonnet",
            description: "Original description"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        let updateRequest = UpdateProjectRequest(
            name: "Updated Name",
            defaultModel: "opus",
            description: "Updated description"
        )

        try await app.test(.PUT, "/api/v1/projects/\(projectId)", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.data?.name, "Updated Name")
            XCTAssertEqual(response.data?.defaultModel, "opus")
            XCTAssertEqual(response.data?.description, "Updated description")
        })
    }

    func testUpdate_PartialUpdate() async throws {
        // Create a project first
        let project = ProjectModel(
            name: "Original Name",
            path: "/path/to/partial",
            defaultModel: "sonnet",
            description: "Original description"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        // Update only the name
        let updateRequest = UpdateProjectRequest(name: "New Name")

        try await app.test(.PUT, "/api/v1/projects/\(projectId)", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<Project>.self)
            XCTAssertEqual(response.data?.name, "New Name")
            XCTAssertEqual(response.data?.defaultModel, "sonnet")
            XCTAssertEqual(response.data?.description, "Original description")
        })
    }

    func testUpdate_NotFound() async throws {
        let randomId = UUID()
        let updateRequest = UpdateProjectRequest(name: "New Name")

        try await app.test(.PUT, "/api/v1/projects/\(randomId)", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testUpdate_InvalidUUID() async throws {
        let updateRequest = UpdateProjectRequest(name: "New Name")

        try await app.test(.PUT, "/api/v1/projects/invalid-uuid", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testUpdate_TouchesLastAccessedAt() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Touch Test",
            path: "/path/to/touch",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()
        let originalAccessedAt = project.lastAccessedAt

        // Wait a small amount to ensure timestamp difference
        try await Task.sleep(nanoseconds: 100_000_000)

        let updateRequest = UpdateProjectRequest(name: "Touched")

        try await app.test(.PUT, "/api/v1/projects/\(projectId)", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            // Verify project was updated in database
            let updatedProject = try await ProjectModel.find(projectId, on: app.db)
            XCTAssertNotNil(updatedProject?.lastAccessedAt)
            XCTAssertNotEqual(updatedProject?.lastAccessedAt, originalAccessedAt)
        })
    }

    // MARK: - Delete Tests (DELETE /api/v1/projects/:id)

    func testDelete_Success() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Delete Test",
            path: "/path/to/delete",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        try await app.test(.DELETE, "/api/v1/projects/\(projectId)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<DeletedResponse>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertTrue(response.data?.deleted ?? false)
        })

        // Verify project was deleted
        let deletedProject = try await ProjectModel.find(projectId, on: app.db)
        XCTAssertNil(deletedProject)
    }

    func testDelete_CascadesSessions() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Cascade Test",
            path: "/path/to/cascade",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        // Create sessions
        let session1 = SessionModel(projectId: projectId, model: "sonnet")
        let session2 = SessionModel(projectId: projectId, model: "haiku")
        try await session1.save(on: app.db)
        try await session2.save(on: app.db)

        let session1Id = try session1.requireID()
        let session2Id = try session2.requireID()

        // Delete project
        try await app.test(.DELETE, "/api/v1/projects/\(projectId)") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }

        // Verify sessions were deleted
        let deletedSession1 = try await SessionModel.find(session1Id, on: app.db)
        let deletedSession2 = try await SessionModel.find(session2Id, on: app.db)
        XCTAssertNil(deletedSession1)
        XCTAssertNil(deletedSession2)
    }

    func testDelete_NotFound() async throws {
        let randomId = UUID()

        try await app.test(.DELETE, "/api/v1/projects/\(randomId)") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testDelete_InvalidUUID() async throws {
        try await app.test(.DELETE, "/api/v1/projects/invalid-uuid") { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - GetSessions Tests (GET /api/v1/projects/:id/sessions)

    func testGetSessions_Success() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Sessions Test",
            path: "/path/to/sessions-test",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        // Create sessions
        let session1 = SessionModel(
            name: "Session 1",
            projectId: projectId,
            model: "sonnet"
        )
        let session2 = SessionModel(
            name: "Session 2",
            projectId: projectId,
            model: "haiku"
        )
        try await session1.save(on: app.db)
        try await session2.save(on: app.db)

        try await app.test(.GET, "/api/v1/projects/\(projectId)/sessions") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<ListResponse<ChatSession>>.self)
            XCTAssertTrue(response.success)
            XCTAssertNotNil(response.data)
            XCTAssertEqual(response.data?.items.count, 2)
        }
    }

    func testGetSessions_EmptyList() async throws {
        // Create a project with no sessions
        let project = ProjectModel(
            name: "Empty Sessions Test",
            path: "/path/to/empty-sessions",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        try await app.test(.GET, "/api/v1/projects/\(projectId)/sessions") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<ListResponse<ChatSession>>.self)
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.data?.items.count, 0)
        }
    }

    func testGetSessions_SortedByLastActiveAt() async throws {
        // Create a project
        let project = ProjectModel(
            name: "Sort Test",
            path: "/path/to/sort",
            defaultModel: "sonnet"
        )
        try await project.save(on: app.db)

        let projectId = try project.requireID()

        // Create sessions with different timestamps
        let oldSession = SessionModel(
            name: "Old Session",
            projectId: projectId,
            model: "sonnet"
        )
        try await oldSession.save(on: app.db)

        // Wait to ensure different timestamp
        try await Task.sleep(nanoseconds: 100_000_000)

        let newSession = SessionModel(
            name: "New Session",
            projectId: projectId,
            model: "haiku"
        )
        try await newSession.save(on: app.db)

        try await app.test(.GET, "/api/v1/projects/\(projectId)/sessions") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(APIResponse<ListResponse<ChatSession>>.self)
            XCTAssertEqual(response.data?.items.count, 2)

            // Should be sorted by lastActiveAt descending (newest first)
            if let sessions = response.data?.items, sessions.count == 2 {
                XCTAssertEqual(sessions[0].name, "New Session")
                XCTAssertEqual(sessions[1].name, "Old Session")
            }
        }
    }

    func testGetSessions_ProjectNotFound() async throws {
        let randomId = UUID()

        try await app.test(.GET, "/api/v1/projects/\(randomId)/sessions") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }

    func testGetSessions_InvalidUUID() async throws {
        try await app.test(.GET, "/api/v1/projects/invalid-uuid/sessions") { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        }
    }

    // MARK: - Integration Tests

    func testFullProjectLifecycle() async throws {
        var projectId: UUID?

        // Create project
        let createRequest = CreateProjectRequest(
            name: "Lifecycle Test",
            path: "/path/to/lifecycle",
            defaultModel: "sonnet"
        )

        try await app.test(.POST, "/api/v1/projects", beforeRequest: { req in
            try req.content.encode(createRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(APIResponse<Project>.self)
            projectId = response.data?.id
        })

        guard let id = projectId else {
            XCTFail("Failed to create project")
            return
        }

        // Read project
        try await app.test(.GET, "/api/v1/projects/\(id)") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }

        // Update project
        let updateRequest = UpdateProjectRequest(name: "Updated Lifecycle")
        try await app.test(.PUT, "/api/v1/projects/\(id)", beforeRequest: { req in
            try req.content.encode(updateRequest)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        // Delete project
        try await app.test(.DELETE, "/api/v1/projects/\(id)") { res async throws in
            XCTAssertEqual(res.status, .ok)
        }

        // Verify deleted
        try await app.test(.GET, "/api/v1/projects/\(id)") { res async throws in
            XCTAssertEqual(res.status, .notFound)
        }
    }
}
