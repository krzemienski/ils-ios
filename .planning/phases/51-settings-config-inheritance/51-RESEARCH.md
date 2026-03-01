# Phase 51: Settings & Config Inheritance - Research

**Researched:** 2026-02-27
**Domain:** SwiftUI Settings UI with config cascade visualization, info tooltips, and backend-driven inheritance
**Confidence:** HIGH

## Summary

Phase 51 transforms the iOS Settings screen from displaying a single config scope (user) into a cascade-aware view that shows which settings are inherited from the host CLI vs locally overridden. The backend work is already complete -- Phase 50 delivered `GET /api/v1/config/effective` which returns `EffectiveConfig` containing merged config values, per-key `ConfigOverride` annotations with `winningScope`, and raw `ConfigProfiles` for all 4 scopes (user, project, local, managed).

The iOS codebase is well-positioned. `SettingsConfigSection.swift` already has an `InheritanceBadge` view (shows "Host Default" or "Custom"), a `SettingsInfoButton` popover component, and a `settingAnnotation(isInherited:tooltip:)` helper that renders both together. The current logic derives `isInherited` from whether a field is `nil` in the single-scope config (`config.model == nil` means inherited). Phase 51 replaces this heuristic with actual data from the `/config/effective` endpoint -- the `ConfigOverride.winningScope` tells the UI definitively whether the value comes from the user scope (custom) or a higher-precedence scope (inherited).

Three gaps need closing: (1) `SettingsViewModel` must call `/config/effective` instead of (or in addition to) `/config?scope=user`, and expose the `EffectiveConfig` data to views; (2) 13 of 15 tooltips are under 20 words and need expanding to meet CFG-03's minimum threshold; (3) the macOS `MacSettingsView` has no inheritance badges, no tooltips, and uses `@AppStorage` for local defaults instead of reading from the backend config -- it needs parity with the iOS implementation.

**Primary recommendation:** Add a `loadEffectiveConfig()` method to `SettingsViewModel` that calls `/config/effective`, stores the `EffectiveConfig`, and provides a helper `isInherited(key:) -> Bool` that checks `ConfigOverride.winningScope != .user`. Update `SettingsConfigSection` to use this data. Expand all tooltips to 20+ words. Bring macOS settings up to parity.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CFG-01 | Config cascade visualization shows "inherited from host" vs "custom override" badges on each setting | `InheritanceBadge` view already exists. Current `isInherited` logic uses nil-check heuristic. Must replace with `ConfigOverride.winningScope` data from `/config/effective`. See "Architecture Patterns > Pattern 1" and "Code Examples > ViewModel Integration". |
| CFG-02 | System prompt and model defaults inherited from connected host CLI configuration, not hardcoded | System prompt section exists with hardcoded `isInherited: true`. Model picker defaults to `SettingsViewModel.defaultModelID` constant. Must use effective config's merged `model` value and winningScope. See "Architecture Patterns > Pattern 2". |
| CFG-03 | Info tooltips (>=20 words) on tool controls, permissions, and settings sections | `SettingsInfoButton` popover component exists. 13 of 15 tooltips are under 20 words. Must expand each to >=20 words with meaningful explanatory text. See "Common Pitfalls > Pitfall 3" for word count audit. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Settings UI, badges, popovers | Already used by all Settings views |
| ILSShared | local | `EffectiveConfig`, `ConfigOverride`, `ConfigScope` DTOs | Already has all required types from Phase 50 |
| Observation | Swift 5.10+ | `@Observable` for SettingsViewModel | Already used by SettingsViewModel |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| APIClient (actor) | local | HTTP GET for `/config/effective` | For fetching effective config data |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Server-side merge (current) | Client-side merge (fetch 3 scopes, merge in VM) | Server-side is correct -- `EffectiveConfig` already exists. No reason to duplicate merge logic. |
| Replace `loadConfig()` entirely | Keep both `loadConfig()` and `loadEffectiveConfig()` | Keep both: `loadConfig(scope: .user)` is needed by `saveWithPatch` (read-modify-write on user scope). `loadEffectiveConfig()` provides the cascade view. |
| Separate ViewModel for effective config | Extend existing SettingsViewModel | Extending is simpler -- one VM, one API client reference, shared loading state. |

