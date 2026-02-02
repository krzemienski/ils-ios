# Phase 01: Backend Validation and iOS Connection

This phase validates the existing ILS infrastructure and delivers a working end-to-end flow: backend server running, iOS app connecting, and basic CRUD operations functional. By the end, you'll see the iOS app successfully fetching and displaying data from the Vapor backend—proving the entire stack works together.

## Tasks

- [x] Build and start the Vapor backend server:
  - Run `swift build` in `/Users/nick/Desktop/ils-ios` to compile
  - Start the server with `swift run ILSBackend` (runs on localhost:8080)
  - Verify health endpoint responds: `curl http://localhost:8080/health`
  - Keep the server running in background for subsequent tasks

  **Completed 2026-02-02**: Build successful (3.68s) with minor Sendable conformance warnings. Server running on port 8080, health endpoint returning "OK".

- [x] Complete the ProjectsController CRUD implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/ProjectsController.swift`
  - Ensure `index()` returns all projects from database
  - Ensure `create()` saves new project to database and returns it
  - Ensure `show()` returns single project by ID
  - Ensure `update()` modifies existing project
  - Ensure `delete()` removes project from database
  - All methods should use Fluent ORM with ProjectModel

  **Completed 2026-02-02**: ProjectsController already fully implemented with Fluent ORM. All CRUD operations verified via curl:
  - `index()` returns projects sorted by lastAccessedAt with session counts
  - `create()` saves projects with duplicate path detection
  - `show()` retrieves by UUID with session count
  - `update()` supports partial updates (name, defaultModel, description)
  - `delete()` cascades to delete associated sessions
  - Bonus: `getSessions()` endpoint for project-session relationship

- [x] Complete the SessionsController CRUD implementation:
  - Read `/Users/nick/Desktop/ils-ios/Sources/ILSBackend/Controllers/SessionsController.swift`
  - Ensure `index()` returns all sessions (optionally filtered by projectId query param)
  - Ensure `create()` saves new session with projectId association
  - Ensure `show()` returns single session by ID
  - Ensure `delete()` removes session from database
  - Sessions should link to projects via projectId field

  **Completed 2026-02-02**: SessionsController already fully implemented with Fluent ORM. All CRUD operations verified via curl:
  - `list()` returns sessions sorted by lastActiveAt, with optional `?projectId=` filter
  - `create()` saves sessions with projectId association, returns projectName in response
  - `get()` retrieves single session by UUID with project relationship eager-loaded
  - `delete()` removes session and returns `{deleted: true}` confirmation
  - Bonus: `fork()` endpoint for session cloning with forkedFrom tracking
  - Bonus: `scan()` endpoint for discovering external Claude Code sessions

- [ ] Test backend API endpoints manually:
  - Create a project: `curl -X POST http://localhost:8080/api/v1/projects -H "Content-Type: application/json" -d '{"name":"Test Project","path":"/tmp/test"}'`
  - List projects: `curl http://localhost:8080/api/v1/projects`
  - Create a session: `curl -X POST http://localhost:8080/api/v1/sessions -H "Content-Type: application/json" -d '{"projectId":"<id-from-above>","name":"Test Session"}'`
  - List sessions: `curl http://localhost:8080/api/v1/sessions`
  - Verify JSON responses match expected DTO structure

- [ ] Verify iOS app APIClient connects to backend:
  - Read `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Services/APIClient.swift`
  - Confirm baseURL is set to `http://localhost:8080` (or configurable)
  - Check that generic `fetch()` and `post()` methods handle JSON encoding/decoding
  - Verify error handling returns meaningful errors to ViewModels

- [ ] Test iOS app displays projects from backend:
  - Open ILSApp in Xcode and run on simulator (with backend running)
  - Navigate to Projects tab
  - Verify projects created via curl appear in the list
  - Create a new project via iOS UI
  - Verify it appears in both iOS list and curl response
  - This proves end-to-end data flow works

- [ ] Fix any compilation warnings in the codebase:
  - Address unused variable warnings in PluginsController
  - Review Sendable conformance warnings and add conformance where appropriate
  - Ensure clean build with `swift build 2>&1 | grep -i warning`
