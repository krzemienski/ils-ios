# Swift 6 Migration Guide -- ILS iOS/macOS

## Current State

- **targeted mode:** CLEAN (zero warnings in project source across all 5 targets)
- **complete mode:** 212 project-source warnings, 0 errors (details below)
  - Backend (ILSBackend + ILSShared): 67 unique warnings across 13 files
  - iOS (ILSApp): 145 unique warnings across 28 files
  - Third-party dependencies: warnings suppressed by SPM (compiled with their own settings)

## Blocker Categories

### Category 1: Non-Sendable APIResponse Returns (76 warnings -- iOS only)

The largest single category. All `@MainActor` ViewModels call `APIClient` (an actor) methods that return `APIResponse<T>` where `T` is not `Sendable`. The returned value crosses an actor boundary.

| File | Lines | Count | Issue |
|------|-------|-------|-------|
| `ViewModels/ChatViewModel.swift` | 277, 287, 313, 323, 385, 401, 557, 579, 594, 607, 621 | 11 | APIResponse results cross actor boundary |
| `ViewModels/TeamsViewModel.swift` | 37, 54, 70, 85, 102, 119, 136, 152, 169, 186, 202 | 11 | APIResponse results cross actor boundary |
| `ViewModels/SkillsViewModel.swift` | 94, 124, 141, 159, 172, 189, 204 | 7 | APIResponse results cross actor boundary |
| `ViewModels/PluginsViewModel.swift` | 72, 93, 107, 118, 133, 153, 167 | 7 | APIResponse results cross actor boundary |
| `ViewModels/MCPViewModel.swift` | 82, 113, 129, 145, 191, 230 | 6 | APIResponse results cross actor boundary |
| `ViewModels/SessionsViewModel.swift` | 152, 174, 234, 277, 293, 312, 324 | 7 | APIResponse results cross actor boundary |
| `ViewModels/ProjectsViewModel.swift` | 62, 102, 122, 139, 156 | 5 | APIResponse results cross actor boundary |
| `ViewModels/SettingsViewModel.swift` | 48, 60, 121, 174 | 4 | APIResponse results cross actor boundary |
| `ViewModels/ThemesViewModel.swift` | 34, 73, 109, 125 | 4 | APIResponse results cross actor boundary |
| `ViewModels/ConfigEditorViewModel.swift` | 24, 57 | 2 | APIResponse results cross actor boundary |
| `ViewModels/NewSessionViewModel.swift` | 42, 62, 116 | 3 | APIResponse results cross actor boundary |
| `ViewModels/DashboardViewModel.swift` | 82, 96 | 2 | APIResponse results cross actor boundary |
| `ViewModels/HostProfilesViewModel.swift` | 30 | 1 | APIResponse results cross actor boundary |
| `Views/Chat/CommandPaletteView.swift` | 159 | 1 | APIResponse results cross actor boundary |
| `Views/Sessions/NewSessionView.swift` | 790 | 1 | APIResponse results cross actor boundary |
| `Views/Sessions/SessionInfoView.swift` | 133 | 1 | APIResponse results cross actor boundary |
| `Theme/CustomThemeAdapter.swift` | 229 | 1 | APIResponse results cross actor boundary |
| `ILSAppApp.swift` | 199 | 1 | APIResponse results cross actor boundary |

**Fix:** Make `APIResponse<T>`, `ListResponse<T>`, `PaginatedResponse<T>`, and all DTO types (`ChatSession`, `Message`, `Project`, `Skill`, `MCPServer`, `Plugin`, `AgentTeam`, `TeamTask`, `TeamMessage`, `CustomTheme`, `StatsResponse`, `ConfigInfo`, `FleetListResponse`, `DeletedResponse`, `AcknowledgedResponse`, `EnabledResponse`, `PluginMarketplace`, `GitHubSearchResult`, `RecentSessionsResponse`, `ProjectGroupInfo`) conform to `Sendable`. Most are already structs with `Codable` -- adding `Sendable` is trivial.

**Estimated effort:** 30 minutes (bulk conformance addition in ILSShared models)

---

### Category 2: Non-Sendable Vapor Controller Methods (58 warnings -- Backend only)

