# Phase 50: Backend API -- Config Endpoint & Audit - Research

**Researched:** 2026-02-27
**Domain:** Vapor 4 REST API -- config merge endpoint + HTTP error code audit
**Confidence:** HIGH

## Summary

Phase 50 requires two distinct pieces of work: (1) a new `GET /api/v1/config/effective` endpoint that reads all config scopes (user, project, local, and optionally managed), merges them with proper precedence, and returns per-key `winningScope` annotations; and (2) an audit of all existing backend endpoints to ensure they return correct HTTP status codes (400/404/500) rather than 200-with-error-body.

The codebase is well-positioned for both. The `ConfigOverride` DTO already exists in `ILSShared/DTOs/ResponseDTOs.swift` with `winningScope: ConfigScope`, `userValue`, `projectValue`, and `localValue` fields. The `ILSErrorMiddleware` already converts `Abort` errors to structured JSON with correct HTTP status codes. The existing `ConfigFileService` reads individual scopes via `readConfig(scope:)`. The work is primarily additive (new endpoint + merge logic) and corrective (finding any endpoints that swallow errors with `try?` instead of propagating them).

**Primary recommendation:** Build the merge endpoint in `ConfigFileService` (reads all 3-4 scope files, merges with local > project > user precedence), expose via a new route on `ConfigController`, and audit controllers for `try?` patterns that hide errors.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| API-01 | All API endpoints return expected JSON structures with proper HTTP error codes (not 200-with-error) | Existing `ILSErrorMiddleware` handles `Abort` errors correctly. Audit needed for `try?` patterns in controllers that silently swallow errors. See "Common Pitfalls > Pitfall 2" and "Architecture Patterns > Pattern 3". |
| API-02 | GET /config/effective endpoint returns merged config with winning-scope annotations per key | `ConfigOverride` DTO already exists. `ConfigFileService.readConfig(scope:)` reads individual scopes. New merge function needed. See "Architecture Patterns > Pattern 1" and "Code Examples > Config Merge". |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vapor 4 | 4.x (already in project) | HTTP framework, routing, request handling | Already used by all controllers |
| ILSShared | local package | DTOs, models, `ConfigScope` enum, `ConfigOverride` DTO | Already has the types needed |
| Foundation | system | `FileManager`, `JSONDecoder/Encoder`, `Data` | Already used by `ConfigFileService` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Fluent | 4.x (already in project) | DB queries for endpoint audit verification | Only for DB-backed controllers |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Server-side merge | Client-side merge (fetch 3 scopes, merge on iOS) | Research and existing pitfall analysis strongly recommend server-side: avoids merge logic duplication and drift. `ConfigOverride` DTO was designed for server-side merge. |
| Flat key-value approach | Nested JSON diff | Flat keys (e.g., `model`, `permissions.allow`) are simpler to annotate and display in UI. Nested approach would require recursive merge algorithm. |

**Installation:** No new dependencies needed. All required libraries are already in the project.

## Architecture Patterns

### Recommended Project Structure

```
Sources/ILSBackend/
├── Controllers/
│   └── ConfigController.swift       # ADD: effective() route handler
├── Services/
│   └── ConfigFileService.swift      # ADD: readEffectiveConfig() merge logic
└── ...

Sources/ILSShared/
├── DTOs/
│   └── ResponseDTOs.swift           # EXISTING: ConfigOverride, ConfigProfiles
└── Models/
    └── ClaudeConfig.swift           # EXISTING: ClaudeConfig struct
    └── MCPServer.swift              # EXISTING: ConfigScope enum
```

### Pattern 1: Config Merge with Per-Key Provenance

**What:** Read all config scopes, merge with precedence (managed > local > project > user), and annotate each key with its winning scope.

**When to use:** For the `GET /config/effective` endpoint.

**Precedence (confirmed from official Claude Code docs):**
1. `managed` -- `/Library/Application Support/ClaudeCode/managed-settings.json` (macOS), cannot be overridden
2. `local` -- `.claude/settings.local.json` (current project, gitignored)
3. `project` -- `.claude/settings.json` (current project, git-committed)
4. `user` -- `~/.claude/settings.json` (all projects)

**Merge strategy:**
- For scalar values (strings, bools, numbers): highest-precedence non-nil value wins
- For array values (permissions.allow, permissions.deny): Claude Code merges and deduplicates across scopes. For the ILS endpoint, report the winning scope as the highest-precedence scope that defines the key
- For missing scope files: treat as empty config (all keys nil), do not error

**Response structure:** Return an array of `ConfigOverride` objects (one per populated key) plus the merged `ClaudeConfig` as the effective result.

