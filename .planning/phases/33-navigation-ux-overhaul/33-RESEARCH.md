# Phase 33: Navigation & UX Overhaul - Research

**Researched:** 2026-02-24
**Domain:** SwiftUI navigation architecture, toolbar management, deep link routing, sidebar UX
**Confidence:** HIGH

## Summary

Phase 33 is a pure iOS/macOS UI phase with zero backend changes. The codebase is in better shape than the prior research suggested. Direct code inspection reveals that **no child views add conflicting `.topBarLeading` toolbar items** -- the hamburger menu is the sole `.topBarLeading` item in the entire codebase. The real issues are: (1) four ActiveScreen destination screens are missing `.inlineNavigationBarTitle()`, (2) chat has no back button because it's rendered as a flat `ActiveScreen` enum swap rather than a NavigationStack push, (3) the sidebar header shows no active host indicator, and (4) deep links need a stale-state audit.

The chat back button is the most architecturally significant change. The current `ActiveScreen` enum-swap model provides no navigation history -- switching `activeScreen` to `.chat(session)` destroys the previous screen entirely. A real back button requires either: (a) converting chat to a `NavigationPath.append()` push within the existing NavigationStack, or (b) tracking the "previous screen" in a simple `@State` property and providing a custom back button that swaps `activeScreen` back. Option (b) is dramatically simpler and fits within the existing architecture without risking `@SceneStorage` conflicts.

**Primary recommendation:** Fix the four missing `.inlineNavigationBarTitle()` calls first, add a custom back button to ChatView using a tracked `previousScreen` state, show active host name in sidebar header, and audit deep links for stale state -- all achievable without architectural changes to the navigation model.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAV-01 | Hamburger/side menu accessible from ALL screens -- child views must not add conflicting `.topBarLeading` toolbar items | Verified: no conflicts exist. Only SidebarRootView:272 uses `.topBarLeading`. All child views use `.primaryAction`, `.navigationBarTrailing`, or `.automatic`. Hamburger is already visible on all screens. May need functional verification only. |
| NAV-02 | Chat session has a back button to return to sessions list -- requires ActiveScreen push/pop instead of flat enum swap | Research provides two implementation approaches: (a) NavigationPath push (high complexity, @SceneStorage conflict risk), (b) tracked `previousScreen` with custom back button (low complexity, fits existing architecture). Recommend option (b). |
| NAV-03 | Home screen layout polish -- stats cards, quick actions ordering, consistent spacing | HomeView.swift inspected: layout uses `theme.spacingLG/MD/SM` consistently, LazyVGrid with 2 columns, section ordering is Welcome > Connection > Tip > Quick Actions > Recent Sessions > Stats. No spacing issues found in code -- may need visual verification. |
| NAV-04 | Sidebar shows active host name indicator below header | SidebarView.swift headerSection shows "ILS" + connection URL. No host profile name shown. `AppState` has no `activeHostName` property. Need to add `activeHostName: String?` to AppState and display it in sidebar header. |
| NAV-05 | Deep link navigation works consistently across all registered `ils://` routes | AppState.handleURL() covers: home, sessions/{uuid}, browser, projects, plugins, mcp, skills, settings, system, fleet, profiles, themes, hooks, teams. No stale state cleanup before navigation. Need to verify each route and add state reset. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ / macOS 14+ | UI framework | Project standard; `@Observable`, `NavigationStack` |
| ILSShared | local SPM | Shared models (FleetHost, ChatSession) | Cross-target model sharing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TipKit | iOS 17+ | Onboarding tips on HomeView | Already integrated; CreateSessionTip |

### No New Dependencies
This phase requires zero new packages. All work is SwiftUI view-layer changes within the existing codebase.

## Architecture Patterns

### Current Navigation Architecture
```
ILSAppApp.swift
  └── .onOpenURL { appState.handleURL(url) }

SidebarRootView (root)
  ├── @State activeScreen: ActiveScreen = .home
  ├── @SceneStorage("activeScreenKey") -- persists screen across launches
  ├── @SceneStorage("lastChatSessionId") -- restores chat session
  ├── NavigationStack (wraps all content)
  │     └── Group { switch activeScreen { ... } }  -- flat enum swap
  │     └── .toolbar { hamburger button (.topBarLeading) }
  ├── SidebarView (overlay on iPhone, split on iPad)
  └── AppState.navigationIntent -- consumed via .onChange

ActiveScreen enum cases:
  .home, .chat(ChatSession), .system, .settings, .browser,
  .teams, .hostProfiles, .themes, .hooks
```

