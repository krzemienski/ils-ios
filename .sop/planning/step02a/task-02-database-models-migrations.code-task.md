# Task: Create Database Models and Migrations

## Description
Create Fluent database models for Project and Session entities, along with their migrations. These models persist data to SQLite and map to the shared ILSShared types.

## Background
Fluent is Vapor's ORM that maps Swift classes to database tables. The backend needs to persist projects and sessions locally while the shared models (structs) are used for API communication.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ProjectModel as Fluent Model class with @ID, @Field, @Timestamp properties
2. Create SessionModel as Fluent Model class with @ID, @Field, @OptionalField, @Timestamp properties
3. Add @Parent relationship from SessionModel to ProjectModel
4. Create CreateProject migration with all columns
5. Create CreateSession migration with all columns and foreign key
6. Implement toShared() methods to convert Fluent models to ILSShared types
7. Implement init(from:) to create Fluent models from shared types

## Dependencies
- ILSShared models (ChatSession, Project)
- Fluent and FluentSQLiteDriver

## Implementation Approach
1. Create Sources/ILSBackend/Models/ProjectModel.swift
2. Define ProjectModel with Fluent property wrappers
3. Add schema name and field keys enum
4. Create Sources/ILSBackend/Models/SessionModel.swift
5. Define SessionModel with optional project relationship
6. Create Sources/ILSBackend/Migrations/CreateProject.swift
7. Create Sources/ILSBackend/Migrations/CreateSession.swift
8. Add conversion methods between Fluent and shared models
9. Verify compilation with `swift build --target ILSBackend`

## Acceptance Criteria

1. **ProjectModel Structure**
   - Given the ProjectModel class
   - When inspecting properties
   - Then all fields from Project struct are represented with Fluent wrappers

2. **SessionModel Relationship**
   - Given the SessionModel class
   - When inspecting relationships
   - Then optional @Parent to ProjectModel exists

3. **Migration Schema**
   - Given the CreateProject migration
   - When inspecting prepare()
   - Then all columns are created with correct types

4. **Model Conversion**
   - Given a Fluent ProjectModel
   - When calling toShared()
   - Then it returns a valid ILSShared.Project

5. **Compilation Success**
   - Given all model and migration files
   - When running `swift build --target ILSBackend`
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: Backend, Vapor, Fluent, Database, Models, Migrations
- **Required Skills**: Vapor, Fluent ORM, Database design, Swift classes