All Vapor route handler methods registered via `routes.get`/`routes.post` are marked `@Sendable` by Vapor, but the controller types (classes) are not `Sendable`.

| Controller | File | Warning Count |
|------------|------|---------------|
| `SessionsController` | `Controllers/SessionsController.swift` | 15 |
| `PluginsController` | `Controllers/PluginsController.swift` | 9 |
| `MCPController` | `Controllers/MCPController.swift` | 9 |
| `ProjectsController` | `Controllers/ProjectsController.swift` | 8 |
| `SkillsController` | `Controllers/SkillsController.swift` | 8 |
| `StatsController` | `Controllers/StatsController.swift` | 5 |
| `ConfigController` | `Controllers/ConfigController.swift` | 4 |

**Fix:** Two options:
1. **Convert controllers to structs** (Vapor 4.89+ supports struct-based route collections). Since controllers hold no mutable state, struct conversion is straightforward.
2. **Add `@Sendable` conformance** to controller classes and mark as `final class: Sendable` (requires ensuring no mutable stored properties).

**Note:** Vapor's own Swift 6 migration is in progress. Vapor 5 will have native Swift 6 support. For Vapor 4.89, option 1 (struct controllers) is the recommended path.

**Estimated effort:** 45 minutes (7 controllers to convert)

---

### Category 3: Mutable Global Variables (22 warnings -- 18 iOS + 4 Backend)

Static properties that are not concurrency-safe because they hold non-`Sendable` types or are mutable global state.

**iOS -- App Intents (10 warnings):**

| File | Line | Property | Issue |
|------|------|----------|-------|
| `Intents/CreateSessionIntent.swift` | 19 | `title` | Nonisolated global shared mutable state |
| `Intents/CreateSessionIntent.swift` | 20 | `description` | Nonisolated global shared mutable state |
| `Intents/CreateSessionIntent.swift` | 121 | `typeDisplayRepresentation` | Nonisolated global shared mutable state |
| `Intents/CreateSessionIntent.swift` | 122 | `caseDisplayRepresentations` | Nonisolated global shared mutable state |
| `Intents/GetSessionInfoIntent.swift` | 7 | `title` | Nonisolated global shared mutable state |
| `Intents/GetSessionInfoIntent.swift` | 8 | `description` | Nonisolated global shared mutable state |
| `Intents/SendMessageIntent.swift` | 10 | `title` | Nonisolated global shared mutable state |
| `Intents/SendMessageIntent.swift` | 11 | `description` | Nonisolated global shared mutable state |
| `Intents/SessionEntity.swift` | 9 | `typeDisplayRepresentation` | Nonisolated global shared mutable state |
| `Intents/SessionEntity.swift` | 10 | `defaultQuery` | Nonisolated global shared mutable state |

**Fix:** Change `static var` to `static let` for all App Intents metadata properties (they are never mutated at runtime).

**iOS -- Date Formatters & EnvironmentKeys (8 warnings):**

| File | Line | Property | Issue |
|------|------|----------|-------|
| `Services/AppLogger.swift` | 17 | `iso8601Formatter` | Non-Sendable `ISO8601DateFormatter` |
| `Utils/DateFormatters.swift` | 7 | `relativeDateTime` | Non-Sendable `RelativeDateTimeFormatter` |
| `Theme/Components/ThemedCodeBlockView.swift` | 7, 14, 21 | `defaultValue` (3 EnvironmentKeys) | Nonisolated global shared mutable state |
| `Views/Chat/CodeBlockView.swift` | 6, 13, 20 | `defaultValue` (3 EnvironmentKeys) | Nonisolated global shared mutable state |

**Fix:** Wrap formatters with `nonisolated(unsafe)` or use `@unchecked Sendable` wrapper. EnvironmentKey `defaultValue` properties: change `static var` to `static let`.

**Backend -- Date Formatters (4 warnings):**

| File | Line | Property | Issue |
|------|------|----------|-------|
| `Controllers/ProjectsController.swift` | 58 | `flexibleISO8601` | Non-Sendable `ISO8601DateFormatter` |
| `Controllers/ProjectsController.swift` | 64 | `fallbackISO8601` | Non-Sendable `ISO8601DateFormatter` |
| `Services/SessionFileService.swift` | 35 | `flexibleISO8601Formatter` | Non-Sendable `ISO8601DateFormatter` |
| `Services/SessionFileService.swift` | 42 | `fallbackISO8601Formatter` | Non-Sendable `ISO8601DateFormatter` |

