# Task: Create MCPServerListView

## Description
Create the MCP server management view showing configured servers across different scopes (User, Project, Local). Support adding, editing, and removing MCP server configurations.

## Background
MCP servers extend Claude Code with external tools. They are configured in JSON files at different scopes. The app provides a UI for managing these configurations.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create MCPServerListView with scope picker (User/Project/Local)
2. List servers for selected scope
3. Show server status (healthy/error) with colored indicators
4. Display command and environment info for each server
5. Add action buttons: Disable, Edit, Delete
6. Create "Add Custom MCP Server" button
7. Create AddMCPServerSheet for adding new servers
8. Form fields: name, command, args (comma-separated), env (key=value pairs)
9. Scope selector for where to add the server

## Dependencies
- ILSShared MCPServer model
- ILSTheme styling
- APIClient for MCP operations

## Implementation Approach
1. Create ILSApp/ILSApp/Views/MCP/MCPServerListView.swift
2. Create MCPServersViewModel with scope-filtered data
3. Add Picker for scope selection at top
4. Create server row component with status, name, command
5. Add swipe actions for edit/delete
6. Create ILSApp/ILSApp/Views/MCP/AddMCPServerSheet.swift
7. Build form with required fields
8. Handle form submission and API call
9. Verify compilation and functionality

## Acceptance Criteria

1. **Scope Picker**
   - Given the MCPServerListView
   - When rendered
   - Then scope picker shows User/Project/Local options

2. **Server List**
   - Given servers exist for selected scope
   - When viewing list
   - Then servers show with status, name, and command

3. **Status Indicators**
   - Given servers with different statuses
   - When viewing rows
   - Then healthy shows green dot, error shows red dot

4. **Add Server Sheet**
   - Given the add button tapped
   - When sheet presents
   - Then form with name, command, args, env, scope fields is shown

5. **Server Actions**
   - Given a server row
   - When swiping or tapping actions
   - Then disable/edit/delete options are available

6. **Compilation Success**
   - Given both views
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Views, MCP, Configuration
- **Required Skills**: SwiftUI Picker, List, Sheet, Forms, Swipe actions
