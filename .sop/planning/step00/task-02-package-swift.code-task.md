# Task: Create Root Package.swift

## Description
Create the Swift Package Manager manifest file that defines the multi-target package structure for ILS. This file configures dependencies (Vapor, Fluent, Yams) and defines the ILSShared library and ILSBackend executable targets.

## Background
The ILS application uses Swift Package Manager for dependency management and build configuration. The package supports both iOS 17+ and macOS 14+ platforms, with Vapor as the backend framework and SQLite for persistence.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Set Swift tools version to 5.9
2. Configure platforms for iOS 17+ and macOS 14+
3. Define ILSShared as a library product
4. Define ILSBackend as an executable product
5. Add dependencies: Vapor 4.89.0+, Fluent 4.9.0+, FluentSQLiteDriver 4.6.0+, Yams 5.0.0+
6. Configure target dependencies correctly (ILSBackend depends on ILSShared)

## Dependencies
- Directory structure from Task 0.1
- Swift 5.9+ toolchain

## Implementation Approach
1. Create Package.swift at project root
2. Define package metadata and platforms
3. Add external dependencies with version requirements
4. Define ILSShared target with Yams dependency
5. Define ILSBackend target with Vapor, Fluent, and ILSShared dependencies

## Acceptance Criteria

1. **Package Resolution**
   - Given the Package.swift file
   - When running `swift package resolve`
   - Then all dependencies are fetched without errors

2. **Package Description**
   - Given the Package.swift file
   - When running `swift package describe`
   - Then output shows ILSShared and ILSBackend targets with correct dependencies

3. **Platform Support**
   - Given the Package.swift configuration
   - When inspecting platform requirements
   - Then iOS 17+ and macOS 14+ are specified

## Metadata
- **Complexity**: Low
- **Labels**: Setup, SPM, Dependencies, Configuration
- **Required Skills**: Swift Package Manager, Dependency management
