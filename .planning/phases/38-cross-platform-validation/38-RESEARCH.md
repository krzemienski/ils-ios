# Phase 38: Cross-Platform Validation - Research

**Researched:** 2026-02-25
**Domain:** Cross-platform build verification, v1.0 REQ regression validation, iOS/iPadOS/macOS feature parity
**Confidence:** HIGH

## Summary

Phase 38 is a **verification-only phase** -- no new features, no code changes unless regressions are found. Its purpose is to confirm that all v3.1 changes from Phases 33-37 (Navigation & UX, Host Profiles, Settings Config Sync, Browse Skills & Plugins, System Monitor & Themes) compile and function correctly across iOS, iPadOS, and macOS, and that all 15 v1.0 audit requirements remain PASS.

The project has a unified AppState class in `ILSApp/ILSApp/AppState.swift` compiled by both iOS and macOS targets. The macOS app (`MacContentView.swift`) renders shared iOS views (`SettingsView`, `BrowserView`, `HomeView`, `SystemMonitorView`, `ChatView`, `HostProfilesView`, `ThemesListView`, `HooksManagementView`, `AgentTeamsListView`) directly in its detail column. This means v3.1 changes to these shared views automatically propagate to the macOS build. The primary risk areas are: (1) new iOS-only APIs introduced without `#if os(iOS)` guards, (2) macOS-specific views (`MacSettingsView`, `MacChatView`, `MacDashboardView`) that don't get the v3.1 feature parity updates, and (3) iPadOS layout differences (split view vs. sheet sidebar).

This phase follows an established pattern -- Phase 16 (v2.0 Cross-Platform Verification) and Phase 10 (v1.0 Final Gate) both used the same three-step approach: build all targets, fix any compilation errors, re-validate all prior REQs.

**Primary recommendation:** Build all three targets (iOS, macOS, Backend), fix any compilation errors from Phases 33-37, re-validate all 15 v1.0 REQs on iOS simulator, then verify feature parity across platforms with focused spot-checks on each v3.1 feature area.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| XP-01 | macOS builds with zero errors after all v3.1 changes (xcodebuild ILSApp + ILSMacApp exit 0, swift build exit 0) | Build verification procedure documented; risk areas identified (shared views, platform guards, AppState properties). Prior Phase 16 provides proven build verification template. |
| XP-02 | All v1.0 audit REQs (REQ-01 through REQ-15) remain PASS | Complete REQ checklist with descriptions catalogued from Phase 10 Final Gate; verification approach documented (code inspection + simulator spot-check). |
| XP-03 | iOS/iPadOS/macOS feature parity verified for all v3.1 changes (navigation, host profiles, settings, browse, system monitor, themes) | Feature-by-platform parity matrix documented below; macOS view architecture analyzed (shared iOS views in detail column); platform-specific divergence points identified. |
</phase_requirements>

## Architecture Patterns

### Cross-Platform View Architecture

```
MacContentView (macOS detail column)
├── HomeView()                  ← SHARED with iOS (v3.1 changes propagate)
├── ChatView(session:)          ← SHARED with iOS
├── SettingsView()              ← SHARED with iOS (has v3.1 config sync)
├── BrowserView()               ← SHARED with iOS (gets v3.1 browse changes)
├── SystemMonitorView()         ← SHARED with iOS (gets v3.1 system changes)
├── HostProfilesView()          ← SHARED with iOS (has v3.1 host profiles)
├── ThemesListView()            ← SHARED with iOS (gets v3.1 theme changes)
├── HooksManagementView()       ← SHARED with iOS
└── AgentTeamsListView()        ← SHARED with iOS

macOS-specific views (NOT in main routing):
├── MacSettingsView             ← SEPARATE macOS settings (NOT used in detail column)
├── MacChatView                 ← Used ONLY in SessionWindowView (multi-window)
├── MacDashboardView            ← UNUSED (MacContentView uses HomeView instead)
├── MacSessionsListView         ← Used in middle column
└── MacProjectsListView         ← Used in middle column
```

