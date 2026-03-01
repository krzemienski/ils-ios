# Phase 41: iPhone Full Validation + Deep Links — Gap Closure Research

**Researched:** 2026-02-25 (gap closure refresh)
**Domain:** SwiftUI iOS view layout, deep link routing, PASS-CRITERIA alignment
**Confidence:** HIGH

## Summary

Phase 41 passed its dual-agent gate (13/13 screens PASS, 15/15 deep links) but an independent verifier identified 4 criterion-level gaps. This research investigates each gap by examining the actual source code, determining root cause, and prescribing the specific fix needed.

All 4 gaps have clear, low-risk fixes. Two are code changes (Gap 1: Hooks buttons visibility, Gap 3: Home nav title), one is a deep link routing change (Gap 4: themes route), and one requires either a code change or a criteria update (Gap 2: sessions search bar). None require architectural changes. Total estimated code delta is under 20 lines across 3 files.

**Primary recommendation:** Fix all 4 gaps with code changes (no criteria updates), rebuild, reinstall, and re-screenshot the 4 affected screens.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IPH-01 | Home screen -- stats cards, quick actions, recent sessions, sparklines | Gap 3 fix (add `.navigationTitle("Home")`) completes criterion 6 |
| IPH-02 | Sessions list -- sessions load, row tap opens chat, session count matches | Gap 2 fix (add `.searchable` to HomeView's sessions section) satisfies criterion 4 |
| IPH-03 | Chat view -- messages display, back button, toolbar actions | Already PASS -- no gap |
| IPH-04 | Browser MCP tab -- MCP servers list with health status | Already PASS -- no gap |
| IPH-05 | Browser Skills tab -- skills list with install/enable states | Already PASS -- no gap |
| IPH-06 | Browser Plugins tab -- plugins list with enable/disable | Already PASS -- no gap |
| IPH-07 | System Monitor -- live metrics, process list, WebSocket connected | Already PASS -- no gap |
| IPH-08 | Settings -- all sections render, inheritance badges, tooltips | Already PASS -- no gap |
| IPH-09 | Host Profiles -- profile list, active indicator, health badges | Already PASS -- no gap |
| IPH-10 | Themes -- theme list with preview, theme editor form | Gap 4 fix (route `ils://themes` to ThemePickerView) satisfies criteria 1-5 |
| IPH-11 | Sidebar navigation -- accessible, active item highlighted | Already PASS -- no gap |
| IPH-12 | Connection states -- connected banner, disconnected banner | Already PASS -- no gap |
| IPH-13 | Any issue found is fixed, rebuilt, re-validated | Process requirement -- applies to all 4 gap fixes |
| DL-01 | `ils://home` navigates to Home | Already PASS -- no gap |
| DL-02 | `ils://sessions` navigates to Sessions list | Already PASS -- no gap |
| DL-03 | `ils://sessions/{uuid}` opens specific chat | Already PASS -- no gap |
| DL-04 | Browser tab deep links navigate correctly | Already PASS -- no gap |
| DL-05 | Settings/system/fleet/themes navigate correctly | Gap 4 fix changes `ils://themes` destination from CustomThemes to ThemePickerView |
| DL-06 | Zero crashes, zero unhandled errors | Already PASS -- no gap |
| GATE-01 | iPhone screenshots organized with numbered naming | Process requirement -- re-screenshot 4 screens |
| GATE-03 | Agent A independently reviews | Process requirement -- re-run gate on affected screens |

</phase_requirements>

## Gap Analysis

### Gap 1: Hooks Screen — Edit Config / Copy Path Buttons Not Visible

**Status in verification:** FAIL (criterion 3)
**PASS-CRITERIA.md criterion:** "Edit Config and/or Copy Path buttons present"

#### Root Cause (HIGH confidence)

The buttons **exist in the code** but are rendered only in the **empty state** branch (`emptyState` computed property, lines 228-328 of `HooksManagementView.swift`). When hooks ARE present (the `hooksList` branch, lines 57-69), the view renders `summaryHeader` + `hookEventSection` entries with NO action buttons at the bottom.

**Evidence from code:**

- **Empty state** (lines 257-301): Contains `NavigationLink` to `ConfigEditorView(scope: "user")` labeled "Edit Config" AND a `Button` labeled "Copy Path" with clipboard copy of `~/.claude/settings.json`. Both are wrapped in an `HStack` inside the empty-state card.
- **Hooks-present state** (lines 57-69): `ScrollView > LazyVStack` containing only `summaryHeader(hooks)` and `ForEach(eventSections)` hook rows. **No action buttons exist in this branch.** The blank space below hook entries in the screenshot confirms the scroll content ends after the hook entries.

**This is NOT a scroll issue.** The buttons simply do not exist in the hooks-present code path.

#### Fix Prescription

Add an action button section at the bottom of the `hooksList` function, after the `ForEach` loop. Reuse the same "Edit Config" `NavigationLink` and "Copy Path" `Button` from the empty state. Extract the buttons into a shared `@ViewBuilder` computed property (e.g., `configActionButtons`) called from both `hooksList` and `emptyState`.

**File to modify:** `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift`
**Location:** Inside `hooksList(_:)` method, after line 64 (closing brace of the `ForEach`), add a call to the shared button builder. Then refactor `emptyState` to call the same builder.

#### Risk: LOW
- No navigation architecture changes
- No new dependencies
- Buttons already proven working in empty state
- ConfigEditorView already exists at `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift`
- The `@State private var showCopiedConfirmation` already exists in the view struct (line 226) and is accessible from both code paths

---

### Gap 2: Sessions Screen — No Search Bar

**Status in verification:** FAIL (criterion 4)
**PASS-CRITERIA.md criterion:** "Search bar present at top of the list"

#### Root Cause (HIGH confidence)

The Sessions "screen" (`ils://sessions` deep link, `ActiveScreen` case `.home`) is **not a separate screen**. It routes to the exact same `HomeView` as `ils://home`. The `handleURL` function in `AppState.swift` (line 106) maps `"sessions"` without a `resourceId` to `navigationIntent = .home`. There is no dedicated `SessionsListView` with its own search bar.

**Evidence from code:**

- `AppState.handleURL()` line 106: `case "sessions":` without a `resourceId` sets `navigationIntent = .home`
- `SidebarRootView.swift` line 266: `case .home:` renders `homeScreen` which is `HomeView`
- `HomeView.swift`: Contains a `recentSessionsSection` (lines 206-241) showing the 5 most recent sessions. No `.searchable()` modifier exists anywhere in HomeView.
- PASS-CRITERIA.md line 55: "Search bar present at top of the list" is listed as iPhone criterion 4 for Screen 02 (Sessions List)

**Architectural reality:** The Sessions screen IS the Home screen. The sidebar shows sessions in its own scrollable section with a count, but the main content area (Home) shows only "Recent Sessions" (top 5) with no search functionality.

#### Fix Prescription (Recommended: Option A)

Add `.searchable` to HomeView. This is the standard SwiftUI modifier for search bars, requires no architectural changes, and satisfies the criterion.

**Option A (RECOMMENDED): Add `.searchable` to HomeView.**
Add a `@State private var sessionSearchText: String = ""` property and a `.searchable(text: $sessionSearchText, prompt: "Search sessions")` modifier to the HomeView body. When `sessionSearchText` is non-empty, show filtered results from `sessionsVM.sessions` (the full list) instead of the top-5 "Recent Sessions". When search is cleared, revert to the default top-5 view. Approximately 10 lines of new code.

**Option B: Create a dedicated SessionsListView.**
Create a new view, add a new `ActiveScreen.sessions` case, update routing. Heavier (~80+ lines, 4 files changed). Not recommended for a gap-closure phase.

**Option C: Update PASS-CRITERIA.md.**
Acknowledge that `ils://sessions` routes to Home and remove the search bar criterion. Lowest effort but undermines validation discipline.

**File to modify (Option A):** `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Home/HomeView.swift`
**Location:** Add `@State` for search text near line 43. Add `.searchable()` modifier after `.refreshable()` around line 99. Modify `recentSessionsSection` to filter by search text when non-empty and show all matching sessions (not just top 5).

#### Risk: LOW
- `.searchable` is a standard SwiftUI modifier, well-tested
- Does not change navigation architecture
- Filtering is client-side on already-loaded data
- No backend changes needed

---

### Gap 3: Home Nav Bar Missing Title

**Status in verification:** PARTIAL (criterion 6)
**PASS-CRITERIA.md criterion:** "Navigation bar title shows 'Home' or app name"

#### Root Cause (HIGH confidence)

`HomeView.swift` has `.inlineNavigationBarTitle()` (line 86) but **no `.navigationTitle()`** modifier anywhere in the file. The `.inlineNavigationBarTitle()` utility (from `PlatformCompat.swift` line 14) only sets `.navigationBarTitleDisplayMode(.inline)` -- it does NOT set a title string. Without `.navigationTitle("Home")`, the navigation bar renders with only the hamburger button from `SidebarRootView`'s toolbar.

**Evidence from code:**

- `HomeView.swift`: Zero matches for `.navigationTitle`
- `PlatformCompat.swift` lines 14-19: `inlineNavigationBarTitle()` calls only `self.navigationBarTitleDisplayMode(.inline)`, no title text
- Contrast with other screens that DO have titles: `HooksManagementView.swift` line 22 has `.navigationTitle("Hooks")`, `ThemesListView.swift` line 64 has `.navigationTitle("Custom Themes")`

**The "Welcome back" text at HomeView lines 114-115 is a content heading inside the ScrollView, NOT a navigation bar title.**

#### Fix Prescription

Add `.navigationTitle("Home")` to HomeView's body, immediately before `.inlineNavigationBarTitle()`.

**File to modify:** `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Home/HomeView.swift`
**Location:** Between `.background(theme.bgPrimary)` (line 76) and `#if os(iOS)` (line 85). Insert `.navigationTitle("Home")` on a new line.

#### Risk: MINIMAL
- Single line addition
- Standard SwiftUI modifier used by every other screen in the app
- No layout impact (inline display mode keeps the title compact in the nav bar)

---

### Gap 4: Themes Deep Link Routes to Custom Themes Editor, Not Theme Picker

**Status in verification:** PARTIAL (criterion 2)
**PASS-CRITERIA.md criteria:** "Built-in themes listed (12+)", "Current/active theme indicated", "Theme previews visible", "Tapping a theme applies it"

#### Root Cause (HIGH confidence)

The `ils://themes` deep link sets `navigationIntent = .themes` (`AppState.swift` line 126). The `.themes` ActiveScreen case routes to `themesScreen` (`SidebarRootView.swift` line 284-285), which renders `ThemesListView()` (line 409). `ThemesListView` is the **Custom Themes editor** -- it lists user-created custom themes, shows an empty state with "No Custom Themes" and a "Create Theme" button. Its navigation title is "Custom Themes" (line 64 of ThemesListView.swift).

The **built-in theme picker** with the 12 themes, active indicator (gold border + checkmark), and color swatches is `ThemePickerView` -- a completely separate view located at `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ThemePickerView.swift`. It is currently only accessible via Settings > Appearance > Theme navigation path.

**The PASS-CRITERIA.md criteria for Screen 11 (Themes) describe ThemePickerView behavior, not ThemesListView behavior:**
- Criterion 1: "Built-in themes listed (expect 12+ themes)" -- ThemePickerView has `ThemePreview.all` with 12 entries. ThemesListView shows only user-created custom themes.
- Criterion 2: "Current/active theme indicated" -- ThemePickerView shows checkmark + accent border on active theme via `themeManager.currentTheme.id == preview.id`. ThemesListView has no active indicator.
- Criterion 3: "Theme previews visible (color swatches or preview cards)" -- ThemePickerView renders mini-screen previews with 4 color swatches per card. ThemesListView shows metadata text rows.
- Criterion 5: "Tapping a theme applies it" -- ThemePickerView calls `themeManager.setTheme()`. ThemesListView opens an editor sheet.

#### Fix Prescription (Recommended: Option A)

**Option A (RECOMMENDED): Change `themesScreen` to render `ThemePickerView`.**
In `SidebarRootView.swift`, change line 409 from `ThemesListView()` to `ThemePickerView()`. ThemePickerView already has its own `.navigationTitle("Theme")` and `.inlineNavigationBarTitle()`. The Custom Themes editor remains accessible via Settings.

**Environment dependency check:** ThemePickerView requires `@Environment(ThemeManager.self)`. This is already injected at the SidebarRootView level (line 88: `@Environment(ThemeManager.self) var themeManager`) and propagates through the view hierarchy. No additional environment setup needed.

**Option B: Create a combined Themes screen.** Build a parent view embedding both. Heavier, better long-term UX, but excessive for gap closure.

**Option C: Update criteria.** Weakens validation discipline. Not recommended.

**File to modify:** `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
**Location:** Lines 408-410. Change `ThemesListView()` to `ThemePickerView()`.

#### Risk: LOW
- ThemePickerView is already a fully functional, tested view used in production (via Settings)
- Environment dependency (ThemeManager) already available at the correct scope
- Navigation title and inline mode already configured in ThemePickerView
- Custom themes remain accessible via Settings > Appearance path

---

## Architecture Patterns

### SwiftUI Navigation Pattern in This App

The app uses a single `NavigationStack` in `SidebarRootView.mainContent()` with a `Group { switch activeScreen }` pattern for top-level routing. Each screen case renders a specific view. Deep links set `appState.navigationIntent` which is consumed by `.onChange(of:)` and forwarded to `activeScreen`.

**Key implication for gap fixes:** Changing what view a screen case renders (Gap 4) or adding modifiers to a view (Gaps 1, 2, 3) does not affect other screens. Each fix is isolated.

### View Modifier Order

SwiftUI navigation title must be applied to the view INSIDE the NavigationStack, not on the NavigationStack itself. HomeView is rendered inside the NavigationStack via `mainContent()`, so adding `.navigationTitle("Home")` directly on HomeView's body is correct.

### `.searchable` Placement

The `.searchable` modifier should be applied inside the NavigationStack content for it to appear in the navigation bar. Applying it on HomeView's ScrollView body (after `.refreshable`) is the correct location.

---

## Common Pitfalls

### Pitfall 1: ThemePickerView Environment Requirements
**What goes wrong:** ThemePickerView uses `@Environment(ThemeManager.self)` which could crash if not provided.
**Why it happens:** View swaps in SidebarRootView might miss environment injection.
**How to avoid:** ThemeManager is already injected at the SidebarRootView level (line 88) and flows to all child views. Verify with a build + launch after the change.
**Warning signs:** "No Observable object of type ThemeManager found" crash at runtime.

### Pitfall 2: Search Bar Interfering with Pull-to-Refresh
**What goes wrong:** `.searchable` and `.refreshable` can conflict on scroll position.
**Why it happens:** Both modify ScrollView's content insets.
**How to avoid:** Apply `.searchable` AFTER `.refreshable` in the modifier chain. Test that both gestures work independently.
**Warning signs:** Pull-to-refresh stops working or search bar doesn't appear on scroll-up.

### Pitfall 3: Hooks Button State Sharing
**What goes wrong:** The `showCopiedConfirmation` @State is defined in the view but used in the empty state. If extracted to a shared method, the @State needs to remain in the view struct.
**Why it happens:** @State properties must be owned by the view struct, not helper methods.
**How to avoid:** Keep `@State private var showCopiedConfirmation` in the HooksManagementView struct (it is already there at line 226). The shared button builder accesses it via `self`.
**Warning signs:** Compile error about @State in computed property or method.

### Pitfall 4: Auto-Build Hook Triggers on Every Edit
**What goes wrong:** Each Swift file edit triggers an automatic xcodebuild. Multiple sequential edits cause multiple builds.
**Why it happens:** `.claude/settings.local.json` has a PostToolUse hook for `*.swift` edits.
**How to avoid:** Batch all changes to a single file into one Edit call where possible. For multi-file changes, expect ~15-45s build per edit.
**Warning signs:** Hook output showing build failures or timeouts.

### Pitfall 5: Screenshots Must Be Recaptured After Code Fixes
**What goes wrong:** Evidence screenshots show the OLD behavior after a code fix because the app was not reinstalled.
**Why it happens:** Auto-build hook builds but does NOT reinstall. The agent must explicitly reinstall.
**How to avoid:** Full cycle after every fix: build (auto) -> find newest binary (`ls -td ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app | head -1`) -> install -> launch -> navigate -> wait 3s -> screenshot.
**Warning signs:** Screenshot shows unchanged behavior after confirmed code fix.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Search bar UI | Custom TextField + overlay | `.searchable(text:prompt:)` modifier | Native iOS search bar with animations, cancel button, keyboard handling |
| Navigation title | Custom Text in toolbar | `.navigationTitle("Home")` | Integrates with NavigationStack, accessibility, back button titles |
| Clipboard copy | Custom UIPasteboard wrapper | Existing `UIPasteboard.general.string` pattern from empty state | Already proven in HooksManagementView lines 276-280 |

---

## Code Examples

### Gap 1 Fix: Extract Shared Action Buttons in HooksManagementView

```swift
// Add to HooksManagementView as a new @ViewBuilder computed property:
@ViewBuilder
private var configActionButtons: some View {
    HStack(spacing: theme.spacingSM) {
        NavigationLink {
            ConfigEditorView(scope: "user")
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "doc.text")
                    .accessibilityHidden(true)
                Text("Edit Config")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }

        Button {
            #if os(iOS)
            UIPasteboard.general.string = "~/.claude/settings.json"
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("~/.claude/settings.json", forType: .string)
            #endif
            if reduceMotion {
                showCopiedConfirmation = true
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedConfirmation = true
                }
            }
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                    .accessibilityHidden(true)
                Text(showCopiedConfirmation ? "Copied" : "Copy Path")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundStyle(showCopiedConfirmation ? theme.success : theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background((showCopiedConfirmation ? theme.success : theme.accent).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }
}

// In hooksList(_:), add INSIDE the LazyVStack after the ForEach closing brace:
configActionButtons
    .padding(.top, theme.spacingSM)

// In emptyState, REPLACE the inline HStack with:
configActionButtons
```

### Gap 2 Fix: Add Search to HomeView

```swift
// Add @State property near line 43:
@State private var sessionSearchText: String = ""

// Add .searchable modifier after .refreshable (around line 99):
.searchable(text: $sessionSearchText, prompt: "Search sessions")

// Modify recentSessionsSection to filter when searching:
private var recentSessionsSection: some View {
    let sessions: [ChatSession]
    if sessionSearchText.isEmpty {
        sessions = Array(sessionsVM.sessions.prefix(5))
    } else {
        sessions = sessionsVM.sessions.filter {
            $0.displayName.localizedCaseInsensitiveContains(sessionSearchText)
        }
    }
    // ... rest unchanged, use `sessions` instead of `recent`
}
```

### Gap 3 Fix: Add Navigation Title to HomeView

```swift
// In HomeView body, add .navigationTitle("Home") before .inlineNavigationBarTitle():
.background(theme.bgPrimary)
.navigationTitle("Home")    // <-- ADD THIS LINE
#if os(iOS)
.inlineNavigationBarTitle()
#endif
```

### Gap 4 Fix: Route Themes to ThemePickerView

```swift
// In SidebarRootView, change themesScreen computed property (lines 408-410):
@ViewBuilder
private var themesScreen: some View {
    ThemePickerView()    // Was: ThemesListView()
}
```

---

## Open Questions

1. **Custom Themes accessibility after Gap 4 fix**
   - What we know: Changing `themesScreen` to `ThemePickerView` removes direct sidebar access to the Custom Themes editor (`ThemesListView`).
   - What's unclear: Should a "Custom Themes" NavigationLink be added to the bottom of ThemePickerView, or is the Settings > Appearance path sufficient?
   - Recommendation: The gap fix itself only requires routing to ThemePickerView. Adding a NavigationLink to ThemesListView at the bottom of ThemePickerView's ScrollView is a nice-to-have that preserves discoverability. Defer to planner discretion.

2. **Sessions search scope**
   - What we know: HomeView shows only 5 recent sessions. The full sessions list (~22K) is in `sessionsVM.sessions`.
   - What's unclear: Should search filter the visible 5, or expand to show all matching sessions from the full list?
   - Recommendation: Show filtered results from `sessionsVM.sessions` (full list) when search text is non-empty, revert to top-5 "Recent Sessions" when search is cleared. This matches user expectation of a search bar.

3. **macOS impact of changes**
   - What we know: HomeView, HooksManagementView, and SidebarRootView are shared between iOS and macOS targets. `.navigationTitle` and `.searchable` are cross-platform SwiftUI modifiers.
   - What's unclear: Whether the macOS app build will be affected by these changes.
   - Recommendation: Run macOS build check after all changes. The modifiers are cross-platform, so no issues are expected. The `#if os(iOS)` guard on `.inlineNavigationBarTitle()` already handles platform differences.

---

## Sources

### Primary (HIGH confidence)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift` -- direct code inspection, buttons confirmed in emptyState only (lines 257-301), absent from hooksList (lines 57-69)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Home/HomeView.swift` -- direct code inspection, zero `.navigationTitle()` matches, no `.searchable()` modifier
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Root/SidebarRootView.swift` -- direct code inspection, `.themes` routes to `ThemesListView()` (line 409), ActiveScreen routing pattern confirmed
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/AppState.swift` -- direct code inspection, `handleURL` routes "sessions" to `.home` (line 106), "themes" to `.themes` (line 126)
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` -- direct code inspection, 12 built-in themes in `ThemePreview.all`, active indicator via `themeManager.currentTheme.id` comparison
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Views/Themes/ThemesListView.swift` -- direct code inspection, custom themes editor with "Custom Themes" title (line 64), empty state with "No Custom Themes"
- `/Users/nick/Desktop/ils-ios/ILSApp/ILSApp/Utils/PlatformCompat.swift` -- direct code inspection, `inlineNavigationBarTitle()` only sets display mode, no title text
- `/Users/nick/Desktop/ils-ios/.planning/phases/40-environment-setup-screen-inventory/PASS-CRITERIA.md` -- criteria definitions for all 13 screens

### Secondary (MEDIUM confidence)
- `/Users/nick/Desktop/ils-ios/.planning/phases/41-iphone-full-validation-deep-links/41-VERIFICATION.md` -- verification report with gap descriptions and screenshot evidence paths

---

## Metadata

**Confidence breakdown:**
- Gap 1 (Hooks buttons): HIGH -- code path confirmed by direct inspection, fix is mechanical extraction of existing code
- Gap 2 (Sessions search): HIGH -- architecture confirmed by direct inspection, `.searchable` is standard SwiftUI
- Gap 3 (Home nav title): HIGH -- single missing modifier confirmed by direct inspection, trivially verified
- Gap 4 (Themes routing): HIGH -- view swap confirmed by direct inspection, ThemePickerView already fully functional

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable codebase, no rapid API changes)
