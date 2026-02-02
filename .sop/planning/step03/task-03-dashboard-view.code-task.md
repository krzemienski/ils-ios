# Task: Create DashboardView

## Description
Create the main dashboard view showing statistics, quick actions, and recent activity. This is the home tab of the app providing an overview of the ILS system status.

## Background
The dashboard provides at-a-glance information about skills, MCP servers, plugins, and recent sessions. Quick actions allow fast access to common operations.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create stat cards showing counts: Skills, MCP Servers, Plugins
2. Each stat card shows total and active counts
3. Create Quick Actions section with navigation links
4. Quick actions: New Session, Browse Skills, Add MCP, Install Plugin
5. Create Recent Activity section showing recent sessions
6. Create Active Sessions section with session list
7. Show connection status in toolbar
8. Pull-to-refresh for data reload
9. Loading states for async data fetching

## Dependencies
- ILSTheme styling
- ILSShared DashboardStats DTO
- APIClient (for data fetching)

## Implementation Approach
1. Create ILSApp/ILSApp/Views/Dashboard/DashboardView.swift
2. Create DashboardViewModel with @Published stats
3. Build ScrollView with sections
4. Create StatCardView component for reusable stat display
5. Create QuickActionRow component for action items
6. Create RecentActivityRow component for session items
7. Implement data fetching in onAppear
8. Add pull-to-refresh with .refreshable
9. Verify compilation and preview rendering

## Acceptance Criteria

1. **Stat Cards Display**
   - Given dashboard data loaded
   - When view renders
   - Then 3 stat cards show Skills, MCPs, Plugins counts

2. **Quick Actions**
   - Given the dashboard
   - When viewing Quick Actions section
   - Then 4 action rows are visible with icons and labels

3. **Recent Activity**
   - Given sessions exist
   - When viewing Recent Activity
   - Then recent sessions are listed with timestamps

4. **Pull to Refresh**
   - Given the dashboard
   - When pulling down
   - Then data refreshes and UI updates

5. **Connection Status**
   - Given the toolbar
   - When viewing
   - Then connection status indicator is visible

6. **Compilation Success**
   - Given the DashboardView
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Views, Dashboard, Stats
- **Required Skills**: SwiftUI, MVVM, Async data loading, Custom components