**Key insight:** Because `MacContentView.detailContent` directly instantiates the same shared iOS views, most v3.1 changes automatically work on macOS without any macOS-specific code. The risk is iOS-only APIs in those shared views that lack `#if os(iOS)` guards.

### Unified AppState (Consolidated Since v2.0)

The project now has a **single** `AppState` class at `ILSApp/ILSApp/AppState.swift`, compiled by both targets. Properties added in v3.1 phases that both targets use:

| Property | Added In | Used By |
|----------|----------|---------|
| `browserSegmentIntent: BrowserSegment?` | Phase 33 | Deep link segment routing |
| `activeHostName: String?` | Phase 33-34 | Sidebar host name display, HostProfilesVM |
| `updateServerURL(_:)` | Existing | Host switch propagation (Phase 34) |

Since AppState is shared, no macOS-specific property additions are needed.

### Platform Compatibility Layer (Existing)

| Shim File | What It Provides |
|-----------|-----------------|
| `PlatformCompat.swift` | `.inlineNavigationBarTitle()` (no-op on macOS), `UIKeyboardType`, `UITextAutocapitalizationType`, `ToolbarItemPlacement` macOS equivalents |
| `HapticManager.swift` | macOS no-op stubs for `impact()`, `notification()`, `selection()` |
| 30+ inline `#if os(iOS)` guards | Per-view iOS-specific code (haptics, keyboard, navigation style) |

### v3.1 Changes By Phase and Platform Impact

| Phase | iOS Changes | macOS Impact | Risk |
|-------|-------------|--------------|------|
| 33: Navigation & UX | `.inlineNavigationBarTitle()` on 4 views, `previousScreen` tracking, `browserSegmentIntent`, deep link segment routing | `.inlineNavigationBarTitle()` is a PlatformCompat no-op on macOS. `previousScreen` is `#if os(iOS)` guarded in ChatView. Deep links work via `MacContentView.handleNavigationIntent()`. | LOW |
| 34: Host Profiles | `HostProfilesViewModel` AppState injection, `activeHostName` persistence, `.onChange(of: appState.serverURL)` handlers on 8 views | All 8 views are shared -- macOS gets these handlers. However `MacContentView` itself does NOT have an onChange handler for host switching on its `sessionsViewModel`. | MEDIUM |
| 35: Settings Config Sync | `saveWithPatch()`, `settingAnnotation()` badges/tooltips, `onChange(isConnected)` auto-refresh | `SettingsView()` is shared -- macOS gets all config sync features. `MacSettingsView` is a separate file NOT used in main routing -- it lacks these features but is not in the user path. | LOW |
| 36: Browse Skills & Plugins | GitHub search, install progress, enable/disable toggles (TBD) | `BrowserView()` is shared -- macOS gets all browse changes. | LOW |
| 37: System Monitor & Themes | System monitor fixes, theme default loading, cross-platform theme consistency (TBD) | `SystemMonitorView()` is shared. Theme changes affect both platforms via `ThemeManager`. | LOW |

## v1.0 Audit REQs Checklist (15 Requirements)

All 15 must re-validate as PASS after Phases 33-37:

