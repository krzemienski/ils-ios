# Phase 49: Foundation -- Fleet-to-HostProfile Rename - Research

**Researched:** 2026-02-27
**Domain:** Swift rename refactor (iOS/macOS/Vapor), API route aliasing, deep link extension, evidence pipeline setup
**Confidence:** HIGH

## Summary

Phase 49 is a terminology rename with four distinct surfaces: (1) Swift source files across all three targets, (2) backend API routes in the Vapor server, (3) deep link URL handling in `AppState.handleURL()`, and (4) setting up a new `evidence/` capture pipeline for v5.0 phases.

The good news: previous work already started this migration. The iOS/macOS UI layer already uses "Host Profiles" everywhere it matters — `HostProfilesView`, `HostProfilesViewModel`, `HostProfileDetailView`, the `ActiveScreen.hostProfiles` case, and the `SidebarView` label all use the new terminology. The `SidebarRootView` already has `static var fleet: ActiveScreen { .hostProfiles }` backward compat and `fromStorageKey` handles both `"fleet"` and `"hostProfiles"`. `AppState.handleURL()` already handles both `"fleet"` and `"profiles"` routing to `.hostProfiles`. The macOS `MacContentView` already uses `hostProfiles` with display string "Host Profiles".

What remains is the backend layer and a handful of internal identifiers: `FleetController`, `FleetHostModel`, `FleetHost` struct, `FleetDTOs`, `FleetListResponse`, `FleetHealthResponse`, `RegisterFleetHostRequest`, `CreateFleetHosts` migration, the Fluent schema `"fleet_hosts"`, API routes `/fleet/*`, one localization string, one UI string in `SettingsView`, and `ResponseDTOs.fleetHostsDeleted`. The backend controller must register both `/host-profiles/*` (new) and `/fleet/*` (alias) routes to satisfy FOUND-01's backward-compatible requirement. The deep link `ils://host-profiles` must be added alongside the existing `ils://fleet` handler.

