# Tasks: ILS iOS App — Complete Polish, Remote Access & System Monitoring

## Phase Overview

| Phase | Tasks | Focus | Dependencies | Status |
|-------|-------|-------|-------------|--------|
| 0 | 0.1-0.5 | Foundation: theme, dead deps, dark mode, health check | None | Pending |
| 1 | 1.1-1.5 | Navigation: TabView replaces sidebar sheet | Phase 0 | Pending |
| 2 | 2.1-2.8 | Feature parity: fix broken features | Phase 1 | Pending |
| 3 | 3.1-3.5 | System monitoring backend | Phase 0 | Pending |
| 4 | 4.1-4.6 | System monitoring iOS | Phase 1, 3 | Pending |
| 5 | 5.1-5.5 | Cloudflare tunnel backend + iOS | Phase 1 | Pending |
| 6 | 6.1-6.6 | Chat rendering: markdown, code, accordions | Phase 1 | Pending |
| 7 | 7.1-7.5 | Onboarding enhancement | Phase 1, 5 | Pending |
| 8 | 8.1-8.9 | UI/UX redesign: cards, empty states, glass, polish | Phase 1, 2 | Pending |
| 9 | 9.1-9.4 | Dead code cleanup & accessibility | Phase 8 | Pending |
| 10 | 10.1-10.3 | Final validation: 13 scenarios, PR | Phase 9 | Pending |

---

## Phase 0: Foundation (Prerequisite for Everything)

Focus: Update theme system, remove dead dependency, fix two critical bugs. No new features.

