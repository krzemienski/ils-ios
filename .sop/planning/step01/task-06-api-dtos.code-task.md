# Task: Create API DTOs

## Description
Create Data Transfer Objects (DTOs) for the REST API communication between iOS app and Vapor backend. These include response wrappers, request bodies, and dashboard statistics.

## Background
The API uses a consistent response format with success/error handling. Request DTOs define the expected payload structure for creating and updating resources. Dashboard stats aggregate counts across all resource types.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create APIResponse<T> generic wrapper with success, data, error, timestamp
2. Create APIError struct with code, message, details and common static errors
3. Create ListResponse<T> for paginated lists with items, total, page, pageSize
4. Create DashboardStats and ResourceStats for dashboard view
5. Create request DTOs: CreateProjectRequest, UpdateProjectRequest, CreateSessionRequest
6. Create ChatRequest and ChatOptions for chat endpoints
7. Create CreateSkillRequest, UpdateSkillRequest for skill management
8. Create CreateMCPServerRequest for MCP configuration
9. Create InstallPluginRequest for plugin installation
10. Create UpdateConfigRequest and ValidateConfigRequest for settings

## Dependencies
- All models from Tasks 1.1-1.5
- Foundation framework

## Implementation Approach
1. Create Sources/ILSShared/DTOs/APIResponse.swift
2. Define generic APIResponse with convenience static methods
3. Define APIError with common error constants
4. Define ListResponse for collection endpoints
5. Define DashboardStats and ResourceStats
6. Create Sources/ILSShared/DTOs/Requests.swift
7. Define all request DTOs with appropriate fields
8. Ensure all types have proper initializers
9. Verify compilation with `swift build --target ILSShared`
10. Verify file count with `ls Sources/ILSShared/**/*.swift | wc -l` (should be 8+)

## Acceptance Criteria

1. **APIResponse Success Helper**
   - Given data of type T
   - When calling APIResponse.success(data)
   - Then it returns APIResponse with success=true and data set

2. **APIResponse Failure Helper**
   - Given an APIError
   - When calling APIResponse.failure(error)
   - Then it returns APIResponse with success=false and error set

3. **Request DTO Encoding**
   - Given a CreateSessionRequest with all fields
   - When encoding to JSON
   - Then all fields are correctly serialized

4. **Compilation Success**
   - Given all DTO files
   - When running `swift build --target ILSShared`
   - Then build succeeds with zero errors

5. **File Count**
   - Given the complete ILSShared package
   - When counting Swift files
   - Then there are 8 or more .swift files

## Metadata
- **Complexity**: Low
- **Labels**: DTOs, Swift, Shared, API, Requests, Responses
- **Required Skills**: Swift, Codable, Generics