The evidence pipeline (FOUND-03) requires creating a `evidence/phase-49-foundation/` directory structure and a capture script that takes numbered screenshots on the iPhone 16 Pro Max simulator (UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`). The existing `evidence/` directory already exists with phase subdirectories as precedent.

**Primary recommendation:** Rename the backend layer in place (rename Swift types, files, and routes), register both old and new routes in `routes.swift`, add `ils://host-profiles` deep link handling, update the single localization entry and SettingsView string, then create the evidence pipeline directory and capture script.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | "Fleet" terminology replaced with "Host Profiles" across all Swift files, API routes (with backward-compatible aliasing), deep links, and UI labels | Full inventory below: 16 files need changes; backward alias pattern in `routes.swift` is straightforward Vapor route duplication |
| FOUND-03 | Validation evidence pipeline captures screenshots and gate tracking artifacts to evidence/ directory | `evidence/` already exists; precedent from phase-10-final shows numbered screenshot + FINAL-REPORT.md pattern; capture via `xcrun simctl io` or `idb simulator screenshot` |
</phase_requirements>

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Swift rename (Edit tool) | Swift 5.10 | Rename types, files, identifiers | Direct file edits; no macro/refactor tooling needed at this scale |
| Vapor RouteCollection | Vapor 4 | Register both old + new routes | `boot(routes:)` called once; register both paths to same handlers |
| xcrun simctl io screenshot | Xcode 16 CLI | Capture simulator screenshots | Built-in, no extra deps; already used in prior phases |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `typealias` in ILSShared | Keep old type names as aliases during transition | Only if other code (worktrees, external callers) uses old names — optional here since all callers are internal |
| Bash capture script | Automate evidence screenshots | FOUND-03: one script that boots simulator, navigates, captures numbered screenshots |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Registering alias routes in `boot()` | A Vapor middleware redirect | Aliases in `boot()` are simpler — same handler, two paths, zero overhead |
| `xcrun simctl io` for screenshots | `idb simulator screenshot` | Both work; `xcrun` requires no extra install; `idb` already used in project automation |

## Architecture Patterns

### Rename Surface Map

Complete inventory of every file requiring changes, grouped by target:

**ILSShared (shared types — rename here propagates to all targets):**
```
Sources/ILSShared/Models/FleetHost.swift
  - struct FleetHost → struct HostProfile  (or rename file + keep typealias FleetHost = HostProfile for compat)
  - enum FleetHost.HealthStatus → HostProfile.HealthStatus
  - precondition messages: "FleetHost name..." → "HostProfile name..."
  - typealias HostProfile = FleetHost  (line 4 — invert: make HostProfile canonical, FleetHost the alias)

Sources/ILSShared/DTOs/FleetDTOs.swift
  - struct RegisterFleetHostRequest → RegisterHostProfileRequest
  - struct FleetListResponse → HostProfileListResponse
    - property: hosts: [FleetHost] → hosts: [HostProfile]
  - struct FleetHealthResponse → HostProfileHealthResponse
    - property: status: FleetHost.HealthStatus → HostProfile.HealthStatus
  - typealiases at top (lines 6-10): invert — make new names canonical, old names aliases

Sources/ILSShared/DTOs/ResponseDTOs.swift
  - property: fleetHostsDeleted → hostProfilesDeleted (breaking JSON change — see Pitfalls)
  - doc comment: "fleet host configurations" → "host profile configurations"
```

**ILSBackend:**
```
Sources/ILSBackend/Controllers/FleetController.swift
  → Rename to HostProfileController.swift
  - struct FleetController → HostProfileController
  - Route group: routes.grouped("fleet") → routes.grouped("host-profiles")
  - Register both groups in boot() for backward compat (see pattern below)
  - All FleetHost/FleetListResponse/etc. refs → renamed shared types
  - Log strings: "Fleet health..." → "Host profile health..."

Sources/ILSBackend/Models/FleetHostModel.swift
  → Rename to HostProfileModel.swift
  - final class FleetHostModel → HostProfileModel
  - static let schema = "fleet_hosts"  ← DO NOT CHANGE (DB table name — changing breaks existing data)
  - Method toShared() returns FleetHost → HostProfile (after shared rename)
  - Constructor: FleetHostModel(...) → HostProfileModel(...)

Sources/ILSBackend/Migrations/CreateFleetHosts.swift
  → Rename to CreateHostProfiles.swift (file name only — DO NOT rename struct without adding migration)
  - struct CreateFleetHosts stays named as-is OR rename to CreateHostProfiles
    WARNING: The migration struct name doesn't matter to Fluent (it uses schema string), but renaming
    the file requires updating configure.swift's app.migrations.add(CreateFleetHosts()) call.

Sources/ILSBackend/Extensions/VaporContent+Extensions.swift
  - Lines 200-204: update extension names to match renamed types
    extension HostProfile: Content {}
    extension HostProfile.HealthStatus: Content {}
    extension HostProfileListResponse: Content {}
    extension HostProfileHealthResponse: Content {}
    extension RegisterHostProfileRequest: Content {}

Sources/ILSBackend/App/routes.swift
  - try admin.register(collection: FleetController()) → HostProfileController()

Sources/ILSBackend/App/configure.swift
  - app.migrations.add(CreateFleetHosts()) → CreateHostProfiles() (if migration struct renamed)
  - Comment: "v2.0 — Fleet management" → "v2.0 — Host profile management"

Sources/ILSBackend/Controllers/DataErasureController.swift
  - Line 43 comment: "Fleet hosts" → "Host profiles"
  - Line 52 log string: "fleet hosts" → "host profiles"
  - FleetHostModel refs → HostProfileModel
```

**ILSApp (iOS):**
```
ILSApp/ILSApp/ViewModels/HostProfilesViewModel.swift
  - All /fleet/* API path strings → /host-profiles/*
    (lines 30, 45, 58, 77, 111 in current file)
  - FleetListResponse → HostProfileListResponse
  - FleetHost → HostProfile (type refs)
  - RegisterFleetHostRequest → RegisterHostProfileRequest
  - FleetHealthResponse → HostProfileHealthResponse
  - DeletedResponse stays (not Fleet-specific)

ILSApp/ILSApp/Views/Fleet/HostProfilesView.swift
  - Directory rename: Views/Fleet/ → Views/HostProfiles/  (requires Xcode project group update)
  - FleetHost type refs → HostProfile
  - FleetHost.HealthStatus → HostProfile.HealthStatus

ILSApp/ILSApp/Views/Fleet/HostProfileDetailView.swift
  - Same directory move as above
  - /fleet/{id}/lifecycle → /host-profiles/{id}/lifecycle
  - /fleet/{id}/logs → /host-profiles/{id}/logs
  - FleetHost type refs → HostProfile

ILSApp/ILSApp/Views/Settings/SettingsView.swift
  - Line 178: "fleet hosts" → "host profiles"
  - Line 205: data.fleetHostsDeleted → data.hostProfilesDeleted (if DTO property renamed)

ILSApp/ILSApp/AppState.swift
  - Line 123: case "fleet", "profiles": → case "fleet", "profiles", "host-profiles":
    (adds ils://host-profiles deep link; keeps fleet for backward compat)

ILSApp/ILSApp/Resources/Localizable.xcstrings
  - Line 149-155: key "fleet" with value "Fleet" → key "hostProfiles" with value "Host Profiles"
    (or add new entry and keep old for compat)
```

**Xcode Project File:**
```
ILSApp/ILSApp.xcodeproj/project.pbxproj
  - Group name: "Fleet" (line 1063, 1160, 1166) → "HostProfiles"
  - path = Fleet → path = HostProfiles
  - File references to renamed Swift files need path updates
  NOTE: If using XcodeGen (project.yml), edit project.yml instead.
        project.yml has no Fleet group (confirmed empty grep result),
        so the pbxproj group may need manual update or regeneration.
```

**macOS App:**
```
ILSApp/ILSMacApp/Views/MacContentView.swift
  - Already uses: case hostProfiles = "Host Profiles"  ✅ No change needed
  - Already uses: HostProfilesView()  ✅ No change needed
  - No fleet references  ✅
```

### Pattern 1: Backward-Compatible API Route Registration

Register both route groups in `HostProfileController.boot()`:

```swift
// Source: Vapor 4 RouteCollection pattern
struct HostProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // New canonical routes
        let hostProfiles = routes.grouped("host-profiles")
        hostProfiles.get(use: index)
        hostProfiles.post("register", use: register)
        hostProfiles.post(":id", "activate", use: activate)
        hostProfiles.delete(":id", use: delete)
        hostProfiles.get(":id", "health", use: health)

        // Backward-compatible aliases (old /fleet/* routes)
        let fleet = routes.grouped("fleet")
        fleet.get(use: index)
        fleet.post("register", use: register)
        fleet.post(":id", "activate", use: activate)
        fleet.delete(":id", use: delete)
        fleet.get(":id", "health", use: health)
    }
    // ... same handler methods ...
}
```

**Confidence:** HIGH — standard Vapor pattern; both route groups call identical handler functions. No duplication of logic.

### Pattern 2: Deep Link Extension

In `AppState.handleURL()`, add `"host-profiles"` alongside existing `"fleet"`:

```swift
case "fleet", "profiles", "host-profiles":
    navigationIntent = .hostProfiles
```

This satisfies both success criteria 3: `ils://fleet` continues to work AND `ils://host-profiles` also works.

### Pattern 3: Evidence Pipeline Directory Structure

Based on existing `evidence/` conventions observed in `phase-10-final/`:

```
evidence/
├── phase-49-foundation/
│   ├── 00-rename-complete.png        # Host Profiles screen showing new label
│   ├── 01-sidebar-host-profiles.png  # Sidebar showing "Host Profiles" nav item
│   ├── 02-api-route-new.txt          # curl /api/v1/host-profiles response
│   ├── 03-api-route-alias.txt        # curl /api/v1/fleet response (alias works)
│   ├── 04-deeplink-fleet.png         # ils://fleet deep link navigates to HP screen
│   ├── 05-deeplink-host-profiles.png # ils://host-profiles deep link navigates to HP screen
│   └── PHASE-REPORT.md              # Summary of all changes made
```

Capture command pattern (from project conventions):
```bash
xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot evidence/phase-49-foundation/00-rename-complete.png
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API backward compat | Custom redirect middleware | Two route groups in `boot()` | Same handler, two paths — zero complexity |
| Screenshot capture | Custom screen recording | `xcrun simctl io screenshot` | Already available, used in prior phases |
| Type migration | Manual find-and-replace everywhere | Edit shared type in ILSShared, let compiler surface all callers | Swift compiler finds every usage — don't miss any |

**Key insight:** The Swift compiler is the authoritative find-all-usages tool. After renaming `FleetHost` → `HostProfile` in `ILSShared/Models/FleetHost.swift`, a build attempt will surface every remaining reference as a compile error. This is the correct workflow: rename the canonical types first, then fix build errors one file at a time.

## Common Pitfalls

### Pitfall 1: Renaming the Fluent Schema String
**What goes wrong:** If `static let schema = "fleet_hosts"` in `FleetHostModel` is changed to `"host_profiles"`, Fluent will try to create a new `host_profiles` table and fail to find the existing `fleet_hosts` table. All user data is lost/inaccessible.
**Why it happens:** Fluent uses the schema string as the actual SQLite table name. Renaming the model class does not rename the database table.
**How to avoid:** Keep `static let schema = "fleet_hosts"` unchanged forever. The database table name is an implementation detail invisible to users.
**Warning signs:** Migration errors at startup, empty host profiles list after rename.

### Pitfall 2: Breaking the ResponseDTOs JSON Contract
**What goes wrong:** Renaming `fleetHostsDeleted` → `hostProfilesDeleted` in `DataErasureResponse` changes the JSON key sent by the backend. `SettingsView.swift` references `data.fleetHostsDeleted` — if only one side is renamed, it compiles but the count will always be 0 (Codable fails silently on unknown keys).
**Why it happens:** The property name in a `Codable` struct IS the JSON key (unless a `CodingKeys` enum overrides it).
**How to avoid:** Rename both the DTO property AND every call site in the same change set. Swift compiler will catch all callers.
**Warning signs:** Data erasure count shows 0 for host profiles even after deleting.

### Pitfall 3: Directory Rename Not Reflected in Xcode Project
**What goes wrong:** Renaming `Views/Fleet/` to `Views/HostProfiles/` on disk without updating `project.pbxproj` causes Xcode to show "missing file" errors and build failures.
**Why it happens:** The `.xcodeproj` contains hardcoded file paths. Moving files without telling Xcode breaks references.
**How to avoid:** The project does NOT use `project.yml` for the Fleet group (confirmed: grep found nothing in project.yml). Must update `project.pbxproj` directly — change group `path = Fleet` → `path = HostProfiles` and update individual file paths. Alternatively, do the rename through Xcode's "Move" functionality (but this is a code-only session).
**Warning signs:** Build errors like "no such file or directory: .../Views/Fleet/HostProfilesView.swift".

### Pitfall 4: API Path Strings in HostProfilesViewModel
**What goes wrong:** The ViewModel hardcodes `/fleet/` path strings in 5 places (lines 30, 45, 58, 77, 111). Missing even one means a silent 404 at runtime.
**Why it happens:** String literals are not type-checked; the compiler won't surface them.
**How to avoid:** After renaming, search the file for every `/fleet/` occurrence and replace with `/host-profiles/`. The old route alias handles backward compat until all strings are updated, but the new canonical paths should be used.
**Warning signs:** Host profiles list empty, activate/remove operations silently fail.

### Pitfall 5: Localization Key Mismatch
**What goes wrong:** `Localizable.xcstrings` has key `"fleet"` with value `"Fleet"` (line 149). If the key is changed without updating all call sites that use `NSLocalizedString("fleet", ...)` or SwiftUI `Text("fleet")`, the UI shows a raw key instead of a localized string.
**Why it happens:** Localization keys are strings — no compile-time check.
**How to avoid:** Search for usages of the `"fleet"` localization key before renaming. Add new key `"hostProfiles"` with value `"Host Profiles"`, keep old `"fleet"` entry for compat. Grep found no explicit `NSLocalizedString("fleet")` call sites in main source — the entry may be unused or auto-generated; verify before removing.
**Warning signs:** UI displays literal "fleet" text instead of "Host Profiles".

### Pitfall 6: Xcode Group Name vs File System Path
**What goes wrong:** `project.pbxproj` has TWO references to "Fleet" — the group name (display) and `path = Fleet` (filesystem). Changing only the group name leaves the filesystem path pointing to a directory named `Fleet/`, which still exists. Changing only the path breaks the group display.
**Why it happens:** These are separate fields in pbxproj.
**How to avoid:** Update both `name = Fleet` and `path = Fleet` entries. Also physically rename the directory from `Views/Fleet/` to `Views/HostProfiles/` on disk.

## Code Examples

### Registering Alias Routes in Vapor

```swift
// Source: Vapor 4 RouteCollection — registering two route groups to same handlers
struct HostProfileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        // Register handlers on both paths
        for group in [routes.grouped("host-profiles"), routes.grouped("fleet")] {
            group.get(use: index)
            group.post("register", use: register)
            group.post(":id", "activate", use: activate)
            group.delete(":id", use: delete)
            group.get(":id", "health", use: health)
        }
    }
}
```

### Inverting Typealias Direction in FleetHost.swift

```swift
// BEFORE (current state):
public typealias HostProfile = FleetHost   // line 4
public struct FleetHost: Codable, ... { ... }