- [ ] 0.1 Add EntityType enum and entity colors to ILSTheme
  - **Do**:
    1. Create `EntityType.swift` in `ILSApp/ILSApp/Theme/` with enum cases: `sessions, projects, skills, mcp, plugins, system`
    2. Add static func `entityColor(_ entity: EntityType) -> Color` returning hex colors from design.md (sessions=#007AFF, projects=#34C759, skills=#AF52DE, mcp=#FF9500, plugins=#FFD60A, system=#30B0C7)
    3. Add static func `entityGradient(_ entity: EntityType) -> LinearGradient` per design.md gradient presets
    4. Add static func `entityIcon(_ entity: EntityType) -> String` returning SF Symbols
    5. Add new background scale to ILSTheme: `bg0` (#000000), `bg1` (#0A0E1A), `bg2` (#111827), `bg3` (#1E293B), `bg4` (#334155)
    6. Add new text scale: `textPrimary` (#F1F5F9), `textSecondary` (#94A3B8), `textTertiary` (#64748B)
    7. Update semantic colors: success=#34C759, warning=#FF9500, error=#FF453A
    8. Add spacing tokens: `space2XS` (2), `spaceXS` (4), `spaceS` (8), `spaceM` (12), `spaceL` (16), `spaceXL` (20), `space2XL` (24), `space3XL` (32)
    9. Add corner radius tokens: `radiusXS` (6), `radiusS` (10), `radiusM` (14), `radiusL` (20), `radiusXL` (28)
  - **Files**: `ILSApp/ILSApp/Theme/EntityType.swift` (NEW), `ILSApp/ILSApp/Theme/ILSTheme.swift` (MODIFY)
  - **Done when**: EntityType enum exists, all 6 entity colors/gradients/icons accessible, new bg/text/spacing/radius tokens in ILSTheme
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(theme): add entity color system and updated design tokens`
  - _Requirements: AC-19.1, FR-8.1_
  - _Design: Color Palette, Entity Colors_

- [ ] 0.2 Remove ClaudeCodeSDK from Package.swift
  - **Do**:
    1. Remove `.package(url: "https://github.com/krzemienski/ClaudeCodeSDK.git", branch: "main")` from dependencies array in `Package.swift`
    2. Remove `.product(name: "ClaudeCodeSDK", package: "ClaudeCodeSDK")` from ILSBackend target dependencies
    3. Grep for any `import ClaudeCodeSDK` in backend sources and remove if found
  - **Files**: `Package.swift` (MODIFY)
  - **Done when**: `swift build` succeeds without ClaudeCodeSDK dependency
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `chore(deps): remove unused ClaudeCodeSDK dependency`
  - _Requirements: AC-20.1, FR-8.5_

- [ ] 0.3 Fix dark mode toggle — wire to UserDefaults
  - **Do**:
    1. In `ILSAppApp.swift`, remove hardcoded `.preferredColorScheme(.dark)`
    2. Add `@AppStorage("colorScheme") private var colorSchemePreference: String = "dark"` to `ILSAppApp`
    3. Add computed property that maps string to `ColorScheme?`: "system"->nil, "light"->.light, "dark"->.dark
    4. Apply `.preferredColorScheme(computedScheme)` using the AppStorage value
    5. Verify `SettingsView` color scheme picker writes to same `UserDefaults` key — update if needed to use `"colorScheme"` key
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift` (MODIFY), `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (MODIFY if needed)
  - **Done when**: Changing color scheme picker in Settings immediately changes app appearance; persists across launches
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(ios): wire dark mode toggle to UserDefaults preference`
  - _Requirements: AC-10.1, AC-10.2, AC-10.3, AC-10.4_

- [ ] 0.4 Fix health check path mismatch
  - **Do**:
    1. In `SettingsView.swift`, find `loadHealth()` method
    2. Verify it calls the correct `/health` path (not `/api/v1/health`)
    3. If it constructs its own URL, fix to use `APIClient.healthCheck()` which already calls `/health` correctly
    4. Ensure "Test Connection" button uses the corrected path
  - **Files**: `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (MODIFY)
  - **Done when**: "Test Connection" in Settings returns green check when backend running on port 9090
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(ios): correct health check path to /health`
  - _Requirements: AC-9.1, AC-9.2, FR-5.2_

- [ ] 0.5 [VERIFY] Phase 0 checkpoint: build succeeds, theme compiles
  - **Do**:
    1. Run backend build: `swift build`
    2. Run iOS build: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build`
    3. Verify EntityType enum accessible from any view
    4. Verify ClaudeCodeSDK no longer in resolved packages
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore(ios): pass phase 0 foundation checkpoint` (only if fixes needed)

---

## Phase 1: Navigation Overhaul

Focus: Replace sidebar-as-sheet with TabView. This is the single highest-impact UX change.

- [x] 1.1 Replace ContentView sidebar+sheet with TabView (5 tabs)
  - **Do**:
    1. Rewrite `ContentView.swift` body to use `TabView(selection: $appState.selectedTab)`
    2. Five tabs: Dashboard ("house.fill"), Sessions ("bubble.left.and.bubble.right.fill"), Projects ("folder.fill"), System ("gauge.with.dots.needle.33percent"), Settings ("gearshape.fill")
    3. Each tab wraps its view in `NavigationStack`
    4. Apply `.tint(.white)` on TabView so inactive tabs are gray, active is white
    5. Apply `.toolbarBackground(.ultraThinMaterial, for: .tabBar)` and `.toolbarBackground(.visible, for: .tabBar)` for glass effect
    6. Update `appState.selectedTab` type from String to an enum or keep String but update values to match new tabs: "dashboard", "sessions", "projects", "system", "settings"
    7. Remove sidebar sheet, `showingSidebar` state, sidebar toolbar button, invisible tap targets
    8. Remove `SidebarView` import/usage from ContentView (keep file for now)
  - **Files**: `ILSApp/ILSApp/ContentView.swift` (REWRITE), `ILSApp/ILSApp/ILSAppApp.swift` (MODIFY selectedTab default)
  - **Done when**: App shows 5-tab bottom bar; tapping each tab shows correct view; no sidebar sheet
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): replace sidebar sheet with 5-tab TabView navigation`
  - _Requirements: AC-4.1, AC-4.2, AC-4.4, AC-4.5, FR-6.1_
  - _Design: Navigation Architecture, Tab Bar_

- [x] 1.2 Move Skills/MCP/Plugins into Settings sub-sections
  - **Do**:
    1. In `SettingsView.swift`, add a "Manage" section with NavigationLinks to SkillsListView, MCPServerListView, PluginsListView
    2. Each link shows entity-colored icon (purple sparkles for Skills, orange server.rack for MCP, yellow puzzlepiece for Plugins) and count badge
    3. Remove Skills/MCP/Plugins from `SidebarItem` enum (keep enum for backward compat but mark unused cases)
    4. Update `handleURL` in AppState to route skills/mcp/plugins to settings tab
  - **Files**: `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (MODIFY), `ILSApp/ILSApp/ILSAppApp.swift` (MODIFY handleURL)
  - **Done when**: Skills, MCP, Plugins accessible via Settings > Manage section; entity-colored icons visible
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): nest Skills/MCP/Plugins under Settings manage section`
  - _Requirements: AC-4.3_
  - _Design: Settings Tab nested structure_

- [x] 1.3 Add slim connection banner replacing blocking red bar
  - **Do**:
    1. Create `ConnectionBanner.swift` in `ILSApp/ILSApp/Theme/Components/` (create Components dir)
    2. Banner: 36pt height, `.ultraThinMaterial` background, shows icon + text + dismiss button
    3. Disconnected: red-tinted, "Reconnecting..." with spinner, auto-retries
    4. Connected: green-tinted, "Connected" text, auto-dismiss after 2 seconds
    5. Animate with spring slide-down from top
    6. In ContentView (now TabView), add `.safeAreaInset(edge: .top)` with ConnectionBanner, removing old red HStack banner
    7. Pass `appState.isConnected` binding to banner
  - **Files**: `ILSApp/ILSApp/Theme/Components/ConnectionBanner.swift` (NEW), `ILSApp/ILSApp/ContentView.swift` (MODIFY)
  - **Done when**: Slim banner slides down when disconnected, auto-dismisses on reconnect; content not pushed down
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add slim connection banner replacing blocking red bar`
  - _Requirements: FR-6.2_
  - _Design: Connection Banner (Slim)_

- [ ] 1.4 Create placeholder SystemMonitorView for System tab
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/System/` directory
    2. Create `SystemMonitorView.swift` with basic placeholder: "System Monitor" title, "Coming soon" text, teal entity color accent
    3. Wire into TabView System tab in ContentView
  - **Files**: `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` (NEW), `ILSApp/ILSApp/ContentView.swift` (MODIFY)
  - **Done when**: System tab shows placeholder view; all 5 tabs navigate correctly
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add placeholder System tab in TabView`
  - _Requirements: AD-4_

- [ ] 1.5 [VERIFY] Phase 1 checkpoint: TabView navigation works
  - **Do**:
    1. Build iOS app
    2. Boot simulator: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14`
    3. Install and launch app
    4. Capture screenshots of all 5 tabs using `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot`
    5. Verify tab bar visible at bottom with 5 icons
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: iOS build succeeds; tab bar with 5 tabs renders correctly
  - **Commit**: `feat(ios): complete navigation overhaul POC` (only if fixes needed)

---

## Phase 2: Feature Parity Fixes

Focus: Fix 8 broken features identified in audit. No new features, just making existing ones work correctly.

- [x] 2.1 Fix CreateSessionRequest to send advanced options
  - **Do**:
    1. In `NewSessionView.swift`, find `createSession()` method (~line 199)
    2. The `CreateSessionRequest` init already accepts systemPrompt, maxBudget, etc. in `Sources/ILSShared/DTOs/Requests.swift`
    3. Update the `CreateSessionRequest(...)` call to pass: `systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt`, `maxBudgetUSD: Double(maxBudget)`, `maxTurns: Int(maxTurns)`, `allowedTools: nil`, `disallowedTools: nil`, `permissions: nil`
    4. Also check `SessionsViewModel.swift` line ~107 for similar `CreateSessionRequest` construction and fix there too
  - **Files**: `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift` (MODIFY), `ILSApp/ILSApp/ViewModels/SessionsViewModel.swift` (MODIFY if needed)
  - **Done when**: Creating session with systemPrompt sends it to backend in request body
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(ios): send advanced options in CreateSessionRequest`
  - _Requirements: AC-8.1, AC-8.2, FR-5.1_

- [x] 2.2 Fix skill install optimistic state
  - **Do**:
    1. In `SkillsListView.swift` or `SkillsViewModel.swift`, find the install handler for GitHub skills
    2. Remove the hardcoded 2-second `Task.sleep` / `DispatchQueue.asyncAfter` delay
    3. Replace with: show spinner during `POST /skills/install` request, on HTTP 200 show "Installed" checkmark, on error revert to "Install" and show toast error
    4. Use existing `ToastModifier` for error display
  - **Files**: `ILSApp/ILSApp/Views/Skills/SkillsListView.swift` (MODIFY), `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` (MODIFY if needed)
  - **Done when**: Install button shows real spinner, reflects actual API result, no fake delay
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(ios): show real skill install status instead of optimistic delay`
  - _Requirements: AC-15.1, AC-15.2, AC-15.3, AC-15.4, FR-5.4_

- [x] 2.3 [VERIFY] Quality checkpoint after parity fixes batch 1
  - **Do**: Run iOS build to verify no compile errors from 2.1-2.2
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds
  - **Commit**: `chore(ios): pass quality checkpoint` (only if fixes needed)

- [x] 2.4 Add session rename (swipe action + backend PUT endpoint)
  - **Do**:
    1. In `Sources/ILSBackend/Controllers/SessionsController.swift`, add `PUT /sessions/:id` route that updates session name in the session JSON file
    2. In `SessionsController.boot(routes:)`, register: `sessions.put(":id", use: rename)`
    3. Request body: `{ "name": "New Name" }`
    4. In `SessionsListView.swift`, add `.swipeActions(edge: .leading)` on each session row with "Rename" button
    5. Rename action presents an alert with TextField, on confirm calls `PUT /api/v1/sessions/:id`
    6. Add `renameSession(id:name:)` method to `APIClient.swift`
    7. Refresh session list after rename
  - **Files**: `Sources/ILSBackend/Controllers/SessionsController.swift` (MODIFY), `ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` (MODIFY), `ILSApp/ILSApp/Services/APIClient.swift` (MODIFY)
  - **Done when**: Swipe left on session reveals "Rename"; renaming updates session name via API
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Commit**: `feat(sessions): add rename via swipe action and PUT endpoint`
  - _Requirements: AC-11.1, AC-11.2, FR-5.6_

- [x] 2.5 Add session export as markdown via share sheet
  - **Do**:
    1. In `SessionInfoView.swift`, add "Export" button that generates markdown from session messages
    2. Markdown format: `# Session: {name}\n\nModel: {model}\nCreated: {date}\n\n---\n\n` + each message as `## User\n{text}\n\n## Assistant\n{text}\n\n`
    3. Present `ShareLink` or `UIActivityViewController` via `.sheet` with the markdown string as a `.txt` file
    4. Include session name, model, timestamps, all messages in export
  - **Files**: `ILSApp/ILSApp/Views/Sessions/SessionInfoView.swift` (MODIFY)
  - **Done when**: Session info "Export" button generates markdown and presents iOS share sheet
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(sessions): add markdown export via share sheet`
  - _Requirements: AC-11.3, AC-11.4, AC-11.5, FR-5.7_

- [x] 2.6 Dynamic marketplace categories from API data
  - **Do**:
    1. In `PluginsViewModel.swift` or `MarketplaceView` (inside PluginsListView), find the hardcoded categories array `["All", "Productivity", "DevOps", "Testing", "Documentation"]`
    2. Replace with dynamic extraction: after fetching marketplace data from `GET /plugins/marketplace`, extract unique `category` values from response
    3. Prepend "All" to the dynamic list
    4. Use this computed category list for the filter UI
  - **Files**: `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` (MODIFY), `ILSApp/ILSApp/ViewModels/PluginsViewModel.swift` (MODIFY if needed)
  - **Done when**: Categories reflect actual marketplace data, not hardcoded strings
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `fix(plugins): derive marketplace categories from API data`
  - _Requirements: AC-16.1, AC-16.2, AC-16.3, FR-5.8_

- [x] 2.7 Dynamic command palette with real Claude CLI commands
  - **Do**:
    1. In `CommandPaletteView.swift`, replace hardcoded command array with real Claude CLI slash commands
    2. Define command list: `/compact`, `/clear`, `/config`, `/cost`, `/doctor`, `/help`, `/init`, `/login`, `/logout`, `/mcp`, `/memory`, `/model`, `/permissions`, `/review`, `/status`, `/terminal-setup`
    3. Each command gets a description string and SF Symbol icon
    4. Keep existing search/filter and insert-on-tap behavior
  - **Files**: `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift` (MODIFY)
  - **Done when**: Command palette shows real CLI commands with descriptions; search filters work
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): populate command palette with real Claude CLI commands`
  - _Requirements: AC-13.1, AC-13.2, AC-13.3, AC-13.4, FR-5.5_

- [ ] 2.8 [VERIFY] Phase 2 checkpoint: all parity fixes build
  - **Do**:
    1. Run backend build
    2. Run iOS build
    3. Verify no compile errors from all Phase 2 changes
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Done when**: Both builds succeed
  - **Commit**: `chore(ios): pass phase 2 feature parity checkpoint` (only if fixes needed)

---

## Phase 3: System Monitoring Backend

Focus: Create 3 new API endpoints + 1 WebSocket for system metrics. macOS-first, Linux `/proc` fallback.

- [ ] 3.1 Create SystemMetricsService.swift — CPU, memory, disk, network
  - **Do**:
    1. Create `Sources/ILSBackend/Services/SystemMetricsService.swift`
    2. Actor that collects: CPU % via `host_processor_info()`, memory via `host_statistics64()`, disk via `FileManager.attributesOfFileSystem(forPath:)`, network via parsing `netstat -ib` output
    3. Define `SystemMetrics` struct: `cpu: Double, memory: MemoryMetrics, disk: DiskMetrics, network: NetworkMetrics, loadAverage: [Double]`
    4. `MemoryMetrics`: `used: UInt64, total: UInt64, percentage: Double`
    5. `DiskMetrics`: `used: UInt64, total: UInt64, percentage: Double`
    6. `NetworkMetrics`: `bytesIn: UInt64, bytesOut: UInt64`
    7. Add `getMetrics() async -> SystemMetrics` method
    8. Add `getProcesses() async -> [ProcessInfo]` method using `Process` to run `ps aux` and parse output (name, pid, cpu%, memMB)
    9. Add `listDirectory(path:)` method returning `[FileEntry]` with name, isDirectory, size, modified date
    10. Restrict file browsing to user home directory — reject paths not starting with `~` or `$HOME`
  - **Files**: `Sources/ILSBackend/Services/SystemMetricsService.swift` (NEW)
  - **Done when**: `swift build` succeeds; service can collect real metrics
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add SystemMetricsService for CPU/memory/disk/network/processes`
  - _Requirements: FR-3.1, FR-3.5, FR-3.6_
  - _Design: System Monitoring_

- [ ] 3.2 Create SystemController.swift with REST endpoints
  - **Do**:
    1. Create `Sources/ILSBackend/Controllers/SystemController.swift`
    2. Implement `RouteCollection` with `boot(routes:)`
    3. `GET /system/metrics` — returns `SystemMetrics` JSON
    4. `GET /system/processes` — returns `[ProcessInfo]` JSON, supports `?sort=cpu|memory` query param
    5. `GET /system/files?path=` — returns `[FileEntry]` JSON, validates path within home dir (403 if outside)
    6. Register in `routes.swift`: `try api.register(collection: SystemController())`
  - **Files**: `Sources/ILSBackend/Controllers/SystemController.swift` (NEW), `Sources/ILSBackend/App/routes.swift` (MODIFY)
  - **Done when**: `curl http://localhost:9090/api/v1/system/metrics` returns JSON with cpu/memory/disk/network
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add system metrics, processes, and files REST endpoints`
  - _Requirements: FR-3.1, FR-3.3, FR-3.4_

- [ ] 3.3 Add WebSocket endpoint for live metrics streaming
  - **Do**:
    1. In `SystemController.swift`, add WebSocket route: `WS /system/metrics/live`
    2. On connection, start a timer (2-second interval) that calls `SystemMetricsService.getMetrics()` and sends JSON to client
    3. On disconnect, cancel timer
    4. Use Vapor's `req.webSocket` handler pattern
    5. JSON format: `{ "timestamp": ISO8601, "cpu": 45.2, "memory": {...}, "disk": {...}, "network": {...} }`
  - **Files**: `Sources/ILSBackend/Controllers/SystemController.swift` (MODIFY)
  - **Done when**: WebSocket client receives metrics JSON every 2 seconds
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add WebSocket endpoint for live system metrics streaming`
  - _Requirements: FR-3.2, AC-5.3_

- [ ] 3.4 [VERIFY] Quality checkpoint: backend builds and endpoints respond
  - **Do**:
    1. Build backend: `swift build`
    2. Start backend: `PORT=9090 swift run ILSBackend &`
    3. Test endpoints: `curl http://localhost:9090/api/v1/system/metrics | python3 -m json.tool`
    4. Test processes: `curl http://localhost:9090/api/v1/system/processes | python3 -m json.tool`
    5. Test files: `curl 'http://localhost:9090/api/v1/system/files?path=~' | python3 -m json.tool`
    6. Test path restriction: `curl 'http://localhost:9090/api/v1/system/files?path=/etc' -w '%{http_code}'` should return 403
    7. Kill backend after testing
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3`
  - **Done when**: All 3 REST endpoints return valid JSON; path restriction works
  - **Commit**: `chore(backend): pass system monitoring checkpoint` (only if fixes needed)

- [ ] 3.5 Add shared DTOs for system metrics
  - **Do**:
    1. In `Sources/ILSShared/DTOs/`, create or update a file with Codable structs matching the backend response:
    2. `SystemMetricsResponse`: cpu, memory (used/total/percentage), disk (used/total/percentage), network (bytesIn/bytesOut), loadAverage
    3. `ProcessInfoResponse`: name, pid, cpuPercent, memoryMB
    4. `FileEntryResponse`: name, isDirectory, size, modifiedDate
    5. These will be used by both backend (Content conformance) and iOS (Decodable)
  - **Files**: `Sources/ILSShared/DTOs/SystemDTOs.swift` (NEW)
  - **Done when**: Shared DTOs compile in both backend and iOS targets
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Commit**: `feat(shared): add system metrics DTOs for backend and iOS`
  - _Requirements: FR-3.1, FR-4.1_

---

## Phase 4: System Monitoring iOS

Focus: Build System tab UI with live charts, process list, file browser. Depends on Phase 3 backend.

- [ ] 4.1 Create MetricsWebSocketClient.swift for live data
  - **Do**:
    1. Create `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift`
    2. Uses `URLSessionWebSocketTask` to connect to `WS /api/v1/system/metrics/live`
    3. Publishes `@Published var latestMetrics: SystemMetricsResponse?`
    4. Maintains sliding window array of last 60 data points for charts
    5. Auto-reconnect with exponential backoff (1s, 2s, 4s, max 30s)
    6. Connect on `connect()`, disconnect on `disconnect()`
    7. Fallback: if WS fails 3 times, switch to polling `GET /system/metrics` every 5 seconds
  - **Files**: `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` (NEW)
  - **Done when**: Client connects to WS, publishes metrics, handles reconnection
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add MetricsWebSocketClient with reconnection and fallback`
  - _Requirements: AC-5.3, AC-5.4, FR-4.4_

- [ ] 4.2 Create SystemMetricsViewModel and MetricChart components
  - **Do**:
    1. Create `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` — owns MetricsWebSocketClient, exposes chart data arrays, process list
    2. Create `ILSApp/ILSApp/Theme/Components/MetricChart.swift` — Swift Charts AreaMark + LineMark with teal gradient per design.md
    3. Create `ILSApp/ILSApp/Theme/Components/ProgressRing.swift` — circular progress with gradient stroke per design.md
    4. MetricChart: title, data points, color, unit; renders area chart with gradient fill
    5. ProgressRing: progress 0-1, gradient, lineWidth; renders circular arc
    6. Data model: `MetricDataPoint` with timestamp + value
  - **Files**: `ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift` (NEW), `ILSApp/ILSApp/Theme/Components/MetricChart.swift` (NEW), `ILSApp/ILSApp/Theme/Components/ProgressRing.swift` (NEW)
  - **Done when**: ViewModel manages WS client; chart components render with Swift Charts
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add SystemMetricsViewModel and chart components`
  - _Requirements: AC-5.1, AC-5.2, AC-5.6, FR-4.1_
  - _Design: MetricChart, ProgressRing components_

- [ ] 4.3 Build SystemMonitorView with metric cards and charts
  - **Do**:
    1. Replace placeholder in `SystemMonitorView.swift` with full implementation
    2. Top section: CPU chart (full-width AreaMark, teal), current % label
    3. Middle: 2-column grid with Memory and Disk ProgressRings showing used/total
    4. Network: dual-line chart (upload teal, download blue) with bytes/s labels
    5. Load average shown as supplementary text below CPU
    6. "Live" indicator pulsing dot in nav bar when WS connected
    7. Connect WS on `.onAppear`, disconnect on `.onDisappear`
  - **Files**: `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` (MODIFY)
  - **Done when**: System tab shows 4 metric cards with real data charts updating every 2 seconds
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): implement System tab with live metric charts`
  - _Requirements: AC-5.1, AC-5.2, AC-5.5, AC-5.6, FR-4.1_
  - _Design: System Monitoring screen_

- [ ] 4.4 Create ProcessListView with search and sort
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/System/ProcessListView.swift`
    2. List of processes from `GET /system/processes` showing name, PID, CPU %, memory MB
    3. Search bar to filter by process name
    4. Sort toggle: CPU (default) or Memory — togglable via segmented picker or button
    5. Pull-to-refresh to reload
    6. Embed below charts in SystemMonitorView as a section
  - **Files**: `ILSApp/ILSApp/Views/System/ProcessListView.swift` (NEW), `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` (MODIFY)
  - **Done when**: Process list shows real processes, search filters, sort toggles work
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add process list with search and sort to System tab`
  - _Requirements: AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5, FR-4.2_

- [ ] 4.5 Create FileBrowserView with breadcrumb navigation
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/System/FileBrowserView.swift`
    2. Starts at `~/` with breadcrumb showing current path components as tappable links
    3. Lists directories (folder icon) and files (doc icon) from `GET /system/files?path=`
    4. Tap directory to navigate in (push new path)
    5. Tap file to show read-only preview (text files only, first 500 lines) in a sheet
    6. Read-only — no create/edit/delete actions
    7. Add as NavigationLink section in SystemMonitorView or as a sub-view
  - **Files**: `ILSApp/ILSApp/Views/System/FileBrowserView.swift` (NEW), `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` (MODIFY)
  - **Done when**: File browser shows home directory, navigates into dirs, shows file preview
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add file browser with breadcrumb navigation to System tab`
  - _Requirements: AC-7.1, AC-7.2, AC-7.3, AC-7.4, AC-7.5, AC-7.6, FR-4.3_

- [ ] 4.6 [VERIFY] Phase 4 checkpoint: system monitoring builds
  - **Do**:
    1. Build both backend and iOS
    2. Verify all System tab views compile
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Done when**: Both builds succeed
  - **Commit**: `chore(ios): pass system monitoring checkpoint` (only if fixes needed)

---

## Phase 5: Cloudflare Tunnel

Focus: Backend tunnel service + iOS settings UI. Quick tunnel first, named tunnel as optional.

- [ ] 5.1 Create TunnelService.swift — spawn cloudflared, parse URL
  - **Do**:
    1. Create `Sources/ILSBackend/Services/TunnelService.swift`
    2. Actor that manages a `Process` running `cloudflared tunnel --url http://localhost:{port}`
    3. Parse stdout for line containing `trycloudflare.com` using regex
    4. Store parsed URL, process reference, start time
    5. `start()` — spawn process, parse URL (timeout 15s), return URL
    6. `stop()` — terminate process, clear state
    7. `status()` — return `TunnelStatus(running: Bool, url: String?, uptime: Int?)`
    8. Check if `cloudflared` binary exists via `which cloudflared`
    9. Handle process termination (unexpected exit → clear state)
    10. Add SIGTERM handler to kill cloudflared on backend shutdown
  - **Files**: `Sources/ILSBackend/Services/TunnelService.swift` (NEW)
  - **Done when**: Service can start/stop cloudflared and parse tunnel URL
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add TunnelService for Cloudflare quick tunnel management`
  - _Requirements: FR-1.1, FR-1.2, FR-1.3, FR-1.4, AC-1.2, AC-1.3_

- [ ] 5.2 Create TunnelController.swift with REST endpoints
  - **Do**:
    1. Create `Sources/ILSBackend/Controllers/TunnelController.swift`
    2. `POST /tunnel/start` — calls TunnelService.start(), returns `{url: "https://..."}`
    3. `POST /tunnel/stop` — calls TunnelService.stop(), returns `{stopped: true}`
    4. `GET /tunnel/status` — returns `{running: bool, url: string?, uptime: int?}`
    5. If cloudflared not found, return 404 with `{error: "cloudflared not installed", installUrl: "https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"}`
    6. Register in `routes.swift`
  - **Files**: `Sources/ILSBackend/Controllers/TunnelController.swift` (NEW), `Sources/ILSBackend/App/routes.swift` (MODIFY)
  - **Done when**: cURL to start/stop/status endpoints works correctly
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -5`
  - **Commit**: `feat(backend): add tunnel start/stop/status REST endpoints`
  - _Requirements: FR-1.1, FR-1.2, FR-1.3_

- [ ] 5.3 Add shared DTOs for tunnel
  - **Do**:
    1. In `Sources/ILSShared/DTOs/`, create `TunnelDTOs.swift`
    2. `TunnelStartResponse`: url String
    3. `TunnelStopResponse`: stopped Bool
    4. `TunnelStatusResponse`: running Bool, url String?, uptime Int?
    5. `TunnelStartRequest`: optional token String?, tunnelName String?, domain String? (for named tunnel)
  - **Files**: `Sources/ILSShared/DTOs/TunnelDTOs.swift` (NEW)
  - **Done when**: DTOs compile in both targets
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Commit**: `feat(shared): add tunnel DTOs`

- [ ] 5.4 Create TunnelSettingsView.swift in iOS
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
    2. "Quick Tunnel" section: toggle switch calls POST /tunnel/start or /tunnel/stop
    3. When running: show URL in copyable text field, "Copy URL" button, QR code (CoreImage CIQRCodeGenerator), uptime, status dot
    4. "Custom Domain" section (collapsed by default via DisclosureGroup): fields for Cloudflare API token, tunnel name, domain
    5. "How it Works" info section with brief explanation
    6. If cloudflared not installed: show message + link to install docs
    7. Add `APIClient` methods for tunnel start/stop/status
    8. Wire into SettingsView under "Remote Access" section as NavigationLink
  - **Files**: `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` (NEW), `ILSApp/ILSApp/Services/APIClient.swift` (MODIFY), `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (MODIFY)
  - **Done when**: Settings > Remote Access > shows tunnel toggle, URL display, QR code, copy button
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add Cloudflare tunnel settings UI with QR code`
  - _Requirements: AC-1.1, AC-1.4, AC-1.5, AC-1.6, AC-1.7, AC-2.1, AC-2.2_
  - _Design: Cloudflare Tunnel screen_

- [ ] 5.5 [VERIFY] Phase 5 checkpoint: tunnel builds end-to-end
  - **Do**:
    1. Build both backend and iOS
    2. Verify TunnelService, TunnelController, TunnelSettingsView all compile
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Done when**: Both builds succeed
  - **Commit**: `feat(tunnel): complete Cloudflare tunnel POC` (only if fixes needed)

---

## Phase 6: Chat Rendering Upgrade

Focus: Markdown, code blocks, tool call accordions, thinking sections, styled bubbles.

- [ ] 6.1 Add swift-markdown-ui dependency to iOS project
  - **Do**:
    1. In `ILSApp/ILSApp.xcodeproj`, add Swift Package dependency: `https://github.com/gonzalezreal/swift-markdown-ui` (version 2.0+)
    2. Or if using Package.swift for iOS: add package there
    3. Since the iOS app uses Xcode project (not SPM), add via Xcode SPM integration
    4. Create a note in the task about adding via `File > Add Package Dependencies` in Xcode project, OR modify the `.xcodeproj` package references programmatically
    5. Alternative: If adding the dependency is complex, implement a basic markdown parser using `AttributedString` with regex for bold/italic/code/lists/headings — avoid the dependency
  - **Files**: `ILSApp/ILSApp.xcodeproj/project.pbxproj` (MODIFY — add package dependency)
  - **Done when**: `import MarkdownUI` compiles in iOS app OR basic AttributedString markdown renderer works
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add markdown rendering capability for chat messages`
  - _Requirements: AC-12.1, FR-7.1_

- [ ] 6.2 Create CodeBlockView.swift with syntax highlighting
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift`
    2. Language header bar (dark bg, language label left, "Copy" button right)
    3. Code content in monospaced font with horizontal scroll
    4. Background: `#0F172A`, header: `#1E293B`
    5. Border: 1px white at 8% opacity, corner radius 10
    6. Copy button copies code to clipboard with haptic feedback
    7. Basic syntax coloring: keywords, strings, comments in different shades (regex-based, not full parser)
  - **Files**: `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (NEW)
  - **Done when**: Code blocks render with language label, monospaced font, copy button, basic coloring
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): add CodeBlockView with syntax highlighting and copy`
  - _Requirements: AC-12.2, FR-7.2_
  - _Design: Code Block Rendering_

- [ ] 6.3 Create ToolCallAccordion.swift and ThinkingSection.swift
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` — expandable disclosure with tool name + icon; expanded shows input JSON preview + output text
    2. Create `ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` — collapsible "Thinking..." section with brain icon; expanded shows thinking text
    3. Both use `DisclosureGroup` with custom styling (dark bg, subtle border)
    4. Tool accordion: chevron rotates on expand, shows tool name as header, input/output as body
    5. Thinking: pulsing animation when active, static when complete
  - **Files**: `ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` (NEW), `ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` (NEW)
  - **Done when**: Both components render with expand/collapse behavior
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): add tool call accordion and thinking section components`
  - _Requirements: AC-12.3, AC-12.4, AC-12.5, FR-7.3, FR-7.4_

- [ ] 6.4 Integrate markdown + code blocks + accordions into MessageView
  - **Do**:
    1. In `MessageView.swift`, replace plain Text rendering with markdown-aware rendering
    2. Parse message content: split into blocks (text, code fence, tool call, thinking)
    3. Text blocks: render with markdown (MarkdownUI or AttributedString)
    4. Code fences (``` delimited): render with `CodeBlockView`
    5. Tool calls: render with `ToolCallAccordion`
    6. Thinking blocks: render with `ThinkingSection`
    7. Keep existing message structure (user vs assistant identification)
  - **Files**: `ILSApp/ILSApp/Views/Chat/MessageView.swift` (MODIFY)
  - **Done when**: Assistant messages render markdown, code blocks highlighted, tool calls expandable
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): integrate markdown, code blocks, and accordions into MessageView`
  - _Requirements: AC-12.1, AC-12.2, AC-12.3, AC-12.4, AC-12.5_

- [ ] 6.5 Restyle chat bubbles — user gradient, assistant glass
  - **Do**:
    1. In `ChatView.swift` or `MessageView.swift`, update bubble backgrounds:
    2. User messages: right-aligned, blue gradient (`#007AFF` to `#0056B3`), 16pt corner radius with 4pt on bottom-right
    3. Assistant messages: left-aligned, `.thinMaterial` + `#111827` bg, white border at 6% opacity, 16pt radius with 4pt on bottom-left
    4. Update send button to blue (#007AFF)
    5. Ensure proper padding and spacing between messages
  - **Files**: `ILSApp/ILSApp/Views/Chat/ChatView.swift` (MODIFY), `ILSApp/ILSApp/Views/Chat/MessageView.swift` (MODIFY)
  - **Done when**: User bubbles are blue gradient right-aligned; assistant bubbles are glass left-aligned
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): restyle bubbles with gradient user and glass assistant`
  - _Requirements: AC-12.6, FR-7.5_
  - _Design: Chat Bubble Styling_

- [ ] 6.6 [VERIFY] Phase 6 checkpoint: chat rendering builds
  - **Do**: Build iOS app, verify all chat components compile
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds
  - **Commit**: `feat(chat): complete chat rendering upgrade` (only if fixes needed)

---

## Phase 7: Onboarding Enhancement

Focus: Multi-mode ServerSetupSheet with connection history and progress indicator.

- [ ] 7.1 Add Local/Remote/Tunnel tab modes to ServerSetupSheet
  - **Do**:
    1. In `ServerSetupSheet.swift`, add segmented picker at top: "Local" | "Remote" | "Tunnel"
    2. Local tab: prefilled `http://localhost:9090`, single Connect button
    3. Remote tab: hostname/IP text field + port field, constructs URL
    4. Tunnel tab: paste Cloudflare URL field (validates `trycloudflare.com` or custom domain)
    5. All tabs use same `connectToServer(url:)` method on AppState
    6. Add ILS branding header (icon + "Welcome to ILS" + subtitle)
  - **Files**: `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` (MODIFY)
  - **Done when**: Three tab modes visible, each provides appropriate input, all connect successfully
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(onboarding): add Local/Remote/Tunnel connection modes`
  - _Requirements: AC-3.1, FR-2.1_
  - _Design: Enhanced Onboarding screen_

- [ ] 7.2 Add multi-step connection progress indicator
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/ConnectionSteps.swift`
    2. Shows 3 steps: "DNS Resolve", "TCP Connect", "Health Check" — each with checkmark/spinner/x
    3. In ServerSetupSheet, when Connect tapped: show steps progress
    4. Step 1: DNS resolve via URL host validation
    5. Step 2: TCP connect attempt
    6. Step 3: Health check response
    7. On success: all 3 checkmarks, then show backend info
    8. On failure: X on failed step with error message
  - **Files**: `ILSApp/ILSApp/Theme/Components/ConnectionSteps.swift` (NEW), `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` (MODIFY)
  - **Done when**: Connection progress shows visual step-by-step feedback
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(onboarding): add multi-step connection progress indicator`
  - _Requirements: AC-3.2, FR-2.2_

- [ ] 7.3 Add connection history and backend info display
  - **Do**:
    1. Store last 5 successful URLs in `UserDefaults` array key `"connectionHistory"`
    2. In ServerSetupSheet, below input: show "Recent" section with tappable history URLs
    3. Tapping a recent URL fills the input field
    4. After successful connection: show backend info (Claude CLI version, project count, skill count) from health check + stats response
    5. Auto-dismiss sheet after 1.5s delay showing "Connected" state
  - **Files**: `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` (MODIFY), `ILSApp/ILSApp/ILSAppApp.swift` (MODIFY — add history to connectToServer)
  - **Done when**: Connection history persists and shows recent URLs; backend info displays after connection
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(onboarding): add connection history and backend info display`
  - _Requirements: AC-3.3, AC-3.4, AC-3.5, FR-2.3, FR-2.4_

- [ ] 7.4 [VERIFY] Phase 7 checkpoint: onboarding builds
  - **Do**: Build iOS app
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds
  - **Commit**: `feat(onboarding): complete enhanced onboarding` (only if fixes needed)

---

## Phase 8: UI/UX Redesign

Focus: Apply entity colors, redesign cards, add empty states, skeleton loading, glass effects. This touches many views.

- [ ] 8.1 Create StatCard and SparklineChart components
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/StatCard.swift` per design.md: title, count, entity type, sparkline data
    2. Card has ProgressRing with entity gradient, count in entity color, title, SparklineChart below
    3. Background: `#111827`, border stroke in entity color at 15% opacity, shadow in entity color at 10%
    4. Create `ILSApp/ILSApp/Theme/Components/SparklineChart.swift` — minimal Swift Charts LineMark, entity-colored, 24pt height
  - **Files**: `ILSApp/ILSApp/Theme/Components/StatCard.swift` (NEW), `ILSApp/ILSApp/Theme/Components/SparklineChart.swift` (NEW)
  - **Done when**: StatCard renders with progress ring, count, sparkline in entity color
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ui): add StatCard and SparklineChart design components`
  - _Requirements: AC-19.2, FR-8.2_
  - _Design: StatCard Component_

- [ ] 8.2 Redesign DashboardView with stat cards, quick actions, system health
  - **Do**:
    1. Replace current DashboardView stat section with 2x2 grid of StatCards (Sessions, Projects, Skills, MCP) using entity colors
    2. Add "Quick Actions" section: "New Session" button, cost total card
    3. Add "Recent Sessions" section with blue entity-colored dots per design
    4. Add "System Health" strip at bottom: compact CPU/Memory bars
    5. Greeting header: "Good evening, Nick" (or time-based) + connection dot
    6. Use new bg-2 (#111827) for card backgrounds
  - **Files**: `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` (MODIFY)
  - **Done when**: Dashboard shows redesigned stat cards, quick actions, recent sessions, system health strip
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(dashboard): redesign with entity-colored stat cards and quick actions`
  - _Requirements: AC-19.2, AC-14.1, FR-8.2_
  - _Design: Dashboard screen_

- [ ] 8.3 Redesign list rows with entity colors
  - **Do**:
    1. SessionsListView rows: blue status dot (filled=active, hollow=inactive), blue accent, swipe rename
    2. ProjectsListView rows: green folder icon accent
    3. SkillsListView rows: purple sparkles icon accent
    4. MCPServerListView rows: orange server.rack icon accent
    5. PluginsListView rows: yellow puzzlepiece icon accent
    6. Each row uses bg-2 background, entity-colored left accent/icon, proper typography hierarchy
  - **Files**: `ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` (MODIFY), `ILSApp/ILSApp/Views/Projects/ProjectsListView.swift` (MODIFY), `ILSApp/ILSApp/Views/Skills/SkillsListView.swift` (MODIFY), `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift` (MODIFY), `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` (MODIFY)
  - **Done when**: Each entity type has distinct color accent in list rows
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ui): apply entity colors to all list rows`
  - _Requirements: AC-19.1, FR-8.1_

- [ ] 8.4 [VERIFY] Quality checkpoint after redesign batch 1
  - **Do**: Build iOS app after stat cards + dashboard + list rows changes
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds
  - **Commit**: `chore(ui): pass redesign batch 1 checkpoint` (only if fixes needed)

- [ ] 8.5 Create custom empty states for each entity type
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/EmptyEntityState.swift`
    2. Takes `EntityType`, title, description, optional action button
    3. Large entity-colored SF Symbol icon, descriptive text, entity-colored action button
    4. Replace all `EmptyStateView` and `ContentUnavailableView` usages across: SessionsListView, ProjectsListView, SkillsListView, MCPServerListView, PluginsListView, SystemMonitorView
    5. Each entity type gets unique copy: "No sessions yet / Start a conversation with Claude", "No projects / Connect to a backend with projects", etc.
  - **Files**: `ILSApp/ILSApp/Theme/Components/EmptyEntityState.swift` (NEW), multiple list views (MODIFY)
  - **Done when**: All 6 entity types have custom empty states with entity-colored icons
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ui): add custom entity-typed empty states`
  - _Requirements: AC-19.4, FR-8.3_
  - _Design: Empty States_

- [ ] 8.6 Add skeleton loading with shimmer across all list views
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/SkeletonRow.swift` — placeholder row with rounded rectangles
    2. Create `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` — left-to-right gradient sweep at 1.5s, repeating
    3. Replace all `ProgressView("Loading...")` with skeleton rows + shimmer in: SessionsListView, ProjectsListView, SkillsListView, MCPServerListView, PluginsListView, DashboardView
    4. Show 5 skeleton rows during loading state
    5. Skeleton disappears once data arrives (no flash of empty state)
  - **Files**: `ILSApp/ILSApp/Theme/Components/SkeletonRow.swift` (NEW), `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` (NEW), multiple list views (MODIFY)
  - **Done when**: All lists show consistent skeleton + shimmer during loading
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ui): add skeleton loading with shimmer animation`
  - _Requirements: AC-18.1, AC-18.2, AC-18.3, FR-6.4_
  - _Design: Skeleton Loading_

- [ ] 8.7 Add aggregate cost tracking to Dashboard
  - **Do**:
    1. In `DashboardViewModel.swift`, add method to compute total cost across all sessions (sum of `session.cost`)
    2. Display as a card in Quick Actions section: "Total Cost: $X.XX"
    3. Data from `GET /api/v1/stats` (if aggregate cost available) or computed client-side from sessions
    4. Format as USD with 2 decimal places
  - **Files**: `ILSApp/ILSApp/ViewModels/DashboardViewModel.swift` (MODIFY), `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` (MODIFY)
  - **Done when**: Dashboard shows total cost across sessions
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(dashboard): add aggregate cost tracking card`
  - _Requirements: AC-14.1, AC-14.4, FR-5.9_

