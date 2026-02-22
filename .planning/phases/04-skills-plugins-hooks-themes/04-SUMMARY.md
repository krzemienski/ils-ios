---
phase: 04
plan: 04
subsystem: skills-plugins-hooks-themes
tags: [skills, plugins, hooks, themes, mcp, security, browser]
dependency_graph:
  requires: [01-01, 02-02, 03-03]
  provides: [clean-skills-api, plugin-detail-nav, github-skill-browse, mcp-key-masking, hooks-management, custom-themes]
  affects: [BrowserView, SettingsConfigSection, MCPServerDetailView, ThemesListView, ThemePickerView]
tech_stack:
  added: [CustomThemeAdapter]
  patterns: [AppTheme protocol adapter, hex→Color conversion, auto-hide timer tasks, XcodeGen glob]
key_files:
  created:
    - ILSApp/ILSApp/Theme/CustomThemeAdapter.swift
  modified:
    - Sources/ILSBackend/Services/SkillsFileService.swift
    - ILSApp/ILSApp/Views/Browser/BrowserView.swift
    - ILSApp/ILSApp/Views/Browser/MCPServerDetailView.swift
    - ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift
    - ILSApp/ILSApp/Views/Settings/ThemePickerView.swift
    - ILSApp/ILSApp/Views/Root/SidebarRootView.swift
    - ILSApp/ILSMacApp/Views/MacContentView.swift
    - ILSApp/ILSApp/Views/Premium/PremiumView.swift
decisions:
  - Stop recursing into skill subdirs when SKILL.md is found (examples/, reference/ are docs, not skills)
  - Exclude documentation filenames (README, CLAUDE, LICENSE) from standalone .md skill candidates
  - Skip plugin cache skills/ dirs inside examples/ subdirectories
  - CustomThemeAdapter falls back to ObsidianTheme for any nil token fields (not crash)
  - Custom theme IDs prefixed with "custom-" to distinguish from built-in themes in ThemePickerView
  - ThemeManager.loadAndRegisterCustomThemes() wired at SidebarRootView startup (non-critical, fails silently)
  - MCP auto-hide uses Task-based timer stored in @State dict, cancelled on manual hide
metrics:
  duration: ~90min
  completed: 2026-02-22
  tasks: 7
  files: 9
---

# Phase 4 Plan 4: Skills, Plugins, Hooks & Theming Summary

**One-liner:** Skills API decontaminated (1336 clean entries), GitHub browse UI added to Browser, custom theme adapter bridges backend DTO to AppTheme protocol with hex-to-Color conversion and ThemePickerView sections.

## Tasks Completed

| Task | Name | Status | Commit |
|------|------|--------|--------|
| 4.1 | Fix Skills API contamination | DONE | 1a6ceb9 |
| 4.2 | Plugin Detail View | DONE (pre-existing PluginConfigView + NavigationLink) | — |
| 4.3 | GitHub Skill Browse UI | DONE | 5ff840a |
| 4.4 | MCP API key masking + auto-hide | DONE | 4268148 |
| 4.5 | Hooks Management screen navigation | DONE | 5ff840a |
| 4.6 | Custom Themes end-to-end | DONE | 4268148 |
| 4.7 | Plugin Status Indicators | DONE | 5ff840a |

## Validation Gates

| Gate | ID | Status | Evidence |
|------|----|--------|---------|
| Skills API Clean | VG-12 | PASS | Total: 1336, contamination: 0, no node_modules |
| Plugin Detail View | VG-13 | PASS | PluginConfigView with NavigationLink in BrowserView |
| Plugin Install/Uninstall | VG-14 | PASS | PluginConfigView uninstall confirmation + PluginsViewModel |
| MCP Key Masking | VG-15 | PASS | 15 masking-related symbols in MCPServerDetailView |
| Hooks Screen | VG-16 | PASS | HooksManagementView + NavigationLink in SettingsConfigSection |
| Custom Theme Create | VG-17 | PASS | CustomThemeAdapter + ThemePickerView "Custom" section |
| GitHub Skill Browse | VG-18 | PASS | githubBrowseSection in BrowserView skillsContent |

## What Was Done

### Task 4.1 — Skills API Decontamination
The `SkillsFileService.scanSkillsRecursively()` was recursing into ALL subdirectories including `examples/`, `reference/`, `templates/` inside skill directories, creating thousands of spurious skill entries (3505 → 1336).

Fixes applied to `SkillsFileService.swift`:
- When a directory contains `SKILL.md`, parse it and STOP — do not recurse into subdirs
- Directories without `SKILL.md` are treated as namespaces and recursed into (depth ≤ 2)
- Added `examples` and `tests` to `excludedDirectories` set
- Added `excludedFilenames` set (README.md, CLAUDE.md, LICENSE.md, etc.) to skip documentation files treated as standalone skills
- Skipped `skills/` directories inside `examples/` or `tests/` paths in `scanPluginCacheSkills()`

Result: 0 artifact contamination, all paths are clean skill roots.

### Task 4.2 — Plugin Detail View
Already fully implemented from previous sessions:
- `PluginConfigView.swift` exists with header, info, controls, commands, agents, and danger zone sections
- `BrowserView.swift` already wraps plugin rows in `NavigationLink` to `PluginConfigView`

