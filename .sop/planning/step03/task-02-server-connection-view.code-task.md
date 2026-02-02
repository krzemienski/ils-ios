# Task: Create ServerConnectionView

## Description
Create the server connection view that allows users to configure and connect to the Vapor backend. Includes host/port configuration and connection status feedback.

## Background
Before using the app, users need to connect to a running ILS backend server. This view provides connection configuration and handles the initial connection handshake.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create form with host and port text fields
2. Default values: host = "localhost", port = "8080"
3. Add authentication method picker (Password/SSH Key) - placeholder for future
4. Add "Connect" button with orange accent styling
5. Show connection status (connecting, failed, success)
6. Add "Local Development" section with quick connect option
7. Show error messages for failed connections
8. On successful connection, update AppState.isConnected

## Dependencies
- AppState from Task 3.1
- ILSTheme styling
- APIClient (will be created, use basic URLSession for now)

## Implementation Approach
1. Create ILSApp/ILSApp/Views/Settings/ServerConnectionView.swift
2. Add @EnvironmentObject var appState: AppState
3. Create @State properties for host, port, connectionState
4. Build form with styled text fields
5. Implement connect() function with health check request
6. Show loading indicator during connection
7. Handle success/failure with appropriate UI feedback
8. Update appState on successful connection
9. Verify compilation and preview rendering

## Acceptance Criteria

1. **Form Fields**
   - Given the ServerConnectionView
   - When rendered
   - Then host and port fields are visible with default values

2. **Connect Button**
   - Given the view with valid input
   - When Connect is tapped
   - Then connection attempt is initiated with loading state

3. **Successful Connection**
   - Given a running backend at the configured address
   - When connection succeeds
   - Then appState.isConnected becomes true

4. **Failed Connection**
   - Given no server at the configured address
   - When connection fails
   - Then error message is displayed

5. **Dark Theme Styling**
   - Given the rendered view
   - When inspecting styling
   - Then dark background, orange accent on button are applied

6. **Compilation Success**
   - Given the ServerConnectionView
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Views, Connection, Settings
- **Required Skills**: SwiftUI forms, URLSession, async/await, State management
