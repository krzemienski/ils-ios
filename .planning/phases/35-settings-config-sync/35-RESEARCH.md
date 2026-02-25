# Phase 35: Settings & Config Sync - Research

**Researched:** 2026-02-25
**Domain:** SwiftUI settings UI with host CLI config sync, inheritance badges, write-safety, and tooltips
**Confidence:** HIGH (all findings from direct codebase inspection + official Claude Code docs)

## Summary

Phase 35 transforms the Settings screen from a partial config mirror into a complete, safe, annotated configuration interface. The existing codebase is 60-70% ready: `InheritanceBadge`, `SettingsInfoButton`, and `settingAnnotation()` components already exist and work correctly on 7 of the ~15 settings fields. The write path (`saveConfig` / `saveConfigToggle`) has a critical safety gap: it round-trips the entire `ClaudeConfig` struct, which silently drops CLI-only fields (`hooks`, `env`, `permissions`, `statusLine`) when the iOS app writes back fields it does not render UI for.

The config auto-refresh mechanism (`onChange(of: appState.serverURL)`) was wired in Phase 34 for SettingsView and 7 other views. The remaining work is: (1) add `settingAnnotation` to the 8 fields that lack it, (2) implement a write allowlist so saves never clobber CLI-only fields, (3) add `onChange(of: appState.isConnected)` trigger for reconnect scenarios, (4) add a system prompt display field (read-only -- `systemPrompt` is NOT a settings.json field; it comes from CLAUDE.md files), (5) convert `saveConfig`/`saveConfigToggle` to a read-then-patch pattern, and (6) ensure every field has a tooltip.

**Primary recommendation:** Start with the write-safety allowlist (CFG-05/CFG-07) since it is the highest-risk item. Then extend `settingAnnotation` coverage (CFG-02/CFG-04). Add config auto-refresh (CFG-03) and system prompt display (CFG-06) last since they are additive with no safety implications.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CFG-01 | Display effective config values from connected host's `~/.claude/settings.json` | Already works via `SettingsViewModel.loadConfig(scope: "user")` -> `GET /config?scope=user`. Displays model, colorScheme, autoUpdatesChannel, toggles, hooks, plugins, env, statusLine, permissions, API key. No new endpoint needed -- existing data is the user-scope effective config. |
| CFG-02 | `InheritanceBadge` on ALL settings fields | 7 of ~15 fields have `settingAnnotation()`. Missing: Allowed rules, Denied rules, Enabled Plugins, Status Line, Environment Vars, API Key section, Agent Teams toggle. Pattern exists -- just needs broader application. |
| CFG-03 | Config auto-refresh on reconnect and host switch | `onChange(of: appState.serverURL)` already triggers `viewModel.loadAll()` in SettingsView (added Phase 34). Need to ADD `onChange(of: appState.isConnected)` for reconnect after network drop. Pattern exists in HomeView and BrowserView. |
| CFG-04 | `SettingsInfoButton` tooltip on every settings field | 7 fields have tooltips via `settingAnnotation()`. Same 8 fields missing tooltips as CFG-02 since `settingAnnotation()` bundles both badge and tooltip together. |
| CFG-05 | Write allowlist -- `hooks`, `env`, `permissions`, `statusLine` never in write payloads | CRITICAL safety gap. `saveConfig()` and `saveConfigToggle()` both do full `ClaudeConfig` struct PUT. Must implement read-then-patch: load fresh config, apply single-field delta, strip dangerous fields before PUT. |
| CFG-06 | System prompt field displayed (read-only if inherited) | `systemPrompt` is NOT a settings.json field per official Claude Code docs. System prompts come from CLAUDE.md files. The app should show CLAUDE.md content as read-only, OR show a "System prompt is configured via CLAUDE.md" informational note. `ClaudeConfig` does not have a `systemPrompt` property. |
| CFG-07 | Inline edit uses read-then-patch pattern | `saveConfig()` currently mutates `config?.content` in-memory then PUTs the full struct. Must change to: (1) GET fresh config, (2) apply delta, (3) strip non-allowlisted fields, (4) PUT. Both `saveConfig()` and `saveConfigToggle()` need this treatment. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Settings UI components | Already used throughout app |
| ILSShared | local | `ClaudeConfig`, `ConfigInfo`, DTOs | Shared between iOS and backend |
| Vapor 4 | latest | Backend ConfigController | Already serves `/config` endpoint |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | iOS 17+ | JSONEncoder/Decoder for config serialization | Config read/write |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Full struct PUT | JSON merge-patch (RFC 7396) | Server-side merge would be safer but requires new backend logic; read-then-patch on client side achieves same goal with existing API |
| New `/config/effective` endpoint | Existing `GET /config?scope=user` | Effective config would merge all scopes; user-scope is sufficient for v3.1 since the app labels it "User Defaults" |