### Pattern 2: Existing Error Handling via ILSErrorMiddleware

**What:** All controller handlers throw `Abort(.statusCode, reason:)` which `ILSErrorMiddleware` catches and converts to structured JSON with correct HTTP status codes.

**When to use:** This is already the established pattern. The audit verifies it is used consistently.

**Existing error mapping (from `ILSErrorMiddleware.httpStatusToCode`):**
- `.badRequest` (400) -> `"BAD_REQUEST"`
- `.unauthorized` (401) -> `"UNAUTHORIZED"`
- `.forbidden` (403) -> `"FORBIDDEN"`
- `.notFound` (404) -> `"NOT_FOUND"`
- `.unprocessableEntity` (422) -> `"VALIDATION_ERROR"`
- `.conflict` (409) -> `"CONFLICT"`
- `.tooManyRequests` (429) -> `"RATE_LIMITED"`
- `.internalServerError` (500) -> `"INTERNAL_ERROR"`
- `.serviceUnavailable` (503) -> `"SERVICE_UNAVAILABLE"`
- `DecodingError` -> `.unprocessableEntity` (422) with field-specific message

### Pattern 3: Audit for `try?` Error Suppression

**What:** Some controllers use `try?` to silently swallow errors, returning successful responses even when underlying operations fail.

**When to use:** During the error code audit, look for `try?` patterns and determine which should propagate errors vs which are intentionally lenient.

**Existing `try?` usage that needs review (from grep):**
- `PluginsController.swift:79` -- `try? fileSystem.readConfig(scope: .user)` (used for enabled status lookup -- lenient is OK here)
- `PluginsController.swift:182,325,354` -- `try? fileSystem.readConfig(scope: .user)` (config mutation paths -- should error propagate?)
- `StatsController.swift:45,63,64,91,92,99,100` -- Multiple `try?` for filesystem reads (stats are best-effort -- lenient is OK)
- `MCPController.swift:147` -- `try? fileSystem.removeMCPServer(...)` (delete-if-exists pattern -- lenient is OK)
- `MCPController.swift:260,261` -- `try?` for JSON parsing in update handler (should validate and return 422)
- `TeamsController.swift:151` -- `try? req.content.decode(...)` (optional body decode -- lenient is OK)
- `TunnelController.swift:33` -- `try? req.content.decode(...)` (optional body -- OK)

### Anti-Patterns to Avoid

- **Client-side config merge:** Never duplicate the merge algorithm on iOS. The backend is the single source of truth.
- **200-with-error-body:** Never return HTTP 200 with `success: false` in the `APIResponse` wrapper. Use `throw Abort(...)` so the middleware returns the correct status code.
- **Untyped scope strings:** Always use `ConfigScope` enum, never raw strings for scope values.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON merge of two configs | Custom recursive JSON merge | Property-by-property merge on `ClaudeConfig` struct | ClaudeConfig has ~12 optional properties; iterating them is clearer than generic JSON diffing and preserves type safety |
| Error response formatting | Custom per-controller error JSON | `throw Abort(.status, reason:)` + `ILSErrorMiddleware` | Middleware already handles all error types consistently |
| Config scope paths | Hardcoded strings in controller | `ConfigFileService` scope resolution | Service already knows all scope paths |

**Key insight:** The `ConfigOverride` DTO was designed specifically for this use case. Don't create a new response type -- populate the existing one.

## Common Pitfalls

### Pitfall 1: Managed Settings Path Varies by OS

**What goes wrong:** The managed settings file lives at different paths on macOS vs Linux vs Windows. Hardcoding a single path breaks cross-platform.

**Why it happens:** The ILS backend currently runs on macOS only (development machine), so it's tempting to hardcode `/Library/Application Support/ClaudeCode/managed-settings.json`.

**How to avoid:** Use a computed property in `ConfigFileService` that checks the OS:
- macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
- Linux: `/etc/claude-code/managed-settings.json`

If the managed file doesn't exist (which is the common case for non-enterprise users), treat it as empty config -- do not error.

**Warning signs:** Error responses when querying `/config/effective` on machines without managed settings.

### Pitfall 2: `try?` Hiding Real Errors in Mutation Paths

**What goes wrong:** Using `try?` when reading config before a write operation means the write may start from an empty/default config, silently losing existing settings.

**Why it happens:** The pattern `(try? readConfig(scope: .user))?.content ?? ClaudeConfig()` is used in `PluginsController` for enable/disable. If the read fails (file corruption, permissions), the fallback empty config overwrites the real config on write.

