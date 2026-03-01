---
phase: 44-platform-performance-compliance
plan: 02
status: complete
commit: a5ccf96
requirements_closed: [PLAT-03, PLAT-04, PLAT-07, PLAT-08]
---

# Plan 44-02 Summary: TipKit Sequential Unlock + Cellular Data Toggle

## What Changed

### PLAT-07 & PLAT-08: TipKit Tips with Sequential Unlock Rules
- **AppTips.swift**: Complete rewrite with 6 tips, each with `@Parameter`-based sequential unlock rules:
  1. `ServerSetupTip` -- shown when no backend configured (no rules)
  2. `CreateSessionTip` -- unlocks when `isConnected = true`
  3. `CommandPaletteTip` -- unlocks when `hasCreatedSession = true`
  4. `ThemeTip` -- unlocks when `appOpenCount >= 5`
  5. `MCPBrowserTip` -- unlocks when `hasCreatedSession = true` AND `appOpenCount >= 3`
  6. `TeamsTip` -- unlocks when `hasViewedMCP = true`
- **ILSAppApp.swift**: App open count tracking and donation to ThemeTip/MCPBrowserTip
- **HomeView.swift**: Added `CommandPaletteTip` TipView
- **NewSessionView.swift**: Donates `hasCreatedSession` to CommandPaletteTip and MCPBrowserTip on session creation
- **ThemesListView.swift**: Added `ThemeTip` TipView at top of list
- **BrowserView.swift**: Added `MCPBrowserTip` TipView in MCP section; donates `hasViewedMCP` to TeamsTip on appear
- **AgentTeamsListView.swift**: Added `TeamsTip` TipView at top of scroll content

### PLAT-04: Cellular Data Toggle
- **SettingsConnectionSection.swift**: Added `#if os(iOS)` cellular data toggle with `UserDefaults` binding (key: `allowsCellularAccess`, defaults to true)
- **APIClient.swift**: Reads `allowsCellularAccess` from UserDefaults into URLSession configuration
- **SSEClient.swift**: Reads `allowsCellularAccess` from UserDefaults into URLSession configuration

### PLAT-03: asyncAfter Elimination (Verified)
- Grep confirms zero `asyncAfter` or `DispatchQueue.main.async` calls in entire `ILSApp/ILSApp/` directory
- Already compliant before this plan; verified and documented

## Files Modified (10)
- `ILSApp/ILSApp/Views/Tips/AppTips.swift`
- `ILSApp/ILSApp/ILSAppApp.swift`
- `ILSApp/ILSApp/Views/Home/HomeView.swift`
- `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift`
- `ILSApp/ILSApp/Views/Themes/ThemesListView.swift`
- `ILSApp/ILSApp/Views/Browser/BrowserView.swift`
- `ILSApp/ILSApp/Views/Teams/AgentTeamsListView.swift`
- `ILSApp/ILSApp/Views/Settings/SettingsConnectionSection.swift`
- `ILSApp/ILSApp/Services/APIClient.swift`
- `ILSApp/ILSApp/Services/SSEClient.swift`

## Build Verification
- iOS: zero errors (warnings only)
- macOS: zero errors (warnings only)