- [ ] 8.8 Apply frosted glass and pull-to-refresh feedback
  - **Do**:
    1. Apply `.ultraThinMaterial` to all sheets (ServerSetupSheet, CommandPaletteView, SessionInfoView) presentationBackground
    2. Apply to overlays and tab bar (already done in Phase 1)
    3. Add haptic feedback (`.notification(.success)`) on pull-to-refresh completion in all list views
    4. Add "Updated just now" timestamp text below list content after refresh
    5. Update `CardStyle` modifier to use `bg2` (#111827) + border stroke + entity shadow
  - **Files**: Multiple sheet views (MODIFY), `ILSApp/ILSApp/Theme/ILSTheme.swift` (MODIFY CardStyle)
  - **Done when**: Sheets use frosted glass; pull-to-refresh has haptic + timestamp; cards use new style
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ui): apply frosted glass materials and pull-to-refresh haptic feedback`
  - _Requirements: AC-19.5, AC-19.6, AC-19.8, FR-6.3, FR-8.4_

- [ ] 8.9 Standardize error handling — toast on all failures
  - **Do**:
    1. Audit all `catch` blocks in ViewModels that use `print()` — replace with toast or `ErrorStateView`
    2. Ensure all user-initiated actions (create, delete, install, toggle, rename, export) show toast on failure
    3. Use `ToastModifier` with error variant (red-tinted background)
    4. Add `.error`, `.success`, `.warning` toast variants to `ToastModifier`
    5. Add retry logic (3 attempts, exponential backoff) in `APIClient` for transient network errors
    6. Replace all `print("Error:...")` with `AppLogger.error(...)` in ViewModels
  - **Files**: `ILSApp/ILSApp/Theme/ILSTheme.swift` (MODIFY ToastModifier), `ILSApp/ILSApp/Services/APIClient.swift` (MODIFY), multiple ViewModels (MODIFY)
  - **Done when**: No silent `print()` failures; all errors show user-facing toast; network retries work
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ux): standardize error handling with toast notifications and retry`
  - _Requirements: AC-17.1, AC-17.2, AC-17.3, AC-17.4, AC-17.5_