| REQ | Title | What to Verify | Risk from v3.1 |
|-----|-------|----------------|----------------|
| REQ-01 | Sidebar navigation | Sidebar opens/closes, all nav items route correctly, deep links work | MEDIUM -- Phase 33 changed deep link routing, added browserSegmentIntent |
| REQ-02 | Settings inheritance | Host defaults badge, per-host overrides | MEDIUM -- Phase 35 rewrote settings config sync, added badges |
| REQ-03 | Model defaults | Default model selection in new session | LOW -- not modified in v3.1 |
| REQ-04 | Skills accuracy | Skills list shows real data | MEDIUM -- Phase 36 may change skills list rendering |
| REQ-05 | Plugins + GitHub | Plugin list, GitHub browse/install | MEDIUM -- Phase 36 adds new browse/install UI |
| REQ-06 | Hooks management | Hooks screen with event types | LOW -- hooks screen not modified in v3.1 |
| REQ-07 | System monitor | Live metrics (CPU, Memory, Disk, Network) | MEDIUM -- Phase 37 targets system monitor fixes |
| REQ-08 | Fleet/Profiles | Host profiles, active indicator | HIGH -- Phase 34 redesigned Fleet to Host Profiles |
| REQ-09 | Quick actions | Quick action buttons on home screen | LOW -- Phase 33 verified ordering, minor spacing changes |
| REQ-10 | Settings tooltips | Info tooltip popovers | MEDIUM -- Phase 35 added tooltips to all fields |
| REQ-11 | Themes + previews | Theme picker, built-in themes | MEDIUM -- Phase 37 targets theme loading fixes |
| REQ-12 | MCP servers | MCP server list with health status | LOW -- not directly modified |
| REQ-13 | API structures | APIResponse wrappers, proper JSON | LOW -- backend API unchanged |
| REQ-14 | Visual regression | No layout breaks across all screens | MEDIUM -- multiple view changes across phases |
| REQ-15 | Sessions consistency | Session data matches between views | LOW -- session data flow unchanged |

**High-risk REQs requiring careful re-validation:** REQ-01 (navigation changes), REQ-02 (settings rewrite), REQ-08 (Fleet to Host Profiles redesign), REQ-14 (visual regression across all changes).

## Feature Parity Matrix (v3.1 Changes)

### Phase 33: Navigation & UX

| Feature | iOS | iPadOS | macOS | Parity Notes |
|---------|-----|--------|-------|-------------|
| Hamburger menu from all screens | `.inlineNavigationBarTitle()` on 9 views | Same (NavigationStack in sheet) | PlatformCompat no-op (macOS uses persistent sidebar) | Parity OK -- macOS sidebar is always visible |
| Chat back button | `previousScreen` tracking, `#if os(iOS)` back button | Same as iOS | `#if os(iOS)` guard -- macOS has no back button (3-column nav) | Parity OK -- macOS doesn't need back button |
| Home screen polish | Theme token spacing | Same as iOS | Shared `HomeView()` | Parity OK |
| Sidebar active host name | `activeHostName` display | Same as iOS | `MacContentView` sidebar header does NOT show `activeHostName` | GAP -- macOS sidebar shows connection status but not host name |
| Deep link segment routing | `browserSegmentIntent` consumed by `SidebarRootView` | Same as iOS | `MacContentView.handleNavigationIntent()` does NOT consume `browserSegmentIntent` | GAP -- macOS deep links navigate to Browser but don't select specific segment |

### Phase 34: Host Profiles

| Feature | iOS | iPadOS | macOS | Parity Notes |
|---------|-----|--------|-------|-------------|
| Host activation propagation | `AppState.updateServerURL()` | Same as iOS | Same (shared AppState) | Parity OK |
| ViewModel reload on host switch | 8 views with `.onChange(of: appState.serverURL)` | Same as iOS | Shared views get this. `MacContentView.sessionsViewModel` does NOT have onChange handler. | GAP -- macOS sessions list may not refresh on host switch (but shared views do) |
| Active profile indicator | Badge on host list row | Same as iOS | Shared `HostProfilesView()` | Parity OK |
| Health status badges | Colored dots per host | Same as iOS | Shared `HostProfilesView()` | Parity OK |
| "Host Profiles" naming | All UI strings updated | Same as iOS | `SidebarSection.hostProfiles = "Host Profiles"` | Parity OK |

### Phase 35: Settings Config Sync

