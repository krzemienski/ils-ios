# Phase 21, Plan 02 — Codable Anti-Pattern Remediation

## Status: COMPLETE

## Files Modified (18 files)

### iOS App (5 files)
1. `ILSApp/ILSApp/Services/APIClient.swift` — CODBL-01 documentation
2. `ILSApp/ILSApp/Services/SyncCoordinator.swift` — CODBL-04 dateDecodingStrategy
3. `ILSApp/ILSApp/Services/SSEClient.swift` — CODBL-04 dateDecodingStrategy
4. `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — CODBL-04 dateDecodingStrategy
5. `ILSApp/ILSApp/Widgets/WidgetDataProvider.swift` — CODBL-04 dateDecodingStrategy (2 sites)

### Backend (2 files)
6. `Sources/ILSBackend/Controllers/ProjectsController.swift` — CODBL-05 do/catch logging (2 sites: index + show)
7. `Sources/ILSBackend/Controllers/FleetController.swift` — CODBL-05 do/catch logging

### Shared Models (7 files)
8. `Sources/ILSShared/Models/Session.swift` — CODBL-06 validating init for SessionStatus, SessionSource, PermissionMode
9. `Sources/ILSShared/Models/Plugin.swift` — CODBL-06 validating init for PluginSource
10. `Sources/ILSShared/Models/MCPServer.swift` — CODBL-06 validating init for MCPScope, MCPStatus
11. `Sources/ILSShared/Models/Message.swift` — CODBL-06 validating init for MessageRole
12. `Sources/ILSShared/Models/Skill.swift` — CODBL-06 validating init for SkillSource
13. `Sources/ILSShared/Models/FleetHost.swift` — CODBL-06 validating init for HealthStatus
14. `Sources/ILSShared/Models/ServerConnection.swift` — CODBL-06 validating init for AuthMethod
15. `Sources/ILSShared/Models/SetupProgress.swift` — CODBL-06 validating init for SetupStep, StepStatus

### Shared DTOs (3 files)
16. `Sources/ILSShared/DTOs/TeamDTOs.swift` — CODBL-06 validating init for TeamMemberStatus, TeamTaskStatus
17. `Sources/ILSShared/DTOs/SetupDTOs.swift` — CODBL-06 validating init for TunnelType, LifecycleAction
18. `Sources/ILSShared/DTOs/Requests.swift` — CODBL-06 validating init for ExportFormat
19. `Sources/ILSShared/DTOs/RemoteMetricsDTOs.swift` — CODBL-06 validating init for ProcessHighlightType, MetricsSource

### Keychain (2 files)
20. `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` — CODBL-03 do/catch for saves, comments for reads
21. `ILSApp/ILSApp/Views/Onboarding/SSHSetupView.swift` — CODBL-03 comment for intentional try? read

## Requirements Addressed

| Req | Description | Status |
|-----|-------------|--------|
| CODBL-01 | Document intentional try? in APIClient.validateResponse | DONE |
| CODBL-02 | CacheService already compliant | N/A (no changes needed) |
| CODBL-03 | Keychain try? sites: wrap saves in do/catch, document reads | DONE |
| CODBL-04 | Add .iso8601 dateDecodingStrategy to all JSONDecoders | DONE |
| CODBL-05 | Replace try? JSONDecoder in backend controllers with do/catch | DONE |
| CODBL-06 | Add validating init(from:) to String-backed Codable enums | DONE |

## Enum Validating Init Summary (CODBL-06)

20 enums across 12 files received validating `init(from:)`:

| Enum | File | Raw Values |
|------|------|------------|
| SessionStatus | Session.swift | active, completed, cancelled, error |
| SessionSource | Session.swift | ils, external |
| PermissionMode | Session.swift | default, acceptEdits, plan, bypassPermissions, delegate, dontAsk |
| TeamMemberStatus | TeamDTOs.swift | idle, active, shutdown |
| TeamTaskStatus | TeamDTOs.swift | pending, in_progress, completed, deleted |
| PluginSource | Plugin.swift | official, community |
| MCPScope | MCPServer.swift | user, project, local |
| MCPStatus | MCPServer.swift | healthy, unhealthy, unknown |
| MessageRole | Message.swift | user, assistant, system |
| SkillSource | Skill.swift | local, plugin, builtin, github |
| HealthStatus | FleetHost.swift | healthy, degraded, unreachable, unknown |
| TunnelType | SetupDTOs.swift | cloudflare, sshPortForward |
| LifecycleAction | SetupDTOs.swift | start, stop, restart |
| ExportFormat | Requests.swift | json, markdown, text |
| SetupStep | SetupProgress.swift | connect_ssh, detect_platform, ... (8 values) |
| StepStatus | SetupProgress.swift | pending, in_progress, success, failure, skipped |
| AuthMethod | ServerConnection.swift | password, sshKey |
| ProcessHighlightType | RemoteMetricsDTOs.swift | claude, ils_backend, swift, none |
| MetricsSource | RemoteMetricsDTOs.swift | local, remote |

Skipped: `ClaudeModel` (already has `unknown(_:)` fallback case with custom init).

## Build Results

| Target | Result |
|--------|--------|
| Backend (`swift build`) | PASS (Build complete! 4.25s) |
| iOS (`ILSApp` scheme) | PASS |
| macOS (`ILSMacApp` scheme) | PASS |

## Deviations

- CODBL-02 (CacheService) was listed as already compliant in the plan — confirmed, no changes needed.
- WidgetDataProvider.swift had 2 sites needing `.iso8601` (loadCachedSessions + fetchHealthFromAPI), not just 2 as estimated. The fetchSessionsFromAPI and fetchSessionCount methods already had `.iso8601`.
- Total files modified: 21 (not 18 as initially estimated due to Keychain files).
