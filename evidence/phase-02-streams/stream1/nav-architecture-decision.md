# Navigation Architecture Decision — Phase 2, Task 2.1

## Decision 1: Keep Custom ZStack Sidebar or Migrate to NavigationSplitView?

**Decision: KEEP ZStack on iPhone. Keep NavigationSplitView on iPad.**

**Rationale:**
- The current ZStack overlay sidebar (`SidebarRootView.swift` lines 130-148) provides a polished overlay UX with spring animation, dim overlay, and edge swipe gesture
- NavigationSplitView on iPhone auto-collapses to a side overlay, but doesn't offer the same fine-grained control over gesture thresholds, animation timing, or drag-to-close
- The iPad layout already uses NavigationSplitView correctly with `columnVisibility` binding
- No migration needed — both layouts work as intended

**Gesture conflict mitigation:**
- Edge swipe threshold is `startX < 30` — Apple reserves approximately 20pt for the system back gesture, but since we're in a NavigationStack with no pushed views (content is replaced via `activeScreen` enum, not pushed), there's no system back gesture to conflict with. The 30pt threshold is safe.
- Recommendation: Keep at 30pt. Reducing to 20pt would make the gesture harder to trigger without any real benefit since there's no system back gesture conflict.

## Decision 2: Back Button vs Hamburger in Chat Detail

**Decision: KEEP hamburger button. No back arrow needed.**

**Rationale:**
- `activeScreen = .chat(session)` replaces the current screen — it's NOT a NavigationStack push
- There's no "previous screen" to go back to; the user navigates by opening the sidebar and selecting a different destination
- This is the correct pattern for sidebar-based apps (similar to Slack, Discord, Telegram)
- The hamburger button is always visible in the toolbar, providing consistent navigation access

## Decision 3: Deep Link + Sidebar State

**Decision: Current implementation is CORRECT. No changes needed.**

**Rationale:**
- `onChange(of: appState.navigationIntent)` in `SidebarRootView.swift` (lines 75-85):
  1. Sets `activeScreen` to the intended destination
  2. Clears any NavigationPath entries
  3. Nils out the intent
  4. Closes sidebar on iPhone (`closeSidebar()`)
- All deep link routes in `AppState.handleURL()` correctly map to `ActiveScreen` cases
- `ils://themes` route already exists and maps to `.themes`

## Decision 4: Active State Indicator

**Decision: Fix `isScreenActive()` — missing `.themes` case.**

**Current code** (`SidebarView.swift` lines 398-407):
```swift
private func isScreenActive(_ screen: ActiveScreen) -> Bool {
    switch (activeScreen, screen) {
    case (.home, .home), (.system, .system), (.settings, .settings),
         (.browser, .browser), (.teams, .teams), (.fleet, .fleet):
        return true
    case (.chat, .chat):
        return true
    default:
        return false
    }
}
```

**Issue:** `.themes` is missing from the tuple pattern match. If the user navigates to Themes, the sidebar won't highlight it.

**Fix:** Add `(.themes, .themes)` to the pattern match.

## Summary

| Question | Decision | Action Required |
|----------|----------|-----------------|
| ZStack vs NavigationSplitView | Keep ZStack (iPhone) + NavigationSplitView (iPad) | None |
| Back button vs hamburger | Keep hamburger | None |
| Deep link + sidebar state | Current implementation correct | None |
| Active state indicator | Missing `.themes` case | Fix in Task 2.2 |
