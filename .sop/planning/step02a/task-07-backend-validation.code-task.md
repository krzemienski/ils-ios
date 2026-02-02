# Task: Build and Test Backend with cURL

## Description
Build the complete backend and validate all endpoints work correctly using cURL commands. This is the gate check for Phase 2A completion.

## Background
Evidence-driven development requires proof that endpoints work before proceeding. Each endpoint must be tested with cURL and the response captured as evidence.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Run `swift build --target ILSBackend` - must succeed
2. Start server with `swift run ILSBackend`
3. Test GET /health - must return "OK"
4. Test POST /projects - create a project
5. Test GET /projects - list projects
6. Test GET /projects/:id - get specific project
7. Test POST /sessions - create a session
8. Test GET /sessions - list sessions
9. Test all other endpoints
10. Capture ALL responses as evidence

## Dependencies
- All Phase 2A tasks complete
- curl installed

## Implementation Approach
1. Build the backend with swift build
2. Start server in background
3. Run health check first
4. Create test project with cURL
5. Create test session with cURL
6. Test each CRUD operation
7. Test chat endpoint (will need valid claude setup)
8. Record all responses
9. Stop server and document results

## Acceptance Criteria

1. **Build Success**
   - Given the complete backend code
   - When running `swift build --target ILSBackend`
   - Then build completes with zero errors

2. **Server Starts**
   - Given the built executable
   - When running `swift run ILSBackend`
   - Then server starts and logs "configured successfully on port 8080"

3. **Health Check**
   - Given running server
   - When calling `curl http://localhost:8080/health`
   - Then response is "OK"

4. **Project CRUD**
   - Given running server
   - When testing all project endpoints
   - Then create returns project, list returns array, get returns single

5. **Session CRUD**
   - Given running server
   - When testing all session endpoints
   - Then create returns session, list returns array with project info

6. **All Endpoints Respond**
   - Given running server
   - When testing ALL 8 API endpoint groups
   - Then all return valid JSON responses

## Metadata
- **Complexity**: Medium
- **Labels**: Backend, Validation, Testing, cURL, Evidence
- **Required Skills**: cURL, REST API testing, Shell scripting
