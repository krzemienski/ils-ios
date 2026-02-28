---
plan: 49-02
phase: 49-foundation
status: complete
completed: 2026-02-27
---

# Summary: 49-02 — iOS Client Path Strings, Deep Link, Directory Rename, Evidence Pipeline

## What Was Built

Updated iOS client layer to use `/host-profiles/*` API paths, extended deep link routing for `ils://host-profiles`, renamed `Views/Fleet/` directory to `Views/HostProfiles/`, cleaned UI strings, and created the Phase 49 evidence capture pipeline.

## API Path String Replacements (5 call sites in HostProfilesViewModel.swift)

| Before | After |
|--------|-------|
| `apiClient.get("/fleet")` | `apiClient.get("/host-profiles")` |
| `apiClient.post("/fleet/register", ...)` | `apiClient.post("/host-profiles/register", ...)` |
| `apiClient.post("/fleet/\(id)/activate", ...)` | `apiClient.post("/host-profiles/\(id)/activate", ...)` |
| `apiClient.delete("/fleet/\(id)")` | `apiClient.delete("/host-profiles/\(id)")` |
| `apiClient.get("/fleet/\(hosts[i].id)/health")` | `apiClient.get("/host-profiles/\(hosts[i].id)/health")` |

Also updated in HostProfileDetailView.swift:
- `/fleet/\(host.id)/lifecycle` → `/host-profiles/\(host.id)/lifecycle`
- `/fleet/\(host.id)/logs` → `/host-profiles/\(host.id)/logs`

## Type Reference Updates

All `FleetHost`, `FleetListResponse`, `FleetHealthResponse`, `RegisterFleetHostRequest` type refs in HostProfilesViewModel.swift updated to canonical names (`HostProfile`, `HostProfileListResponse`, etc.). Views still compile via backward-compat typealiases.

## Deep Link Extension (AppState.swift)

```swift
// Before:
case "fleet", "profiles":
// After:
case "fleet", "profiles", "host-profiles":
```

`ils://host-profiles` now routes to `.hostProfiles` alongside existing `fleet` and `profiles` aliases.

## UI String Update (SettingsView.swift)

Line 178: "fleet hosts" → "host profiles" in data erasure description text.
`data.fleetHostsDeleted` property access left unchanged (JSON key compatibility).

## Localizable.xcstrings

Added new key `"hostProfiles"` with value `"Host Profiles"` (English). Existing `"fleet"` key preserved.

## Directory Rename

- `ILSApp/ILSApp/Views/Fleet/` → `ILSApp/ILSApp/Views/HostProfiles/`
- `project.pbxproj` updated: 3 occurrences of `Fleet` → `HostProfiles` (group reference, group definition, `path = HostProfiles`)
- `fleet_hosts`, `CreateFleetHosts` references in pbxproj left unchanged

## Evidence Pipeline

- `evidence/phase-49-foundation/capture.sh` created and executable (`-rwxr-xr-x`)
- Captures 3 screenshots: home screen, `ils://host-profiles` deep link, `ils://fleet` backward-compat deep link
- Includes instructions for API JSON evidence via curl

## Build Results

- iOS (`ILSApp`): `** BUILD SUCCEEDED **` — zero errors
- Backend (`swift build`): Build complete (6.53s) — zero errors (from Plan 01, no regressions)

## Deviations from Plan

None. All steps executed as specified.

## Self-Check: PASSED

- [x] Zero `/fleet` API paths in HostProfilesViewModel.swift
- [x] 5 `/host-profiles` paths present (grep -c returns 5)
- [x] `case "fleet", "profiles", "host-profiles":` in AppState.swift
- [x] `ILSApp/ILSApp/Views/HostProfiles/` exists with both view files
- [x] `ILSApp/ILSApp/Views/Fleet/` does not exist
- [x] `evidence/phase-49-foundation/capture.sh` exists, executable, contains `xcrun simctl io`
- [x] iOS build exits 0
- [x] Backend build exits 0
