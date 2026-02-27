---
phase: 46-security-compliance
plan: 01
status: complete
---

# Plan 46-01: Backend Authorization, Request Limits, GDPR Erasure

## What Was Built

1. **AdminMiddleware** -- Role-based route guard checking `X-Admin-Token` header against `ILS_ADMIN_KEY` env var. Uses constant-time string comparison to prevent timing attacks. Open access when no key configured (development mode).

2. **Route Splitting** -- `routes.swift` reorganized with public routes (Sessions, Chat, Projects, Skills, MCP, Plugins, Stats, Themes, Teams) on `api` group and admin-protected routes (Config, System, Fleet, Tunnel, DataErasure) on `admin` group.

3. **Configurable Body Size** -- `ILS_MAX_BODY_MB` env var controls max request body size (default: 10 MB). Explicit `PAYLOAD_TOO_LARGE` error code in ILSErrorMiddleware.

4. **DataErasureController** -- GDPR Article 17 endpoint at `DELETE /data/all`. Deletes all tables in a single transaction with FK-safe order (messages -> sessions -> projects -> themes -> fleet_hosts -> cached_results). Returns per-table deletion counts via `DataErasureResponse` DTO.

## Key Files

### Created
- `Sources/ILSBackend/Middleware/AdminMiddleware.swift`
- `Sources/ILSBackend/Controllers/DataErasureController.swift`

### Modified
- `Sources/ILSBackend/App/routes.swift`
- `Sources/ILSBackend/App/configure.swift`
- `Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift`
- `Sources/ILSShared/DTOs/ResponseDTOs.swift`
- `Sources/ILSBackend/Extensions/VaporContent+Extensions.swift`

## Self-Check: PASSED

- [x] AdminMiddleware with constant-time comparison
- [x] Routes split into public/admin groups
- [x] Configurable body size via env var
- [x] PAYLOAD_TOO_LARGE error code
- [x] DataErasureController with transactional deletion
- [x] Backend builds with zero errors