| Feature | iOS | iPadOS | macOS | Parity Notes |
|---------|-----|--------|-------|-------------|
| Config values from host | `SettingsView` shows host config | Same as iOS | Shared `SettingsView()` in detail column | Parity OK |
| Inheritance badges | `settingAnnotation()` on all fields | Same as iOS | Shared `SettingsView()` | Parity OK |
| Config auto-refresh | `onChange(isConnected)` | Same as iOS | Shared `SettingsView()` | Parity OK |
| Tooltips | `SettingsInfoButton` on all fields | Same as iOS | Shared `SettingsView()` | Parity OK |
| `MacSettingsView` divergence | N/A | N/A | `MacSettingsView` is a separate file with NO config sync, NO badges, NO tooltips | INFO -- `MacSettingsView` not used in main routing but exists as dead code / alternate settings |

### Phases 36-37: Browse & System Monitor (TBD -- not yet implemented)

These phases have not started. Parity assessment will depend on implementation. Since both `BrowserView()` and `SystemMonitorView()` are shared views used by macOS, changes should propagate automatically.

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

All three must exit 0 with zero errors. Warnings are acceptable but should be noted.

### Step 2: Fix Any Build Errors

Common fix patterns from prior cross-platform phases:
- Missing `#if os(iOS)` guard: wrap the iOS-only block
- Missing macOS equivalent: add `#else` with macOS API or no-op
- Missing property on AppState: not applicable (unified AppState now)
- New import without guard: wrap `import UIKit` in `#if os(iOS)` or `#if canImport(UIKit)`

### Step 3: Re-Validate 15 v1.0 REQs on iOS

Boot simulator `50523130-57AA-48B0-ABD0-4D59CE455F14`, install fresh build, verify each REQ. Focus on high-risk REQs (01, 02, 08, 14) first.

For each REQ:
1. Define PASS criteria before checking
2. Navigate to relevant screen
3. Verify expected behavior
4. Screenshot key states as evidence
5. Record PASS/FAIL with evidence reference

### Step 4: Verify Feature Parity

For each v3.1 feature area, verify on both iOS and macOS:
- **Navigation (Phase 33):** Deep links, sidebar, back button on iOS / persistent sidebar on macOS
- **Host Profiles (Phase 34):** Activate host, verify all views reload, check sidebar indicator
- **Settings (Phase 35):** Config values, inheritance badges, tooltips, auto-refresh
- **Browse (Phase 36):** GitHub search, install, enable/disable (once Phase 36 is complete)
- **System Monitor (Phase 37):** Live metrics, theme loading (once Phase 37 is complete)

### Step 5: iPadOS Verification

iPadOS uses the same code as iOS but with different layout behavior:
- `NavigationSplitView` instead of sheet sidebar
- Wider screen may show split view instead of stacked navigation
- Verify: sidebar, detail views, and chat all render correctly in split view

iPadOS can be verified using the same simulator UDID if an iPad simulator is available, or by checking that no `UIDevice.current.userInterfaceIdiom == .phone` hardcodes exist in v3.1 changes.

## Known Parity Gaps to Investigate

| Gap | Severity | Location | Resolution |
|-----|----------|----------|------------|
| macOS sidebar does not show `activeHostName` | LOW | `MacContentView.sidebarContent` | Add host name display below connection status (matches iOS SidebarView pattern) |
| macOS deep links don't consume `browserSegmentIntent` | LOW | `MacContentView.handleNavigationIntent()` | Add `browserSegmentIntent` consumption to match iOS SidebarRootView pattern |
| macOS `sessionsViewModel` no host-switch reload | LOW | `MacContentView` | Add `.onChange(of: appState.serverURL)` to reconfigure and reload sessions |
| `MacSettingsView` lacks v3.1 features | INFO | `ILSMacApp/Views/MacSettingsView.swift` | Not in user path (detail column uses shared `SettingsView`). Consider deprecating or removing |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-platform compilation check | Manual file-by-file review | `xcodebuild` for both schemes | Build system catches all platform API errors at compile time |
| REQ regression testing | Custom test harness | ios-validation-runner protocol from Phase 10 | Already proven in Phase 10 and Phase 32 |
| Feature parity audit | Diffing iOS vs macOS view files | Feature matrix spot-check | macOS uses shared iOS views -- most parity is automatic |
| macOS-specific fixes | Separate macOS view copies | `#if os(iOS)` inline guards in shared views | Established pattern (90+ guards in codebase) |