**Installation:** No new dependencies needed.

## Architecture Patterns

### Current Settings Architecture
```
SettingsView (@Environment AppState)
  |-- .task { viewModel.configure(client:); loadAll() }
  |-- .onChange(appState.serverURL) { reconfigure + reload }
  |
  |-- SettingsConnectionSection
  |-- SettingsAppearanceSection
  |-- SettingsConfigSection (viewModel, colorSchemePreference binding)
  |     |-- generalSettingsSection    [7 settingAnnotation calls]
  |     |-- apiKeySection             [1 SettingsInfoButton, NO InheritanceBadge]
  |     |-- permissionsSection        [1 settingAnnotation on defaultMode, NOT on allow/deny]
  |     |-- advancedSection           [1 settingAnnotation on hooks, NOT on plugins/statusLine/env]
  |     |-- statisticsSection
  |-- SettingsAboutSection
```

### Pattern 1: settingAnnotation (existing, needs broader application)
**What:** Combines `InheritanceBadge` + `SettingsInfoButton` in a single HStack
**When to use:** After EVERY settings field that displays a config value
**Example:**
```swift
// Source: SettingsConfigSection.swift line 489
private func settingAnnotation(isInherited: Bool, tooltip: String) -> some View {
    HStack(spacing: theme.spacingSM) {
        InheritanceBadge(isInherited: isInherited)
        Spacer()
        SettingsInfoButton(text: tooltip)
    }
}
```

### Pattern 2: Read-Then-Patch Write (NEW -- must implement)
**What:** Before any config PUT, load fresh config from server, apply only the changed field, strip dangerous fields, then PUT
**When to use:** Every config write operation
**Example:**
```swift
// NEW pattern for SettingsViewModel
func saveConfigField<T>(_ keyPath: WritableKeyPath<ClaudeConfig, T>, value: T) async -> String? {
    guard let client else { return "Client not configured" }
    isSaving = true
    defer { isSaving = false }

    do {
        // Step 1: Load fresh config from server
        let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=user")
        guard var freshConfig = response.data?.content else {
            return "Could not load current configuration"
        }

        // Step 2: Apply the single-field delta
        freshConfig[keyPath: keyPath] = value

        // Step 3: Strip non-allowlisted fields before write
        let safeConfig = stripDangerousFields(freshConfig)

        // Step 4: PUT back
        let request = UpdateConfigRequest(scope: "user", content: safeConfig)
        let putResponse: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
        if let updated = putResponse.data {
            config = updated
        }
        return nil
    } catch {
        return "Failed to save: \(error.localizedDescription)"
    }
}

/// Fields the iOS app is allowed to write. Everything else is preserved from server state.
private static let writableFields: Set<String> = [
    "model", "theme", "autoUpdatesChannel",
    "alwaysThinkingEnabled", "includeCoAuthoredBy"
]
```

### Pattern 3: Config Auto-Refresh on Reconnect (existing pattern, needs addition)
**What:** `onChange(of: appState.isConnected)` triggers reload when connection restored
**When to use:** Settings screen needs fresh data after network recovery
**Example:**
```swift
// Source: HomeView.swift line 100 (existing pattern)
.onChange(of: appState.isConnected) { _, connected in
    if connected { Task { await viewModel.loadAll() } }
}
```

