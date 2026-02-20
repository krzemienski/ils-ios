---
phase: quick-2
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  # H4 - Hardcoded font sizes (text-sized values only, not icon/decorative)
  - ILSApp/ILSApp/Theme/Components/ThemedCodeBlockView.swift
  - ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift
  - ILSApp/ILSApp/Views/Fleet/FleetHostDetailView.swift
  - ILSApp/ILSApp/Views/Components/InfoTooltipButton.swift
  - ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift
  - ILSApp/ILSApp/Views/Home/HomeView.swift
  - ILSApp/ILSApp/Views/Browser/BrowserView.swift
  - ILSApp/ILSApp/Views/Settings/HooksManagementView.swift
  - ILSApp/ILSApp/Views/Themes/ThemePreviewCard.swift
  - ILSApp/ILSApp/Views/Onboarding/QuickConnectView.swift
  - ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
  - ILSApp/ILSApp/Views/Premium/FeatureGateView.swift
  - ILSApp/ILSApp/Views/Premium/PremiumView.swift
  # H5 - Size class landscape fix
  - ILSApp/ILSApp/Views/Root/SidebarRootView.swift
  # H7 - ThemePickerView O(n*m)
  - ILSApp/ILSApp/Views/Settings/ThemePickerView.swift
autonomous: true
requirements: [H1, H2, H3, H4, H5, H6, H7, H8, H9, H10, H11, H12, H13]

must_haves:
  truths:
    - "All user-facing text uses theme font tokens (theme.fontCaption, theme.fontBody, theme.fontTitle3) instead of hardcoded numeric sizes"
    - "iPhone Pro Max landscape shows iPhone layout (overlay sidebar), not iPad split view"
    - "ThemePickerView uses Set-based lookup for available theme IDs"
  artifacts:
    - path: "ILSApp/ILSApp/Views/Root/SidebarRootView.swift"
      provides: "Correct size class + idiom check for iPad vs iPhone"
      contains: "userInterfaceIdiom"
    - path: "ILSApp/ILSApp/Views/Settings/ThemePickerView.swift"
      provides: "O(1) Set lookup for available themes"
      contains: "Set<String>"
  key_links:
    - from: "All view files"
      to: "ThemeSnapshot font tokens"
      via: "theme.fontCaption / theme.fontBody / theme.fontTitle3"
      pattern: "theme\\.font(Caption|Body|Title3)"
---

<objective>
Fix remaining HIGH priority audit backlog items H4, H5, and H7. Items H1-H3, H6, H8-H13 verified as already fixed or correct-by-design.

Purpose: Eliminate hardcoded font sizes that bypass Dynamic Type, fix iPhone Pro Max landscape routing, and clean up minor performance issue in theme picker.
Output: All HIGH audit items resolved, both iOS and macOS builds green.
</objective>

<execution_context>
@/Users/nick/.claude/get-shit-done/workflows/execute-plan.md
@/Users/nick/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

## Triage Results (from planner file verification)

### ALREADY FIXED / CORRECT BY DESIGN (no action needed):
- **H1** (BrowserView accessibility): Custom segmented control already has `.accessibilityLabel` and `.accessibilityAddTraits(.isSelected)` on lines 143-144
- **H2** (SidebarSessionRow touch target): Already has `.frame(minHeight: 44).contentShape(Rectangle())` on lines 54-55
- **H3** (HomeView relativeTime): Already uses `DateFormatters.relativeDateTime.localizedString(for:relativeTo:)` on line 246
- **H6** (BrowserView .contains on arrays): `togglingSkills` is `Set<UUID>`, `togglingPlugins`/`installingPlugins` are `Set<String>` -- already O(1)
- **H8** (MetricsWebSocketClient nonisolated(unsafe)): REQUIRED per CLAUDE.md pitfalls -- deinit is nonisolated and cannot access @MainActor properties. Removing breaks compilation.
- **H9** (SubscriptionManager fire-and-forget Task): Singleton (`static let shared`) lives for entire process -- deinit never called, cancellation meaningless
- **H10** (PluginsViewModel nonisolated(unsafe)): Same pattern as H8 -- required for deinit Task cancellation
- **H11** (SkillsViewModel nonisolated(unsafe)): Same pattern as H8 -- required for deinit Task cancellation
- **H12** (ScreenshotProtectionModifier animation): Already has `reduceMotion ? nil : .easeInOut(duration: 0.2)` on line 28
- **H13** (ShimmerModifier GeometryReader): No GeometryReader present -- uses LinearGradient directly