### Pattern 1: Custom Back Button via Previous Screen Tracking
**What:** Track the screen the user came from before entering chat, and provide a custom back button that returns to it.
**When to use:** NAV-02 -- chat back button without architectural changes.
**Example:**
```swift
// In SidebarRootView:
@State private var previousScreen: ActiveScreen? = nil

// When navigating to chat, record where we came from:
private func navigateToChat(_ session: ChatSession) {
    previousScreen = activeScreen
    activeScreen = .chat(session)
}

// In ChatView toolbar, add a back button:
// SidebarRootView passes a `onBack: (() -> Void)?` closure to ChatView
// ChatView renders it as a .topBarLeading toolbar item when non-nil
```

### Pattern 2: Sidebar Active Host Indicator
**What:** Show the active host profile name in the sidebar header below the connection status.
**When to use:** NAV-04 -- active host visibility.
**Example:**
```swift
// In AppState, add:
var activeHostName: String? = nil

// In SidebarView headerSection, below the connection status:
if let hostName = appState.activeHostName {
    HStack(spacing: theme.spacingXS) {
        Image(systemName: "desktopcomputer")
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
        Text(hostName)
            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .lineLimit(1)
    }
}
```

### Pattern 3: inlineNavigationBarTitle Consistency
**What:** Apply `.inlineNavigationBarTitle()` to all ActiveScreen destination views.
**When to use:** NAV-03 -- consistent navigation bar style.
**Example:**
```swift
// Add after .navigationTitle() in each missing view:
.navigationTitle("System")
.inlineNavigationBarTitle()  // <-- add this

// Already uses #if os(iOS) guard internally via PlatformCompat.swift
```

### Anti-Patterns to Avoid
- **Adding `.topBarLeading` toolbar items in child views:** This would hide the hamburger menu. All child views must use `.primaryAction`, `.navigationBarTrailing`, `.automatic`, or `.confirmationAction` placement. NEVER `.topBarLeading`.
- **Converting ActiveScreen to NavigationPath for chat:** This would break `@SceneStorage("lastChatSessionId")` restoration and require rethinking the entire navigation model. The custom back button approach is dramatically simpler.
- **Adding new ActiveScreen enum cases:** Only add cases for truly top-level screens. Sub-flows (like skill detail, theme editor) should use NavigationLink pushes within their parent screen's NavigationStack.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Inline navigation bar title | Custom `.navigationBarTitleDisplayMode(.inline)` per-platform | `PlatformCompat.inlineNavigationBarTitle()` | Already exists; handles iOS/macOS compile-time guard |
| Haptic feedback | Direct `UIImpactFeedbackGenerator` calls | `HapticManager.impact(.light)` / `.selection()` | Existing wrapper used throughout codebase |
| Edge swipe gesture | Custom `UIGestureRecognizer` | Existing `edgeSwipeGesture` in SidebarRootView | Already handles open/close with 30pt edge zone and spring animation |

## Common Pitfalls

### Pitfall 1: Adding .topBarLeading Items in Child Views
**What goes wrong:** A child view adds a `.topBarLeading` toolbar item (e.g., a custom back button), which replaces the hamburger menu button from SidebarRootView's NavigationStack toolbar.
**Why it happens:** SwiftUI merges toolbar items from the NavigationStack and its child views. When a child adds `.topBarLeading`, it takes precedence over the parent's `.topBarLeading` item.
**How to avoid:** ALL child views must use `.primaryAction`, `.navigationBarTrailing`, `.topBarTrailing`, or `.automatic` placement. The ChatView back button must be implemented as a separate `.topBarLeading` item ONLY when chat is the active screen, passed from SidebarRootView -- not added by ChatView itself.
**Warning signs:** Hamburger button disappears on certain screens.

