# Phase 54: Navigation, Profiles & Polish - Research

**Researched:** 2026-02-28
**Domain:** SwiftUI Navigation, Host Profile Switching, System Metrics, Backend File Scanning
**Confidence:** HIGH

## Summary

Phase 54 addresses five distinct requirements spanning the iOS Home screen, session data consistency, host profile switching UX, system monitor metrics, and backend skills file scanning. All five areas have existing implementations that need targeted enhancements rather than greenfield development.

The Home screen already has a Quick Actions grid with four cards (Discover Skills, Configure MCP, Browse Plugins, Edit Settings) but is missing "New Session" -- the most common user action. The recent sessions on Home use the shared `SessionsViewModel` from `SidebarRootView`, which should ensure data consistency with the dedicated Sessions list, but the Home screen shows only 5 items via `prefix(5)` while the sidebar shows all sessions -- the requirement demands exact data parity in count, order, and content. Host profile switching already updates the `AppState.activeHostName` and persists via UserDefaults, and the sidebar already displays the active host name, but there is no visual confirmation feedback (banner/toast) when switching. The System Monitor already renders real-time CPU, memory, disk, and network via WebSocket with automatic fallback to REST polling. Skills file scanning already excludes `node_modules` via `SkillsFileService.excludedDirectories` -- this needs verification, not implementation.

**Primary recommendation:** This phase is predominantly UI polish and data consistency work on the iOS side with one backend verification task. No new libraries, no architectural changes. Focus on targeted additions to existing views and view models.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAV-01 | Home screen displays quick action shortcuts above recent sessions | Home screen already has a `quickActionsGrid` with 4 cards. Need to add "New Session" card (triggers existing `showNewSessionSheet`) and potentially "System Monitor" card. Cards are already positioned above `recentSessionsSection` in the VStack. |
| NAV-02 | Home recent sessions list matches dedicated Sessions screen data exactly | Both Home and Sidebar use the same shared `SessionsViewModel` instance from `SidebarRootView`. Home currently does `Array(sessionsVM.sessions.prefix(5))` -- the discrepancy is the `prefix(5)` cap vs showing all. Need to align display logic: either show all with a "Show All" link, or ensure the visible subset is identical in sort order and content fields. The actual data source is already shared. |
| PROF-01 | Profile switching updates settings context with visual feedback showing which host's config is active | `HostProfilesViewModel.activate()` already calls `appState.updateServerURL()` and sets `appState.activeHostName`. Sidebar already shows the active host name. Missing: visual confirmation feedback (toast/banner) on switch, and a persistent indicator on the Home screen or settings context showing which host is active. |
| PROF-02 | System monitor shows real-time CPU, memory, disk, and network metrics from connected host | `SystemMonitorView` already renders all four metric types via `MetricsWebSocketClient` with live charts (CPU line chart, Memory/Disk progress rings, Network dual-series chart). Load average and process list also present. The view connects on `onAppear` and disconnects on `onDisappear`. It reacts to `appState.serverURL` changes. This requirement appears to already be met -- needs verification evidence. |
| FOUND-02 | Skills file scanning confirmed to exclude node_modules directories | `SkillsFileService.swift` line 143 has `excludedDirectories` Set containing `"node_modules"` as the first entry. The recursive scan in `scanSkillsRecursively()` checks `Self.excludedDirectories.contains(item)` before recursing into subdirectories. This is already implemented -- needs verification evidence only. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ / macOS 14+ | All UI views (HomeView, HostProfilesView, SystemMonitorView) | Project standard; `@Observable`, `NavigationStack` |
| Swift Charts | iOS 17+ | CPU and network time-series charts in SystemMonitorView | Already in use for system monitor |
| ILSShared | internal | Shared DTOs (ChatSession, FleetHost/HostProfile, SystemMetricsResponse) | Monorepo shared package |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TipKit | iOS 17+ | Onboarding tips on Home screen (CreateSessionTip) | Already integrated in HomeView |
| URLSession WebSocket | iOS 17+ | Live metrics streaming (MetricsWebSocketClient) | Already in use; no changes needed |

### Alternatives Considered

None. This phase requires no new dependencies -- all work uses existing project infrastructure.

## Architecture Patterns

### Existing Architecture (No Changes Needed)

```
SidebarRootView (owns shared SessionsViewModel)
├── SidebarView (reads sessionsVM)
├── HomeView (reads sessionsVM, owns DashboardViewModel)
├── SystemMonitorView (owns SystemMetricsViewModel → MetricsWebSocketClient)
└── HostProfilesView (owns HostProfilesViewModel)
```

