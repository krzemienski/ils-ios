# Phase 16: Cross-Platform Verification - Research

**Researched:** 2026-02-23
**Domain:** macOS build compatibility, iOS-only API audit, v1.0 REQ regression validation
**Confidence:** HIGH

## Summary

Phase 16 is a **verification phase**, not an implementation phase. Its purpose is to confirm that all code changes from Phases 12-15 (service layer, ViewModel, SSE lifecycle, view rendering optimizations) compile and function correctly on macOS, and that all 15 v1.0 audit REQs remain PASS on iOS.

The codebase already has extensive cross-platform support: 90+ `#if os(iOS)` guards across 40+ files, a `PlatformCompat.swift` shim providing macOS no-ops for iOS-only modifiers, and a `HapticManager.swift` with full macOS fallbacks. The macOS app (`ILSMacApp/`) has 14 dedicated Swift files with its own `AppState` class in `ILSMacApp.swift`. The iOS app shares views, services, and ViewModels with macOS via the same Xcode project -- both targets compile files from `ILSApp/ILSApp/`.

The primary risk areas are: (1) iOS-only APIs introduced in Phases 13-15 without `#if os(iOS)` guards, specifically `UIApplication` notifications, `ProcessInfo.isLowPowerModeEnabled`, and memory pressure observers; (2) macOS `AppState` divergence from iOS `AppState` (macOS has its own copy in `ILSMacApp.swift` with fewer features like no `NetworkMonitor`); (3) animation lifecycle changes (Phase 22's `PulsingGlow`/`PulsingModifier` `isVisible` guards) that must work on both platforms.

**Primary recommendation:** Run all three builds (iOS, macOS, Backend), fix any compilation errors caused by missing `#if os()` guards, then re-validate all 15 v1.0 REQs on iOS simulator.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| COMPAT-01 | ILSMacApp scheme builds successfully on macOS 14+ with zero errors | Build verification procedure documented; known risk areas identified (iOS-only APIs in SSEClient, ILSAppApp, animation files) |
| COMPAT-02 | All 15 v1.0 audit REQs pass re-validation on iOS; iOS-only APIs have macOS guards | Complete REQ checklist catalogued; iOS-only API inventory compiled from codebase scan |
</phase_requirements>

## Architecture Patterns

### Project Structure (Cross-Platform)
```
ILSApp/
├── ILSApp/                    # Shared source (149+ Swift files)
│   ├── Views/                 # SwiftUI views (shared, #if os() guarded)
│   ├── ViewModels/            # @Observable VMs (shared)
│   ├── Services/              # APIClient, SSEClient, etc. (shared)
│   ├── Theme/                 # ThemeSnapshot, CyberpunkEffects (shared)
│   └── Utils/                 # PlatformCompat.swift, HapticManager.swift
├── ILSMacApp/                 # macOS-only (14 Swift files)
│   ├── Views/                 # MacContentView, MacDashboardView, etc.
│   ├── Managers/              # WindowManager, NotificationManager
│   ├── Services/              # SpotlightIndexer
│   ├── Commands/              # ILSCommands (menu bar)
│   ├── TouchBar/              # ChatTouchBarProvider
│   └── ILSMacApp.swift        # macOS @main + AppState
└── ILSApp.xcodeproj           # Both ILSApp and ILSMacApp schemes
```

### Key Architectural Difference: Dual AppState
The iOS and macOS targets each have their own `AppState` class:

- **iOS** (`ILSApp/ILSAppApp.swift`): Has `NetworkMonitor`, `lastSyncDate`, `isOffline` computed from `networkMonitor.isConnected`
- **macOS** (`ILSMacApp/ILSMacApp.swift`): Has `isOffline: Bool = false` (static), no `NetworkMonitor`

Both share: `connectionManager`, `pollingManager`, `navigationIntent`, `handleURL()`, `handleScenePhase()`.

This means any optimization that touches `AppState` must check BOTH copies.

### Cross-Platform Compatibility Shims

**PlatformCompat.swift** provides macOS no-ops for:
- `inlineNavigationBarTitle()` (wraps `navigationBarTitleDisplayMode(.inline)`)
- `UIKeyboardType` enum + `keyboardType()` modifier
- `UITextAutocapitalizationType` + `autocapitalization()` modifier
- `TextInputAutocapitalization` + `textInputAutocapitalization()` modifier
- `ToolbarItemPlacement.navigationBarTrailing` / `.navigationBarLeading`

**HapticManager.swift** provides macOS no-op stubs for `impact()`, `notification()`, `selection()`.

### Pattern: How Existing #if Guards Work

The codebase uses two guard patterns:

1. **File-level guard** (entire file is platform-specific):
```swift
#if os(iOS)
import UIKit
// ... entire file ...
#else
// macOS fallback
#endif
```
Used in: `HapticManager.swift`, `LiveActivity/ILSLiveActivity.swift`, `ShareSheet.swift`

2. **Inline guard** (specific code blocks within shared files):
```swift
#if os(iOS)
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification, ...)
#endif
```
Used in: `SSEClient.swift`, `ILSAppApp.swift`, `QuickConnectView.swift`, and 30+ view files

## iOS-Only API Inventory (Potential Phase 13-15 Risk Areas)

### Currently Guarded iOS-Only APIs

| API | File | Guard | Added By |
|-----|------|-------|----------|
| `UIApplication.didEnterBackgroundNotification` | `SSEClient.swift:55` | `#if os(iOS)` | Phase 22 (ENRG-05) |
| `UIApplication.didReceiveMemoryWarningNotification` | `ILSAppApp.swift:53` | `#if os(iOS)` | Phase 12 (MEM-01) |
| `UIKit` import | `SSEClient.swift:5` | `#if os(iOS)` | Phase 22 |
| `UIKit` import | `ILSAppApp.swift:6` | `#if canImport(UIKit)` | Original |
| `UIApplication.shared.sendAction` | `SSHSetupView.swift:350` | `#if os(iOS)` | Original |
| `UIApplication.shared.connectedScenes` | `SessionExporter.swift:16` | `#if os(iOS)` | Original |
| `ActivityKit` | `ILSLiveActivity.swift:4` | `#if os(iOS)` (file-level) | Original |
| `WidgetKit` | `Widgets/*.swift` | iOS target only | Original |
| `UIKit` | `TunnelSettingsView.swift:6` | `#if os(iOS)` (file-level) | Original |

### APIs Phases 13-15 May Introduce (MUST be guarded)

| Potential API | Phase | Risk | Guard Pattern |
|---------------|-------|------|---------------|
| `ProcessInfo.processInfo.isLowPowerModeEnabled` | Phase 14 (BATT-01) | iOS+macOS available, but semantics differ | Available on both -- no guard needed, but test on macOS |
| `UIApplication.didEnterBackgroundNotification` | Phase 14 (BATT-02) | iOS-only | `#if os(iOS)` required; use `NSApplication.didResignActiveNotification` on macOS |
| `NotificationCenter` for memory warnings | Phase 13 (MEM) | iOS-only UIKit notification | Already guarded in Phase 12; new usages need same pattern |
| `UIApplication.shared` | Any phase | iOS-only | Must use `#if os(iOS)` or `#if canImport(UIKit)` |
| `NSProcessInfo.thermalState` observers | Phase 14 | Available on both platforms | No guard needed |
| `DispatchSource.makeMemoryPressureSource` | Phase 13 | macOS+iOS | Available on both -- no guard needed |

### macOS Equivalents for iOS Background Lifecycle

| iOS API | macOS Equivalent | Notes |
|---------|-----------------|-------|
| `UIApplication.didEnterBackgroundNotification` | `NSApplication.didResignActiveNotification` | macOS apps rarely fully "background" |
| `UIApplication.willEnterForegroundNotification` | `NSApplication.didBecomeActiveNotification` | |
| `UIApplication.didReceiveMemoryWarningNotification` | `NSApplication.willTerminateNotification` or `DispatchSource.makeMemoryPressureSource` | macOS has no equivalent memory warning |
| `ScenePhase.background` | Works on macOS via SwiftUI | But macOS apps stay `.inactive` more than `.background` |

## v1.0 Audit REQs Checklist (15 Requirements)

All 15 must re-validate as PASS on iOS after Phases 12-15:

| REQ | Title | What to Verify | Risk from Optimization |
|-----|-------|----------------|----------------------|
| REQ-01 | Sidebar navigation | Sidebar opens/closes, all nav items route correctly | LOW -- navigation not touched by perf phases |
| REQ-02 | Settings inheritance | Host defaults badge, per-host overrides | LOW -- settings views untouched |
| REQ-03 | Model defaults | Default model selection in new session | LOW -- not in perf scope |
| REQ-04 | Skills accuracy | Skills list shows real data, no node_modules | LOW -- data loading timing may change with dedup |
| REQ-05 | Plugins + GitHub | Plugin list, GitHub browse/install | LOW -- same as REQ-04 |
| REQ-06 | Hooks management | Hooks screen with event types, config path | LOW -- not in perf scope |
| REQ-07 | System monitor | Live metrics (CPU, Memory, Disk, Network) | MEDIUM -- WebSocket lifecycle changes in Phase 14 |
| REQ-08 | Fleet/Profiles | Host profiles, backend connection | LOW -- not in perf scope |
| REQ-09 | Quick actions | Quick action buttons on home screen | LOW -- not in perf scope |
| REQ-10 | Settings tooltips | Info tooltip popovers | LOW -- not in perf scope |
| REQ-11 | Themes + previews | Theme picker, 12 built-in themes | LOW -- not in perf scope |
| REQ-12 | MCP servers | MCP server list with health status | MEDIUM -- MCP health check changed in Phase 18 |
| REQ-13 | API structures | APIResponse wrappers, proper JSON | LOW -- APIClient dedup is transparent |
| REQ-14 | Visual regression | No layout breaks across all screens | MEDIUM -- view layer rendering changes in Phase 15 |
| REQ-15 | Sessions consistency | Session data matches between Home and Sidebar | MEDIUM -- ViewModel/cache changes in Phase 13 |

**High-risk REQs requiring careful re-validation:** REQ-07, REQ-12, REQ-14, REQ-15.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| macOS background lifecycle | Custom window observer pattern | `NSApplication.didResignActiveNotification` + SwiftUI `scenePhase` | Already proven pattern in codebase |
| Platform API detection | Runtime `#available` checks | Compile-time `#if os()` guards | Catches errors at build time, not runtime |
| macOS memory pressure | UIKit memory warning ports | `DispatchSource.makeMemoryPressureSource` or skip (macOS has virtual memory) | macOS handles memory pressure fundamentally differently |
| Cross-platform view diffs | Separate macOS view copies | `#if os(iOS)` inline guards in shared views | Already 90+ guards in codebase -- consistent pattern |

## Common Pitfalls

### Pitfall 1: Forgetting macOS AppState is a Separate Class
**What goes wrong:** Changes to iOS `AppState` in `ILSAppApp.swift` are not reflected in macOS `AppState` in `ILSMacApp.swift`. Features like `NetworkMonitor` only exist on iOS.
**Why it happens:** Both files define `class AppState` but they are entirely separate implementations. Easy to miss when optimizing.
**How to avoid:** After any optimization that touches `AppState`, grep for the property in both files. If iOS gains a new property used by shared views/services, macOS must add it too (or the feature must be guarded).
**Warning signs:** macOS build fails with "Value of type 'AppState' has no member 'X'".

### Pitfall 2: UIKit Imports Without Guards
**What goes wrong:** `import UIKit` at the top of a shared file causes macOS build failure.
**Why it happens:** Phases 13-15 may add `UIApplication` background/foreground observers to shared services.
**How to avoid:** Always wrap UIKit imports in `#if os(iOS)` or `#if canImport(UIKit)`. Use the SSEClient pattern as reference.
**Warning signs:** macOS build error "No such module 'UIKit'".

### Pitfall 3: Background Lifecycle Asymmetry
**What goes wrong:** Phase 14 adds SSE/WebSocket disconnect on `UIApplication.didEnterBackgroundNotification`, but macOS never fires this notification, so connections never pause.
**Why it happens:** macOS apps rarely truly "background" -- they go `.inactive` but keep running.
**How to avoid:** For macOS, use `NSApplication.didResignActiveNotification` or accept that macOS keeps connections alive (which is actually the expected macOS behavior for desktop apps).
**Warning signs:** macOS connections never disconnect; battery usage higher than expected.

### Pitfall 4: Low Power Mode Availability
**What goes wrong:** `ProcessInfo.processInfo.isLowPowerModeEnabled` compiles on macOS but always returns `false` before macOS 12, and on macOS 12+ it reflects the system's Low Power Mode setting.
**Why it happens:** The API exists on macOS but Low Power Mode is a newer macOS feature.
**How to avoid:** The API is safe to use cross-platform. Just be aware that macOS behavior differs -- macOS Low Power Mode is opt-in and rare.
**Warning signs:** None for compilation; just behavioral difference.

### Pitfall 5: NetworkMonitor Missing on macOS
**What goes wrong:** Shared code references `NetworkMonitor.shared` but macOS `AppState` doesn't initialize it.
**Why it happens:** `NetworkMonitor` is in `ILSApp/ILSApp/Services/NetworkMonitor.swift` (shared), but macOS `AppState` doesn't use it.
**How to avoid:** `NetworkMonitor` is a singleton (`NetworkMonitor.shared`), so it can be accessed from any shared code. But macOS `AppState.isOffline` is a static `false` -- if any optimization routes through `appState.isOffline`, macOS will never report offline.
**Warning signs:** Offline detection doesn't work on macOS; polls continue when network is down.

## Verification Procedure

### Step 1: Build All Three Targets
```bash
# iOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -20

# macOS
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet 2>&1 | tail -20

# Backend
swift build 2>&1 | tail -10
```

### Step 2: Fix Any macOS Build Errors
Common fix patterns:
- Missing `#if os(iOS)` guard: wrap the iOS-only block
- Missing macOS equivalent: add `#else` with macOS API or no-op
- Missing property on macOS AppState: add matching property

### Step 3: Re-Validate 15 v1.0 REQs on iOS
Boot simulator `50523130-57AA-48B0-ABD0-4D59CE455F14`, install fresh build, verify each REQ via the app UI. Focus on high-risk REQs (07, 12, 14, 15) first.

### Step 4: Spot-Check macOS Functionality
Launch macOS build, verify:
- Sidebar navigation works (all 8 sections)
- Sessions list loads and sessions open
- System monitor shows live data
- Settings page renders
- No crashes on navigation

## macOS-Specific Build Considerations

### BUILD-04 Context
`BUILD-04` [MEDIUM] in REQUIREMENTS.md flags "Fix macOS target compiling all iOS files". Currently assigned to Phase 23. This means the macOS target may compile iOS-only files that happen to work because of `#if os()` guards. Phase 16 should NOT attempt to fix BUILD-04 -- just verify the build passes.

### macOS Target Files (14 files)
1. `ILSMacApp.swift` -- @main App + AppState
2. `AppDelegate.swift` -- Menu bar customization
3. `MacContentView.swift` -- NavigationSplitView (3-column)
4. `MacDashboardView.swift` -- Unused (MacContentView uses HomeView)
5. `MacChatView.swift` -- macOS chat with NSSavePanel
6. `MacSettingsView.swift` -- macOS settings
7. `MacSessionsListView.swift` -- Sessions sidebar
8. `MacProjectsListView.swift` -- Projects list
9. `SessionWindowView.swift` -- Multi-window support
10. `WindowManager.swift` -- Window lifecycle
11. `NotificationManager.swift` -- UNUserNotificationCenter
12. `SpotlightIndexer.swift` -- Spotlight search indexing
13. `ILSCommands.swift` -- Menu bar commands
14. `ChatTouchBarProvider.swift` -- Touch Bar (guarded `#if os(macOS)`)

### Shared Files Both Targets Compile
All files in `ILSApp/ILSApp/` are compiled by both targets (per BUILD-04 note). The `#if os()` guards make this work. Key shared files with iOS-only code:
- `Services/SSEClient.swift` -- UIKit background notification (guarded)
- `ILSAppApp.swift` -- Memory warning observer (guarded), but this is also the iOS @main so macOS should NOT compile it (it has its own @main)
- `Utils/HapticManager.swift` -- Full macOS fallback
- `Utils/PlatformCompat.swift` -- macOS no-op shims
- `Views/Shared/ShareSheet.swift` -- `#if os(iOS)` file-level guard
- `LiveActivity/ILSLiveActivity.swift` -- `#if os(iOS)` file-level guard
- 30+ view files with inline `#if os(iOS)` guards for haptics, keyboard, navigation style

## Open Questions

1. **How does the Xcode project handle dual @main?**
   - What we know: iOS has `@main struct ILSAppApp` in `ILSAppApp.swift`, macOS has `@main struct ILSMacApp` in `ILSMacApp.swift`. Both exist in the project.
   - What's unclear: Whether `ILSAppApp.swift` is excluded from the macOS target's compile sources (it should be, or both `@main` would conflict).
   - Recommendation: Verify target membership in Xcode project before running the macOS build. If it builds today (Phase 24 confirmed it does), this is already handled.

2. **Will Phase 13-15 changes require new macOS AppState properties?**
   - What we know: macOS AppState is a separate class with fewer features. Phases 13-15 are not yet implemented.
   - What's unclear: Whether new ViewModel optimizations will depend on AppState properties that only exist on iOS.
   - Recommendation: After Phases 13-15, check each new AppState property/method and add to macOS if used by shared code.

## Sources

### Primary (HIGH confidence)
- Codebase scan: 90+ `#if os()` guards found across 40+ files via ripgrep
- `ILSApp/ILSApp/Utils/PlatformCompat.swift` -- cross-platform shim patterns
- `ILSApp/ILSApp/Utils/HapticManager.swift` -- full macOS fallback pattern
- `ILSApp/ILSApp/Services/SSEClient.swift` -- iOS-only UIKit guard pattern (Phase 22)
- `ILSApp/ILSMacApp/ILSMacApp.swift` -- macOS AppState divergence documented
- `.planning/phases/10-final-gate/10-SUMMARY.md` -- v1.0 REQ baseline (15/15 PASS)
- `.planning/ROADMAP.md` -- Phase 16 success criteria and COMPAT-01/02

### Secondary (MEDIUM confidence)
- Phase 24 validation (v3.0) confirmed all 3 builds pass as of 2026-02-23
- BUILD-04 documents known issue of macOS compiling iOS files (Phase 23 scope)
- Phase 22 decisions document SSE background disconnect pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies; all Apple SDK APIs with established patterns
- Architecture: HIGH -- cross-platform patterns already established in codebase (90+ guards)
- Pitfalls: HIGH -- all identified from direct codebase analysis and documented Phase 12-22 decisions

**Research date:** 2026-02-23
**Valid until:** 2026-03-23 (stable -- no external dependencies)
