---
phase: quick-1
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - ILSApp/ILSApp/Views/Home/HomeView.swift
  - ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift
autonomous: true
requirements: [C1, C2, C3, C4, C5, C6, C7, C8, C9]

must_haves:
  truths:
    - "All 9 critical backlog items are verified as resolved"
    - "No view uses raw .navigationBarTitleDisplayMode(.inline) — all use .inlineNavigationBarTitle() helper"
    - "iOS and macOS builds succeed with zero errors"
  artifacts:
    - path: "ILSApp/ILSApp/Views/Home/HomeView.swift"
      provides: "Consistent inline nav bar title"
      contains: "inlineNavigationBarTitle"
    - path: "ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift"
      provides: "Consistent inline nav bar title"
      contains: "inlineNavigationBarTitle"
  key_links:
    - from: "ILSApp/ILSApp/Utils/PlatformCompat.swift"
      to: "All views with navigation titles"
      via: "inlineNavigationBarTitle() helper"
      pattern: "\\.inlineNavigationBarTitle\\(\\)"
---

<objective>
Verify and close all 9 critical audit backlog items (C1-C9), applying the one remaining consistency fix.

Purpose: The audit flagged 9 critical items. Investigation reveals C1-C7 were already fixed in prior sessions. C8 is architecturally sound (iPad uses NavigationSplitView, iPhone uses custom overlay that yields to back swipe). C9 is fixed except for two files using raw `.navigationBarTitleDisplayMode(.inline)` instead of the cross-platform `.inlineNavigationBarTitle()` helper.

Output: All C1-C9 items verified resolved. Two files updated for API consistency. Both platform builds green.
</objective>

<execution_context>
@/Users/nick/.claude/get-shit-done/workflows/execute-plan.md
@/Users/nick/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@ILSApp/ILSApp/Utils/PlatformCompat.swift
@ILSApp/ILSApp/Views/Home/HomeView.swift
@ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Standardize navigationBarTitleDisplayMode to cross-platform helper</name>
  <files>
    ILSApp/ILSApp/Views/Home/HomeView.swift
    ILSApp/ILSApp/Views/Browser/AddMCPServerView.swift
  </files>
  <action>
In HomeView.swift, replace `.navigationBarTitleDisplayMode(.inline)` with `.inlineNavigationBarTitle()`. Remove the `#if os(iOS)` / `#endif` guard around it if present, since `inlineNavigationBarTitle()` already handles platform detection internally (it's a no-op on macOS).

In AddMCPServerView.swift, replace `.navigationBarTitleDisplayMode(.inline)` with `.inlineNavigationBarTitle()`. Same pattern — remove any platform guard wrapping the call since the helper handles it.

This is a cosmetic consistency fix — both calls were already functionally `.inline`. The helper just ensures cross-platform compatibility without requiring `#if os(iOS)` at every call site.

Do NOT change any other code in these files.
  </action>
  <verify>
Run both builds in parallel:
- `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5`
- `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5`

Then verify no raw `.navigationBarTitleDisplayMode` calls remain outside PlatformCompat.swift:
`grep -rn 'navigationBarTitleDisplayMode' ILSApp/ILSApp/ --include='*.swift' | grep -v PlatformCompat`

Expected: zero results (only PlatformCompat.swift should contain the raw API call).
  </verify>
  <done>
All views use `.inlineNavigationBarTitle()` consistently. Zero raw `.navigationBarTitleDisplayMode` calls outside the PlatformCompat helper. Both iOS and macOS builds succeed with zero errors.
  </done>
</task>

<task type="auto">
  <name>Task 2: Document C1-C9 resolution status</name>
  <files>
    (no file modifications — verification-only task)
  </files>
  <action>
Verify each C1-C9 item is resolved by confirming the fix exists in the current codebase. Document findings in the SUMMARY:

- C1 (ILSAppApp.swift:56 launch animation): FIXED — `@Environment(\.accessibilityReduceMotion)` at line 13, gated `withAnimation` at lines 57-63
- C2 (ProgressRing.swift:44 ring animation): FIXED — `reduceMotion ? nil : .easeInOut` at line 45
- C3 (StatCard.swift:59 press scale): FIXED — `reduceMotion ? nil : .easeInOut` at line 61
- C4 (UserMessageCard.swift:15 UIScreen.main): FIXED — replaced with `Spacer(minLength: 60)` at line 16
- C5 (MessageView.swift:226 MarkdownParser): FIXED — `@State segments` + `.task(id: text)` at lines 226-277
- C6 (ThemeMarketplaceView.swift:230 filteredThemes): FIXED — `@State filteredThemesCache` + `.onChange` at lines 51, 104-106
- C7 (ILSAppApp.swift forced dark): FIXED — `computedColorScheme` respects "light"/"dark"/"system" preference at lines 15-21
- C8 (SidebarRootView custom sidebar): ADDRESSED — iPad uses NavigationSplitView (line 127), iPhone uses custom overlay that yields to NavigationStack back swipe (line 332). This is the correct architectural approach for compact width.
- C9 (Inconsistent navigationBarTitleDisplayMode): FIXED — all 33 views use `.inlineNavigationBarTitle()` after Task 1 cleanup. Two remaining raw calls in HomeView and AddMCPServerView standardized.

No grep for `UIScreen.main` in UserMessageCard, no grep for forced `.colorScheme(.dark)` — both already confirmed absent.
  </action>
  <verify>
Summarize all 9 items with FIXED/ADDRESSED status in the plan summary output.
  </verify>
  <done>
All 9 critical backlog items documented as resolved with specific line-number evidence. SUMMARY file created.
  </done>
</task>

</tasks>

<verification>
1. `grep -rn 'navigationBarTitleDisplayMode' ILSApp/ILSApp/ --include='*.swift' | grep -v PlatformCompat` returns zero results
2. `grep -rn 'UIScreen\.main' ILSApp/ILSApp/ --include='*.swift'` returns zero results
3. `grep -rn '\.colorScheme(\.dark)' ILSApp/ILSApp/ --include='*.swift'` returns zero results
4. iOS build succeeds: `xcodebuild -scheme ILSApp` exits 0
5. macOS build succeeds: `xcodebuild -scheme ILSMacApp` exits 0
</verification>

<success_criteria>
- All 9 critical items (C1-C9) verified as resolved
- Two files updated for `.inlineNavigationBarTitle()` consistency
- Both iOS and macOS builds pass with zero errors
- No regressions introduced
</success_criteria>

<output>
After completion, create `.planning/quick/1-fix-all-critical-backlog-items-c1-c9/1-SUMMARY.md`
</output>
