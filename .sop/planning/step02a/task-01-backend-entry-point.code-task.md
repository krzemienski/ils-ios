# Task: Create Backend Entry Point

## Description
Create the Vapor backend application entry point and configuration. This establishes the server startup, database configuration, CORS middleware, and route registration.

## Background
The ILS backend is a Vapor 4 application that serves as a bridge between the iOS app and Claude Code CLI. It uses SQLite for persistence and needs CORS configured for iOS app communication.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create @main entrypoint using async/await pattern
2. Configure environment detection and logging
3. Set up CORS middleware allowing all origins (local development)
4. Configure SQLite database with file-based storage (ils.sqlite)
5. Register database migrations
6. Set up route registration
7. Log successful configuration on port 8080

## Dependencies
- ILSShared package must compile
- Vapor, Fluent, FluentSQLiteDriver dependencies

## Implementation Approach
1. Create Sources/ILSBackend/App/entrypoint.swift with @main struct
2. Implement async main() with environment detection
3. Create Sources/ILSBackend/App/configure.swift
4. Configure CORS with permissive settings for development
5. Set up SQLite database connection
6. Add migration registrations (will be created in next task)
7. Create Sources/ILSBackend/App/routes.swift placeholder
8. Verify compilation (may have errors until migrations/routes exist)

## Acceptance Criteria

1. **Entry Point Structure**
   - Given the entrypoint.swift file
   - When inspecting the code
   - Then it uses @main struct with async main()

2. **CORS Configuration**
   - Given the configure.swift file
   - When inspecting CORS setup
   - Then all origins, standard methods, and headers are allowed

3. **Database Configuration**
   - Given the configure.swift file
   - When inspecting database setup
   - Then SQLite with file "ils.sqlite" is configured

4. **Files Created**
   - Given the App directory
   - When listing files
   - Then entrypoint.swift, configure.swift exist

## Metadata
- **Complexity**: Low
- **Labels**: Backend, Vapor, Setup, Configuration
- **Required Skills**: Vapor, Swift async/await, Server configuration
