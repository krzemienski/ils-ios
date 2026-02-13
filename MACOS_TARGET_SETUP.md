# macOS Target Setup Guide

## Current Status

✅ **All source files created**: 13 Swift files + assets exist in `<project-root>/ILSApp/ILSMacApp/`
❌ **Xcode target missing**: ILSMacApp target not added to ILSApp.xcodeproj
❌ **Cannot build**: Target required before E2E verification can proceed

## Problem

The implementation for the native macOS app is complete (Phases 1-5), but all source files exist only in the filesystem and are not integrated into the Xcode project. The xcodeproj Ruby gem cannot handle local Swift packages (XCLocalSwiftPackageReference), blocking automated project modification.

## Manual Setup Required (15 minutes)

### Step 1: Open Project in Xcode

```bash
cd <project-root>/ILSApp
open ILSApp.xcodeproj
```

### Step 2: Create macOS App Target

1. **File → New → Target**
2. Select **macOS → App**
3. Configure:
   - Product Name: `ILSMacApp`
   - Team: (your team)
   - Organization Identifier: `com.ils`
   - Bundle Identifier: `com.ils.mac`
   - Interface: SwiftUI
   - Language: Swift
   - Include Tests: ✅ (optional)
4. Click **Finish**
5. Xcode will create default files - **DELETE THESE**:
   - `ILSMacApp/ContentView.swift` (auto-generated)
   - `ILSMacApp/ILSMacAppApp.swift` (auto-generated, if different from existing)

### Step 3: Add Existing Source Files

The following files already exist and need to be added to the ILSMacApp target:

1. Right-click ILSMacApp group → **Add Files to "ILSApp"**
2. Navigate to `<project-root>/ILSApp/ILSMacApp/`
3. Select all existing files:
   - ✅ `ILSMacApp.swift` (main app file)
   - ✅ `AppDelegate.swift`
   - ✅ `Views/` folder (4 files)
   - ✅ `Managers/` folder (2 files)
   - ✅ `TouchBar/` folder (1 file)
   - ✅ `Assets.xcassets`
   - ✅ `Credits.rtf`
4. **Important**:
   - ☑️ Check "Copy items if needed": **NO** (files already in place)
   - ☑️ Select "Add to targets": **ILSMacApp**
   - ☑️ Create groups: **Yes**
5. Click **Add**

### Step 4: Link Shared Source Files

Add these existing iOS source files to the ILSMacApp target (multi-select in Project Navigator, check ILSMacApp in Target Membership):

**ViewModels** (all files in `ILSApp/ViewModels/`):
- ChatViewModel.swift
- SessionsViewModel.swift
- ProjectsViewModel.swift
- SkillsViewModel.swift
- MCPViewModel.swift
- PluginsViewModel.swift
- DashboardViewModel.swift

**Services** (all files in `ILSApp/Services/`):
- APIClient.swift
- SSEClient.swift
- AppLogger.swift (if exists)
- ThemeManager.swift
- TunnelService.swift (if exists)

**Models** (all files in `ILSApp/Models/`):
- All model files

**Shared Views** (if any):
- `ILSApp/Views/Components/` (all files)
- `ILSApp/Views/Shared/` (all files, if directory exists)

### Step 5: Link ILSShared Package

1. Select ILSMacApp target → **Build Phases**
2. Expand **Dependencies** section
3. Click **+** → Select **ILSShared** (local package)
4. Ensure it also appears in **Frameworks, Libraries, and Embedded Content**

### Step 6: Configure Build Settings

1. Select ILSMacApp target → **Build Settings**
2. Verify/Update:
   - **macOS Deployment Target**: 14.0
   - **Swift Language Version**: 5.0
   - **Code Signing**: Automatic
   - **Hardened Runtime**: YES
   - **App Sandbox**: YES (if using entitlements)

### Step 7: Verify Info.plist and Entitlements

The files already exist - just verify they're referenced correctly:

1. **Info.plist**: `ILSMacApp/Info.plist`
   - Should be auto-detected by Xcode
   - Verify in Build Settings → **Info.plist File**

2. **Entitlements**: `ILSMacApp/ILSMacApp.entitlements`
   - Verify in Build Settings → **Code Sign Entitlements**

### Step 8: Build and Verify

```bash
# From terminal:
cd <project-root>/ILSApp
xcodebuild -project ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' clean build
```

Expected output: `** BUILD SUCCEEDED **`

## Verification After Setup

Once the target is created and builds successfully, proceed to end-to-end verification:

1. ✅ Build succeeds with zero errors
2. ✅ Run macOS app - it launches
3. ✅ Connection to backend works
4. ✅ All menu items appear (File, Edit, View, Window)
5. ✅ Keyboard shortcuts work (Cmd+1-7, Cmd+N, Cmd+K, etc.)
6. ✅ Multi-window support (open session in new window)
7. ✅ Sidebar navigation works
8. ✅ Chat functionality works (send message, streaming response)

## Files Already Created

All implementation files exist and are ready to use:

```
ILSApp/ILSMacApp/
├── ILSMacApp.swift (main app entry point)
├── AppDelegate.swift (menu bar setup)
├── Info.plist
├── ILSMacApp.entitlements
├── Assets.xcassets/
│   └── AppIcon.appiconset/
├── Credits.rtf
├── Views/
│   ├── MacContentView.swift (NavigationSplitView)
│   ├── MacChatView.swift (chat interface)
│   ├── MacSessionsListView.swift (sessions list)
│   ├── MacDashboardView.swift (dashboard)
│   ├── MacProjectsListView.swift (projects)
│   ├── MacSettingsView.swift (settings)
│   └── SessionWindowView.swift (multi-window support)
├── Managers/
│   ├── WindowManager.swift (multi-window management)
│   └── NotificationManager.swift (native notifications)
└── TouchBar/
    └── ChatTouchBarProvider.swift (Touch Bar support)
```

## Troubleshooting

### Build Error: "No such module 'ILSShared'"
- Ensure ILSShared package is linked (Step 5)
- Clean build folder: Product → Clean Build Folder

### Build Error: "Undefined symbol: AppLogger"
- Ensure AppLogger.swift is added to ILSMacApp target (Step 4)

### Build Error: Missing imports
- Ensure all ViewModels and Services are added to target (Step 4)

### Linker Errors
- Verify all .swift files in ILSMacApp/ are in Compile Sources build phase
- Check Target Membership for each file

## Next Steps After Setup

Once the macOS target builds successfully:

1. Run the E2E verification test plan (see `E2E_VERIFICATION_PLAN.md`)
2. Execute manual verification checklist
3. Create UI tests (subtask 6-2)
4. Mark subtask 6-1 as complete