### Pattern 1: Shared ViewModel for Session Data Consistency (NAV-02)

**What:** `SidebarRootView` owns a single `SessionsViewModel` instance and passes it to both `SidebarView` and `HomeView`. This ensures both consumers see the same data.

**When to use:** Already in use. The data discrepancy comes from HomeView's `prefix(5)` display limit, not from different data sources.

**Key code (current):**
```swift
// SidebarRootView.swift line 117
@State private var sessionsVM = SessionsViewModel()

// Passed to HomeView (line 367)
HomeView(sessionsVM: sessionsVM, ...)

// HomeView shows prefix(5)
let displaySessions = Array(sessionsVM.sessions.prefix(5))
```

**Fix approach:** Remove the `prefix(5)` cap or add a "View All" button that navigates to the sessions screen. The requirement says "exact same data (count, order, content)" -- this means either showing all sessions or making the Home "Recent Sessions" section explicitly match the Sessions screen's display. Since showing thousands of sessions on the home screen is poor UX, the correct interpretation is: what IS shown must match (same sort order, same fields, same content) and there should be a count/link making the full list accessible.

### Pattern 2: Profile Switch Feedback via Toast/Banner

**What:** Show a transient visual confirmation when the active host profile changes.

**When to use:** After `HostProfilesViewModel.activate()` succeeds.

**Approach options:**
1. **Banner approach** (recommended): Add a transient banner similar to the existing `refreshingBanner` in HomeView. Show "Switched to {hostName}" for 3 seconds with animation.
2. **Toast approach**: Use a custom toast overlay at the bottom of the screen.
3. **Alert approach**: Use a SwiftUI `.alert()` -- heaviest UX, not recommended.

**Implementation:** Add a `@State var profileSwitchBanner: String?` to the containing view or AppState, set it from `activate()`, and auto-dismiss after a delay.

### Pattern 3: Quick Action Cards (NAV-01)

**What:** The Home screen's quick action grid uses a `LazyVGrid` with two columns. Each card is a `quickActionCard()` function taking icon, title, subtitle, color, and action.

**Current cards:**
1. "Discover Skills" -> `onNavigateToBrowser?(.skills)`
2. "Configure MCP" -> `onNavigateToBrowser?(.mcp)`
3. "Browse Plugins" -> `onNavigateToBrowser?(.plugins)`
4. "Edit Settings" -> `onNavigate?(.settings)`

**Missing (per requirements):** "New Session" shortcut. The success criteria says "e.g., New Session, Browse Skills, Configure MCP" -- New Session is the first example.

**Fix:** Add a "New Session" card that triggers `showNewSessionSheet = true`. This sheet already exists in HomeView.

### Anti-Patterns to Avoid

- **Creating a separate SessionsViewModel for Home:** Home and Sidebar MUST share the same instance. The current architecture already does this correctly via SidebarRootView.
- **Polling system metrics when view is not visible:** SystemMonitorView already correctly connects on `onAppear` and disconnects on `onDisappear`. Do not change this.
- **Storing active host ID in multiple places:** AppState.activeHostName and UserDefaults are already the single source of truth. Do not add another store.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Transient banner/toast | Custom toast overlay system | Simple `@State` property + `.task(id:)` auto-dismiss | SwiftUI's native animation + conditional rendering is simpler than building a toast framework |
| WebSocket metrics client | New metrics client | Existing `MetricsWebSocketClient` with REST fallback | Already battle-tested with reconnection, heartbeat, fallback polling |
| Session data consistency | Separate data fetch for Home | Shared `SessionsViewModel` from SidebarRootView | Already correctly shared; fix the display, not the data source |

**Key insight:** Every "implementation" in this phase is a targeted modification to existing code, not a new system. The risk is over-engineering simple changes.

## Common Pitfalls

### Pitfall 1: Breaking Session Sort Order Parity

**What goes wrong:** Home screen shows sessions in a different order than the Sessions screen because of different sorting logic.
**Why it happens:** Home uses `sessionsVM.sessions.prefix(5)` (order from API: most recent first). The Sessions screen might use `groupedSessions` (grouped by project) or `groupedSessionsByTime` (grouped by time period).
**How to avoid:** Verify that both Home and the sidebar/sessions views use the same base `sessions` array from `SessionsViewModel`. The Home shows a flat list of the most recent; the sidebar shows time-grouped. These are different views of the same data. The requirement "exact same data" should mean: the sessions shown on Home are a subset of those on the Sessions screen, in the same order, with the same fields displayed.
**Warning signs:** If a session appears on the Sessions screen but not on Home (or vice versa), or if the order differs.