**How to avoid:** For mutation paths (read-modify-write), use `try readConfig(...)` and let errors propagate as 500. For display-only paths (stats), `try?` with graceful fallback is fine.

**Warning signs:** User settings mysteriously reset after enabling/disabling a plugin.

### Pitfall 3: ConfigScope Enum Missing `managed` Case

**What goes wrong:** The success criteria specifies `winningScope` can be `user/project/local/managed`, but the current `ConfigScope` enum only has `user`, `project`, `local`.

**Why it happens:** The `managed` scope was not part of the original design. It was added to Claude Code for enterprise use.

**How to avoid:** Add a `case managed` to the `ConfigScope` enum in `MCPServer.swift`. Include backward-compatible decoding so existing clients that don't know about `managed` don't crash.

**Warning signs:** JSON decoding errors when the effective config response includes `"winningScope": "managed"`.

### Pitfall 4: Array Merge Semantics

**What goes wrong:** Claude Code merges and deduplicates array settings (like `permissions.allow`) across scopes. Reporting the "winning scope" for an array is ambiguous -- elements come from multiple scopes.

**Why it happens:** Scalar merge ("last writer wins") is simple, but array merge is inherently multi-source.

**How to avoid:** For array fields, report the highest-precedence scope that contributes to the array. Document in the API response that array values are merged, not replaced. The `ConfigOverride.winningValue` should contain the serialized merged array, and `winningScope` should indicate the highest-precedence scope that defines the key.

**Warning signs:** UI shows "Inherited from User" for a permissions array that actually includes project-scope rules.

### Pitfall 5: Health Endpoint Returns Non-APIResponse Format

**What goes wrong:** The `HealthController` returns raw `Response` objects with `HealthDetail`, `ReadyResponse`, and `LiveResponse` structs -- not wrapped in `APIResponse<T>`. This is intentional (health probes should be minimal), but the audit should not flag it as a defect.

**Why it happens:** Health endpoints at `/health/*` are registered outside the `/api/v1` prefix and serve a different purpose (k8s probes, monitoring).

**How to avoid:** Explicitly exclude `/health/*` endpoints from the API structure audit. They are not part of the API contract.

**Warning signs:** Audit flagging health endpoints as non-conformant.

## Code Examples

### Config Merge Logic (ConfigFileService)

```swift
// Source: Pattern derived from existing ConfigFileService + Claude Code precedence docs

/// Effective configuration with per-key scope annotations.
struct EffectiveConfig: Codable, Sendable {
    /// Merged config values (highest-precedence non-nil for each key)
    let config: ClaudeConfig
    /// Per-key annotations showing which scope won
    let overrides: [ConfigOverride]
    /// All scope configs that were read (for debugging)
    let profiles: ConfigProfiles
}

/// Read all scopes, merge, and annotate.
func readEffectiveConfig() throws -> EffectiveConfig {
    let userConfig = try? readConfig(scope: .user)
    let projectConfig = try? readConfig(scope: .project)
    let localConfig = try? readConfig(scope: .local)
    let managedConfig = readManagedConfig() // returns nil if file doesn't exist

    // Precedence: managed > local > project > user
    let scopes: [(ConfigScope, ClaudeConfig?)] = [
        (.user, userConfig?.content),
        (.project, projectConfig?.content),
        (.local, localConfig?.content),
        (.managed, managedConfig)
    ]

    var merged = ClaudeConfig()
    var overrides: [ConfigOverride] = []

    // For each key in ClaudeConfig, find the highest-precedence non-nil value
    // Example for "model":
    let modelScopes = scopes.filter { $0.1?.model != nil }
    if let winner = modelScopes.last { // last = highest precedence
        merged.model = winner.1?.model
        overrides.append(ConfigOverride(
            key: "model",
            winningScope: winner.0,
            winningValue: winner.1?.model ?? "",
            userValue: userConfig?.content.model,
            projectValue: projectConfig?.content.model,
            localValue: localConfig?.content.model
        ))
    }
    // ... repeat for each ClaudeConfig property

    return EffectiveConfig(
        config: merged,
        overrides: overrides,
        profiles: ConfigProfiles(
            user: userConfig,
            project: projectConfig,
            local: localConfig
        )
    )
}
```

### New Controller Route

```swift
// Source: Existing ConfigController pattern

/// GET /config/effective - Get merged effective configuration
@Sendable
func effective(req: Request) async throws -> APIResponse<EffectiveConfig> {
    let effectiveConfig = try fileSystem.readEffectiveConfig()
    return APIResponse(success: true, data: effectiveConfig)
}

// In boot(routes:):
config.get("effective", use: effective)
```

