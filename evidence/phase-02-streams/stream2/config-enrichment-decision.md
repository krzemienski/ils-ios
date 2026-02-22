# Config Enrichment Decision

## Decision: Option C (No Backend Change)

### Options Considered

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| A | Backend queries Claude CLI for defaults | Most accurate | CLI may not be installed on backend host; adds subprocess dependency |
| B | Backend hardcodes known defaults | Simple to implement | Defaults drift as CLI updates; maintenance burden |
| **C** | **iOS handles nil with UI labels** | **Zero backend change; clear UX via badges** | **Fallback model string may not match CLI exactly** |

### Rationale

1. The backend (`ConfigFileService`) reads `~/.claude/settings.json` as raw JSON. Fields absent from the file arrive as `nil` on iOS.
2. The iOS app already has `InheritanceBadge` showing "Host Default" for nil values and "Custom" for explicit values.
3. Adding CLI queries to the backend introduces a subprocess dependency that may fail in headless deployments.
4. Hardcoding defaults in the backend creates a maintenance burden as Claude CLI evolves.
5. Option C keeps the architecture simple: backend is a transparent passthrough, iOS handles presentation.

### Implementation

- `SettingsViewModel.defaultModelID` remains as the fallback model string
- All 8 settings show `InheritanceBadge(isInherited: field == nil)`
- All 8 settings show `SettingsInfoButton` with explanatory tooltip
- Auto Updates Channel shows "Stable" when nil (the CLI default)
- No backend code changes required