## Common Pitfalls

### Pitfall 1: Assuming macOS Gets Everything Automatically

**What goes wrong:** A v3.1 change adds an iOS-specific feature (e.g., `.refreshable { }` with haptic feedback) that compiles on macOS but doesn't work correctly.
**Why it happens:** macOS compiles the shared views but some SwiftUI modifiers behave differently (`.refreshable` requires pull-to-refresh gesture on iOS but works via menu on macOS).
**How to avoid:** For each v3.1 feature, verify it WORKS on macOS, not just that it compiles.
**Warning signs:** Feature works on iOS but has no visible effect or different behavior on macOS.

### Pitfall 2: Forgetting MacContentView's sessionsViewModel

**What goes wrong:** After host switch, shared views reload correctly but the macOS sessions list in the middle column shows stale data.
**Why it happens:** `MacContentView` creates its own `sessionsViewModel` at line 55, but has no `.onChange(of: appState.serverURL)` handler to reconfigure it.
**How to avoid:** Add an onChange handler to MacContentView that reconfigures and reloads sessionsViewModel when serverURL changes.
**Warning signs:** Sessions list shows data from previous host after switching.

### Pitfall 3: MacSettingsView Confusion

**What goes wrong:** Tester navigates to Settings on macOS and sees the old `MacSettingsView` instead of the v3.1-updated shared `SettingsView`.
**Why it happens:** `MacContentView.detailContent` routes `.settings` to `SettingsView()` (shared), NOT `MacSettingsView()`. But `MacSettingsView` still exists and could be used in future routing changes.
**How to avoid:** Confirm `MacContentView.detailContent` uses `SettingsView()` for the `.settings` case. Consider deprecating `MacSettingsView` if it's not needed.
**Warning signs:** macOS settings page looks different from iOS settings page.

### Pitfall 4: iPadOS Split View Regression

**What goes wrong:** v3.1 navigation changes (previousScreen tracking, deep link segment routing) break on iPadOS where `NavigationSplitView` shows sidebar and detail simultaneously.
**Why it happens:** iPadOS split view means sidebar is always visible, so the sheet-based sidebar animation and back button behavior differ from iPhone.
**How to avoid:** Test on both iPhone and iPad simulators. Verify that `previousScreen` tracking doesn't cause issues when sidebar is persistently visible.
**Warning signs:** Back button appears on iPadOS when it shouldn't; sidebar doesn't dismiss after selection.

### Pitfall 5: Build Succeeds but Runtime Crash

**What goes wrong:** All builds pass with zero errors, but the app crashes at runtime on macOS due to a missing `@Environment` or mismatched view hierarchy.
**Why it happens:** Shared views expect environment objects injected by iOS `SidebarRootView`, but macOS `MacContentView` may inject them differently.
**How to avoid:** Launch the macOS app and navigate to every section. Check for crashes in System Console.
**Warning signs:** EXC_BAD_ACCESS or "Missing environment object" crash on specific macOS screens.

## iOS-Only API Audit Checklist

Files modified in Phases 33-37 that need platform guard verification:

| File | Modified In | iOS-Only Risk | Check For |
|------|-------------|---------------|-----------|
| `AppState.swift` | Phase 33-34 | LOW | `NetworkMonitor` is shared. No UIKit imports. |
| `SidebarRootView.swift` | Phase 33 | `#if os(iOS)` for back button | Verify back button guard exists |
| `ChatView.swift` | Phase 33-34 | `#if os(iOS)` for back button, haptics | Verify all guards exist |
| `HostProfilesView.swift` | Phase 34 | None expected | Verify no UIKit APIs |
| `HostProfilesViewModel.swift` | Phase 34 | None expected | Verify no UIKit APIs |
| `SettingsView.swift` | Phase 35 | Possible UIKit usage in tooltips | Verify guards exist |
| `SettingsConfigSection.swift` | Phase 35 | None expected | Verify no UIKit APIs |
| `SettingsViewModel.swift` | Phase 35 | None expected | Verify no UIKit APIs |
| `BrowserView.swift` | Phase 36 (TBD) | Existing `#if os(iOS)` guards | Verify new code respects guards |
| `SystemMonitorView.swift` | Phase 37 (TBD) | None expected | Verify no UIKit APIs |

