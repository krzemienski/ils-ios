# Task: Create Vapor Extensions for ILSShared Types

## Description
Create Vapor-specific extensions and Content conformances for ILSShared types. This enables seamless encoding/decoding of shared types in Vapor request/response handling.

## Background
Vapor uses the Content protocol for automatic JSON encoding/decoding in routes. ILSShared types need Content conformance to work with Vapor's request body parsing and response encoding.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Add Content conformance to all ILSShared request DTOs
2. Add Content conformance to all ILSShared response types
3. Create extension for APIResponse to work with Vapor
4. Add helper methods for common response patterns
5. Create custom error handling middleware for APIError
6. Ensure all conformances work with async route handlers

## Dependencies
- All ILSShared types
- Vapor framework

## Implementation Approach
1. Create Sources/ILSBackend/Extensions/ILSShared+Vapor.swift
2. Add Content conformance via extensions (trivial for Codable types)
3. Create Response helpers for APIResponse
4. Create Sources/ILSBackend/Extensions/ErrorMiddleware.swift
5. Implement custom error handling that returns APIError format
6. Register middleware in configure.swift
7. Verify compilation with `swift build --target ILSBackend`

## Acceptance Criteria

1. **Content Conformance**
   - Given CreateProjectRequest
   - When used as route handler parameter
   - Then Vapor automatically decodes from request body

2. **Response Encoding**
   - Given APIResponse<Project>
   - When returned from route handler
   - Then Vapor automatically encodes to JSON

3. **Error Handling**
   - Given an error thrown in route
   - When error middleware catches it
   - Then response is formatted as APIResponse with error

4. **Compilation Success**
   - Given all extensions
   - When running `swift build --target ILSBackend`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Low
- **Labels**: Backend, Vapor, Extensions, Codable, Content
- **Required Skills**: Vapor Content protocol, Swift extensions, Error handling