### Pitfall 2: @SceneStorage Conflict with Chat Navigation Changes
**What goes wrong:** Changing how chat navigation works breaks `@SceneStorage("lastChatSessionId")` restoration on app relaunch.
**Why it happens:** `activeScreenKey` is saved as "chat" and `lastChatSessionId` stores the UUID. On relaunch, `SidebarRootView.task` restores the chat session. If the navigation model changes (e.g., chat becomes a NavigationPath push instead of an ActiveScreen case), the restoration path breaks.
**How to avoid:** Keep `.chat(ChatSession)` as an `ActiveScreen` case. The custom back button approach preserves this entirely -- it only adds a `previousScreen` tracking state alongside the existing model.
**Warning signs:** App relaunches to blank home screen instead of restoring the last active chat session.

### Pitfall 3: Deep Link Navigation Without State Reset
**What goes wrong:** `ils://sessions/{uuid}` navigates to a chat, but the previous screen's state (e.g., a half-completed form in Settings, or an in-progress install in Browser) is silently abandoned.
**Why it happens:** `ActiveScreen` is a flat enum swap. Setting `activeScreen = .chat(session)` destroys the previous view and its `@State` properties entirely.
**How to avoid:** This is inherent to the current architecture and acceptable for v3.1. Document that deep links perform a hard navigation, not a stack push. Ensure `previousScreen` is set correctly so the back button works after a deep link.
**Warning signs:** User returns from deep-linked chat to a reset home screen instead of their previous context.

### Pitfall 4: macOS Build Break from iOS-Only Toolbar Placement
**What goes wrong:** Using `.topBarLeading` or `.navigationBarTrailing` placement directly in shared code causes macOS build errors.
**Why it happens:** `PlatformCompat.swift` provides fallback typealias on macOS for `.navigationBarTrailing` and `.navigationBarLeading` (mapping to `.automatic`), but `.topBarLeading` is NOT aliased -- it only compiles inside `#if os(iOS)` blocks.
**How to avoid:** Always wrap `.topBarLeading` usage in `#if os(iOS)` / `#else` / `#endif`. The existing hamburger button in SidebarRootView already does this correctly. Any new `.topBarLeading` items (e.g., chat back button) must follow the same pattern.
**Warning signs:** `Cannot find 'topBarLeading' in scope` error when building ILSMacApp scheme.

### Pitfall 5: previousScreen Tracking Creates Stale Reference
**What goes wrong:** `previousScreen` holds a reference to a screen that no longer makes sense (e.g., user was on `.browser`, navigated to chat, then the sidebar was used to go to `.settings`, and now `previousScreen` still points to `.browser`).
**Why it happens:** `previousScreen` is only updated when navigating TO chat, but sidebar navigation doesn't clear it.
**How to avoid:** Clear `previousScreen` to nil whenever `activeScreen` changes via the sidebar (not via the back button). Only set `previousScreen` when transitioning to `.chat` from a non-chat screen.
**Warning signs:** Chat back button returns to an unexpected screen.

## Code Examples

### Verified: Current Hamburger Button Implementation (SidebarRootView.swift:269-297)
```swift
// Source: ILSApp/ILSApp/Views/Root/SidebarRootView.swift
.toolbar {
    if showHamburger {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            Button {
                openSidebar()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: theme.fontTitle3, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
            }
            .accessibilityLabel("Open sidebar")
            .accessibilityHint("Opens navigation sidebar")
        }
        #else
        ToolbarItem(placement: .automatic) {
            // macOS version...
        }
        #endif
    }
}
```

### Verified: ChatView Toolbar (ChatView.swift:267-327)
```swift
// Source: ILSApp/ILSApp/Views/Chat/ChatView.swift
// Uses .primaryAction placement -- does NOT conflict with hamburger
ToolbarItem(placement: .primaryAction) {
    Menu {
        Button { /* rename */ } label: { Label("Rename", systemImage: "pencil") }
        Button { /* fork */ } label: { Label("Fork Session", systemImage: "arrow.branch") }
        Button { /* export */ } label: { Label("Export", systemImage: "square.and.arrow.up") }
        Button { /* info */ } label: { Label("Session Info", systemImage: "info.circle") }
        Divider()
        Button(role: .destructive) { /* delete */ } label: { Label("Delete Session", systemImage: "trash") }
    } label: {
        Image(systemName: "ellipsis.circle")
    }
}
```

