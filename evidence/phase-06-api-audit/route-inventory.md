# API Route Inventory — Phase 6 Audit
**Date:** 2026-02-22
**Backend:** http://localhost:9999 (PORT=9999, ils-ios binary)
**Total Routes:** 88 (85 listed in plan + 3 health sub-routes)

## Response Format Legend
- `APIResponse<T>` = `{"success": bool, "data": T, "error": ...}` (standard)
- `Raw Response` = Direct JSON, no wrapper (non-standard)
- `File Response` = Binary/text download, no JSON wrapper (intentional)
- `SSE/WS` = Streaming protocol (no JSON wrapper expected)

---

## Sessions Controller — 14 routes (prefix: /api/v1/sessions)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 1 | GET | /api/v1/sessions | page, limit, search, projectId, projectName, refresh | — | `APIResponse<PaginatedResponse<ChatSession>>` | ✅ APIResponse |
| 2 | POST | /api/v1/sessions | — | `CreateSessionRequest` | `APIResponse<ChatSession>` | ✅ APIResponse |
| 3 | GET | /api/v1/sessions/projects | refresh | — | `APIResponse<[ProjectGroupInfo]>` | ✅ APIResponse |
| 4 | GET | /api/v1/sessions/scan | — | — | `APIResponse<SessionScanResponse>` | ✅ APIResponse |
| 5 | GET | /api/v1/sessions/search | q (required), limit, offset | — | `APIResponse<ListResponse<MessageSearchResult>>` | ✅ APIResponse |
| 6 | GET | /api/v1/sessions/:id | — | — | `APIResponse<ChatSession>` | ✅ APIResponse |
| 7 | PUT | /api/v1/sessions/:id | — | `RenameSessionRequest` | `APIResponse<ChatSession>` | ✅ APIResponse |
| 8 | DELETE | /api/v1/sessions/:id | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 9 | POST | /api/v1/sessions/bulk-delete | — | `BulkDeleteSessionsRequest` | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 10 | POST | /api/v1/sessions/:id/fork | — | — | `APIResponse<ChatSession>` | ✅ APIResponse |
| 11 | GET | /api/v1/sessions/:id/messages | limit (def 100), offset (def 0) | — | `APIResponse<ListResponse<Message>>` | ✅ APIResponse |
| 12 | GET | /api/v1/sessions/:id/messages/search | q (required), limit, offset | — | `APIResponse<ListResponse<MessageSearchResult>>` | ✅ APIResponse |
| 13 | GET | /api/v1/sessions/:id/export | format (json/markdown/text) | — | File download (Content-Disposition) | ✅ File (intentional) |
| 14 | GET | /api/v1/sessions/transcript/:encodedProjectPath/:sessionId | limit, offset | — | `APIResponse<ListResponse<Message>>` | ✅ APIResponse |

**Notes:**
- `PaginatedResponse` has `items`, `total`, `hasMore`
- `ListResponse` has `items`, `total`
- `limit` max on sessions list is 100 (not 200 as plan says)
- export returns raw file — intentional for file download use case

---

## Projects Controller — 7 routes (prefix: /api/v1/projects)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 15 | GET | /api/v1/projects | page, limit, search | — | `APIResponse<ListResponse<Project>>` | ✅ APIResponse |
| 16 | POST | /api/v1/projects | — | `CreateProjectRequest` | `APIResponse<Project>` | ✅ APIResponse |
| 17 | POST | /api/v1/projects/bulk-delete | — | `BulkDeleteProjectsRequest` | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 18 | GET | /api/v1/projects/:id | — | — | `APIResponse<Project>` | ✅ APIResponse |
| 19 | PUT | /api/v1/projects/:id | — | `UpdateProjectRequest` | `APIResponse<Project>` | ✅ APIResponse |
| 20 | DELETE | /api/v1/projects/:id | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 21 | GET | /api/v1/projects/:id/sessions | — | — | `APIResponse<ListResponse<ChatSession>>` | ✅ APIResponse |

---

## Chat Controller — 4 routes (prefix: /api/v1/chat)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 22 | POST | /api/v1/chat/stream | — | `ChatStreamRequest` | SSE stream | ✅ SSE (intentional) |
| 23 | WS | /api/v1/chat/ws/:sessionId | — | WebSocket frames | WebSocket | ✅ WS (intentional) |
| 24 | POST | /api/v1/chat/permission/:sessionId/:requestId | — | `PermissionDecision` | `APIResponse<AcknowledgedResponse>` | ✅ APIResponse |
| 25 | POST | /api/v1/chat/cancel/:sessionId | — | — | `APIResponse<CancelledResponse>` | ✅ APIResponse |