### Pitfall 2: Profile Switch Not Updating System Monitor Base URL

**What goes wrong:** Switching host profiles changes `appState.serverURL` but the SystemMonitorView doesn't pick up the new URL if it was already displayed.
**Why it happens:** SystemMonitorView has `.onChange(of: appState.serverURL)` which calls `viewModel.updateBaseURL(newURL)` and reconnects. This should work. But if the user is on the System Monitor screen when switching profiles, the WebSocket needs to reconnect to the new host.
**How to avoid:** Verify the existing `.onChange` handler in SystemMonitorView works end-to-end when the server URL changes mid-session.
**Warning signs:** System metrics showing data from the old host after a profile switch.

### Pitfall 3: Home Quick Actions Grid Layout Breaking on iPad

**What goes wrong:** Adding a 5th quick action card (New Session) to the 2-column LazyVGrid creates an asymmetric layout with one card orphaned in the last row.
**Why it happens:** 5 items / 2 columns = 2 full rows + 1 orphan.
**How to avoid:** Either use 3 columns (for 5-6 items), keep 2 columns and accept the orphan (it stretches to fill via `.flexible()`), or use an even number of cards (add a 6th like "System Monitor").
**Warning signs:** Ugly layout with a single wide card at the bottom of the grid.

### Pitfall 4: UserDefaults activeHostName Stale After App Update

**What goes wrong:** `activeHostName` is stored in UserDefaults as a string. If a host is removed, the stale name persists until another host is activated.
**Why it happens:** `HostProfilesViewModel.remove()` only clears `activeHostName` if the removed host was the active one. This is correct. But if the backend loses the host profile data (e.g., database reset), the UserDefaults value becomes orphaned.
**How to avoid:** On app launch, validate that the persisted `activeHostName` corresponds to an actual host profile from the API response. Already partially handled: `HostProfilesViewModel.loadHosts()` sets `activeHostId` from the API response.
**Warning signs:** Sidebar shows a host name that doesn't exist in the Host Profiles list.

### Pitfall 5: node_modules Exclusion Not Covering Symlinked Directories

**What goes wrong:** `SkillsFileService.scanSkillsRecursively()` checks `Self.excludedDirectories.contains(item)` against the directory name. If `node_modules` is a symlink, `FileManager.contentsOfDirectory` still returns it as a directory entry, and the name check will still match.
**How to avoid:** The current implementation is correct -- it checks the name `"node_modules"` regardless of whether it's a real directory or symlink. But the `scanPluginCacheSkills()` method resolves symlinks for `visitedSkillDirs` deduplication, which is a separate concern. No change needed.
**Warning signs:** Skills list suddenly showing thousands of entries after installing a JS-based skill/plugin.

## Code Examples

### Adding "New Session" Quick Action Card to HomeView

```swift
// In HomeView.swift, quickActionsGrid, add before or after existing cards:
quickActionCard(
    icon: "plus.bubble.fill",
    title: "New Session",
    subtitle: nil,
    color: theme.entitySession
) {
    showNewSessionSheet = true
}
```

### Profile Switch Confirmation Banner

```swift
// In HostProfilesView or a parent view:
@State private var switchBannerText: String?

// After successful activation:
switchBannerText = "Switched to \(host.name)"
Task {
    try? await Task.sleep(for: .seconds(3))
    switchBannerText = nil
}

// In the view body:
if let bannerText = switchBannerText {
    HStack {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(theme.success)
        Text(bannerText)
            .font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
    }
    .padding(theme.spacingMD)
    .background(theme.success.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
    .transition(.move(edge: .top).combined(with: .opacity))
}
```

### Session Data Consistency Fix

```swift
// In HomeView.swift, recentSessionsSection:
// BEFORE (causes count discrepancy):
let displaySessions = Array(sessionsVM.sessions.prefix(5))

// AFTER (show same data, with "View All" link):
let displaySessions: [ChatSession] = {
    if isSearching {
        return sessionsVM.sessions.filter {
            $0.displayName.localizedCaseInsensitiveContains(sessionSearchText)
        }
    } else {
        return Array(sessionsVM.sessions.prefix(5))
    }
}()

// Add "View All" button in the header:
HStack {
    Text("Recent Sessions")
    Spacer()
    Button("View All (\(sessionsVM.totalCount))") {
        onNavigate?(.browser)  // or a dedicated sessions screen
    }
}
```