### Verified: Deep Link Handler (AppState.swift:79-115)
```swift
// Source: ILSApp/ILSApp/AppState.swift
func handleURL(_ url: URL) {
    guard url.scheme == "ils" else { return }
    let resourceId: UUID? = { /* extract from path */ }()
    switch url.host {
    case "home": navigationIntent = .home
    case "sessions":
        if let resourceId { navigateToSession(id: resourceId) }
        else { navigationIntent = .home }
    case "browser", "projects", "plugins", "mcp", "skills":
        navigationIntent = .browser
    case "settings": navigationIntent = .settings
    case "system": navigationIntent = .system
    case "fleet", "profiles": navigationIntent = .hostProfiles
    case "themes": navigationIntent = .themes
    case "hooks": navigationIntent = .hooks
    case "teams": navigationIntent = .teams
    default: break
    }
}
```

### Verified: inlineNavigationBarTitle() Shim (PlatformCompat.swift:14)
```swift
// Source: ILSApp/ILSApp/Utils/PlatformCompat.swift
extension View {
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NavigationView` | `NavigationStack` / `NavigationSplitView` | iOS 16 / WWDC22 | Already adopted in SidebarRootView |
| `@StateObject` | `@State` + `@Observable` | iOS 17 / WWDC23 | Already adopted for all ViewModels |
| Tab bar navigation | Sidebar overlay (iPhone) / Split view (iPad) | Project decision | Correct for 9+ screens |

## Open Questions

1. **Is the hamburger actually hidden on any screen at runtime?**
   - What we know: Code inspection shows no conflicting `.topBarLeading` items in any child view. The hamburger is rendered at the NavigationStack level in `mainContent(showHamburger:)`.
   - What's unclear: Whether any runtime behavior (e.g., NavigationStack back button from a `.navigationDestination` push within ChatView) visually replaces the hamburger.
   - Recommendation: Functionally verify by running the app and navigating to each screen. If the hamburger is visible everywhere, NAV-01 may already be satisfied and just needs documentation.

2. **Should the chat back button replace the hamburger or coexist?**
   - What we know: There's only one `.topBarLeading` slot in the toolbar. Adding a back button for chat would need to either replace the hamburger or use a different placement.
   - What's unclear: The best UX pattern -- hamburger + back button side by side, or back button replaces hamburger in chat.
   - Recommendation: In chat, replace the hamburger with a back button. The sidebar is still accessible via edge swipe. This matches iOS platform conventions where the back button takes the leading position.

3. **What should "Local" mean in the sidebar host indicator?**
   - What we know: No active host profile means localhost:9999. `AppState` has no `activeHostName` property.
   - What's unclear: Whether "Local" is the right default label, or if it should show the server URL instead.
   - Recommendation: Show "Local" when `activeHostName` is nil and `isConnected` is true. Show the profile name when one is active. This is simple and clear.

## Detailed Audit Results

### `.toolbar` Usage Across All ActiveScreen Destinations

| Screen | View File | `.toolbar` Items | Placement | Conflicts with Hamburger? |
|--------|-----------|-----------------|-----------|--------------------------|
| Home | HomeView.swift | None | N/A | NO |
| Chat | ChatView.swift | Ellipsis menu | `.primaryAction` | NO |
| System | SystemMonitorView.swift | Live indicator | `.navigationBarTrailing` | NO |
| Settings | SettingsView.swift | None visible at root | N/A | NO |
| Browser | BrowserView.swift | None visible at root | N/A | NO |
| Teams | AgentTeamsListView.swift | Plus button | `.primaryAction` | NO |
| Host Profiles | HostProfilesView.swift | Plus button (NavigationLink) | `.navigationBarTrailing` | NO |
| Themes | ThemesListView.swift | Import + Plus buttons | `.topBarTrailing` + `.primaryAction` | NO |
| Hooks | HooksManagementView.swift | None visible | N/A | NO |

**Conclusion:** Zero toolbar conflicts found. Hamburger should be visible on all screens.

### `.inlineNavigationBarTitle()` Coverage

