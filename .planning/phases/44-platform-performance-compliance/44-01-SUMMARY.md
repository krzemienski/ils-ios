---
phase: 44-platform-performance-compliance
plan: 01
status: complete
commit: d7848f0
requirements_closed: [PLAT-01, PLAT-02, PLAT-05, PLAT-06]
---

# Plan 44-01 Summary: Live Activity Wiring + Render Optimizations

## What Changed

### PLAT-01 & PLAT-02: Live Activity Dynamic Island
- **Info.plist**: Added `NSSupportsLiveActivities = true`
- **project.yml**: Added `NSSupportsLiveActivities: true` for XcodeGen regeneration safety
- **ChatViewModel.swift**: Added `sessionDisplayName` and `sessionModel` properties; wired `startLiveActivity()` when streaming starts, `updateLiveActivity()` during message processing, `endLiveActivity()` when streaming ends -- all guarded with `#if os(iOS)` and `#available(iOS 16.2, *)`
- Live Activity views (compact/expanded Dynamic Island layouts) already existed in `ILSLiveActivity.swift` -- this plan wired the lifecycle calls

### PLAT-06: drawingGroup() Metal Compositing
- **GlassCard.swift**: Added `.drawingGroup()` after `.shadow()` -- offloads shadow compositing to Metal for 30+ usage sites across 10 views
- **StatCard.swift**: Added `.drawingGroup()` after `.shadow()`, placed before `.scaleEffect()` to preserve press gesture interaction

### PLAT-05: .equatable() Render Skipping
- **AssistantCard.swift**: Added `Equatable` conformance comparing `message.id`, `text`, `toolCalls.count`, `toolResults.count`, `cost`, `tokenCount`
- **UserMessageCard.swift**: Added `Equatable` conformance comparing `message.id`, `message.text`
- **ChatMessageList.swift**: Added `.equatable()` modifier to both card types in ForEach
- **BrowserView.swift**: Extracted `browserRow()` to `BrowserRowView` struct (Equatable) and `pluginRow()` to `PluginRowView` struct (Equatable), both with `.equatable()` at call sites

## Files Modified (10)
- `ILSApp/ILSApp/Info.plist`
- `ILSApp/project.yml`
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- `ILSApp/ILSApp/Theme/GlassCard.swift`
- `ILSApp/ILSApp/Theme/Components/StatCard.swift`
- `ILSApp/ILSApp/Views/Chat/AssistantCard.swift`
- `ILSApp/ILSApp/Views/Chat/UserMessageCard.swift`
- `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift`
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift`

## Build Verification
- iOS: zero errors (warnings only)
- macOS: zero errors (warnings only)