**Installation:** No new dependencies. All types exist in ILSShared. APIClient already supports generic `GET`.

## Architecture Patterns

### Recommended Changes

```
ILSApp/ILSApp/
├── ViewModels/
│   └── SettingsViewModel.swift     # ADD: loadEffectiveConfig(), effectiveConfig property, isInherited(key:) helper
├── Views/Settings/
│   └── SettingsConfigSection.swift  # MODIFY: use effectiveConfig for badge logic, expand tooltips
│   └── SettingsView.swift           # MODIFY: call loadEffectiveConfig() in .task
└── ...

ILSApp/ILSMacApp/Views/
└── MacSettingsView.swift            # MODIFY: add inheritance badges, tooltips, use backend config
```

### Pattern 1: EffectiveConfig-Driven Inheritance Badges

**What:** Replace the nil-check heuristic (`config.model == nil` means inherited) with actual `ConfigOverride.winningScope` data from the backend.

**When to use:** For every setting row that displays an `InheritanceBadge`.

**Current (heuristic):**
```swift
settingAnnotation(
    isInherited: config.model == nil,  // Nil means "not set in this scope" = inherited
    tooltip: "..."
)
```

**New (data-driven):**
```swift
settingAnnotation(
    isInherited: viewModel.isInherited(key: "model"),  // Checks winningScope from /config/effective
    tooltip: "..."
)
```

**Why this is better:** The nil-check heuristic only works when viewing a single scope. If the user sets `model` in the user scope, it shows "Custom" even if a project-scope override actually wins. The effective config endpoint resolves this ambiguity.

### Pattern 2: System Prompt and Model Defaults from Host

**What:** Show the actual inherited value (from whichever scope wins) rather than a hardcoded fallback.

**Current problem:** The model picker defaults to `SettingsViewModel.defaultModelID = "claude-sonnet-4-20250514"` when `config.model` is nil. This is a hardcoded iOS-side fallback, not the host's actual default.

**Solution:** Use `effectiveConfig.config.model` as the displayed value. If the winning scope is not `.user`, show the "Host Default" badge with the actual model name from the effective config.

**For system prompt:** The system prompt section currently hardcodes `isInherited: true`. This is structurally correct (CLAUDE.md files are always host-side), but should still reference the effective config to confirm no override exists.

### Pattern 3: saveWithPatch Compatibility

**What:** The existing `saveWithPatch` method reads from `/config?scope=user`, applies a delta, and PUTs back. This pattern must be preserved.

**Why it matters:** When a user toggles a setting from "Inherited" to "Custom", the write goes to the user scope. The `saveWithPatch` method correctly handles this. After saving, `loadEffectiveConfig()` should be called to refresh the cascade view so the badge updates from "Host Default" to "Custom".

**Flow:**
1. User toggles setting -> `saveWithPatch` writes to user scope
2. After save completes -> `loadEffectiveConfig()` refreshes cascade data
3. Badge updates from "Host Default" to "Custom" because `winningScope` is now `.user`

### Anti-Patterns to Avoid

