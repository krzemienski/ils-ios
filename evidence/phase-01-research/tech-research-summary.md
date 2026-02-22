# Technical Documentation Research Summary

**Gate:** VG-03B | **Status:** PASS | **Date:** 2026-02-21
**Researcher:** tech-researcher | **Sources:** Context7 MCP, Official Documentation, Web Research

---

## 1. SwiftUI NavigationSplitView

**Problem:** Current code uses a custom `ZStack` overlay sidebar on iPhone (`SidebarRootView.swift` lines 130-148) and `NavigationSplitView` on iPad (lines 112-126). Should we unify to a single `NavigationSplitView` for both?

**Recommendation:** Keep the current split approach. `NavigationSplitView` on iPhone collapses the sidebar into a full-screen list pushed onto the navigation stack -- it does NOT provide a floating/overlay sidebar. The current custom overlay (280pt, edge swipe, spring animation) provides a better hamburger-menu UX on iPhone. Unifying would degrade the iPhone experience.

**Key patterns for iPad/Mac:**

```swift
@State private var columnVisibility: NavigationSplitViewVisibility = .automatic
@State private var preferredColumn: NavigationSplitViewColumn = .sidebar
@State private var selectedItem: Item.ID?

NavigationSplitView(
    columnVisibility: $columnVisibility,
    preferredCompactColumn: $preferredColumn
) {
    List(items, selection: $selectedItem) { item in
        NavigationLink(value: item) { Text(item.name) }
    }
} detail: {
    if let selectedItem { DetailView(item: selectedItem) }
    else { Text("Select an item") }
}
```

**Gotchas:**
- Column visibility is IGNORED when collapsed (iPhone) -- system decides layout
- `preferredCompactColumn` controls which column shows first when collapsed
- Use value-presenting `NavigationLink(value:)` for proper stack adaptation on iPhone
- Three-column layout only shows all three on iPad landscape or Mac

**Files to modify:** None -- current `SidebarRootView.swift` approach is correct. iPad uses `NavigationSplitView`, iPhone uses custom overlay. This is the right architecture.

---

## 2. @Observable + Environment Injection

**Problem:** How to implement config inheritance display (showing "Inherited" vs "Custom Override" badges) with the existing `@Observable` AppState pattern?

**Recommendation:** Use `@Observable` view models with computed properties that compare local values against host defaults. The existing `SettingsConfigSection.swift` already has `InheritanceBadge` and `settingAnnotation()` -- extend this pattern to all settings.

**Key pattern for inheritance badges:**

```swift
@Observable @MainActor
class SettingsViewModel {
    var hostConfig: ClaudeConfig?     // from GET /config?scope=user
    var localOverrides: [String: Any] = [:]

    func isInherited(key: String) -> Bool {
        return localOverrides[key] == nil
    }

    func effectiveValue<T>(key: String, hostValue: T, localValue: T?) -> T {
        localValue ?? hostValue
    }
}

// In view:
HStack {
    Text("Default Model")
    Spacer()
    Text(viewModel.effectiveModel)
    InheritanceBadge(isInherited: viewModel.isInherited(key: "model"))
}
```

**Gotchas:**
- `@Observable` classes do NOT need `@Published` -- property access is tracked automatically
- Use `@Environment` to propagate shared state (AppState) down the view tree
- `@State` initializers run before `@EnvironmentObject` is injected -- never access environment in `@State init`

**Files to modify:** `SettingsViewModel.swift` (add host config comparison), `SettingsConfigSection.swift` (extend annotations to all settings)

---

## 3. SwiftUI Form/Settings Patterns

**Problem:** How to build a settings screen with inheritance indicators (badges showing "Host Default" vs "Custom Override") following Apple HIG?

**Recommendation:** Use Apple's native `Form` with `Section` headers, `LabeledContent` for key-value display, and progressive disclosure via `DisclosureGroup`. Add inheritance badges as trailing content in each row.

**Key pattern:**

