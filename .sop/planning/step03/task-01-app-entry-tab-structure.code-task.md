# Task: Create ILSApp Entry Point and Tab Structure

## Description
Create the main app entry point with the root navigation structure. Implement a tab-based layout with Dashboard, Skills, MCP Servers, Plugins, and Settings tabs. Include server connection state management.

## Background
The ILS app uses a tab-based navigation with a session-centric approach. Before showing the main interface, it checks for server connectivity. The app maintains connection state globally.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create ILSApp.swift with @main App struct
2. Create AppState ObservableObject for global state (connection status, server URL)
3. Create ContentView that switches between ServerConnectionView and MainTabView
4. Create MainTabView with TabView containing 5 tabs
5. Tab icons: house (Dashboard), lightbulb (Skills), server.rack (MCP), puzzlepiece (Plugins), gear (Settings)
6. Apply dark theme background throughout
7. Use environment object for AppState injection

## Dependencies
- ILSTheme from Phase 2B
- ILSShared package linked

## Implementation Approach
1. Create ILSApp/ILSApp/ILSApp.swift with @main
2. Create ILSApp/ILSApp/ViewModels/AppState.swift
3. Define isConnected, serverHost, serverPort properties
4. Create ILSApp/ILSApp/Views/ContentView.swift
5. Show ServerConnectionView when !isConnected, MainTabView otherwise
6. Create ILSApp/ILSApp/Views/MainTabView.swift with TabView
7. Add placeholder views for each tab (will be replaced)
8. Inject AppState as environmentObject
9. Verify compilation and simulator launch

## Acceptance Criteria

1. **App Launches**
   - Given the app entry point
   - When running on simulator
   - Then app launches without crashes

2. **Connection State Handling**
   - Given AppState.isConnected = false
   - When ContentView renders
   - Then ServerConnectionView is displayed

3. **Tab Navigation**
   - Given AppState.isConnected = true
   - When MainTabView renders
   - Then 5 tabs are visible with correct icons

4. **Dark Theme**
   - Given the app running
   - When viewing any screen
   - Then dark background (#000000) is applied

5. **Compilation Success**
   - Given all entry point files
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Navigation, App Structure, State Management
- **Required Skills**: SwiftUI, @main, ObservableObject, TabView
