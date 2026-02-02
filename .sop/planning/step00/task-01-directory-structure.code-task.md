# Task: Create Project Directory Structure

## Description
Create the complete directory structure for the ILS application, including the Swift package source directories and iOS app directories. This establishes the foundation for the entire project.

## Background
The ILS (Intelligent Local Server) application uses a multi-target Swift package structure with:
- `ILSShared` - Shared models used by both backend and iOS app
- `ILSBackend` - Vapor-based backend server
- `ILSApp` - iOS SwiftUI application

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create Sources directory with ILSShared and ILSBackend subdirectories
2. Create ILSApp directory structure for iOS app
3. Organize subdirectories by concern (Models, DTOs, Controllers, Services, Views, ViewModels, Theme)
4. Follow Swift package conventions

## Dependencies
- macOS with Swift toolchain installed
- Terminal access

## Implementation Approach
1. Create Sources/ILSShared/Models and Sources/ILSShared/DTOs directories
2. Create Sources/ILSBackend with App, Controllers, Services, Models, Extensions subdirectories
3. Create ILSApp/ILSApp with Theme, Views, ViewModels, Services subdirectories
4. Create view-specific subdirectories under Views (Sidebar, Sessions, Chat, Projects, Plugins, MCP, Settings)

## Acceptance Criteria

1. **Source Directory Structure**
   - Given the project root directory
   - When running `tree Sources -d`
   - Then the output shows ILSShared/{Models,DTOs} and ILSBackend/{App,Controllers,Services,Models,Extensions}

2. **iOS App Directory Structure**
   - Given the project root directory
   - When running `tree ILSApp -d`
   - Then the output shows ILSApp/{Theme,Views,ViewModels,Services} with Views subdirectories

3. **All Directories Created**
   - Given the complete directory structure
   - When listing all directories
   - Then all specified directories exist and are empty (ready for code)

## Metadata
- **Complexity**: Low
- **Labels**: Setup, Directory Structure, Environment
- **Required Skills**: Terminal, File system operations
