# Task: Create Session and Project Models

## Description
Create the core data models for ChatSession and Project that will be shared between the iOS app and Vapor backend. These models define the primary entities for session management and project organization.

## Background
The ILS application is session-centric, similar to the Messages app. Sessions represent chat conversations with Claude, while Projects organize sessions by codebase/directory. The ChatSession type is named to avoid conflicts with Foundation.URLSession.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ChatSession struct with Codable, Identifiable, Sendable, Hashable conformance
2. Include fields: id, claudeSessionId, name, projectId, projectName, model, permissionMode, status, messageCount, totalCostUSD, source, createdAt, lastActiveAt
3. Create SessionStatus enum (active, completed, cancelled, error)
4. Create SessionSource enum (ils, external)
5. Create PermissionMode enum with all Claude Code permission modes
6. Create Project struct with similar conformances
7. Include Project fields: id, name, path, defaultModel, description, createdAt, lastAccessedAt

## Dependencies
- Directory structure from Phase 0
- Package.swift configured

## Implementation Approach
1. Create Sources/ILSShared/Models/Session.swift
2. Define ChatSession with all required fields and initializer
3. Define supporting enums (SessionStatus, SessionSource, PermissionMode)
4. Create Sources/ILSShared/Models/Project.swift
5. Define Project with all required fields and initializer
6. Verify compilation with `swift build --target ILSShared`

## Acceptance Criteria

1. **ChatSession Model Compiles**
   - Given the Session.swift file
   - When building ILSShared target
   - Then compilation succeeds with zero errors

2. **Project Model Compiles**
   - Given the Project.swift file
   - When building ILSShared target
   - Then compilation succeeds with zero errors

3. **Protocol Conformance**
   - Given both models
   - When inspecting type conformance
   - Then both conform to Codable, Identifiable, Sendable, Hashable

4. **PermissionMode Display Names**
   - Given the PermissionMode enum
   - When accessing displayName property
   - Then each case returns a human-readable string

## Metadata
- **Complexity**: Low
- **Labels**: Models, Swift, Shared, Session, Project
- **Required Skills**: Swift, Codable, Protocol conformance