```swift
Form {
    Section("General") {
        LabeledContent("Default Model") {
            HStack {
                Text(viewModel.effectiveModel)
                settingAnnotation(
                    isInherited: viewModel.isModelInherited,
                    tooltip: "Model used for new sessions when not specified"
                )
            }
        }

        LabeledContent("Color Scheme") {
            Picker("", selection: $viewModel.colorScheme) {
                Text("System").tag(ColorScheme?.none)
                Text("Light").tag(ColorScheme?.some(.light))
                Text("Dark").tag(ColorScheme?.some(.dark))
            }
        }
    }
}
```

**Gotchas:**
- `Form` automatically adapts styling per platform (grouped on iOS, standard on macOS)
- Use `LabeledContent` (iOS 16+) instead of custom `HStack { Text(); Spacer(); Text() }`
- `DisclosureGroup` for expandable sections (permissions rules, allowed tools)
- Reset-to-default: show an "x" button only on overridden values that calls `viewModel.resetToInherited(key:)`

**Files to modify:** `SettingsConfigSection.swift` (already has foundation -- extend to all 8 settings items per REQ-10)

---

## 4. SSE (Server-Sent Events) in Swift

**Problem:** Current `SSEClient` pattern for chat streaming and system metrics. Research connection lifecycle best practices for backgrounding/resuming.

**Recommendation:** The current SSEClient implementation is architecturally sound. Key improvements: (1) ensure clean disconnect on `scenePhase` change to `.background`, (2) implement heartbeat watchdog (already done: `LastActivityTracker` actor with 45s timeout), (3) exponential backoff on reconnection (already implemented: max 3 attempts, capped 30s).

**Key lifecycle pattern:**

```swift
// SSE connection lifecycle with scenePhase
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active:
        sseClient.reconnectIfNeeded()
    case .background:
        sseClient.disconnect()
    case .inactive:
        break // keep connection during app switcher
    @unknown default:
        break
    }
}
```

**Gotchas:**
- `URLSessionStreamTask` is NOT suitable for SSE -- use `URLSessionDataTask` with streaming delegate
- iOS kills background connections after ~30s -- always disconnect cleanly on background
- Heartbeat watchdog prevents "zombie" connections where TCP is alive but server stopped sending
- Two-tier timeout: 30s for initial connection, 5min for total response (already implemented)
- `ObservableObject` is required for SSEClient because `URLSession` delegate requires class conformance

**Files to modify:** None critical -- current `SSEClient.swift` implementation is correct. Monitor `MetricsWebSocketClient.swift` for similar patterns.

---

## 5. SwiftUI Theming with EnvironmentValues

**Problem:** Current `ThemeSnapshot` + `\.theme` environment key pattern. How to properly preview themes and fix the "0 themes" backend issue?

**Recommendation:** The existing `ThemeSnapshot` pattern (concrete Sendable struct replacing `any AppTheme` existential) is architecturally correct and performant. The "0 themes" issue is a backend data problem, not a theming architecture issue -- `ThemesController` reads from the database which has no seeded themes. Built-in themes are Swift-side only in `ThemeManager`.

**Key pattern (already implemented):**

```swift
// ThemeSnapshot as EnvironmentValue
private struct ThemeKey: EnvironmentKey {
    static let defaultValue = ThemeSnapshot(from: ObsidianTheme())
}

extension EnvironmentValues {
    var theme: ThemeSnapshot {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// Usage in any view
@Environment(\.theme) private var theme
// theme.fontBody, theme.bgPrimary, theme.accent, etc.
```

**Fix for 0 themes:** Either (A) seed the database with the 13 built-in themes on backend startup, or (B) have `ThemesController` return built-in themes from `ThemeManager` when the database is empty. Option B is simpler and keeps the single source of truth in Swift code.

**Gotchas:**
- `.preferredColorScheme` propagates UP to enclosing presentation (sheet/window), not just down
- Setting `.environment(\.colorScheme)` only affects children -- usually not what you want
- Asset Catalog colors auto-resolve for light/dark but NOT for custom themes
- Store theme identifier in `@AppStorage`, not the theme object
- 13 built-in themes: Cyberpunk, Obsidian, Slate, Midnight, GhostProtocol, NeonNoir, ElectricGrid, Ember, Crimson, Carbon, Graphite, Paper, Snow