// AFTER (canonical rename):
/// Backward-compatible alias — new code should use HostProfile.
public typealias FleetHost = HostProfile
public struct HostProfile: Codable, ... {
    // preconditions updated:
    precondition(!name.isEmpty, "HostProfile name must not be empty")
    precondition(!host.isEmpty, "HostProfile host must not be empty")
    precondition(port > 0 && port <= 65535, "HostProfile SSH port must be 1-65535")
    precondition(backendPort > 0 && backendPort <= 65535, "HostProfile backend port must be 1-65535")
}
```

### Evidence Capture Script Pattern

```bash
#!/bin/bash
# evidence/phase-49-foundation/capture.sh
SIMULATOR_UDID="50523130-57AA-48B0-ABD0-4D59CE455F14"
OUT_DIR="evidence/phase-49-foundation"
mkdir -p "$OUT_DIR"

# Boot simulator if needed
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

# Install and launch app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ILSApp.app" -path "*/Debug-iphonesimulator/*" | head -1)
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" com.ils.app

sleep 2

# Navigate to Host Profiles via deep link
xcrun simctl openurl "$SIMULATOR_UDID" "ils://host-profiles"
sleep 1

# Capture screenshot
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUT_DIR/00-rename-complete.png"
echo "Captured: 00-rename-complete.png"
```

### APIClient Path Update Pattern

```swift
// HostProfilesViewModel.swift — update all /fleet/ → /host-profiles/
// BEFORE:
let response: APIResponse<FleetListResponse> = try await appState.apiClient.get("/fleet")
let newHost: FleetHost = try await appState.apiClient.post("/fleet/register", body: request)
let _: FleetHost = try await appState.apiClient.post("/fleet/\(id)/activate", body: EmptyBody())
let _: DeletedResponse = try await appState.apiClient.delete("/fleet/\(id)")
// health polling: appState.apiClient.get("/fleet/\(hosts[i].id)/health")