**Fix:** Wrap with `nonisolated(unsafe)` since these are set-once-read-many static lets.

**Estimated effort:** 20 minutes

---

### Category 4: Sending Risks / Data Races (17 warnings -- 16 iOS + 1 Backend)

Values of non-Sendable types being sent across concurrency boundaries.

**iOS:**

| File | Line | Issue |
|------|------|-------|
| `Services/CitadelSSHService.swift` | 89, 176, 205 | Sending `client` (SSHClient) risks data races |
| `Services/PerformanceMonitor.swift` | 36, 62 | Sending `payloads` risks data races |
| `Services/SSEClient.swift` | 138 | Closure as `sending` parameter risks data races |
| `ViewModels/ChatViewModel.swift` | 288, 324 | Sending `data` risks data races |
| `ViewModels/ProjectsViewModel.swift` | 68 | Sending `data` risks data races |
| `ViewModels/SetupViewModel.swift` | 92, 105, 113 | Sending `self` risks data races |
| `Widgets/ServerStatusWidget.swift` | 20, 27 | Closure as `sending` parameter risks data races |
| `Widgets/SessionWidget.swift` | 20, 28 | Closure as `sending` parameter risks data races |

**Backend:**

| File | Line | Issue |
|------|------|-------|
| `Services/StreamingService.swift` | 98 | Sending non-Sendable closure risks data races |

**Fix:** Case-by-case analysis required:
- **CitadelSSHService**: `SSHClient` from Citadel is not Sendable. Wrap in actor or use `@unchecked Sendable` wrapper if thread-safety is guaranteed.
- **PerformanceMonitor/ChatViewModel/ProjectsViewModel**: Make payload types Sendable (overlaps with Category 1).
- **SetupViewModel**: Ensure `@MainActor` isolation is consistent.
- **Widgets**: Use `@Sendable` closures or restructure Timeline providers.
- **StreamingService**: Restructure SSE closure to be `@Sendable`.

**Estimated effort:** 60 minutes (requires careful analysis of each case)

---

### Category 5: Global Actor Isolation -- UIKit/HapticManager (12 warnings -- iOS only)

Calls to `@MainActor`-isolated UIKit APIs from non-isolated contexts.

| File | Line | Issue |
|------|------|-------|
| `Utils/HapticManager.swift` | 6 | `UIImpactFeedbackGenerator(style:)` init from nonisolated context |
| `Utils/HapticManager.swift` | 6 | `.impactOccurred()` from nonisolated context |
| `Utils/HapticManager.swift` | 10 | `UINotificationFeedbackGenerator()` init from nonisolated context |
| `Utils/HapticManager.swift` | 10 | `.notificationOccurred()` from nonisolated context |
| `Utils/HapticManager.swift` | 14 | `UISelectionFeedbackGenerator()` init from nonisolated context |
| `Utils/HapticManager.swift` | 14 | `.selectionChanged()` from nonisolated context |
| `Utils/SessionExporter.swift` | 15 | `UIActivityViewController` init from nonisolated context |
| `Utils/SessionExporter.swift` | 16 | `UIApplication.shared` from nonisolated context |
| `Utils/SessionExporter.swift` | 16 | `.connectedScenes` from nonisolated context |
| `Utils/SessionExporter.swift` | 17 | `.windows` from nonisolated context |
| `Utils/SessionExporter.swift` | 17 | `.rootViewController` from nonisolated context |
| `Utils/SessionExporter.swift` | 18 | `.present()` from nonisolated context |

**Fix:** Mark `HapticManager` static methods as `@MainActor` (they only make sense on main thread anyway). Mark `SessionExporter.shareSession()` as `@MainActor`.

**Estimated effort:** 10 minutes

---

### Category 6: DispatchWorkItem Capture Semantics (6 warnings -- Backend only)

`DispatchWorkItem` instances captured in `@Sendable` closures in `ClaudeExecutorService`.

