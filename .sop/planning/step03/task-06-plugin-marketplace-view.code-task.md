# Task: Create PluginMarketplaceView

## Description
Create the plugin marketplace view for browsing, installing, and managing Claude Code plugins. Show both installed plugins and available plugins from the marketplace.

## Background
Claude Code plugins are extensions available from marketplaces (official and community). The app allows browsing available plugins, installing them, and managing installed ones.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create PluginMarketplaceView with segmented control (Installed/Available)
2. Search field for filtering plugins
3. Display plugin cards with name, description, stars
4. Show install status (installed/not installed)
5. Install/Uninstall buttons based on status
6. Show plugin commands and agents when expanded
7. Filter by source (Official/Community)
8. Pull-to-refresh for marketplace data

## Dependencies
- ILSShared Plugin model
- ILSTheme styling
- APIClient for plugin operations

## Implementation Approach
1. Create ILSApp/ILSApp/Views/Plugins/PluginMarketplaceView.swift
2. Create PluginsViewModel with installed and available arrays
3. Add segmented picker for Installed/Available toggle
4. Add searchable modifier for filtering
5. Create PluginCardView component
6. Show install button for available, uninstall for installed
7. Add source filter picker (All/Official/Community)
8. Implement install/uninstall actions
9. Verify compilation and functionality

## Acceptance Criteria

1. **Segmented Control**
   - Given the PluginMarketplaceView
   - When rendered
   - Then Installed/Available picker is visible

2. **Search Field**
   - Given the plugin list
   - When typing in search
   - Then list filters to matching plugins

3. **Plugin Cards**
   - Given plugins loaded
   - When viewing cards
   - Then name, description, and star count are displayed

4. **Install Action**
   - Given an available plugin
   - When tapping Install
   - Then plugin is installed and status updates

5. **Uninstall Action**
   - Given an installed plugin
   - When tapping Uninstall
   - Then plugin is removed and status updates

6. **Source Filter**
   - Given the filter picker
   - When selecting Official
   - Then only official plugins are shown

7. **Compilation Success**
   - Given the PluginMarketplaceView
   - When building the project
   - Then build succeeds with zero errors

## Metadata
- **Complexity**: Medium
- **Labels**: iOS, SwiftUI, Views, Plugins, Marketplace
- **Required Skills**: SwiftUI Picker, List, Cards, Async actions