Note: The key insight for NAV-02 is that the data source is already shared. The "discrepancy" is in presentation (prefix cap, field display). The fix ensures what IS shown matches exactly, and provides navigation to the full list.

### Active Host Indicator on Home Screen

```swift
// In HomeView.swift welcomeSection, after the server URL text:
if let hostName = appState.activeHostName {
    HStack(spacing: theme.spacingXS) {
        Image(systemName: "desktopcomputer")
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
        Text(hostName)
            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
    }
    .padding(.horizontal, theme.spacingSM)
    .padding(.vertical, 4)
    .background(theme.accent.opacity(0.1))
    .clipShape(Capsule())
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.fleet` enum case | `.hostProfiles` enum case with `.fleet` alias | Phase 49 (v5.0) | All navigation and deep links use hostProfiles; fleet is backward-compat alias |
| Direct MetricsWebSocketClient usage | SystemMetricsViewModel wrapper | v3.1 (Phase 34) | ViewModel owns lifecycle, exposes computed properties for charts |
| DashboardViewModel owns session data | Shared SessionsViewModel from SidebarRootView | v3.1 (Phase 34) | Single source of truth for sessions across sidebar and home |

**Deprecated/outdated:**
- `MacDashboardView`: Marked as unused (comment: "MacContentView uses HomeView instead"). Retained for potential future use. Has its own `SessionsViewModel` instance which is the WRONG pattern -- but since it's never instantiated outside previews, this is a non-issue.

## Open Questions

1. **NAV-02 "exact same data" interpretation**
   - What we know: Home uses `prefix(5)` of the shared `sessionsVM.sessions`. The Sessions screen shows all sessions grouped by time or project.
   - What's unclear: Does "exact same data" mean the Home must show ALL sessions (impractical for 22K+), or that the visible subset must use identical sort order and display fields?
   - Recommendation: Show same sort order and fields for the visible subset, add a "View All (N)" link that navigates to the dedicated sessions view. The count shown on Home should match `sessionsVM.totalCount` (the total, not the displayed subset).

2. **Profile switch feedback location**
   - What we know: The switch happens in HostProfilesView via the context menu. AppState updates immediately.
   - What's unclear: Should the confirmation banner appear on the HostProfiles screen, or globally (visible on any screen)?
   - Recommendation: Show the banner in HostProfilesView (where the action happened) and also update the Home screen's welcome section to show the active host badge. The sidebar already shows the host name -- verify it updates instantly.

3. **PROF-02 scope -- is this already complete?**
   - What we know: SystemMonitorView already displays real-time CPU, memory, disk, and network from the connected host. WebSocket streaming is live.
   - What's unclear: Is the requirement asking for something beyond what already exists?
   - Recommendation: Capture verification evidence showing the system monitor working with live data. If the metrics update visibly while the screen is open, this requirement is met. No new implementation needed -- just evidence.

## Sources

### Primary (HIGH confidence)

- Codebase inspection: `ILSApp/ILSApp/Views/Home/HomeView.swift` -- current quick actions grid, session display logic
- Codebase inspection: `ILSApp/ILSApp/ViewModels/SessionsViewModel.swift` -- shared session data source, caching, search
- Codebase inspection: `ILSApp/ILSApp/Views/HostProfiles/HostProfilesView.swift` -- host list, activate action
- Codebase inspection: `ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift` -- activate(), AppState update, UserDefaults persistence
- Codebase inspection: `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` -- full system monitor with all four metric types
- Codebase inspection: `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` -- WebSocket lifecycle, process auto-refresh
- Codebase inspection: `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` -- WebSocket with REST fallback, reconnection
- Codebase inspection: `Sources/ILSBackend/Services/SkillsFileService.swift` -- excludedDirectories includes node_modules
- Codebase inspection: `ILSApp/ILSApp/AppState.swift` -- activeHostName property, URL handling
- Codebase inspection: `ILSApp/ILSApp/Views/Root/SidebarView.swift` -- active host indicator in sidebar header
- Codebase inspection: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` -- shared SessionsViewModel ownership, screen routing

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, all existing infrastructure
- Architecture: HIGH - Direct codebase inspection of all affected files
- Pitfalls: HIGH - Based on actual code patterns and known project history (MEMORY.md)

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (stable -- no external dependency changes)