// AFTER:
let response: APIResponse<HostProfileListResponse> = try await appState.apiClient.get("/host-profiles")
let newHost: HostProfile = try await appState.apiClient.post("/host-profiles/register", body: request)
let _: HostProfile = try await appState.apiClient.post("/host-profiles/\(id)/activate", body: EmptyBody())
let _: DeletedResponse = try await appState.apiClient.delete("/host-profiles/\(id)")
// health polling: appState.apiClient.get("/host-profiles/\(hosts[i].id)/health")
```

## State of the Art

| Old Approach | Current Approach | Status | Notes |
|--------------|------------------|--------|-------|
| `FleetHost` canonical type | `HostProfile` typealias exists, `FleetHost` still canonical | Partially migrated | ILSShared already has `typealias HostProfile = FleetHost` |
| `FleetListResponse` direct use | `HostProfileListResponse` typealias exists | Partially migrated | Aliases at top of FleetDTOs.swift |
| UI labels: "Fleet" | UI labels: "Host Profiles" | Complete | SidebarView, MacContentView, HostProfilesView all use new label |
| `ActiveScreen.fleet` case | `ActiveScreen.hostProfiles` with `.fleet` compat alias | Complete | SidebarRootView.swift |
| `/fleet/*` routes only | `/fleet/*` routes only (alias pending) | Incomplete | Backend still only has /fleet/* |
| `ils://fleet` only | `ils://fleet` + `ils://host-profiles` | Incomplete | AppState handles fleet/profiles but not host-profiles |

## Open Questions

1. **Should `Views/Fleet/` directory be renamed to `Views/HostProfiles/` on disk?**
   - What we know: `project.pbxproj` has `path = Fleet` group containing `HostProfileDetailView.swift` and `HostProfilesView.swift`. The files inside are already renamed but the directory is not.
   - What's unclear: Whether the planner wants to rename the directory (cosmetic but complete) or leave it (avoids pbxproj surgery risk).
   - Recommendation: Yes, rename the directory and update pbxproj — the success criterion says "no remnants of old terminology visible anywhere." A `Views/Fleet/` folder is a remnant.

2. **Should `FleetHostModel` Fluent model be renamed to `HostProfileModel`?**
   - What we know: `static let schema = "fleet_hosts"` MUST stay unchanged (table name). The class name is only an internal Swift identifier.
   - What's unclear: Whether renaming the class adds value vs. the risk of missing a reference.
   - Recommendation: Yes, rename the class (compiler enforces all callers), but add a comment explicitly documenting why the schema string stays `"fleet_hosts"`.

3. **Is the `Localizable.xcstrings` "fleet" key actively used?**
   - What we know: The key exists with value "Fleet". No `NSLocalizedString("fleet")` call found in a grep of the main source.
   - What's unclear: Whether it's auto-generated by Xcode or explicitly used somewhere.
   - Recommendation: Search for all `"fleet"` string usages; if no caller exists, remove the key. If callers exist, add a new `"hostProfiles"` key and keep `"fleet"` for compat.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection — all 16 files inventoried above from `/Users/nick/Desktop/ils-ios/` main codebase
- `evidence/` directory structure at `/Users/nick/Desktop/ils-ios/evidence/` — existing pattern confirmed
- Vapor 4 RouteCollection API — `boot(routes:)` dual registration is standard Vapor pattern

### Secondary (MEDIUM confidence)
- Xcode pbxproj group/path structure — inspected directly from `project.pbxproj` lines 1063-1166

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are existing project infrastructure; no new dependencies
- Architecture (rename inventory): HIGH — derived from direct file inspection of all 16 affected files
- Pitfalls: HIGH — derived from actual code (schema string, Codable key names, pbxproj paths)

**Research date:** 2026-02-27
**Valid until:** Stable indefinitely — pure rename, no external dependencies