---

## Phase 9: Dead Code Cleanup & Accessibility

Focus: Remove unused code, apply consistent styling, basic accessibility pass.

- [ ] 9.1 Remove unused services and deprecated theme aliases
  - **Do**:
    1. Audit `CacheManager.swift` — if no real caching logic, remove file
    2. Audit `ConfigurationManager.swift` — if just reading backend config, keep; if unused, remove
    3. Audit `KeychainService.swift` — if not used by any view/viewmodel, remove
    4. Remove deprecated corner radius aliases from ILSTheme (`cornerRadiusS`, `cornerRadiusM`, `cornerRadiusL`, `cornerRadiusXL`)
    5. Update any views still using old aliases to use new tokens
    6. Remove `SidebarView.swift` if no longer referenced after TabView migration
    7. Remove old `ServerConnectionViewModel.swift` if functionality moved to AppState
  - **Files**: `ILSApp/ILSApp/Services/CacheManager.swift` (DELETE?), `ILSApp/ILSApp/Services/ConfigurationManager.swift` (DELETE?), `ILSApp/ILSApp/Services/KeychainService.swift` (DELETE?), `ILSApp/ILSApp/Theme/ILSTheme.swift` (MODIFY), `ILSApp/ILSApp/Views/Sidebar/SidebarView.swift` (DELETE?)
  - **Done when**: No dead services, no deprecated aliases, clean build
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `chore(cleanup): remove unused services and deprecated theme aliases`
  - _Requirements: AC-20.2, AC-20.3, FR-8.6_