**Files to modify:** `Sources/ILSBackend/Controllers/ThemesController.swift` (return built-in themes), `ThemeManager.swift` (expose theme list for API)

---

## 6. Claude Code CLI Config Hierarchy

**Problem:** How does `~/.claude.json` (user), `.claude.json` (project), `.claude/settings.json` (local) merge? The backend `GET /api/v1/config?scope=user` currently returns raw `~/.claude.json` without `model` field.

**Recommendation:** Claude Code uses a 5-level settings hierarchy (highest to lowest precedence): (1) Managed settings (`/Library/Application Support/ClaudeCode/`), (2) CLI arguments, (3) Local project (`.claude/settings.local.json` -- gitignored), (4) Project (`.claude/settings.json` -- committed), (5) User (`~/.claude/settings.json`).

**Key configuration structure:**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "claude-sonnet-4-6",
  "permissions": {
    "allow": ["Bash(npm run *)", "Read", "Write"],
    "ask": ["Bash(git push *)"],
    "deny": ["Read(.env*)", "WebFetch"]
  },
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "./validate.sh" }] }]
  },
  "env": { "NODE_ENV": "development" }
}
```

**Fix for missing model field:** The config endpoint reads `~/.claude.json` which is a legacy file. The actual settings file is `~/.claude/settings.json`. Update `ConfigFileService.swift` to read from the correct path hierarchy and merge scopes. The `model` field should come from the effective merged config, not just the user-level file.

**Gotchas:**
- Settings merge across scopes -- lower precedence ADDS to higher, but `deny` always wins
- Permission rule syntax: `'Tool'` (all uses), `'Tool(specifier)'` (specific pattern), `'Tool(glob)'` (glob)
- Model field accepts aliases: `'sonnet'`, `'haiku'`, `'opus'` -- actual model determined by `ANTHROPIC_DEFAULT_*_MODEL` env vars
- Hooks are snapshot at startup -- mid-session changes require review in `/hooks` menu
- `.claude/settings.local.json` is auto-gitignored

**Files to modify:** `Sources/ILSBackend/Services/ConfigFileService.swift` (read correct paths, merge scopes), `Sources/ILSBackend/Controllers/ConfigController.swift` (expose merged config)

---

## 7. SwiftUI Accessibility + Dynamic Type

**Problem:** Current code uses `theme.fontCaption`, `theme.fontBody` etc. Do these properly scale with Dynamic Type?

**Recommendation:** The theme font tokens (`theme.fontCaption`, `theme.fontBody`, etc.) use SwiftUI's `.system()` font API with relative text styles, which DOES support Dynamic Type automatically. The key is that no hardcoded absolute font sizes below 11pt should exist anywhere (HIG minimum). The previous audit eliminated all `size: 10` instances (39 occurrences across 14 files, replaced with `theme.fontCaption`).

**Key pattern (already implemented):**

```swift
// In ThemeSnapshot (correct - uses text style):
var fontCaption: Font { .system(.caption) }
var fontBody: Font { .system(.body) }
var fontTitle: Font { .system(.title).bold() }

// In views (correct usage):
Text("Label")
    .font(theme.fontCaption)
    .foregroundStyle(theme.textSecondary)
```

**Gotchas:**
- `.system(.caption)` automatically scales with Dynamic Type -- no `.dynamicTypeSize()` modifier needed
- `.dynamicTypeSize()` modifier is for LIMITING range, not enabling scaling
- HIG minimum font size is 11pt -- `LaunchScreenView` correctly uses `size: 11` for monospaced
- All 13 themes should use relative text styles, not absolute sizes
- VoiceOver labels: most views have `.accessibilityLabel()` but coverage needs systematic audit
- Test with Accessibility Inspector in Xcode to verify Dynamic Type scaling

**Files to modify:** None -- current theme font token system is correct. Verify no new hardcoded sizes are introduced during Phases 2-6.