| File | Line | Issue |
|------|------|-------|
| `Services/ClaudeExecutorService.swift` | 220 | Mutation of captured `didTimeout` in concurrent code |
| `Services/ClaudeExecutorService.swift` | 221 | Capture of `timeoutWork` (non-Sendable DispatchWorkItem) |
| `Services/ClaudeExecutorService.swift` | 222 | Capture of `totalTimeoutWork` (non-Sendable DispatchWorkItem) |
| `Services/ClaudeExecutorService.swift` | 314 | Mutation of captured `didTimeout` in concurrent code |
| `Services/ClaudeExecutorService.swift` | 315 | Capture of `timeoutWork` (non-Sendable DispatchWorkItem) |
| `Services/ClaudeExecutorService.swift` | 316 | Capture of `totalTimeoutWork` (non-Sendable DispatchWorkItem) |

**Fix:** Refactor timeout logic to use Swift Concurrency (`Task.sleep` + `withTaskCancellationHandler`) instead of `DispatchWorkItem`. This eliminates the GCD/Sendable boundary entirely.

**Estimated effort:** 30 minutes (2 methods: `executeWithSDK` and `executeWithDirectCLI`)

---

### Category 7: Non-Sendable Type Access in Deinit / APIClient (6 warnings -- iOS only)

| File | Line | Issue |
|------|------|-------|
| `Services/APIClient.swift` | 186 | Non-Sendable `Task<Any, any Error>` exits actor-isolated context |
| `Services/APIClient.swift` | 186 | Non-Sendable `Any` sent to actor-isolated context |
| `Services/APIClient.swift` | 219 | Non-Sendable `Task<Any, any Error>` exits actor-isolated context |
| `Services/APIClient.swift` | 219 | Non-Sendable `Any` sent to actor-isolated context |
| `Services/PollingManager.swift` | 66 | Non-Sendable `NSObjectProtocol?` accessed in nonisolated deinit |
| `Services/PollingManager.swift` | 69 | Non-Sendable `NSObjectProtocol?` accessed in nonisolated deinit |

**Fix:**
- **APIClient**: Replace `Task<Any, any Error>` with typed tasks (e.g., `Task<Data, Error>`) so the result type is `Sendable`.
- **PollingManager**: Move observer removal to an explicit `stop()` method called before deinit, or use `nonisolated(unsafe)` for the observer properties.

**Estimated effort:** 20 minutes

---

### Category 8: @preconcurrency Imports (4 warnings -- 3 iOS + 1 Backend)

| File | Line | Module | Target |
|------|------|--------|--------|
| `Services/PollingManager.swift` | 1 | `ObjectiveC` | iOS |
| `Services/SyncCoordinator.swift` | 1 | `ObjectiveC` | iOS |
| `Utils/SyntaxHighlighter.swift` | 3 | `Splash` | iOS |
| `Services/ClaudeExecutorService.swift` | 1 | `Dispatch` | Backend |

**Fix:** Add `@preconcurrency import ObjectiveC`, `@preconcurrency import Splash`, and `@preconcurrency import Dispatch` to suppress warnings from modules not yet updated for Sendable.

**Estimated effort:** 5 minutes

---

### Category 9: Miscellaneous (4 warnings -- Backend only)

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `Services/SystemMetricsService.swift` | 255 | `vm_kernel_page_size` shared mutable state | Use `nonisolated(unsafe)` or read via helper function |
| `Middleware/RequestLoggingMiddleware.swift` | 23, 34 | `.string` deprecated (use `.rawValue`) | Replace `.string` with `.rawValue` |
| `Middleware/ILSErrorMiddleware.swift` | 15 | Nil coalescing on non-optional | Remove unnecessary `?? ""` |
| `Views/Themes/ThemesListView.swift` | 151 | MainActor-isolated `jsonDecoder` accessed from outside actor | Make `jsonDecoder` nonisolated or mark access `@MainActor` |

**Estimated effort:** 10 minutes

---

## Third-Party Dependency Warnings (not actionable)