- [ ] 9.2 Audit entity color consistency across all views
  - **Do**:
    1. Grep for `ILSTheme.accent` usage — replace with entity-specific colors where appropriate
    2. Sessions views: use `EntityType.sessions` color
    3. Projects views: use `EntityType.projects` color
    4. Skills views: use `EntityType.skills` color
    5. MCP views: use `EntityType.mcp` color
    6. Plugins views: use `EntityType.plugins` color
    7. System views: use `EntityType.system` color
    8. Keep `ILSTheme.accent` only for truly generic/app-level accents
  - **Files**: Multiple view files (MODIFY)
  - **Done when**: Each entity section uses its designated color, not generic orange accent
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `refactor(ui): apply consistent entity colors across all views`
  - _Requirements: AC-19.1, FR-8.1_

- [ ] 9.3 Basic accessibility pass
  - **Do**:
    1. Add `accessibilityLabel` to all charts: "CPU usage is X%, trending up/down"
    2. Add `accessibilityLabel` to ProgressRing: "X percent complete"
    3. Add `accessibilityLabel` to tab bar items with descriptive labels
    4. Ensure skeleton loading announces "Loading" to VoiceOver
    5. Check `@Environment(\.accessibilityReduceMotion)` in ShimmerModifier — disable animation when true
    6. Verify all buttons have accessibility labels
  - **Files**: Multiple component and view files (MODIFY)
  - **Done when**: VoiceOver reads sensible labels; reduced motion honored for shimmer
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(a11y): add accessibility labels and reduced motion support`
  - _Requirements: NFR-9_

- [ ] 9.4 [VERIFY] Phase 9 checkpoint: clean build, no warnings
  - **Do**:
    1. Build both backend and iOS
    2. Check for compiler warnings
    3. Verify no unused imports
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -3`
  - **Done when**: Both builds succeed with minimal warnings
  - **Commit**: `chore(cleanup): pass final cleanup checkpoint` (only if fixes needed)