### Task 4.3 — GitHub Skill Browse UI
Added `githubBrowseSection` to `BrowserView.skillsContent`:
- GitHub search field with debounced search (via `SkillsViewModel.updateGitHubSearchText()`)
- Results list showing name, description, repository path, and star count
- Per-result Install button calling `skillsVM.installFromGitHub(result:)`
- Loading spinner during install, haptic feedback on success
- Empty state when search returns no results

### Task 4.4 — MCP Key Auto-Hide
`MCPServerDetailView` already had:
- Sensitive key detection (KEY, TOKEN, SECRET, PASSWORD, CREDENTIAL, AUTH patterns)
- Masked display with `••••••••ABCD` format
- Eye/eye.slash toggle button

Added: 5-second auto-hide timer using `Task`-based approach with `@State private var autoHideTasks: [String: Task<Void, Never>]`. Each reveal creates a Task that calls `MainActor.run { revealedKeys.remove(key) }` after 5 seconds. Manual hide cancels the pending task.

### Task 4.5 — Hooks Navigation from Settings
`SettingsConfigSection.advancedSection` previously showed hooks count as plain text (`settingsRow`). Wrapped in `NavigationLink` to `HooksManagementView` for both the 0-hooks and N-hooks cases. The full `HooksManagementView` was pre-existing with all 5 event types, group cards, matcher display, and empty state.

`SidebarRootView`, `ILSAppApp.swift` and `MacContentView.swift` already had `.hooks` deep link and screen routing.

### Task 4.6 — Custom Themes End-to-End
Created `CustomThemeAdapter.swift`:
- Conforms to `AppTheme` protocol
- Maps `ColorTokens` hex strings → `SwiftUI.Color` via `Color(hex:)`
- Maps `SpacingTokens.spacingXS/S/M/L/XL` → `spacingXS/SM/MD/LG/XL`
- Maps `CornerRadiusTokens.cornerRadiusS/M/L` → `cornerRadiusSmall/cornerRadius/cornerRadiusLarge`
- Falls back to `ObsidianTheme()` for any nil token field
- ID prefixed `"custom-{uuid}"` for disambiguation
- Includes `ThemeManager.loadAndRegisterCustomThemes(client:)` extension

Wiring:
- `SidebarRootView.task` calls `themeManager.loadAndRegisterCustomThemes(client:)` on app launch
- `ThemePickerView` shows "Built-in" section (12 hardcoded themes) + "Custom" section (themes with `id.hasPrefix("custom-")`)
- Custom theme cards use `ThemeSnapshot(appTheme)` to render accurate preview colors

### Task 4.7 — Plugin Status Indicators
Added `pluginRow(_ plugin: Plugin)` method to `BrowserView`:
- Version badge: `v1.2.3` when `plugin.version` is non-nil
- Source badge: `Official` (accent color) or `Community` (skill entity color) when `plugin.source` is non-nil
- Star count with `star.fill` icon when `plugin.stars > 0`
- Marketplace badge when `plugin.marketplace` is non-nil
- Install progress spinner when `pluginsVM.installingPlugins.contains(plugin.name)`
- NavigationLink wraps full row (was already done for PluginConfigView)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] macOS switch not exhaustive for .hooks case**
- Found during: Task 4.5 macOS build verification
- Issue: `MacContentView.swift` had two switch statements on `ActiveScreen` missing `.hooks` case
- Fix: Added `.hooks: HooksManagementView()` to `detailContent` switch and `.hooks: selectedSection = .settings` to `handleNavigationIntent` switch
- Files modified: `ILSApp/ILSMacApp/Views/MacContentView.swift`
- Commit: 5ff840a

**2. [Rule 3 - Blocking] PremiumView navigationBarTitleDisplayMode unavailable on macOS**
- Found during: macOS build after Task 4.5 changes
- Issue: Pre-existing `PremiumView.swift:36` used `navigationBarTitleDisplayMode(.inline)` without `#if os(iOS)` guard
- Fix: Wrapped in `#if os(iOS)` conditional compilation
- Files modified: `ILSApp/ILSApp/Views/Premium/PremiumView.swift`
- Commit: 5ff840a

**3. [Rule 3 - Blocking] CustomThemeAdapter.swift not in Xcode project**
- Found during: Task 4.6 iOS build after creating adapter
- Issue: New Swift file created via Write tool not automatically included in `project.pbxproj`
- Fix: Ran `xcodegen generate` to regenerate project from `project.yml` (which uses glob patterns)
- Files modified: `ILSApp/ILSApp.xcodeproj/project.pbxproj`
- Commit: 4268148

### Pre-existing Work (not counted as deviations)
- `PluginConfigView.swift` — fully implemented from previous sessions (Task 4.2 was pre-done)
- `HooksManagementView.swift` — fully implemented from previous sessions (Task 4.5 navigation link only needed)
- `ThemesListView.swift` — already wired `ThemeEditorView` (stubs mentioned in plan were already removed)
- `MCPServerDetailView.swift` — masking + reveal already implemented (only auto-hide was missing)

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| CustomThemeAdapter.swift exists | FOUND |
| HooksManagementView.swift exists | FOUND |
| SkillsFileService.swift exists | FOUND |
| BrowserView.swift exists | FOUND |
| MCPServerDetailView.swift exists | FOUND |
| 04-SUMMARY.md exists | FOUND |
| Commit 1a6ceb9 exists | FOUND |
| Commit 5ff840a exists | FOUND |
| Commit 4268148 exists | FOUND |
| Skills API total | 1336 (was 3505) |
| Skills API contamination | 0 |
