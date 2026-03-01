---
plan: 49-01
phase: 49-foundation
status: complete
completed: 2026-02-27
---

# Summary: 49-01 — ILSShared + Backend Rename (Fleet → HostProfile)

## What Was Built

Inverted the canonical type direction in ILSShared and renamed all backend artifacts from Fleet* to HostProfile*.

## Changes Made

### ILSShared (Sources/ILSShared/)

**Models/FleetHost.swift**
- `public struct FleetHost` → `public struct HostProfile` (canonical)
- `public typealias HostProfile = FleetHost` → `public typealias FleetHost = HostProfile` (backward-compat)
- Updated 4 precondition message strings: "FleetHost …" → "HostProfile …"
- Doc comments updated throughout

**DTOs/FleetDTOs.swift**
- `struct RegisterFleetHostRequest` → `struct RegisterHostProfileRequest` (canonical)
- `struct FleetListResponse` → `struct HostProfileListResponse` (canonical; `hosts: [HostProfile]`)
- `struct FleetHealthResponse` → `struct HostProfileHealthResponse` (canonical; `status: HostProfile.HealthStatus`)
- Added backward-compat typealiases: `FleetListResponse`, `FleetHealthResponse`, `RegisterFleetHostRequest`

### ILSBackend (Sources/ILSBackend/)

**Controllers/HostProfileController.swift** (renamed from FleetController.swift)
- `struct FleetController` → `struct HostProfileController`
- Registers BOTH route groups in `boot(routes:)`:
  - `/host-profiles/*` (new canonical)
  - `/fleet/*` (backward-compatible alias, same handlers)
- All handler type refs updated: `FleetHost` → `HostProfile`, `FleetListResponse` → `HostProfileListResponse`, etc.
- Log strings updated: "Fleet health…" → "Host profile health…"

**Models/HostProfileModel.swift** (renamed from FleetHostModel.swift)
- `final class FleetHostModel` → `final class HostProfileModel`
- `static let schema = "fleet_hosts"` — UNCHANGED (preserves all user data)
- Added comment: "DB table name — MUST remain "fleet_hosts" to preserve existing data."
- `func toShared() -> FleetHost` → `func toShared() -> HostProfile`

**App/routes.swift**
- `FleetController()` → `HostProfileController()`

**Controllers/DataErasureController.swift**
- Comment: `// Fleet hosts` → `// Host profiles`
- Log string: `"fleet hosts"` → `"host profiles"`
- `FleetHostModel` references → `HostProfileModel`

**Extensions/VaporContent+Extensions.swift**
- 5 Content extensions updated: `FleetHost` → `HostProfile`, `FleetListResponse` → `HostProfileListResponse`, etc.

## Dual Route Registration Confirmed

```
routes.grouped("host-profiles")  ← new canonical
routes.grouped("fleet")           ← backward-compatible alias
```
Both point to identical handler methods.

## Build Result

`swift build` → **Build complete! (6.53s)** — zero errors, pre-existing warnings only.

## Deviations from Plan

None. All steps executed as specified. `fleetHostsDeleted` in ResponseDTOs.swift was correctly left unchanged (JSON key compatibility).

## Self-Check: PASSED

- [x] `public struct HostProfile` exists in FleetHost.swift
- [x] `public typealias FleetHost = HostProfile` exists
- [x] No `public struct FleetHost` anywhere in Sources/ILSShared/
- [x] `HostProfileController.swift` exists; `FleetController.swift` does not
- [x] `HostProfileModel.swift` exists; `FleetHostModel.swift` does not
- [x] Both `routes.grouped("host-profiles")` and `routes.grouped("fleet")` in HostProfileController
- [x] `static let schema = "fleet_hosts"` unchanged
- [x] `swift build` exits 0