### Anti-Patterns to Avoid
- **Full struct round-trip PUT:** Never PUT the entire `ClaudeConfig` received from GET. This drops fields the app does not render (hooks, env, permissions rules, statusLine). Always strip to allowlisted fields only.
- **Treating user-scope as effective config:** The user-scope config (`~/.claude/settings.json`) is one of 6 precedence levels. Label it "User Defaults" not "Active Settings" or "Effective Config".
- **Adding systemPrompt to ClaudeConfig:** `systemPrompt` is not a settings.json field. It comes from CLAUDE.md files. Do not add it to the config model.
- **Using `try?` for save operations:** Current `saveConfig` uses `do/catch` correctly. Maintain this -- never downgrade to `try?` for user-visible mutations.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Inheritance badge | Custom badge component | Existing `InheritanceBadge` in SettingsConfigSection.swift | Already styled, themed, tested |
| Tooltip popover | Custom popover | Existing `SettingsInfoButton` in SettingsConfigSection.swift | Already handles sizing, dismissal, theming |
| Badge + tooltip combo | Separate badge and tooltip per field | Existing `settingAnnotation(isInherited:tooltip:)` | Single call per field, consistent spacing |
| Config scope detection | Manual nil-checking per field | `isInherited: config.fieldName == nil` pattern | All ClaudeConfig fields are Optional; nil = inherited |
| JSON field stripping | Manual property-by-property copy | Codable round-trip with explicit field inclusion | Safer than forgetting to copy a new field |

**Key insight:** The entire badge/tooltip infrastructure exists. The work is applying the existing `settingAnnotation()` function to 8 more fields and implementing write-safety. No new UI components needed.

## Common Pitfalls

