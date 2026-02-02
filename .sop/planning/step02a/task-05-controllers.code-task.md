# Task: Create All Controllers

## Description
Create all REST API controllers for the backend: Health, Projects, Sessions, Chat, Skills, MCPServers, Plugins, and Config. Each controller handles CRUD operations for its resource type.

## Background
The backend provides a REST API for the iOS app. Controllers define routes and handlers for each endpoint. The chat controller is special as it returns SSE streams rather than JSON responses.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create HealthController with GET /health returning "OK"
2. Create ProjectController with CRUD: list, get, create, update, delete
3. Create SessionController with: list, get, create, delete, list by project
4. Create ChatController with POST /chat returning SSE stream
5. Create SkillController with: list, get, create, update, delete, invoke
6. Create MCPServerController with: list by scope, create, update, delete
7. Create PluginController with: list, install, uninstall, marketplace list
8. Create ConfigController with: get, update, validate by scope
9. Use appropriate HTTP methods and status codes
10. Return ILSShared DTOs wrapped in APIResponse

## Dependencies
- All services (ClaudeExecutorService, StreamingService)
- Fluent models and migrations
- ILSShared DTOs

## Implementation Approach
1. Create Sources/ILSBackend/Controllers/ directory structure
2. Create HealthController.swift with simple health check
3. Create ProjectController.swift with RouteCollection conformance
4. Create SessionController.swift with project relationship handling
5. Create ChatController.swift integrating StreamingService
6. Create SkillController.swift with file system operations
7. Create MCPServerController.swift with config file handling
8. Create PluginController.swift with marketplace integration
9. Create ConfigController.swift with scope-based config access
10. Create routes.swift to register all controllers
11. Verify compilation

## Acceptance Criteria

1. **Health Endpoint**
   - Given the HealthController
   - When GET /health is called
   - Then response is 200 with body "OK"

2. **Project CRUD**
   - Given ProjectController
   - When all CRUD endpoints are defined
   - Then list/get/create/update/delete are available

3. **Session Filtering**
   - Given SessionController
   - When GET /sessions?projectId=uuid is called
   - Then only sessions for that project are returned

4. **Chat Streaming**
   - Given ChatController
   - When POST /chat is called
   - Then response Content-Type is text/event-stream

5. **Route Registration**
   - Given routes.swift
   - When all controllers are registered
   - Then all endpoints are accessible

6. **Compilation Success**
   - Given all controllers
   - When running `swift build --target ILSBackend`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: High
- **Labels**: Backend, Vapor, Controllers, REST API, CRUD
- **Required Skills**: Vapor routing, REST design, Fluent queries, Error handling
