# Task: Create APIClient

## Description
Create the centralized API client for communicating with the Vapor backend. Handle all REST endpoints, error handling, and SSE streaming for chat.

## Background
The iOS app communicates with the Vapor backend via REST API and SSE. The APIClient encapsulates all network operations with proper error handling and async/await support.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create APIClient actor for thread-safe network operations
2. Configure base URL from AppState (host:port)
3. Implement generic request method with Codable response handling
4. Create methods for all resource endpoints (projects, sessions, skills, etc.)
5. Implement SSE streaming for chat endpoint
6. Handle APIError responses and convert to Swift errors
7. Support request timeout configuration
8. Add logging for debugging

## Dependencies
- ILSShared DTOs (all request/response types)
- Foundation URLSession

## Implementation Approach
1. Create ILSApp/ILSApp/Services/APIClient.swift
2. Define APIClient actor with baseURL property
3. Create generic request<T: Decodable>() method
4. Add helper methods: get(), post(), put(), delete()
5. Implement each resource's methods:
   - health(), getProjects(), createProject(), etc.
   - getSessions(), createSession(), etc.
   - getSkills(), createSkill(), etc.
   - getMCPServers(), createMCPServer(), etc.
   - getPlugins(), installPlugin(), etc.
6. Implement streamChat() returning AsyncThrowingStream
7. Parse SSE data: lines into StreamMessage
8. Add proper error handling and logging
9. Verify compilation

## Acceptance Criteria

1. **Health Check**
   - Given a running backend
   - When calling apiClient.health()
   - Then "OK" response is returned

2. **CRUD Operations**
   - Given the APIClient
   - When calling getProjects(), createProject(), etc.
   - Then correct HTTP methods and paths are used

3. **Error Handling**
   - Given a failed request
   - When error response received
   - Then APIError is properly decoded and thrown

4. **SSE Streaming**
   - Given a chat request
   - When calling streamChat()
   - Then AsyncThrowingStream yields StreamMessage objects

5. **Base URL Configuration**
   - Given host and port settings
   - When APIClient is initialized
   - Then all requests use correct base URL

6. **Compilation Success**
   - Given the APIClient
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: High
- **Labels**: iOS, Networking, API, REST, SSE, Async
- **Required Skills**: URLSession, async/await, Codable, SSE parsing, Error handling
