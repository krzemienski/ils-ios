# Config Flow Trace: CLI -> Backend -> iOS Settings

## Overview

This document traces how each of the 8 settings items flows from its source of truth through the backend API to the iOS Settings screen.

**API Endpoint**: `GET /api/v1/config?scope=user`
**Backend**: `ConfigController.get()` -> `FileSystemService.readConfig()` -> `ConfigFileService.readConfig()`
**Config File**: `~/.claude/settings.json` (user scope)

## Architecture

```
~/.claude/settings.json
        |
        v
ConfigFileService.readConfig(scope:)
  - Reads file with JSONDecoder
  - Returns ConfigInfo(scope, path, content: ClaudeConfig, isValid)
        |
        v
ConfigController.get(req:)
  - Wraps in APIResponse<ConfigInfo>
  - No enrichment, no defaults injection
        |
        v
iOS APIClient.get("/config?scope=user")
  - Decodes APIResponse<ConfigInfo>
        |
        v
SettingsViewModel.config: ConfigInfo?
  - Exposes raw config to views
  - defaultModelID = "claude-sonnet-4-20250514" (fallback)
        |
        v
SettingsConfigSection
  - Renders each field with nil-checking
  - InheritanceBadge(isInherited: field == nil)
  - SettingsInfoButton(text: tooltip)
```

## Per-Item Trace Matrix

### 1. Default Model

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `model` field. Absent if user never set it. Claude CLI binary uses its own default internally. |
| **Backend** | `ConfigFileService` reads JSON, `ClaudeConfig.model` is `String?`. No enrichment. |
| **API Response** | `content.model` = string value or absent (decoded as nil) |
| **iOS Model** | `ClaudeConfig.model: String?` |
| **ViewModel** | Fallback: `SettingsViewModel.defaultModelID = "claude-sonnet-4-20250514"` |
| **View** | Picker binding uses `config.model ?? defaultModelID`. Badge: `isInherited: config.model == nil` |

### 2. Color Scheme

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `theme.colorScheme`. Absent = system default. |
| **Backend** | `ThemeConfig.colorScheme: String?` decoded from JSON. |
| **API Response** | `content.theme.colorScheme` = "light"/"dark"/"system" or absent |
| **iOS Model** | `ClaudeConfig.theme: ThemeConfig?`, `ThemeConfig.colorScheme: String?` |
| **ViewModel** | `syncColorScheme()` reads `config.theme?.colorScheme ?? "system"` |
| **View** | Picker bound to `$colorSchemePreference`. Badge: `isInherited: config.theme?.colorScheme == nil` |

### 3. Extended Thinking

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `alwaysThinkingEnabled`. Absent = CLI default (false). |
| **Backend** | `ClaudeConfig.alwaysThinkingEnabled: Bool?` |
| **API Response** | `content.alwaysThinkingEnabled` = true/false or absent |
| **iOS Model** | `ClaudeConfig.alwaysThinkingEnabled: Bool?` |
| **ViewModel** | Toggle saves via `saveConfigToggle(key:value:)` |
| **View** | Toggle binding: `config.alwaysThinkingEnabled ?? false`. Badge: `isInherited: config.alwaysThinkingEnabled == nil` |

### 4. Include Co-Author

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `includeCoAuthoredBy`. Absent = CLI default (false). |
| **Backend** | `ClaudeConfig.includeCoAuthoredBy: Bool?` |
| **API Response** | `content.includeCoAuthoredBy` = true/false or absent |
| **iOS Model** | `ClaudeConfig.includeCoAuthoredBy: Bool?` |
| **ViewModel** | Toggle saves via `saveConfigToggle(key:value:)` |
| **View** | Toggle binding: `config.includeCoAuthoredBy ?? false`. Badge: `isInherited: config.includeCoAuthoredBy == nil` |

### 5. Auto Updates Channel

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `autoUpdatesChannel`. Absent = CLI default ("stable"). |
| **Backend** | `ClaudeConfig.autoUpdatesChannel: String?` |
| **API Response** | `content.autoUpdatesChannel` = "stable"/"beta"/etc or absent |
| **iOS Model** | `ClaudeConfig.autoUpdatesChannel: String?` |
| **ViewModel** | Read-only, no save method needed |
| **View** | Only shown when non-nil (BUG: should always show, defaulting to "Stable"). No badge or tooltip. |

### 6. Permissions (Default Mode)

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `permissions.defaultMode`. Absent = "prompt" (ask for each). |
| **Backend** | `PermissionsConfig.defaultMode: String?` |
| **API Response** | `content.permissions.defaultMode` = "ask"/"allow"/"deny" or absent |
| **iOS Model** | `ClaudeConfig.permissions: PermissionsConfig?` |
| **ViewModel** | Read-only display |
| **View** | Shows mode + allow/deny counts with DisclosureGroups. Badge present for defaultMode. |

### 7. API Key

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | Environment variable `ANTHROPIC_API_KEY` or config. Backend detects and masks. |
| **Backend** | `ClaudeConfig.apiKeyStatus: APIKeyStatus?` with `isConfigured`, `maskedKey`, `source` |
| **API Response** | `content.apiKeyStatus` = object or absent |
| **iOS Model** | `ClaudeConfig.apiKeyStatus: APIKeyStatus?` |
| **ViewModel** | Read-only display |
| **View** | Shows configured/not with shield icon, masked key, source. No badge (not editable). Has footer text about CLI editing. |

### 8. Hooks

| Layer | Value/Behavior |
|-------|---------------|
| **Source** | `~/.claude/settings.json` -> `hooks` object with Pascal-case keys (SessionStart, PreToolUse, etc.). |
| **Backend** | `HooksConfig` with CodingKeys mapping Pascal-case to camelCase properties |
| **API Response** | `content.hooks` = object with arrays or absent |
| **iOS Model** | `ClaudeConfig.hooks: HooksConfig?` |
| **ViewModel** | Read-only, `countHooks()` sums all event arrays |
| **View** | Shows total count only. No badge or tooltip. No breakdown by event type. |

## Key Finding: No Backend Enrichment

The backend (`ConfigFileService.readConfig`) performs a raw JSON decode of `~/.claude/settings.json` and returns it as-is. There is no enrichment with CLI defaults. When a field is absent from the JSON file, it arrives as `nil` on the iOS side.

**Decision: Option C** -- No backend change. The iOS app handles nil values with:
1. Sensible fallbacks (e.g., `defaultModelID` for model, `"system"` for color scheme, `false` for booleans)
2. `InheritanceBadge(isInherited: true)` when the value is nil, clearly showing "Host Default"
3. `SettingsInfoButton` tooltips explaining what "Host Default" means for each setting

This is the correct approach because:
- The backend may not have Claude CLI installed (headless deployment)
- CLI defaults change between versions; hardcoding them in the backend would drift
- The UI already communicates inheritance clearly via badges
