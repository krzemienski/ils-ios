# Feature Landscape: Comprehensive Functional Validation (iOS & iPad)

**Domain:** iOS/iPadOS functional validation for a 12+ screen native SwiftUI app
**Researched:** 2026-02-25
**Confidence:** HIGH (based on existing codebase analysis, previous milestone evidence, Apple platform patterns)

---

## Scope Framing

This is NOT a feature-building milestone. v3.5 validates that everything already built across 5
prior milestones (v1.0, v2.0, v3.0, v1.5, v3.1) actually works from a user's perspective on
both iPhone and iPad. The "features" here are validation flows, evidence artifacts, and coverage
dimensions. The question per area is: what must be validated, what states must be observed, and
what does "complete" look like?

Validation dimensions researched:
1. Per-screen visual validation (iPhone + iPad)
2. Deep link navigation (all 15 registered routes)
3. Navigation flows and state transitions
4. Connection states (connected, disconnected, reconnect)
5. Evidence collection and dual-agent confirmation

---

## Table Stakes

Features/flows that MUST be validated. Missing any of these means the milestone is incomplete.

### 1. Per-Screen Visual Validation (iPhone)

Every screen must be launched on the dedicated iPhone 16 Pro Max simulator
(UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`), captured as a numbered screenshot,
and confirmed to render correctly with real data from the backend.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Home screen with stats + quick actions | Entry point; first impression | Low | PASS in Quick-5 audit |
| Sidebar with all 8 nav items + session list | Primary navigation | Low | PASS in Quick-5 audit |
| Sessions list with real session data | Core feature (22K+ sessions) | Low | Validate count, row layout, status badges |
| Chat view with real messages + back button | Core value; NAV-02 back button | Med | NOT yet validated in Quick-5; requires session tap |
| Browser - MCP tab with server health | Connected MCP servers | Low | Partially seen in Quick-5 (16 servers); needs full capture |
| Browser - Skills tab with Active badges | Browse/install skills | Low | PASS in Quick-5 audit |
| Browser - Plugins tab with category filters | Browse/install plugins | Low | PASS in Quick-5 audit |
| System Monitor with live CPU/Memory/Disk/Network | Real-time metrics | Low | PASS in Quick-5 audit |
| Settings top: connection, model, InheritanceBadges | Config sync + badges | Low | PASS in Quick-5 audit |
| Settings bottom: API Key, Permissions, Hooks, Env | Full settings scroll | Low | PASS in Quick-5 audit |
| Host Profiles with health dots + active indicator | Multi-host management | Med | NOT yet validated in Quick-5 |
| Themes list with preview swatches | Theme browsing/selection | Med | NOT yet validated in Quick-5 |
| Hooks management with event types | Hook config view | Med | NOT yet validated in Quick-5; may show empty state |
| Agent Teams list | Team management | Med | NOT yet validated in Quick-5; likely shows empty state |

**Priority:** The 5 unvalidated screens (Chat+back, MCP detail, Host Profiles, Themes, Hooks)
are the primary gap from Quick-5 and must be addressed first.

### 2. Per-Screen Visual Validation (iPad)

Every screen must ALSO be captured on an iPad simulator. The app uses a fundamentally different
layout on iPad: `NavigationSplitView` with a persistent sidebar column instead of the iPhone's
sheet-based overlay sidebar. This is a structural difference requiring its own validation pass.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| iPad sidebar always visible (persistent column) | NavigationSplitView layout; `isRegularWidth` branch | Med | Core iPad UX difference from iPhone |
| iPad split-view: sidebar + detail side-by-side | columnVisibility defaults to `.all` | Med | Verify both columns render simultaneously |
| iPad Home with wider content area | Stats cards should use extra horizontal space | Low | Check LazyVGrid column adaptation |
| iPad Sessions list in sidebar column | Sessions shown in sidebar, not as a full-screen list | Med | Different information density than iPhone |
| iPad Chat filling detail column | Messages should fill available detail width | Low | Verify message width constraints adapt |
| iPad Browser with tabs + list in detail pane | Tabbed browser in wider pane | Low | Verify tab picker and list layout |
| iPad System Monitor with wider metric cards | Dashboard metrics in wider layout | Low | Check grid column count adaptation |
| iPad Settings form in detail column | Form sections should use iPad width | Low | Standard SwiftUI Form behavior |
| iPad Host Profiles in detail column | List with health dots in wider pane | Low | Verify row layout |
| iPad Themes in detail column | Theme cards/list in wider layout | Low | Check grid adaptation |
| iPad Hooks in detail column | Hooks management in wider layout | Low | Empty state or hook list |
| iPad Agent Teams in detail column | Teams list in wider layout | Low | Likely empty state |
| iPad portrait sidebar behavior | Sidebar may auto-hide in portrait mode | Med | NavigationSplitView default portrait behavior on iPad |

**Critical note:** No dedicated iPad simulator exists yet in the project. One must be created
for v3.5 (e.g., iPad Pro 13-inch, iPadOS 18.x via `xcrun simctl create`).

### 3. Deep Link Navigation (Both Devices)

Every registered `ils://` route must be tested via `xcrun simctl openurl <udid> <url>` and
confirmed to navigate to the correct screen. Test on BOTH iPhone and iPad simulators.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| `ils://home` | Basic route | Low | |
| `ils://sessions` (no UUID) | Falls through to Home | Low | |
| `ils://sessions/{uuid}` | Parameterized; async session fetch | Med | UUID must be lowercase; tests API lookup |
| `ils://browser` | Opens Browser (MCP default segment) | Low | |
| `ils://projects` | Alias for Browser | Low | |
| `ils://mcp` | Browser with MCP tab selected | Med | Was broken; fixed in commit d351068 |
| `ils://skills` | Browser with Skills tab selected | Low | Fixed and validated in Quick-5 |
| `ils://plugins` | Browser with Plugins tab selected | Low | Fixed and validated in Quick-5 |
| `ils://settings` | Opens Settings | Low | |
| `ils://system` | Opens System Monitor | Low | |
| `ils://fleet` | Legacy alias for Host Profiles | Low | |
| `ils://profiles` | Alternate alias for Host Profiles | Low | |
| `ils://themes` | Opens Themes | Low | |
| `ils://hooks` | Opens Hooks | Low | |
| `ils://teams` | Opens Agent Teams | Low | |
| Deep link from cold start | App not running; URL launches app to correct screen | High | Tests @SceneStorage restoration + handleURL |
| Deep link from background | App suspended; URL resumes to correct screen | Med | Tests .onOpenURL while backgrounded |
| Invalid deep link (e.g., `ils://invalid`) | Should not crash; no-op or fallback | Low | Default case in switch |

### 4. Navigation Flow Validation

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| iPhone sidebar via edge swipe | Primary sidebar access on compact-width | Low | DragGesture from leading edge |
| iPhone sidebar via hamburger button | Toolbar button opens sidebar | Low | All screens must have .topBarLeading item |
| Chat back button returns to previous screen | NAV-02; previousScreen @State tracking | Med | Must work from sidebar tap AND deep link |
| Chat session switching preserves back context | Switch session in sidebar; back still navigates correctly | Med | navigateToChat() handles in-chat switches |
| @SceneStorage restoration on relaunch | Kill app, relaunch; restores last screen | Med | activeScreenKey + lastChatSessionId persistence |
| Browser segment persists across tab switches | Select Skills tab, leave, return; Skills still selected | Low | browserSegment @State in SidebarRootView |
| Sidebar session list search/filter | Type in search; sessions filter correctly | Low | SidebarView search functionality |
| Quick Actions from Home navigate correctly | Tap quick action; navigates to correct screen | Low | onNavigateToBrowser callback |

### 5. Connection State Validation

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Connected: all data loads from backend | Backend running on port 9999; real data flows | Low | Normal happy path; prerequisite for everything |
| Disconnected: graceful degradation | Backend stopped; ConnectionBanner visible, no crashes | Med | Stop backend, observe every screen |
| Reconnection: data auto-refreshes | Restart backend; app recovers without user action | Med | PollingManager reconnect, onChange(isConnected) |
| Wrong backend binary detection | OLD binary at ils/ vs CURRENT at ils-ios/ | Low | Verify with `lsof -i :9999 -P -n` before any validation |

### 6. Log Capture and Crash Checking

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Zero crashes during full screen walk | Basic stability requirement | Low | Monitor Xcode console or `log stream` |
| No uncaught exceptions in console | Runtime errors indicate broken code paths | Low | Filter for `ILSApp` process in console output |
| Log Viewer screen displays entries | AppLogger captures logs for in-app viewing | Med | Navigate to log viewer, confirm entries visible |

### 7. Evidence Gate (Dual-Agent Confirmation)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Numbered screenshot per iPhone screen | Traceable evidence: "screenshot 01 shows Home" | Low | Sequential: `iphone-01-home.png`, `iphone-02-sidebar.png` |
| Numbered screenshot per iPad screen | Same standard for iPad | Low | Sequential: `ipad-01-home.png`, `ipad-02-split-view.png` |
| Deep link evidence screenshots | Each route produces a screenshot of the destination | Low | `deeplink-01-home.png`, etc. |
| Second agent reviews all evidence | Independent confirmation prevents false PASS claims | Med | Agent reads screenshots, confirms or disputes |
| Evidence manifest file | Index mapping screenshot number to screen + verdict | Low | Markdown table in evidence directory |
| Log capture file | Console output saved during validation run | Low | Redirect `log stream` to file |

---

## Differentiators

Features that elevate validation beyond "does it render." Not strictly required but
significantly increase confidence in product quality.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Empty state validation per screen | Graceful UX when no data exists | Med | Hooks (no hooks), Teams (no teams), Themes (no custom) |
| Error state / error banner validation | Error banners, retry affordances render correctly | Med | Kill backend mid-flow, check error handling per screen |
| Premium gate visual check | Free vs premium UI renders correctly | Med | FeatureGateView overlay appears on gated features |
| Scroll-to-bottom on long lists | 22K sessions, 50+ skills don't cause jank | Med | Verify LazyVStack performance subjectively |
| Dark mode parity | All screens correct in dark mode | Med | ThemeSnapshot supports dark; doubles screenshot count |
| Dynamic Type at XXL size | Large text doesn't break layouts | Med | HIG font compliance done in v3.1; verify visually |
| iPad orientation change | Portrait to landscape preserves state + layout | Med | Sidebar visibility changes; detail pane resizes |
| iPad multitasking (Split View) | App in 50/50 split with Safari doesn't crash | Med | iPad-specific multitasking validation |
| Memory pressure resilience | App survives `xcrun simctl memory warning` | Low | No data loss after low-memory warning |
| Scene phase transitions | Background then foreground preserves state | Med | PollingManager pauses/resumes, timers pause |
| Host switch propagation | Switch host profile; all ViewModels reload | High | HP-02; cascading onChange through AppState |
| GitHub browse/install round-trip | Search, install, verify badge, uninstall | High | Requires GitHub API access; BRW-01..08 |
| Chat streaming end-to-end | Send message, see streaming, receive response | High | Requires Claude CLI; env var stripping critical |
| Widget rendering check | ServerStatusWidget shows connected/disconnected | Low | WidgetKit gallery or home screen |

---

## Anti-Features

Features to explicitly NOT validate in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Unit test coverage | Project mandate: no mocks, stubs, or test files | Validate through real system interaction only |
| Automated UI test scripts (XCUITest) | Fragile on this codebase; conflicts with functional validation mandate | Manual `xcrun simctl` screenshot capture |
| Performance benchmarking | Completed in v2.0 milestone (838ms cold-start) | Reference v2.0 evidence if needed |
| Code-level audit | Completed in v1.5 + v3.0 (70/70 findings resolved) | Trust prior evidence; focus on UX |
| macOS validation | Already validated in v3.1 Phase 38 (XP-01/02/03 PASS) | Out of scope for v3.5 |
| App Store submission | Separate milestone per PROJECT.md | Note any blockers found but do not attempt |
| Accessibility audit (VoiceOver) | Separate concern; a11y labels added in v3.0 | Note obvious issues if seen |
| Localization testing | App is English-only | Skip entirely |
| Network throttling / slow connection | Useful but not in scope | Defer to future milestone |
| StoreKit sandbox testing | Premium gate testing requires sandbox setup | Note if FeatureGateView renders; skip purchase flow |
| Backend API regression testing | API layer tested implicitly through UI validation | No separate API test pass needed |

---

## Feature Dependencies

```
Backend running (port 9999, correct binary from ils-ios/)
  |
  +--> ALL screen validations depend on real data from backend
  |
  +--> Home (stats from /api/v1/sessions, /skills, /mcp, /plugins)
  +--> Sessions list (/api/v1/sessions with 22K+ entries)
  |     +--> Chat view (requires session row tap or ils://sessions/{uuid})
  |           +--> Chat back button (requires previousScreen @State)
  |           +--> Chat streaming (requires Claude CLI + env var stripping)
  +--> Browser tabs (/api/v1/mcp, /api/v1/skills, /api/v1/plugins)
  |     +--> GitHub browse/install (requires internet + GitHub API)
  +--> System Monitor (WebSocket to host + REST fallback via MetricsWebSocketClient)
  +--> Settings (/api/v1/config with InheritanceBadge rendering)
  |     +--> Host switch propagation (requires 2+ host profiles configured)
  +--> Host Profiles (/api/v1/fleet with health polling)
  +--> Themes (/api/v1/themes + built-in ThemeSnapshot)
  +--> Hooks (local config display; may show empty state)
  +--> Agent Teams (local; likely shows empty state)

iPhone simulator (50523130-57AA-48B0-ABD0-4D59CE455F14)
  +--> iPhone validation (EXISTING; ready to use)

iPad simulator (MUST BE CREATED)
  +--> iPad validation (NEW; requires xcrun simctl create)
  +--> iPad portrait + landscape testing
  +--> iPad multitasking (differentiator only)

Quick-5 audit (7/12 PASS) --> 5 remaining screens are top priority:
  1. Chat View (back button, message display)
  2. Browse - MCP (full capture with health badges)
  3. Host Profiles (health dots, active indicator)
  4. Themes (swatch list, selection)
  5. Hooks (event types or empty state)

Deep link testing --> requires xcrun simctl openurl on both devices
Screenshot capture --> requires xcrun simctl io <udid> screenshot
Dual-agent confirmation --> evidence files at known path for second agent to review
```

---

## MVP Recommendation

Prioritize in this order:

1. **Complete remaining 5 iPhone screens** -- MCP detail, Host Profiles, Chat+back button,
   Themes, Hooks. These are the known gap from Quick-5 and provide immediate coverage uplift
   from 7/12 to 12/12 (plus Agent Teams = 13).

2. **Create iPad simulator and validate all 13 screens** -- iPad is explicitly called out in
   the milestone goal. NavigationSplitView persistent sidebar is structurally different from
   iPhone. This is the largest new validation surface.

3. **Deep link testing: all 15 routes on both devices** -- Deep links are a stated milestone
   target. Browser segment routing was recently broken and fixed (d351068), proving this area
   is fragile. Use `xcrun simctl openurl` for deterministic testing.

4. **Navigation flow validation** -- Sidebar access, chat back button, @SceneStorage
   restoration, browser segment persistence. These cross-cutting flows span multiple screens
   and catch integration issues that per-screen captures miss.

5. **Connection state validation** -- Connected (happy path, prerequisite for everything),
   disconnected (graceful degradation), reconnection (auto-recovery). Three captures per
   state minimum.

6. **Evidence gate: numbered screenshots + dual-agent review** -- The milestone explicitly
   requires "two independent agent teammates confirm every screenshot and log verdict."
   Evidence must be organized, numbered, and reviewable.

7. **Log capture** -- Zero crashes, zero uncaught exceptions during the full validation run.
   Save console output for evidence.

**Defer:**
- **GitHub browse/install flow**: Requires external GitHub API; BRW-01..08 already PASS from
  v3.1. Include only if time permits.
- **Chat streaming E2E**: Requires Claude CLI in environment; env constraints may block. Test
  chat view rendering and back button, not message sending.
- **Dark mode**: Doubles screenshot count. Valuable differentiator but stretch goal only.
- **iPad multitasking**: Nice-to-have iPad differentiator; not core validation.
- **Premium gate**: Hard to toggle subscription state in simulator without StoreKit setup.

---

## Sources

- Codebase: `SidebarRootView.swift` -- ActiveScreen enum (10 cases), iPadLayout/iPhoneLayout branches, isRegularWidth check
- Codebase: `AppState.swift` -- handleURL() with 15 deep link routes (home, sessions, browser, mcp, skills, plugins, settings, system, fleet, profiles, themes, hooks, teams, projects + parameterized sessions/{uuid})
- Codebase: `FeatureGate.swift` -- Premium feature gating (chatExport, customThemes, advancedMonitoring, unlimitedSessions)
- Quick-5 audit: `.planning/quick/5-cross-milestone-reflection-audit-with-fu/5-SUMMARY.md` -- 7/12 screens PASS, 5 remaining
- v3.1 requirements: `.planning/REQUIREMENTS.md` -- 31/31 complete, full traceability matrix
- PROJECT.md: v3.5 milestone definition -- iPhone + iPad + deep links + dual-agent evidence gate
- [iOS App Testing Checklist (ThinkSys)](https://thinksys.com/qa-testing/ios-app-testing-checklist/)
- [iOS App Testing Checklist (Aalpha)](https://www.aalpha.net/blog/ios-app-testing-checklist/)
- [Mobile App Testing Checklist 2025 (NextNative)](https://nextnative.dev/blog/mobile-app-testing-checklist)
- [NavigationSplitView Documentation (Apple)](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [NavigationSplitView on iPad (Hacking with Swift)](https://www.hackingwithswift.com/forums/swiftui/navigationsplitview-on-ipad-is-weird/28465)
- [Deep Link Testing Guide 2026 (Smler)](https://app.smler.io/blogs/deep-linking/ios/how-to-test-deep-links-ios-complete-guide-2026)
- [Deep Link Testing (BrowserStack)](https://www.browserstack.com/guide/test-deep-links-on-android-and-ios)
- [Edge Cases in Mobile Apps (Appmatics)](https://www.appmatics.com/en/blog/edge-cases)
- [iOS Simulator Commands (GitHub Gist)](https://gist.github.com/patriknyblad/be3678bf6b515f11b602051530b5ac3e)