| Screen | Has `.navigationTitle()`? | Has `.inlineNavigationBarTitle()`? | Action Needed? |
|--------|--------------------------|-----------------------------------|----------------|
| HomeView | No (uses custom text) | YES (line 86) | No |
| ChatView | YES ("Chat") | YES (line 85) | No |
| SystemMonitorView | YES ("System") | **NO** | **ADD** |
| SettingsView | YES ("Settings") | YES (line 65) | No |
| BrowserView | YES ("Browse") | YES (line 119) | No |
| AgentTeamsListView | YES ("Agent Teams") | **NO** | **ADD** |
| HostProfilesView | YES ("Host Profiles") | **NO** | **ADD** |
| ThemesListView | YES ("Custom Themes") | **NO** | **ADD** |
| HooksManagementView | YES ("Hooks") | YES (line 24) | No |

**Four screens need `.inlineNavigationBarTitle()` added:** SystemMonitorView, AgentTeamsListView, HostProfilesView, ThemesListView.

### Deep Link Route Audit

| Route | Handler | ActiveScreen Target | Notes |
|-------|---------|---------------------|-------|
| `ils://home` | Direct | `.home` | OK |
| `ils://sessions` | Direct | `.home` (no UUID) | OK -- falls back to home |
| `ils://sessions/{uuid}` | Async fetch | `.chat(session)` | OK -- fetches session, falls back to minimal |
| `ils://browser` | Direct | `.browser` | OK |
| `ils://projects` | Direct | `.browser` | OK -- routes to browser (projects are a browser segment) |
| `ils://plugins` | Direct | `.browser` | OK |
| `ils://mcp` | Direct | `.browser` | OK |
| `ils://skills` | Direct | `.browser` | OK |
| `ils://settings` | Direct | `.settings` | OK |
| `ils://system` | Direct | `.system` | OK |
| `ils://fleet` | Direct | `.hostProfiles` | OK |
| `ils://profiles` | Direct | `.hostProfiles` | OK |
| `ils://themes` | Direct | `.themes` | OK |
| `ils://hooks` | Direct | `.hooks` | OK |
| `ils://teams` | Direct | `.teams` | OK |

**Issues found:**
1. Browser sub-routes (`ils://projects`, `ils://plugins`, `ils://mcp`, `ils://skills`) all navigate to `.browser` but do NOT set the initial segment. The `browserSegment` state in SidebarRootView is not updated by deep links -- user always lands on the default segment.
2. No `ils://chat/{uuid}` alias -- only `ils://sessions/{uuid}` works.
3. No state cleanup before navigation -- if a deep link fires while the user is mid-action (e.g., composing a message), the action is silently abandoned.

## Sources

### Primary (HIGH confidence)
- Direct code inspection: `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` -- full navigation architecture, hamburger implementation, ActiveScreen enum
- Direct code inspection: `ILSApp/ILSApp/Views/Root/SidebarView.swift` -- sidebar header, navigation items, session list
- Direct code inspection: `ILSApp/ILSApp/Views/Chat/ChatView.swift` -- toolbar items, navigation title, sheet presentations
- Direct code inspection: `ILSApp/ILSApp/AppState.swift` -- deep link handler, navigationIntent, connection state
- Direct code inspection: `ILSApp/ILSApp/Views/Home/HomeView.swift` -- layout structure, section ordering, spacing
- Direct code inspection: `ILSApp/ILSApp/Utils/PlatformCompat.swift` -- inlineNavigationBarTitle() implementation
- Grep audit: `.topBarLeading` across entire ILSApp -- only one match (SidebarRootView:272)
- Grep audit: `ToolbarItem` placements across all Views -- no conflicts found
- Grep audit: `.inlineNavigationBarTitle()` across all Views -- four screens missing

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` -- navigation architecture overview confirmed by code inspection
- `.planning/research/FEATURES.md` -- navigation feature landscape, back button analysis
- `.planning/research/PITFALLS.md` -- toolbar conflict analysis confirmed by code inspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new dependencies, all existing SwiftUI
- Architecture: HIGH -- all findings from direct code inspection of actual source files
- Pitfalls: HIGH -- toolbar conflict audit is exhaustive (grep of entire codebase), @SceneStorage behavior is well-understood from prior milestones

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (30 days -- stable codebase, no external dependency changes)