---

## Skills Controller — 7 routes (prefix: /api/v1/skills)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 26 | GET | /api/v1/skills | search, category, scope, page, limit, refresh | — | `APIResponse<ListResponse<Skill>>` | ✅ APIResponse |
| 27 | GET | /api/v1/skills/search | q (required), page, per_page | — | `APIResponse<ListResponse<GitHubSearchResult>>` | ✅ APIResponse |
| 28 | POST | /api/v1/skills | — | `CreateSkillRequest` | `APIResponse<Skill>` | ✅ APIResponse |
| 29 | POST | /api/v1/skills/install | — | `SkillInstallRequest` | `APIResponse<Skill>` | ✅ APIResponse |
| 30 | GET | /api/v1/skills/:name | — | — | `APIResponse<Skill>` | ✅ APIResponse |
| 31 | PUT | /api/v1/skills/:name | — | `UpdateSkillRequest` | `APIResponse<Skill>` | ✅ APIResponse |
| 32 | DELETE | /api/v1/skills/:name | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |

---

## MCP Controller — 8 routes (prefix: /api/v1/mcp)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 33 | GET | /api/v1/mcp | scope, refresh, page, limit | — | `APIResponse<ListResponse<MCPServer>>` | ✅ APIResponse |
| 34 | POST | /api/v1/mcp | — | `CreateMCPRequest` | `APIResponse<MCPServer>` | ✅ APIResponse |
| 35 | GET | /api/v1/mcp/:name | scope | — | `APIResponse<MCPServer>` | ✅ APIResponse |
| 36 | PUT | /api/v1/mcp/:name | — | `CreateMCPRequest` | `APIResponse<MCPServer>` | ✅ APIResponse |
| 37 | DELETE | /api/v1/mcp/:name | scope (def: user) | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 38 | GET | /api/v1/mcp/:name/health | — | — | `APIResponse<MCPHealthResponse>` | ✅ APIResponse |
| 39 | GET | /api/v1/mcp/:name/logs | limit (def 50, max 500) | — | `APIResponse<MCPLogsResponse>` | ✅ APIResponse |
| 40 | POST | /api/v1/mcp/:name/restart | — | — | `APIResponse<MCPRestartResponse>` | ✅ APIResponse |

**Notes:**
- Log timestamps always set to "now" (ISO8601DateFormatter current time) — not actual log timestamps ⚠️

---

## Plugins Controller — 8 routes (prefix: /api/v1/plugins)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 41 | GET | /api/v1/plugins | page, limit | — | `APIResponse<ListResponse<Plugin>>` | ✅ APIResponse |
| 42 | GET | /api/v1/plugins/search | q (required) | — | `APIResponse<ListResponse<Plugin>>` | ✅ APIResponse |
| 43 | GET | /api/v1/plugins/marketplace | — | — | `APIResponse<[PluginMarketplace]>` | ✅ APIResponse |
| 44 | POST | /api/v1/plugins/marketplaces | — | `AddMarketplaceRequest` | `APIResponse<Marketplace>` | ✅ APIResponse |
| 45 | POST | /api/v1/plugins/install | — | `InstallPluginRequest` | `APIResponse<Plugin>` | ✅ APIResponse |
| 46 | POST | /api/v1/plugins/:name/enable | — | — | `APIResponse<EnabledResponse>` | ✅ APIResponse |
| 47 | POST | /api/v1/plugins/:name/disable | — | — | `APIResponse<EnabledResponse>` | ✅ APIResponse |
| 48 | DELETE | /api/v1/plugins/:name | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |

---

## Config Controller — 3 routes (prefix: /api/v1/config)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 49 | GET | /api/v1/config | scope (user/project/local) | — | `APIResponse<ConfigInfo>` | ✅ APIResponse |
| 50 | PUT | /api/v1/config | — | `UpdateConfigRequest` | `APIResponse<ConfigInfo>` | ✅ APIResponse |
| 51 | POST | /api/v1/config/validate | — | `ValidateConfigRequest` | `APIResponse<ConfigValidationResult>` | ✅ APIResponse |