### Pitfall 1: Config Write Drops CLI Fields (CRITICAL)
**What goes wrong:** `saveConfig()` PUTs the entire `ClaudeConfig` struct. Optional fields that were `nil` when decoded (because they weren't in the JSON from the server) are written back as field omission, effectively deleting them from the host's `~/.claude/settings.json`.
**Why it happens:** `ClaudeConfig` has fields like `hooks`, `env`, `permissions.allow`, `permissions.deny`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces` that the app reads but should never write. JSON Codable round-trip silently drops nil optional fields.
**How to avoid:** Implement a write allowlist. Only include fields the app explicitly manages (`model`, `theme`, `autoUpdatesChannel`, `alwaysThinkingEnabled`, `includeCoAuthoredBy`) in the write payload. Load fresh config, apply delta, strip everything outside the allowlist.
**Warning signs:** After changing model in Settings, hooks disappear from `~/.claude/settings.json`. Environment variables vanish. Permission rules reset.

### Pitfall 2: systemPrompt Is Not a settings.json Field
**What goes wrong:** Adding a `systemPrompt` property to `ClaudeConfig` and trying to read/write it via the config endpoint.
**Why it happens:** The requirement says "System prompt field displayed." But Claude Code configures system prompts via CLAUDE.md files, not settings.json. The official docs explicitly state: "To add custom instructions, use CLAUDE.md files or the --append-system-prompt flag."
**How to avoid:** CFG-06 should display an informational section: "System prompt is configured via CLAUDE.md files on your host" with a read-only display of the CLAUDE.md content if available. Do NOT add `systemPrompt` to `ClaudeConfig`. The NewSessionView and AdvancedOptionsSheet already handle per-session system prompts via the chat API -- that is a different concern.
**Warning signs:** Backend returns empty/null systemPrompt; field always shows as empty.

### Pitfall 3: onChange(isConnected) Without Guard
**What goes wrong:** `onChange(of: appState.isConnected)` fires on both connect AND disconnect. Without checking `if connected`, the app makes API calls during disconnection, producing errors.
**Why it happens:** SwiftUI `onChange` fires for any value change, including false->true and true->false.
**How to avoid:** Always guard: `if connected { Task { await viewModel.loadAll() } }`
**Warning signs:** Error banners flash during network transitions.

### Pitfall 4: Missing settingAnnotation on Read-Only Fields
**What goes wrong:** Fields like "Allowed rules", "Denied rules", "Enabled Plugins" are displayed without an InheritanceBadge. Users cannot tell if these are inherited from host config or explicitly set.
**Why it happens:** The original implementation added `settingAnnotation` to the first 5 fields (model, colorScheme, updatesChannel, two toggles) and the hooks field, but not to the remaining fields. The permissions allow/deny lists, plugins count, statusLine, and env vars were added later without the annotation.
**How to avoid:** Every settings row must be immediately followed by `settingAnnotation(isInherited:tooltip:)`. Audit all fields, not just editable ones.
**Warning signs:** Visual inconsistency -- some fields have badges, others don't.

### Pitfall 5: Stale Config After Save
**What goes wrong:** After `saveConfig()`, the local `config` property is updated from the PUT response. But if the user navigates away and back, `.task` calls `loadAll()` which may serve a cached response from `APIClient`'s NSCache (60s TTL for config).
**Why it happens:** `APIClient` caches GET responses. After a PUT, the cached GET is stale.
**How to avoid:** After any successful PUT to `/config`, invalidate the config cache: use `client.get("/config?scope=user", bypassCache: true)` or call `client.invalidateCache(for: "/config")` if such a method exists. Currently `loadConfig()` does a standard GET which may hit cache.
**Warning signs:** Settings show old values after navigating away and back within 60s of a save.

## Code Examples

### Current settingAnnotation Coverage Audit

Fields WITH `settingAnnotation()` (7 total):
```
General section:
  1. Default Model       -> settingAnnotation(isInherited: config.model == nil, ...)
  2. Color Scheme         -> settingAnnotation(isInherited: config.theme?.colorScheme == nil, ...)
  3. Updates Channel      -> settingAnnotation(isInherited: config.autoUpdatesChannel == nil, ...)
  4. Extended Thinking    -> settingAnnotation(isInherited: config.alwaysThinkingEnabled == nil, ...)
  5. Include Co-Author    -> settingAnnotation(isInherited: config.includeCoAuthoredBy == nil, ...)

Permissions section:
  6. Default Mode         -> settingAnnotation(isInherited: permissions.defaultMode == nil, ...)

Advanced section:
  7. Hooks Configured     -> settingAnnotation(isInherited: config.hooks == nil, ...)
```

Fields WITHOUT `settingAnnotation()` (8 total -- need adding):
```
API Key section:
  8. API Key Status       -> NEEDS: settingAnnotation(isInherited: true, tooltip: "...")
                             (always inherited -- API keys cannot be set from iOS app)

Permissions section:
  9. Allowed Rules        -> NEEDS: settingAnnotation(isInherited: permissions.allow == nil, ...)
  10. Denied Rules        -> NEEDS: settingAnnotation(isInherited: permissions.deny == nil, ...)

Advanced section:
  11. Enabled Plugins     -> NEEDS: settingAnnotation(isInherited: config.enabledPlugins == nil, ...)
  12. Status Line         -> NEEDS: settingAnnotation(isInherited: config.statusLine == nil, ...)
  13. Environment Vars    -> NEEDS: settingAnnotation(isInherited: config.env == nil, ...)

Experimental section:
  14. Agent Teams toggle  -> NEEDS: local-only annotation (AppStorage, not from host)
                             Consider: settingAnnotation(isInherited: false, tooltip: "...")
                             OR: a distinct "Local Only" badge variant

Statistics section:
  15. Stats rows          -> NO annotation needed (these are live counts, not config values)
```

### Tooltip Text Inventory (needed for CFG-04)

```swift
// Tooltips for fields that need them (CFG-04 completion):

// API Key
"Your Anthropic API key. Managed on the host via environment variables or `claude config set apiKey`. Cannot be edited from the iOS app for security."

// Allowed Rules
"Tools and patterns explicitly allowed to run without confirmation. Configured in host CLI settings."

// Denied Rules
"Tools and patterns explicitly blocked from running. Configured in host CLI settings."

// Enabled Plugins
"Plugins installed and enabled on the host. Manage plugins from the Browse tab."

// Status Line
"Custom status line displayed in the Claude Code terminal. Configured on the host."

// Environment Vars
"Environment variables passed to Claude Code sessions. Configured on the host."

// Agent Teams
"Experimental feature: coordinate multiple AI agents working together. This setting is stored locally on your device."
```

### Write Allowlist Implementation

```swift
// In SettingsViewModel -- fields the iOS app is allowed to modify
private static let writeAllowlist: Set<String> = [
    "model", "theme", "autoUpdatesChannel",
    "alwaysThinkingEnabled", "includeCoAuthoredBy"
]

/// Creates a ClaudeConfig containing ONLY allowlisted fields.
/// All other fields are nil (omitted from JSON), preserving whatever
/// the host has configured for hooks, env, permissions, etc.
private func sanitizedForWrite(_ config: ClaudeConfig) -> ClaudeConfig {
    ClaudeConfig(
        model: config.model,
        // permissions: nil -- NEVER write permissions from iOS
        // env: nil -- NEVER write env from iOS
        // hooks: nil -- NEVER write hooks from iOS
        // enabledPlugins: nil -- NEVER write plugin state from iOS
        // extraKnownMarketplaces: nil -- NEVER write
        includeCoAuthoredBy: config.includeCoAuthoredBy,
        // statusLine: nil -- NEVER write statusLine from iOS
        alwaysThinkingEnabled: config.alwaysThinkingEnabled,
        autoUpdatesChannel: config.autoUpdatesChannel,
        theme: config.theme
        // apiKeyStatus: nil -- NEVER write
    )
}
```

**CRITICAL PROBLEM with sanitizedForWrite approach:** If the server writes the sanitized config verbatim, it will ALSO drop the non-allowlisted fields from disk because they are nil/omitted. The correct approach requires a **server-side merge** OR a **client-side merge**:

```swift
/// Read-then-patch: load fresh config, apply delta, write back FULL config
/// with only the delta fields changed. This preserves all server-side fields.
func saveWithPatch(applying delta: (inout ClaudeConfig) -> Void) async -> String? {
    guard let client else { return "Client not configured" }
    isSaving = true
    defer { isSaving = false }

    do {
        // 1. Load fresh config
        let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=user")
        guard var freshConfig = response.data?.content else {
            return "Could not load current config"
        }

        // 2. Apply ONLY the changed field(s)
        delta(&freshConfig)

        // 3. Write back the FULL config (preserving hooks, env, etc.)
        let request = UpdateConfigRequest(scope: "user", content: freshConfig)
        let putResponse: APIResponse<ConfigInfo> = try await client.put("/config", body: request)
        if let updated = putResponse.data {
            config = updated
        }
        return nil
    } catch {
        return "Failed to save: \(error.localizedDescription)"
    }
}

// Usage:
func updateModel(_ newModel: String) {
    Task {
        _ = await saveWithPatch { config in
            config.model = newModel
        }
    }
}
```

**Why this is correct:** By loading the FULL config first (including hooks, env, permissions, etc.) and only mutating the one field the user changed, the PUT writes back the complete config with all existing fields preserved. The dangerous fields are never touched by the delta closure.

**The allowlist enforcement then becomes:** only expose delta closures for allowlisted fields. Never create a delta closure that modifies `hooks`, `env`, `permissions`, `statusLine`, `enabledPlugins`, or `extraKnownMarketplaces`.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `includeCoAuthoredBy` field | `attribution` object | Claude Code 2025 | `includeCoAuthoredBy` is deprecated in favor of `attribution.commit` / `attribution.pr`. The app should continue supporting both for backward compatibility since many users still have the old field. |
| `systemPrompt` in config | CLAUDE.md files | Always (never was in settings.json) | System prompt was never a settings.json field. Custom instructions are configured via CLAUDE.md files at user/project/local scopes. |
| `permissions.allow` + `permissions.deny` only | `permissions.ask` + `permissions.additionalDirectories` + `permissions.disableBypassPermissionsMode` added | Claude Code 2025-2026 | `PermissionsConfig` in ILSShared is missing `ask`, `additionalDirectories`, and `disableBypassPermissionsMode` fields. These should be added for completeness but are NOT part of Phase 35 scope. |

**Deprecated/outdated:**
- `includeCoAuthoredBy`: Deprecated in favor of `attribution` object. Still functional.

## Open Questions

1. **CFG-06: What does "System prompt field" actually mean?**
   - What we know: `systemPrompt` is NOT a settings.json field. It comes from CLAUDE.md files. The per-session system prompt is handled by NewSessionView/AdvancedOptionsSheet via the chat API.
   - What's unclear: Does the requirement mean "show the content of the host's CLAUDE.md" or "show a note explaining where system prompts come from"?
   - Recommendation: Add a read-only informational section in Settings: "System Prompt" label with text "Configured via CLAUDE.md files on your host. Per-session system prompts can be set when creating a new session." This satisfies the requirement without adding a non-existent field. If a backend endpoint to read CLAUDE.md content exists or is trivial to add, show the content read-only.

2. **Backend writes full payload -- no server-side merge**
   - What we know: `ConfigFileService.writeConfig()` serializes whatever `ClaudeConfig` it receives and writes it to disk. There is no field-level merge.
   - What's unclear: Should we add server-side merge to the backend, or is client-side read-then-patch sufficient?
   - Recommendation: Client-side read-then-patch is sufficient for v3.1. It avoids backend changes and the app already loads config before saving. Document the pattern clearly.

3. **Cache invalidation after config save**
   - What we know: `APIClient` has NSCache with TTL. After PUT, the cached GET response is stale.
   - What's unclear: Does `APIClient` have a cache invalidation method for specific paths?
   - Recommendation: After successful PUT, immediately call `loadConfig()` (which does a GET). If the GET returns cached data, the PUT response already updated `config` property directly, so the UI will show correct values. The cache will expire naturally within 60s. This is acceptable for v3.1.

## Sources

### Primary (HIGH confidence)
- `ILSApp/ILSApp/Views/Settings/SettingsConfigSection.swift` -- InheritanceBadge, SettingsInfoButton, settingAnnotation, current field coverage audit
- `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` -- saveConfig(), saveConfigToggle(), loadConfig(), full struct write-back pattern
- `ILSApp/ILSApp/Views/Settings/SettingsView.swift` -- onChange(appState.serverURL) already wired, layout composition
- `Sources/ILSShared/Models/ClaudeConfig.swift` -- all config fields, all optional, complete field inventory
- `Sources/ILSBackend/Services/ConfigFileService.swift` -- readConfig/writeConfig implementation, no server-side merge
- `Sources/ILSBackend/Controllers/ConfigController.swift` -- GET/PUT/validate routes, full payload write
- `Sources/ILSShared/DTOs/ResponseDTOs.swift` -- ConfigProfiles, ConfigOverride, UpdateConfigRequest DTOs
- [Claude Code settings docs](https://code.claude.com/docs/en/settings) -- official schema, confirmed NO systemPrompt field, full field inventory

### Secondary (MEDIUM confidence)
- `ILSApp/ILSApp/Views/Settings/ConfigEditorView.swift` -- raw JSON editor for advanced users, onChange(serverURL) pattern
- `ILSApp/ILSApp/AppState.swift` -- activeHostName, serverURL forwarding, updateServerURL()
- `.planning/research/PITFALLS.md` -- Pitfall 2 (config write drops CLI fields), Pitfall 9 (scope semantics)
- `.planning/research/FEATURES.md` -- Feature 1 (host CLI config sync), anti-features list
- `.planning/research/ARCHITECTURE.md` -- Feature 1 data flow, component boundaries
- [A developer's guide to settings.json](https://www.eesel.ai/blog/settings-json-claude-code) -- community guide confirming schema

### Tertiary (LOW confidence)
- None -- all findings verified against source code and official docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new libraries, all existing patterns
- Architecture: HIGH -- settings infrastructure 60-70% built, patterns verified in source
- Pitfalls: HIGH -- write-back bug verified by reading saveConfig() and ConfigFileService.writeConfig()
- CFG-06 (systemPrompt): HIGH -- verified against official Claude Code docs that systemPrompt is NOT a settings.json field

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable -- settings infrastructure unlikely to change)