### NEEDS FIXING:
- **H4**: Hardcoded text font sizes (11, 12, 13, 14, 16) in 13 files bypass theme typography and Dynamic Type
- **H5**: SidebarRootView uses `horizontalSizeClass == .regular` without device idiom check -- iPhone Pro Max landscape gets iPad layout
- **H7**: ThemePickerView checks `availableThemes.contains(where:)` per card -- O(n*m) (trivial with 12 themes but easy to fix)

## Font Size Mapping

Use these theme token replacements for hardcoded sizes:
- `size: 11` -> `theme.fontCaption` (caption/fine print)
- `size: 12` -> `theme.fontCaption` (caption/secondary labels)
- `size: 13` -> `theme.fontCaption` (caption/code text -- fontCaption covers this range)
- `size: 14` -> `theme.fontBody` (body text / info labels)
- `size: 16` -> `theme.fontBody` (body text)

Icon/decorative sizes (20, 24, 28, 36, 40, 48, 56, 64) are SF Symbols -- these do NOT need theme tokens and should be kept as-is. They scale with Dynamic Type automatically via SF Symbols.

## LiveActivity Exception

`ILSApp/ILSApp/LiveActivity/ILSLiveActivity.swift` has hardcoded sizes but LiveActivity widgets have no access to theme environment -- these are intentionally excluded.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace hardcoded text font sizes with theme tokens (H4)</name>
  <files>
    ILSApp/ILSApp/Theme/Components/ThemedCodeBlockView.swift
    ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift
    ILSApp/ILSApp/Views/Fleet/FleetHostDetailView.swift
    ILSApp/ILSApp/Views/Components/InfoTooltipButton.swift
    ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift
    ILSApp/ILSApp/Views/Home/HomeView.swift
    ILSApp/ILSApp/Views/Browser/BrowserView.swift
    ILSApp/ILSApp/Views/Settings/HooksManagementView.swift
    ILSApp/ILSApp/Views/Themes/ThemePreviewCard.swift
    ILSApp/ILSApp/Views/Onboarding/QuickConnectView.swift
    ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift
    ILSApp/ILSApp/Views/Premium/FeatureGateView.swift
    ILSApp/ILSApp/Views/Premium/PremiumView.swift
  </files>
  <action>
    In each file, find `.font(.system(size: N, ...))` where N is a text-sized value (11, 12, 13, 14, 16) and replace with the appropriate theme token:

    - `size: 11` -> `theme.fontCaption`
    - `size: 12` -> `theme.fontCaption`
    - `size: 13` -> `theme.fontCaption`
    - `size: 14` -> `theme.fontBody`
    - `size: 16` -> `theme.fontBody`

    Preserve all other `.font()` parameters (weight, design). For example:
    - `.font(.system(size: 12, design: theme.fontDesign))` becomes `.font(.system(size: theme.fontCaption, design: theme.fontDesign))`
    - `.font(.system(size: 14, weight: .medium, design: theme.fontDesign))` becomes `.font(.system(size: theme.fontBody, weight: .medium, design: theme.fontDesign))`

    DO NOT change:
    - Sizes >= 20 (icon/decorative SF Symbol sizes)
    - Anything in LiveActivity/ (no theme access)
    - `ScreenshotProtectionModifier.swift` line 18 (size: 40 is an icon)

    For files that don't already have `@Environment(\.theme) private var theme: ThemeSnapshot`, add it. Most files already have it.

    For `PremiumView.swift` specifically: size: 22 is a title-range size -- replace with `theme.fontTitle3`. Size: 16 -> `theme.fontBody`.

    After completing all replacements, run iOS build to verify no compilation errors.
  </action>
  <verify>
    1. `grep -rn '\.font(\.system(size: 1[1-6]' ILSApp/ILSApp/ --include='*.swift' | grep -v LiveActivity | grep -v 'size: 15'` returns zero results (size 15 only in LiveActivity)
    2. iOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5` succeeds
  </verify>
  <done>All hardcoded text font sizes (11-16) in non-LiveActivity iOS files replaced with theme.fontCaption or theme.fontBody tokens. Zero hardcoded text sizes remain outside LiveActivity.</done>
</task>

<task type="auto">
  <name>Task 2: Fix iPhone Pro Max landscape routing and ThemePickerView lookup (H5, H7)</name>
  <files>
    ILSApp/ILSApp/Views/Root/SidebarRootView.swift
    ILSApp/ILSApp/Views/Settings/ThemePickerView.swift
  </files>
  <action>
    **H5 — SidebarRootView.swift:**

    Change the `isRegularWidth` computed property from:
    ```swift
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    ```
    To (iOS only — check device idiom to prevent iPhone Pro Max landscape from getting iPad layout):
    ```swift
    private var isRegularWidth: Bool {
        #if os(iOS)
        // iPhone Pro Max reports .regular in landscape — force iPhone layout for phones
        if UIDevice.current.userInterfaceIdiom == .phone {
            return false
        }
        #endif
        return horizontalSizeClass == .regular
    }
    ```
    This ensures iPhones (including Pro Max in landscape) always get the overlay sidebar, while iPads and Macs get the split view. No import needed — UIDevice is in UIKit which SwiftUI already imports on iOS.

    **H7 — ThemePickerView.swift:**

    Add a computed `Set<String>` for available theme IDs to avoid O(n) scan per card:
    ```swift
    private var availableThemeIDs: Set<String> {
        Set(themeManager.availableThemes.map(\.id))
    }
    ```

    Then in `themeCard(_:)`, change:
    ```swift
    let isAvailable = themeManager.availableThemes.contains(where: { $0.id == preview.id })
    ```
    To:
    ```swift
    let isAvailable = availableThemeIDs.contains(preview.id)
    ```

    After both changes, run iOS and macOS builds to verify.
  </action>
  <verify>
    1. `grep -n 'userInterfaceIdiom' ILSApp/ILSApp/Views/Root/SidebarRootView.swift` shows the idiom check
    2. `grep -n 'Set<String>' ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` shows the Set-based lookup
    3. iOS build succeeds: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5`
    4. macOS build succeeds: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet 2>&1 | tail -5`
  </verify>
  <done>iPhone Pro Max landscape correctly shows overlay sidebar instead of iPad split view. ThemePickerView uses O(1) Set lookup for available theme IDs. Both iOS and macOS builds pass.</done>
</task>

</tasks>

<verification>
1. Zero hardcoded text font sizes (11-16) outside LiveActivity: `grep -rn '\.font(\.system(size: 1[1-6]' ILSApp/ILSApp/ --include='*.swift' | grep -v LiveActivity | grep -v 'size: 15'` returns empty
2. iOS build green: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet`
3. macOS build green: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSMacApp -destination 'platform=macOS' -quiet`
4. `SidebarRootView.swift` contains `userInterfaceIdiom == .phone` check
5. `ThemePickerView.swift` contains `Set<String>` for available theme IDs
</verification>

<success_criteria>
- All 13 HIGH priority audit items (H1-H13) are resolved: 10 verified as already-fixed/correct-by-design, 3 fixed in this plan
- H4: Zero hardcoded text font sizes (11-16) remain outside LiveActivity
- H5: iPhone Pro Max landscape uses overlay sidebar, not iPad split view
- H7: ThemePickerView uses Set-based O(1) lookup
- Both iOS and macOS builds compile without errors
</success_criteria>

<output>
After completion, create `.planning/quick/2-fix-all-high-priority-backlog-items-h1-h/2-01-SUMMARY.md`
</output>