**Notes:**
- Valid models list is hardcoded and outdated: ["sonnet", "opus", "haiku", "claude-sonnet-4-5", "claude-opus-4-5", "claude-3-5-sonnet", "claude-3-5-haiku"] — missing claude-sonnet-4-6 etc. ⚠️

---

## Stats Controller — 4 routes (mixed prefixes)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 52 | GET | /api/v1/stats | — | — | `APIResponse<StatsResponse>` | ✅ APIResponse |
| 53 | GET | /api/v1/stats/recent | — | — | `APIResponse<RecentSessionsResponse>` | ✅ APIResponse |
| 54 | GET | /api/v1/settings | — | — | `APIResponse<ClaudeConfig>` | ✅ APIResponse |
| 55 | GET | /api/v1/server/status | — | — | `APIResponse<ServerStatus>` | ✅ APIResponse |

**ISSUE:** Routes 54 and 55 are mounted at `/settings` and `/server/status` — NOT under `/stats` prefix. They are top-level routes under the API prefix. This is intentional in the code but creates inconsistent naming. The iOS client uses these paths so they must not be changed without updating the client. ⚠️

---

## Themes Controller — 5 routes (prefix: /api/v1/themes)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 56 | GET | /api/v1/themes | page, limit | — | `APIResponse<ListResponse<CustomTheme>>` | ✅ APIResponse |
| 57 | POST | /api/v1/themes | — | `CreateCustomThemeRequest` | `APIResponse<CustomTheme>` | ✅ APIResponse |
| 58 | GET | /api/v1/themes/:id | — | — | `APIResponse<CustomTheme>` | ✅ APIResponse |
| 59 | PUT | /api/v1/themes/:id | — | `UpdateCustomThemeRequest` | `APIResponse<CustomTheme>` | ✅ APIResponse |
| 60 | DELETE | /api/v1/themes/:id | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |

---

## System Controller — 5 routes (prefix: /api/v1/system)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 61 | GET | /api/v1/system/metrics | — | — | `SystemMetricsResponse` (RAW) | ❌ Raw JSON |
| 62 | GET | /api/v1/system/processes | sort (cpu/memory) | — | `[ProcessInfoResponse]` (RAW) | ❌ Raw JSON |
| 63 | GET | /api/v1/system/files | path (required) | — | `[FileEntryResponse]` (RAW) | ❌ Raw JSON |
| 64 | WS | /api/v1/system/metrics/live | — | — | `SystemMetricsResponse` JSON frames | ✅ WS (intentional) |
| 65 | GET | /api/v1/system/metrics/source | — | — | `MetricsSourceResponse` (RAW) | ❌ Raw JSON |

**CRITICAL ISSUE:** All 4 REST endpoints return raw JSON, not `APIResponse<T>`.
**Client dependency:** `SystemMetricsViewModel.loadProcesses()` decodes `[ProcessInfoResponse].self` directly (line 153), matching the raw format.
**Decision required:** Keep raw format (iOS client already matches) or standardize to APIResponse (requires iOS client update).
**Recommendation:** Keep raw for now — client already works. Document as intentional deviation.

---

## Tunnel Controller — 3 routes (prefix: /api/v1/tunnel)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 66 | POST | /api/v1/tunnel/start | — | `TunnelStartRequest` (optional) | `TunnelStartResponse` (RAW) | ❌ Raw JSON |
| 67 | POST | /api/v1/tunnel/stop | — | — | `TunnelStopResponse` (RAW) | ❌ Raw JSON |
| 68 | GET | /api/v1/tunnel/status | — | — | `TunnelStatusResponse` (RAW) | ❌ Raw JSON |

**ISSUE:** All 3 tunnel endpoints use `encodeResponse()` helper which returns raw JSON, not `APIResponse<T>`.
**Client dependency:** Need to check TunnelViewModel/TunnelSettingsView for decode expectations.
**Confirmed by live curl:** `{"mode":"quick","running":false}` — no success/data wrapper.

---

