# Phase 6 Summary — Backend API Audit

**Status:** COMPLETE
**Started:** 2026-02-22
**Completed:** 2026-02-22
**Commit:** `94bc0fd` (tasks 6.1-6.3)

## What Was Delivered

### Task 6.1: Route Enumeration
- Complete inventory of **88 routes** across 14 controllers + 3 health endpoints
- Documented: method, path, query params, request body, response type, wrapper status
- Evidence: `evidence/phase-06-api-audit/route-inventory.md`

### Task 6.2: Inconsistency Analysis
Identified response wrapper inconsistencies:

| Priority | Controller | Issue | Decision |
|----------|-----------|-------|----------|
| P1 | SystemController | 4 REST endpoints return raw JSON | Keep raw — iOS client already decodes raw format |
| P1 | TunnelController | 3 endpoints return raw JSON | Noted — standardize in future if needed |
| P2 | FleetController | `/fleet/:id/health` had no real check | **Fixed** — real HTTP health check implemented |
| P2 | MCPController | Log timestamps always "now" | Noted — cosmetic issue |
| P2 | StatsController | `/settings`, `/server/status` outside `/stats` group | Intentional — documented |
| P3 | ConfigController | Hardcoded model list outdated | Noted — needs update when new models ship |

### Task 6.3: Endpoint Fixes
- **FleetController**: Implemented real HTTP health check to `http(s)://{host}:{backendPort}/health`
  - 5-second timeout for health checks
  - Parses version from health response JSON
  - Persists health status and timestamp to database
  - Status mapping: 2xx → healthy, other → degraded, error → unreachable
- **ConfigController**: 18 lines of fixes
- **MCPController**: 45 lines of improvements

### Task 6.4: Live Verification
20 endpoints tested against running backend — **all 20 PASS**:

| Controller | Endpoints Tested | Result |
|-----------|-----------------|--------|
| Health | 3 | PASS (healthy, ready, alive) |
| Sessions | 4 | PASS (22,430 sessions, 365 groups) |
| Projects | 1 | PASS (374 projects) |
| Stats | 4 | PASS (all 4 returning APIResponse) |
| Skills | 1 | PASS (1,342 skills) |
| MCP | 1 | PASS (16 servers) |
| Plugins | 1 | PASS (97 plugins) |
| Config | 1 | PASS |
| Themes | 1 | PASS (0 custom themes) |
| System | 2 | PASS (raw JSON, 1,201 processes) |
| Tunnel | 1 | PASS (raw JSON, not running) |
| Teams | 1 | PASS (5 teams) |
| Fleet | 1 | PASS (1 host) |

### Task 6.5: Documentation
- Route inventory: `evidence/phase-06-api-audit/route-inventory.md` (245 lines)
- Audit script: `scripts/api-audit.sh` (947 lines) — comprehensive bash script for all endpoints
- This summary document

## Key Metrics

| Metric | Value |
|--------|-------|
| Total routes audited | 88 |
| With APIResponse wrapper | 75 (85.2%) |
| Raw JSON (intentional — SSE/WS/file) | 6 (6.8%) |
| Raw JSON (documented deviation) | 7 (8.0%) |
| Endpoints fixed | 3 controllers |
| Files changed | 3 (+ 2 evidence/scripts) |
| Live verification | 20/20 PASS |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Keep SystemController raw JSON | iOS client (`SystemMetricsViewModel`) already decodes raw format directly |
| Keep TunnelController raw JSON | Would require iOS `TunnelViewModel` update — defer to future sprint |
| Keep health endpoints outside `/api/v1` | Infrastructure-level checks, not API resources |
| Keep `/settings` and `/server/status` paths | iOS client depends on these exact paths |
| FleetController health → real HTTP check | Was returning hardcoded `.healthy` — now performs actual connectivity test |
