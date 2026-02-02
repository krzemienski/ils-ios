# Task: Create Xcode Project for iOS App

## Description
Create the Xcode project for the ILSApp iOS application. Configure it as a SwiftUI app targeting iOS 17+, add the local ILSShared package as a dependency, and configure Info.plist for local network access.

## Background
The iOS app needs to communicate with the local Vapor backend over HTTP. This requires proper network permissions in Info.plist. The app uses SwiftUI and depends on shared models from the ILSShared package.

## Reference Documentation
**Required:**
- Design: .sop/planning/design/detailed-design.md

**Note:** You MUST read the detailed design document before beginning implementation.

## Technical Requirements
1. Create Xcode iOS App project named "ILSApp" in ILSApp/ directory
2. Configure Interface as SwiftUI, Language as Swift
3. Set minimum deployment target to iOS 17.0
4. Add local package dependency to ILSShared (from parent directory)
5. Add NSLocalNetworkUsageDescription to Info.plist
6. Add NSBonjourServices with _http._tcp to Info.plist

## Dependencies
- Package.swift from Task 0.2
- Xcode 15+ installed
- ILSShared target must build successfully

## Implementation Approach
1. Open Xcode and create new iOS App project
2. Configure project settings for iOS 17+ and SwiftUI
3. Add local package dependency pointing to root Package.swift
4. Link ILSShared to the app target
5. Update Info.plist with network usage permissions
6. Build and verify default ContentView displays

## Acceptance Criteria

1. **Project Opens Without Errors**
   - Given the Xcode project file
   - When opening in Xcode
   - Then no errors or warnings appear in project navigator

2. **Build Succeeds**
   - Given the configured project
   - When pressing Cmd+B to build
   - Then build completes with zero errors

3. **Simulator Launch**
   - Given the built app
   - When running on iOS Simulator
   - Then the default ContentView displays correctly

4. **Local Network Permissions**
   - Given the Info.plist configuration
   - When inspecting the plist
   - Then NSLocalNetworkUsageDescription and NSBonjourServices are present

## Metadata
- **Complexity**: Medium
- **Labels**: Setup, Xcode, iOS, SwiftUI, Configuration
- **Required Skills**: Xcode project configuration, iOS development, Info.plist