## Build Commands

```bash
# iOS build (dedicated simulator)
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet

# macOS build
xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet

# Backend build
swift build

# Backend verification
lsof -i :9999 -P -n  # Binary path MUST be in ils-ios
curl -s http://localhost:9999/health

# iOS simulator setup
xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null || true
xcrun simctl status_bar 50523130-57AA-48B0-ABD0-4D59CE455F14 override \
  --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
```

## Open Questions

1. **iPadOS simulator availability**
   - What we know: The dedicated simulator is iPhone 16 Pro Max (UDID 50523130). iPad testing requires a separate simulator.
   - What's unclear: Whether an iPad simulator is available or if iPadOS verification should be code-inspection only.
   - Recommendation: Use code inspection for iPadOS (`#if os(iOS)` guards cover both iPhone and iPad). Only create an iPad simulator if runtime testing is explicitly requested.

2. **Phases 36-37 completion status at Phase 38 execution time**
   - What we know: Phase 36 has only RESUME.md. Phase 37 directory is empty. Phase 38 depends on both.
   - What's unclear: Whether Phase 38 should wait for complete Phases 36-37, or validate only completed phases (33-35).
   - Recommendation: Phase 38 MUST wait for Phases 36-37 to complete. The requirement says "all v3.1 changes verified." Partial validation is not meaningful.

3. **MacSettingsView disposition**
   - What we know: `MacSettingsView` exists but is NOT used in the main routing (`MacContentView.detailContent` uses `SettingsView()`). It has its own settings UI without v3.1 config sync features.
   - What's unclear: Whether it should be removed, deprecated, or kept as an alternative macOS-native settings layout.
   - Recommendation: Flag as informational finding. It's not in the user path, so it doesn't affect parity. Can be cleaned up in a future phase.

## Sources

### Primary (HIGH confidence)
- `ILSApp/ILSMacApp/Views/MacContentView.swift` -- macOS view routing confirmed: uses shared iOS views in detail column
- `ILSApp/ILSApp/AppState.swift` -- Unified AppState class compiled by both targets
- `.planning/phases/33-*/33-VERIFICATION.md` -- Phase 33 verification (5/5 truths, all NAV reqs satisfied)
- `.planning/phases/34-*/34-VERIFICATION.md` -- Phase 34 verification (5/5 truths, all HP reqs satisfied)
- `.planning/phases/35-*/35-VERIFICATION.md` -- Phase 35 verification (7/7 truths, all CFG reqs satisfied)
- `.planning/phases/10-final-gate/10-SUMMARY.md` -- v1.0 REQ baseline (15/15 PASS)
- `.planning/phases/16-cross-platform-verification/16-VERIFICATION.md` -- v2.0 cross-platform verification template (6/6 truths, COMPAT-01/02 satisfied)
- `ILSApp/ILSApp/Utils/PlatformCompat.swift` -- Cross-platform shim patterns

### Secondary (MEDIUM confidence)
- Phase 33-35 summaries documenting "both iOS and macOS builds pass with zero errors" after each plan execution
- Phase 32 final validation confirming all v1.5 builds green before v3.1 started

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies; same Apple SDK APIs and existing cross-platform patterns
- Architecture: HIGH -- Shared view architecture well-documented; macOS view routing confirmed via code analysis
- Pitfalls: HIGH -- All identified from direct codebase analysis and prior cross-platform verification experience (Phase 10, 16, 32)

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable -- verification-only phase with no external dependencies)