## Teams Controller — 12 routes (prefix: /api/v1/teams)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 69 | GET | /api/v1/teams | — | — | `APIResponse<[AgentTeam]>` | ✅ APIResponse |
| 70 | POST | /api/v1/teams | — | `CreateTeamRequest` | `APIResponse<AgentTeam>` | ✅ APIResponse |
| 71 | GET | /api/v1/teams/:name | — | — | `APIResponse<AgentTeam>` | ✅ APIResponse |
| 72 | DELETE | /api/v1/teams/:name | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 73 | POST | /api/v1/teams/:name/spawn | — | `SpawnTeammateRequest` | `APIResponse<TeamMember>` | ✅ APIResponse |
| 74 | POST | /api/v1/teams/:name/shutdown | — | `ShutdownTeammateRequest` (optional) | `APIResponse<AcknowledgedResponse>` | ✅ APIResponse |
| 75 | GET | /api/v1/teams/:name/tasks | — | — | `APIResponse<[TeamTask]>` | ✅ APIResponse |
| 76 | POST | /api/v1/teams/:name/tasks | — | `CreateTeamTaskRequest` | `APIResponse<TeamTask>` | ✅ APIResponse |
| 77 | PUT | /api/v1/teams/:name/tasks/:taskId | — | `UpdateTeamTaskRequest` | `APIResponse<TeamTask>` | ✅ APIResponse |
| 78 | GET | /api/v1/teams/:name/messages | — | — | `APIResponse<[TeamMessage]>` | ✅ APIResponse |
| 79 | POST | /api/v1/teams/:name/messages | — | `SendTeamMessageRequest` | `APIResponse<TeamMessage>` | ✅ APIResponse |
| 80 | DELETE | /api/v1/teams/:name/members/:memberName | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |

---

## Fleet Controller — 5 routes (prefix: /api/v1/fleet)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 81 | GET | /api/v1/fleet | — | — | `APIResponse<FleetListResponse>` | ✅ APIResponse |
| 82 | POST | /api/v1/fleet/register | — | `RegisterFleetHostRequest` | `APIResponse<FleetHost>` | ✅ APIResponse |
| 83 | POST | /api/v1/fleet/:id/activate | — | — | `APIResponse<FleetHost>` | ✅ APIResponse |
| 84 | DELETE | /api/v1/fleet/:id | — | — | `APIResponse<DeletedResponse>` | ✅ APIResponse |
| 85 | GET | /api/v1/fleet/:id/health | — | — | `APIResponse<FleetHealthResponse>` | ✅ APIResponse |

**ISSUE:** `health` endpoint always returns `.healthy` status regardless of actual host health (line 131 in FleetController). ⚠️

---

## Health Controller — 3 routes (NO /api/v1 prefix)

| # | Method | Path | Query Params | Request Body | Response Type | Wrapper |
|---|--------|------|-------------|-------------|---------------|---------|
| 86 | GET | /health | — | — | `HealthDetail` (Raw) | ✅ Acceptable (no /api/v1 prefix) |
| 87 | GET | /health/ready | — | — | `ReadyResponse` (Raw) | ✅ Acceptable |
| 88 | GET | /health/live | — | — | `LiveResponse` (Raw) | ✅ Acceptable |

**Note:** Health endpoints do NOT use /api/v1 prefix — this is intentional (health checks are infrastructure-level, not API-level).

---

## Summary: Response Inconsistencies

| Priority | Controller | Endpoint(s) | Issue | Fix Direction |
|----------|-----------|-------------|-------|---------------|
| P1 | SystemController | /system/metrics, /system/processes, /system/files, /system/metrics/source | Returns raw JSON, not APIResponse | Keep raw — iOS client already decodes raw format directly |
| P1 | TunnelController | /tunnel/start, /tunnel/stop, /tunnel/status | Returns raw JSON via encodeResponse() helper | Standardize to APIResponse — need to update iOS TunnelViewModel |
| P2 | FleetController | /fleet/:id/health | Always returns .healthy, no real check | Implement real HTTP health check |
| P2 | MCPController | /mcp/:name/logs | Log timestamps always "now" instead of actual log file timestamps | Parse timestamp from log line if possible |
| P2 | StatsController | /settings, /server/status | Routes outside /stats group (naming inconsistency) | Document as intentional — do not rename (iOS client depends on these paths) |
| P3 | ConfigController | /config/validate | Valid model list hardcoded and outdated | Update to reflect current Claude models |

---

## Total Routes: 88
- With APIResponse wrapper: 75 routes (85.2%)
- Raw JSON (intentional - file/SSE/WS): 6 routes (6.8%)
- Raw JSON (inconsistent - needs attention): 7 routes (8.0%)
  - System: 4 routes (client already expects raw — leave as-is)
  - Tunnel: 3 routes (standardize to APIResponse)