### Error Audit Fix Example (MCPController)

```swift
// BEFORE (try? hides errors):
let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath))
let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

// AFTER (propagate errors):
let data: Data
do {
    data = try Data(contentsOf: URL(fileURLWithPath: settingsPath))
} catch {
    throw Abort(.internalServerError, reason: "Failed to read settings: \(error.localizedDescription)")
}
let existing: [String: Any]
do {
    guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw Abort(.internalServerError, reason: "Settings file is not a JSON object")
    }
    existing = parsed
} catch let error as Abort {
    throw error
} catch {
    throw Abort(.unprocessableEntity, reason: "Settings file contains invalid JSON")
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 3 config scopes (user/project/local) | 4 scopes (+ managed for enterprise) | Claude Code 2025 H2 | `ConfigScope` enum needs `managed` case |
| Config read per-scope only | Effective/merged config endpoint expected | Phase 50 (this phase) | New endpoint, new merge logic |
| `try?` in mutation paths | Proper error propagation | Phase 50 (this phase) | Some `try?` patterns need correction |

**Deprecated/outdated:**
- `~/.claude.json` was the legacy config location. Current code uses `~/.claude/settings.json` (already correct).

## Open Questions

1. **Managed scope priority in the `ConfigScope` enum ordering**
   - What we know: Claude Code precedence is managed > local > project > user
   - What's unclear: Should we add `managed` as a case to `ConfigScope` now, or defer it? No managed settings file exists on the dev machine.
   - Recommendation: Add the case now with graceful handling when the file doesn't exist. This matches the success criteria which lists `managed` as a possible `winningScope` value. The `ConfigScope` init(from:) decoder already handles unknown values gracefully by throwing -- we just need to add the case.

2. **Array merge representation in ConfigOverride**
   - What we know: `permissions.allow` merges across scopes in Claude Code
   - What's unclear: Should `ConfigOverride` represent merged arrays, or only scalar values?
   - Recommendation: For v5.0, treat arrays as "last non-nil wins" (same as scalars). True array merge is a Claude Code-specific behavior that requires deep knowledge of which keys are arrays. Document this simplification. Phase 51 (Settings UI) can refine if needed.

3. **Project scope path resolution**
   - What we know: Project config is at `.claude/settings.json` relative to working directory. Backend runs from the `ils-ios` repo root.
   - What's unclear: Should the endpoint accept a project path parameter, or always use CWD?
   - Recommendation: Default to CWD (backend's working directory). This matches the current `ConfigFileService.readConfig(scope: .project)` behavior. Phase 51 can extend this if a project path parameter is needed.

## Sources

### Primary (HIGH confidence)
- Claude Code official settings docs: https://code.claude.com/docs/en/settings -- 4-tier scope system, precedence order, managed settings paths, all settings keys
- Codebase analysis: `Sources/ILSBackend/Controllers/ConfigController.swift` -- existing config routes
- Codebase analysis: `Sources/ILSBackend/Services/ConfigFileService.swift` -- scope path resolution
- Codebase analysis: `Sources/ILSShared/DTOs/ResponseDTOs.swift` -- `ConfigOverride` DTO with `winningScope`
- Codebase analysis: `Sources/ILSShared/Models/MCPServer.swift` -- `ConfigScope` enum
- Codebase analysis: `Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift` -- error handling chain

### Secondary (MEDIUM confidence)
- Previous research: `.planning/research/PITFALLS.md` Pitfall 3 -- config merge endpoint design
- Previous research: `.planning/research/FEATURES.md` -- ConfigOverride DTO analysis
- Previous research: `.planning/research/STACK.md` -- server-side merge recommendation
- Phase 45 research/plan: `.planning/phases/45-data-backend-hardening/45-RESEARCH.md` -- ConfigScope enum migration (completed)

### Tertiary (LOW confidence)
- Managed settings path on macOS not verified on dev machine (no `/Library/Application Support/ClaudeCode/` directory exists). Path from official docs, but runtime behavior untested.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All libraries already in project, no new dependencies
- Architecture: HIGH -- `ConfigOverride` DTO already designed for this, `ConfigFileService` has scope reading, `ILSErrorMiddleware` handles errors
- Pitfalls: HIGH -- Grep analysis identified exact `try?` locations and patterns; official docs confirm scope precedence
- Config merge logic: MEDIUM -- Array merge semantics need clarification, managed scope path untested on this machine

**Research date:** 2026-02-27
**Valid until:** 2026-03-27 (stable domain -- config file formats and Vapor patterns don't change rapidly)