---

## Phase 10: Final Validation & PR

Focus: Full local CI, run all 13 validation scenarios, create PR.

- [ ] 10.1 [VERIFY] Full local CI: backend build + iOS build
  - **Do**:
    1. Clean build both targets
    2. `swift build` for backend
    3. `xcodebuild clean build` for iOS
    4. Fix any remaining compile errors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' clean build 2>&1 | tail -5`
  - **Done when**: Clean build succeeds for both targets
  - **Commit**: `chore(build): pass local CI` (only if fixes needed)

- [ ] 10.2 Functional validation: run all 13 scenarios with screenshot evidence
  - **Do**:
    1. Start backend: `PORT=9090 swift run ILSBackend`
    2. Boot simulator: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14`
    3. Install and launch app on simulator
    4. Run through VS-1 through VS-13 from requirements.md:
       - VS-1: Cloudflare tunnel lifecycle (start/stop/copy URL)
       - VS-2: First-run onboarding (3 tabs, connect, backend info)
       - VS-3: Tab bar navigation (5 tabs)
       - VS-4: System metrics live (charts update)
       - VS-5: File browser (navigate directories)
       - VS-6: Advanced session creation (systemPrompt sent)
       - VS-7: Dark/light mode toggle
       - VS-8: Chat markdown rendering
       - VS-9: Session rename & export
       - VS-10: Skill install real status
       - VS-11: System monitoring backend cURL
       - VS-12: Cost tracking
       - VS-13: Error handling consistency
    5. Capture screenshot for each step using `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot`
    6. Save to `.omc/evidence/ios-app-polish2/`
    7. For VS-11: use cURL commands, save terminal output
  - **Files**: Screenshots saved to `.omc/evidence/ios-app-polish2/` (NEW dir)
  - **Done when**: 13/13 scenarios pass with screenshot/terminal evidence
  - **Verify**: `ls -la /Users/nick/Desktop/ils-ios/.omc/evidence/ios-app-polish2/ | wc -l` (should show 20+ evidence files)
  - **Commit**: `chore(validation): capture evidence for all 13 scenarios`

- [ ] 10.3 [VERIFY] AC checklist — verify all acceptance criteria
  - **Do**:
    1. Read requirements.md
    2. For each AC-*, verify via code grep or screenshot evidence:
       - AC-1.x (tunnel): TunnelSettingsView exists, endpoints respond
       - AC-3.x (onboarding): ServerSetupSheet has 3 tabs, history, progress
       - AC-4.x (tabs): TabView with 5 tabs, glass material
       - AC-5.x (metrics): System tab with charts, WS client
       - AC-6.x (processes): ProcessListView with search/sort
       - AC-7.x (files): FileBrowserView with breadcrumbs
       - AC-8.x (session options): CreateSessionRequest sends advanced fields
       - AC-9.x (health): SettingsView uses /health
       - AC-10.x (dark mode): No hardcoded .dark, AppStorage wired
       - AC-11.x (rename/export): Swipe rename, share sheet export
       - AC-12.x (chat): Markdown, code blocks, accordions, bubbles
       - AC-13.x (commands): Real CLI commands in palette
       - AC-14.x (cost): Aggregate cost on dashboard
       - AC-15.x (skill install): Real status, no delay
       - AC-16.x (marketplace): Dynamic categories
       - AC-17.x (errors): Toast on failure, no silent print
       - AC-18.x (loading): Skeleton + shimmer
       - AC-19.x (design): Entity colors, stat cards, empty states, glass
       - AC-20.x (cleanup): No ClaudeCodeSDK, no dead services
    3. Document pass/fail for each
  - **Verify**: Grep codebase for key patterns: `grep -r "EntityType" ILSApp/ILSApp/ | wc -l` (should be >20), `grep -r "preferredColorScheme(.dark)" ILSApp/ILSApp/ILSAppApp.swift` (should return nothing), `grep -r "ClaudeCodeSDK" Package.swift` (should return nothing)
  - **Done when**: All acceptance criteria confirmed met
  - **Commit**: None

---

## Phase 11: PR Lifecycle

- [ ] 11.1 Create PR
  - **Do**:
    1. Verify on feature branch: `git branch --show-current` (should be `design/v2-redesign`)
    2. Stage all changes: `git add -A`
    3. Push: `git push -u origin design/v2-redesign`
    4. Create PR: `gh pr create --title "feat(ios): complete polish, system monitoring, tunnel, redesign" --body "..."`
    5. PR body: summary of all phases, link to evidence screenshots, AC checklist
  - **Verify**: `gh pr checks` shows CI status
  - **Done when**: PR created and pushed
  - **Commit**: None (PR creation, not a commit)

- [ ] 11.2 Monitor CI and fix failures
  - **Do**:
    1. Watch CI: `gh pr checks --watch`
    2. If failures: read logs, fix locally, push fixes
    3. Re-verify until all checks pass
  - **Verify**: `gh pr checks` shows all green
  - **Done when**: CI pipeline passes
  - **Commit**: `fix(ci): address CI failures` (if needed)

- [ ] 11.3 [VERIFY] Final AC verification
  - **Do**:
    1. Re-read requirements.md one final time
    2. Confirm all 20 user stories addressed
    3. Confirm all 13 validation scenarios have evidence
    4. Confirm all must-have functional requirements implemented
  - **Verify**: Evidence directory has files for all scenarios
  - **Done when**: All acceptance criteria confirmed met with evidence
  - **Commit**: None

---

## Notes

### POC Shortcuts (Phase 1-2)
- System tab is placeholder until Phase 4
- Markdown rendering may use basic AttributedString instead of swift-markdown-ui if dependency integration is complex
- Syntax highlighting in code blocks is regex-based, not full parser
- QR code uses CoreImage, not a third-party library

### Production TODOs (deferred)
- Named Cloudflare tunnel with persistent config (AC-2.3, AC-2.4, AC-2.5)
- Linux `/proc/*` support for system metrics (macOS-only for POC)
- Full syntax highlighting engine for code blocks
- iPad-specific layouts
- Push notifications
- Permission handling for Claude tool use (stub remains)
- WebSocket chat (SSE remains primary)
- SSH provisioning wizard (deferred per AD-3)

### Risk Areas
- Phase 6 (markdown rendering): swift-markdown-ui dependency may have integration issues with Xcode project SPM; fallback to AttributedString parser
- Phase 3 (system metrics): `host_processor_info()` requires specific Darwin imports; may need conditional compilation
- Phase 5 (tunnel): Cloudflare tunnel requires `cloudflared` binary on host; POC can only validate if binary installed
- Phase 8 (redesign): Touches many files; risk of regression. Quality checkpoints after every 2-3 tasks mitigate this.

### Effort Estimates
| Phase | Effort | Tasks |
|-------|--------|-------|
| 0 Foundation | S | 5 |
| 1 Navigation | M | 5 |
| 2 Feature Parity | M | 8 |
| 3 System Backend | M | 5 |
| 4 System iOS | L | 6 |
| 5 Tunnel | M | 5 |
| 6 Chat Rendering | L | 6 |
| 7 Onboarding | M | 4 |
| 8 UI Redesign | XL | 9 |
| 9 Cleanup | S | 4 |
| 10 Validation | M | 3 |
| 11 PR | S | 3 |
| **Total** | **XL** | **63** |