- **Removing the user-scope config load:** `loadConfig(scope: .user)` is still needed by `saveWithPatch`. Don't remove it.
- **Writing to non-user scopes from iOS:** The backend only supports writes to the user scope. Don't try to write to project/local/managed.
- **Showing raw `winningScope` to users:** Display "Host Default" (for user, project, local, managed that isn't the user) or "Custom" (for user scope), not "project" or "local".
- **Caching effective config too aggressively:** APIClient caches `/config` paths for 60 seconds. After a `saveWithPatch`, bypass cache by reloading.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config merge logic on iOS | Client-side merge of 3+ scope files | `GET /config/effective` backend endpoint | Server already implements the merge with correct precedence. Duplicating it risks drift. |
| Inheritance badge component | New badge view | Existing `InheritanceBadge` struct | Already shows "Host Default" / "Custom" with correct styling |
| Tooltip popover component | New tooltip view | Existing `SettingsInfoButton` struct | Already renders info.circle + popover with theme-consistent styling |
| Per-key scope lookup | Iterating overrides array on every render | `Dictionary` lookup built once from `[ConfigOverride]` | O(1) lookups instead of O(n) per setting row |

**Key insight:** The UI components already exist. This phase is about wiring them to real data (effective config endpoint) and expanding tooltip text. No new UI components are needed.

## Common Pitfalls

### Pitfall 1: Dual Config State Confusion

**What goes wrong:** Having both `config: ConfigInfo?` (user scope) and `effectiveConfig: EffectiveConfig?` on the ViewModel creates confusion about which to read from.

**Why it happens:** `saveWithPatch` needs the user-scope config for read-modify-write. The UI needs the effective config for display.

**How to avoid:** Clear naming and documentation. `config` is the user-scope config used by `saveWithPatch`. `effectiveConfig` is the merged config used by the UI for display and badge logic. The `loadAll()` method should load both. Consider renaming `config` to `userScopeConfig` for clarity.

**Warning signs:** UI showing "Custom" badge but the value actually comes from project scope.

### Pitfall 2: Badge Not Updating After Save

**What goes wrong:** User toggles a setting, it saves successfully, but the badge still shows "Host Default" because the effective config wasn't reloaded.

**Why it happens:** `saveWithPatch` updates the user-scope config and refreshes `config`, but doesn't refresh `effectiveConfig`.

**How to avoid:** After every `saveWithPatch` call, also call `loadEffectiveConfig()` to refresh cascade data. The badge will update because `winningScope` for the changed key will now be `.user`.

**Warning signs:** Badge stays "Host Default" after toggling a setting to "Custom".

### Pitfall 3: Tooltip Word Count Below Threshold

**What goes wrong:** CFG-03 requires >=20 words per tooltip. 13 of 15 current tooltips are under 20 words.

**Current word counts (BELOW 20):**
| Setting | Current Words | Text |
|---------|--------------|------|
| Model | 17 | "The Claude model used for conversations..." |
| Color Scheme | 9 | "Controls the app's appearance..." |
| Updates Channel | 14 | "Controls which release channel..." |
| Extended Thinking | 12 | "Enables extended thinking mode..." |
| Co-Author | 10 | "Adds co-authored-by attribution..." |
| Default Mode | 13 | "Controls which tools Claude can use..." |
| Allowed Rules | 14 | "Tools and patterns explicitly allowed..." |
| Denied Rules | 12 | "Tools and patterns explicitly blocked..." |
| Hooks | 17 | "Lifecycle hooks that run custom commands..." |
| Plugins | 13 | "Plugins installed and enabled on the host..." |
| Status Line | 13 | "Custom status line displayed..." |
| Env Vars | 11 | "Environment variables passed to Claude..." |
| Agent Teams | 16 | "Experimental feature: coordinate multiple AI..." |

**Tooltips already >=20 words (PASS):**
- System Prompt: 36 words
- API Key: 25 words

**How to avoid:** Expand each tooltip to at least 20 words with meaningful content: what the setting does, what values are valid, where it's configured, and what happens when changed. Do not pad with filler.

**Warning signs:** Tooltips that repeat the setting label or add meaningless words to reach the count.

### Pitfall 4: macOS Settings View Divergence

**What goes wrong:** `MacSettingsView` uses `@AppStorage` for model and color scheme defaults, completely disconnected from the backend config. It has no inheritance badges, no tooltips, and no effective config integration.

**Why it happens:** macOS was built with local-only settings as a simpler initial implementation.

**How to avoid:** macOS general settings should use the same `SettingsViewModel` pattern as iOS: load effective config, display inheritance badges, show tooltips. The `@AppStorage` values for `defaultModel` and `colorSchemePreference` should be replaced with (or derived from) the effective config.

**Warning signs:** iOS and macOS showing different model defaults or different inheritance states.

### Pitfall 5: APIClient Cache Stale After Write

**What goes wrong:** After `saveWithPatch` writes to user config, the next `GET /config/effective` returns stale cached data because the cache TTL is 60 seconds.

**Why it happens:** APIClient has a 60-second TTL for `/config` paths. The effective config endpoint uses the same prefix.

**How to avoid:** Either (a) pass `cacheTTL: 0` when calling `loadEffectiveConfig()` after a save, or (b) add a cache invalidation method to APIClient for a specific path. Option (a) is simpler and sufficient for this use case.

**Warning signs:** Badge not updating until 60 seconds after toggling a setting.

## Code Examples

### ViewModel Integration

```swift
// SettingsViewModel additions

/// Effective configuration with per-key scope annotations from /config/effective.
/// Used by the UI for inheritance badge logic.
var effectiveConfig: EffectiveConfig?

/// Per-key override lookup for O(1) access.
private var overrideLookup: [String: ConfigOverride] = [:]

func loadEffectiveConfig(bypassCache: Bool = false) async {
    guard let client else { return }
    isLoadingConfig = true
    do {
        let cacheTTL: TimeInterval? = bypassCache ? 0 : nil
        let response: APIResponse<EffectiveConfig> = try await client.get(
            "/config/effective",
            cacheTTL: cacheTTL
        )
        effectiveConfig = response.data
        // Build lookup dictionary for O(1) access
        if let overrides = response.data?.overrides {
            overrideLookup = Dictionary(
                uniqueKeysWithValues: overrides.map { ($0.key, $0) }
            )
        }
    } catch {
        self.error = error
    }
    isLoadingConfig = false
}

/// Whether a setting key's effective value comes from a scope other than user.
func isInherited(key: String) -> Bool {
    guard let override = overrideLookup[key] else {
        return true // No override means no value set anywhere -- treat as inherited/default
    }
    return override.winningScope != .user
}

/// The winning scope label for display purposes.
func winningScope(for key: String) -> ConfigScope? {
    overrideLookup[key]?.winningScope
}
```

### Updated loadAll

```swift
func loadAll() async {
    async let statsTask: () = loadStats()
    async let effectiveTask: () = loadEffectiveConfig()
    async let configTask: () = loadConfig()  // Still needed for saveWithPatch
    async let healthTask: () = loadHealth()
    _ = await (statsTask, effectiveTask, configTask, healthTask)
}
```

### Updated settingAnnotation Usage

```swift
// In SettingsConfigSection, replace:
settingAnnotation(
    isInherited: config.model == nil,
    tooltip: "The Claude model used for conversations..."
)

// With:
settingAnnotation(
    isInherited: viewModel.isInherited(key: "model"),
    tooltip: "The Claude model used for new conversations. When set to 'inherited', the model configured in your host's Claude CLI settings (via `claude config set model`) is used. Override locally to use a different model for this device."
)
```

### Model Picker Using Effective Config

```swift
// Use effective config for display value, user config for writes
Picker("Default Model", selection: Binding(
    get: {
        // Show the effective (merged) model value
        viewModel.effectiveConfig?.config.model ?? SettingsViewModel.defaultModelID
    },
    set: { newModel in
        viewModel.updateModel(newModel)
    }
)) {
    ForEach(availableModels, id: \.self) { model in
        Text(formatModelName(model)).tag(model)
    }
}
```

### saveWithPatch + Effective Config Refresh

```swift
// After any saveWithPatch, refresh effective config to update badges
func saveWithPatch(applying delta: (inout ClaudeConfig) -> Void) async -> String? {
    // ... existing implementation ...

    // After successful save, refresh effective config with cache bypass
    if result == nil {  // nil means success
        await loadEffectiveConfig(bypassCache: true)
    }
    return result
}
```

### Expanded Tooltip Example (>=20 words)

```swift
// BEFORE (9 words -- FAILS CFG-03):
tooltip: "Controls the app's appearance. System follows your device setting."

// AFTER (24 words -- PASSES CFG-03):
tooltip: "Controls whether the app uses light or dark mode. 'System' automatically follows your device's Display & Brightness setting. This preference is stored in your local app configuration."
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-scope config display | Effective config with cascade visualization | Phase 51 (this phase) | UI shows actual inheritance, not heuristic |
| Nil-check for inheritance (`config.model == nil`) | `ConfigOverride.winningScope != .user` from `/config/effective` | Phase 51 (this phase) | Accurate badges when project/local scope has values |
| Short tooltips (9-17 words) | Expanded tooltips (>=20 words each) | Phase 51 (this phase) | Meets CFG-03 requirement |
| macOS uses @AppStorage only | macOS uses backend config with inheritance | Phase 51 (this phase) | Cross-platform parity |

**Deprecated/outdated:**
- The nil-check heuristic (`config.model == nil` means inherited) will be superseded but not removed -- it served as a reasonable placeholder before the effective config endpoint existed.

## Open Questions

1. **Should macOS general settings fully mirror iOS, or is partial parity acceptable?**
   - What we know: `MacSettingsView` uses `@AppStorage` for model and color scheme, has no inheritance badges or tooltips, and doesn't load config from the backend.
   - What's unclear: Whether full parity is required for Phase 51, or if it can be deferred. The success criteria mention "each setting row in the Settings screen" without specifying platform.
   - Recommendation: Include macOS in Phase 51 scope. The General and Advanced tabs should show inheritance badges and tooltips. Use the same `SettingsViewModel` and `EffectiveConfig` data. The `@AppStorage` values for model/colorScheme should be replaced with backend-driven values plus a local persistence layer for offline access.

2. **Cache invalidation strategy after settings writes**
   - What we know: APIClient caches `/config` paths for 60 seconds. After `saveWithPatch`, the effective config endpoint may return stale data.
   - What's unclear: Whether passing `cacheTTL: 0` is sufficient, or if a cache `invalidate(path:)` method is needed.
   - Recommendation: Use `cacheTTL: 0` for the post-save reload. This is simple and sufficient. APIClient's `get` method already supports this parameter. No new cache invalidation API needed.

3. **How to handle settings that exist only locally (Agent Teams toggle)**
   - What we know: The "Agent Teams" experimental toggle uses `@AppStorage("enableAgentTeams")` and has no backend equivalent. Its badge correctly shows `isInherited: false`.
   - What's unclear: Should purely local settings still have the "Custom" badge, or should they use a different indicator like "Local Only"?
   - Recommendation: Keep the "Custom" badge. "Local Only" would require a third badge variant and adds complexity without user value. The tooltip already explains "This setting is stored locally on your device."

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` -- existing InheritanceBadge, SettingsInfoButton, settingAnnotation patterns (555 lines)
- Codebase analysis: `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` -- loadConfig, saveWithPatch, saveConfig patterns (183 lines)
- Codebase analysis: `Sources/ILSBackend/Controllers/ConfigController.swift` -- effective() route handler already implemented
- Codebase analysis: `Sources/ILSBackend/Services/ConfigFileService.swift` -- readEffectiveConfig() merge logic already implemented (360 lines)
- Codebase analysis: `Sources/ILSShared/DTOs/ResponseDTOs.swift` -- EffectiveConfig, ConfigOverride, ConfigProfiles DTOs
- Codebase analysis: `Sources/ILSShared/Models/ClaudeConfig.swift` -- all config fields with Optional types
- Codebase analysis: `Sources/ILSShared/Models/MCPServer.swift` -- ConfigScope enum with managed case
- Codebase analysis: `ILSApp/ILSMacApp/Views/MacSettingsView.swift` -- macOS settings (no inheritance, no tooltips, @AppStorage only)
- Codebase analysis: `ILSApp/ILSApp/Services/APIClient.swift` -- generic get with cacheTTL parameter, 60s TTL for /config paths

### Secondary (MEDIUM confidence)
- Phase 50 research: `.planning/phases/50-backend-api/50-RESEARCH.md` -- config merge architecture, scope precedence
- Phase 50 plan: `.planning/phases/50-backend-api/50-01-PLAN.md` -- confirms EffectiveConfig endpoint is implemented

### Tertiary (LOW confidence)
- None. All findings are from direct codebase analysis.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All types, components, and endpoint already exist. No new dependencies.
- Architecture: HIGH -- Pattern is clear: add loadEffectiveConfig() to ViewModel, wire to existing UI components.
- Pitfalls: HIGH -- All pitfalls identified from direct code analysis (word counts, cache TTL, dual state, macOS divergence).
- Tooltip expansion: HIGH -- Exact word counts measured, specific tooltips identified for expansion.

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable domain -- SwiftUI patterns and existing codebase structure don't change rapidly)