SPM compiles third-party dependencies with their own concurrency settings. Under `-strict-concurrency=complete` for our targets only:
- **Vapor 4.89**: Not yet Swift 6 compatible. Vapor 5 (in development) targets full Swift 6 support.
- **Fluent 4.9**: Follows Vapor's timeline.
- **Citadel 0.7**: `SSHClient` is not `Sendable` (Category 4 blocker).
- **Splash 0.16**: Not updated for Sendable (Category 8 -- use `@preconcurrency import`).
- **MarkdownUI 2.4, HighlightSwift 1.0, GRDB 7.0**: No known concurrency issues in our usage patterns.

## Warning Summary

| Category | Backend | iOS | Total | Effort |
|----------|---------|-----|-------|--------|
| 1. Non-Sendable APIResponse returns | 0 | 76 | 76 | 30 min |
| 2. Non-Sendable Vapor controllers | 58 | 0 | 58 | 45 min |
| 3. Mutable global variables | 4 | 18 | 22 | 20 min |
| 4. Sending risks / data races | 1 | 16 | 17 | 60 min |
| 5. Global actor isolation (UIKit) | 0 | 12 | 12 | 10 min |
| 6. DispatchWorkItem captures | 6 | 0 | 6 | 30 min |
| 7. Non-Sendable in deinit/APIClient | 0 | 6 | 6 | 20 min |
| 8. @preconcurrency imports | 1 | 3 | 4 | 5 min |
| 9. Miscellaneous | 4 | 1 | 5 | 10 min |
| **Total** | **74** | **132** | **206** | **~3.5 hrs** |

*Note: Some warnings appear in multiple categories due to overlapping diagnostics. The 212 raw unique warnings consolidate to ~206 distinct issues.*

## Recommended Migration Order

1. **Category 8: @preconcurrency imports** (5 min, 4 warnings) -- Trivial, immediate wins
2. **Category 9: Miscellaneous** (10 min, 5 warnings) -- Quick deprecated/nil-coalescing fixes
3. **Category 5: Global actor isolation (UIKit)** (10 min, 12 warnings) -- Simple `@MainActor` annotations
4. **Category 3: Mutable global variables** (20 min, 22 warnings) -- `static var` to `static let`, `nonisolated(unsafe)` wrappers
5. **Category 1: Non-Sendable APIResponse returns** (30 min, 76 warnings) -- Bulk `Sendable` conformance on DTOs (highest count, mechanical)
6. **Category 7: Non-Sendable in deinit/APIClient** (20 min, 6 warnings) -- Typed tasks and explicit cleanup
7. **Category 6: DispatchWorkItem captures** (30 min, 6 warnings) -- Refactor to Swift Concurrency
8. **Category 2: Non-Sendable Vapor controllers** (45 min, 58 warnings) -- Struct controller conversion (depends on Vapor compatibility)
9. **Category 4: Sending risks / data races** (60 min, 17 warnings) -- Case-by-case analysis, some depend on upstream libraries

## Prerequisites

- **Vapor 5 or Vapor 4 Swift 6 update**: Categories 2 and parts of 4 depend on upstream Vapor support for `@Sendable` route handlers and Sendable request/response types.
- **Citadel Sendable update**: Category 4 (CitadelSSHService) requires `SSHClient` to be Sendable, or a local actor wrapper.
- **Apple framework updates**: Category 5 may benefit from future UIKit Sendable annotations, though `@MainActor` marking is the correct fix regardless.
- **Splash Sendable update**: Category 8 can be resolved with `@preconcurrency import` now, but a proper fix requires upstream Sendable conformance.

## Timeline Recommendation

**Phase 1 (immediate, ~1 hour):** Categories 8, 9, 5, 3 -- 43 warnings eliminated with minimal risk.

**Phase 2 (short-term, ~1.5 hours):** Categories 1, 7 -- 82 warnings eliminated by making DTOs Sendable and fixing APIClient typing.

**Phase 3 (medium-term, ~2 hours):** Categories 6, 2, 4 -- 81 warnings eliminated, requires more careful refactoring and may need upstream library updates for full resolution.

**Total estimated effort: ~3.5 hours to reach -strict-concurrency=complete with zero warnings.**

---
*Generated: 2026-02-24*
*Baseline: strict-concurrency=targeted (CLEAN) across all 5 build targets*
