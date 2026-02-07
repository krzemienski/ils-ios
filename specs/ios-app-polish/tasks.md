---
spec: ios-app-polish
phase: tasks
total_tasks: 20
created: 2026-02-06T18:40:00-05:00
---

# Tasks: ILS iOS App — Functional Polish (Round 2)

## Execution Context

- Testing depth: Comprehensive — all 13 scenarios with screenshot evidence
- Execution priority: Quality first — complete all 13 scenarios
- Deployment: Local-only (no remote, no CI)
- Previous round completed: Phase 1 (1.1–1.12) + Phase 2 (2.1–2.3) fully executed with 3 commits

## Already Implemented (DO NOT re-implement)

- ServerSetupSheet onboarding (created + wired)
- Deterministic project IDs (CryptoKit SHA256)
- Real plugin install via git clone
- Cancel button wired to backend
- Session creation auto-navigates to ChatView
- Dashboard recent sessions tappable (NavigationLink)
- Fork alert "Open Fork" auto-navigate
- Marketplace search client-side filtering
- Disconnected banner "Configure" for first-run
- 14 dead files deleted (SSH, Fleet, Config mocks, NewProjectView)
- Settings/Projects cleaned up
- Connection logic centralized in AppState.connectToServer()

---

## Phase 1: Remaining Implementation Gaps

- [x] 1.1 Verify external session merge is working in SessionsViewModel
  - **Do**:
    1. Read `ILSApp/ILSApp/ViewModels/SessionsViewModel.swift` — confirm `loadSessions()` calls both `GET /sessions` and `GET /sessions/scan`
    2. If `/sessions/scan` is NOT called, add it: `let external = try await apiClient.get("/sessions/scan")`, merge with DB sessions, dedupe by `claudeSessionId`
    3. If already present, mark external sessions with `isExternal = true` or use `claudeSessionId != nil` as indicator
    4. Verify `ChatView` shows read-only mode for external sessions (input bar hidden, banner shown)
  - **Files**:
    - `ILSApp/ILSApp/ViewModels/SessionsViewModel.swift` (verify or modify)
    - `ILSApp/ILSApp/Views/Chat/ChatView.swift` (verify read-only mode)
  - **Done when**: Sessions list shows both ILS and external sessions; external sessions open in read-only mode
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E "(error:|BUILD)" | tail -5`
  - **Commit**: `feat(ios): verify external session merge in sessions list` (only if code changes needed)
  - _Requirements: FR-2, AC-2.1, AC-2.2, AC-2.3_

- [x] 1.2 Verify MCP CRUD UI is fully wired
  - **Do**:
    1. Read `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift` — confirm add/edit/delete actions exist
    2. Read `ILSApp/ILSApp/Views/MCP/NewMCPServerView.swift` — confirm form sends `POST /mcp`
    3. Read `ILSApp/ILSApp/Views/MCP/EditMCPServerView.swift` — confirm `PUT /mcp/:name`
    4. Read `ILSApp/ILSApp/ViewModels/MCPViewModel.swift` — confirm `addServer`, `deleteServer`, `updateServer`
    5. Fix any gaps found
  - **Files**:
    - MCP view files (verify or modify)
  - **Done when**: MCP list shows servers; add/edit/delete all call backend endpoints
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E "(error:|BUILD)" | tail -5`
  - **Commit**: `fix(ios): wire MCP CRUD UI to backend` (only if changes needed)
  - _Requirements: FR-9, AC-7.2 through AC-7.6_

- [x] 1.3 Verify Skills detail + search + install is wired
  - **Do**:
    1. Read `ILSApp/ILSApp/Views/Skills/SkillsListView.swift` — confirm detail navigation, search UI, install button
    2. Read `ILSApp/ILSApp/ViewModels/SkillsViewModel.swift` — confirm `searchGitHub()`, `installFromGitHub()`, `deleteSkill()`
    3. Confirm `GET /skills/:name` called for detail, `GET /skills/search?q=` for search, `POST /skills/install` for install
    4. Fix any gaps
  - **Files**:
    - Skills view/VM files (verify or modify)
  - **Done when**: Skills list shows installed skills; tap opens detail; search finds GitHub skills; install works
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E "(error:|BUILD)" | tail -5`
  - **Commit**: `fix(ios): wire skills search and install to backend` (only if changes needed)
  - _Requirements: FR-10, FR-11, AC-9.1 through AC-9.7_

- [x] 1.4 [VERIFY] Build checkpoint after gap analysis
  - **Do**: Build backend + iOS, verify zero errors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E "(error:|BUILD)" | tail -5`
  - **Done when**: Both builds pass
  - **Commit**: `chore: pass build checkpoint` (only if fixes needed)

## Phase 2: Comprehensive Scenario Validation (All 13)

Each task captures screenshots to `.omc/evidence/ios-app-polish/` using:
- `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot /path/to/file.png`
- Tab switching: modify `selectedTab` in ILSAppApp.swift, incremental build, capture, revert
- idb_describe for accessibility tree, idb_tap for element interaction

---

- [x] 2.1 S-01: First Launch & Server Setup
  - **Do**:
    1. Ensure backend running on port 9090
    2. Build and install app on simulator
    3. If possible, clear UserDefaults to simulate first launch (delete + reinstall app)
    4. Launch app — capture `s01-onboarding.png` (ServerSetupSheet should appear since hasConnectedBefore=false)
    5. If backend running, connect succeeds — capture `s01-connected.png` (green indicator + dismiss)
    6. Modify selectedTab to "dashboard", rebuild, capture `s01-dashboard.png` (real stats), revert
  - **Files**: Evidence screenshots only
  - **Done when**: 3 screenshots captured showing onboarding → connection → dashboard flow
  - **Verify**: `ls .omc/evidence/ios-app-polish/s01-*.png | wc -l` shows 3
  - _Requirements: US-1, AC-1.1 through AC-1.4_

- [x] 2.2 S-02: Browse External Claude Code Sessions
  - **Do**:
    1. Ensure selectedTab is "sessions", build and launch
    2. Capture `s02-sessions-list.png` — verify merged list with external sessions
    3. Use idb_describe to find external session row, tap it
    4. Capture `s02-readonly-transcript.png` — verify read-only banner + no input bar
    5. If external sessions don't appear, check SessionsViewModel code and fix
  - **Files**: Evidence screenshots (or SessionsViewModel.swift if fix needed)
  - **Done when**: Screenshots show external sessions in list + read-only transcript view
  - **Verify**: `ls .omc/evidence/ios-app-polish/s02-*.png | wc -l` shows 2+
  - _Requirements: US-2, AC-2.1 through AC-2.5_

- [x] 2.3 S-03: Create New Session & Chat
  - **Do**:
    1. On sessions tab, use idb_describe to find "+" button, tap it
    2. Capture `s03-new-session.png` — NewSessionView with project picker
    3. Fill form via idb_type, tap Create
    4. Capture `s03-auto-navigate.png` — should be in ChatView immediately
    5. Type a message, tap send
    6. Capture `s03-streaming.png` — streaming indicator visible
    7. Capture `s03-response-complete.png` — full response, input re-enabled
  - **Files**: Evidence screenshots only
  - **Done when**: 4 screenshots showing create → auto-navigate → send → response
  - **Verify**: `ls .omc/evidence/ios-app-polish/s03-*.png | wc -l` shows 4
  - _Requirements: US-3, AC-3.1 through AC-3.7_

- [x] 2.4 S-04: Chat in Multiple Projects
  - **Do**:
    1. Create session in one project, send message, capture `s04-project-a.png`
    2. Go back, create session in different project, send message, capture `s04-project-b.png`
    3. Verify responses are independent (no cross-contamination)
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots showing isolated project chats
  - **Verify**: `ls .omc/evidence/ios-app-polish/s04-*.png | wc -l` shows 2
  - _Requirements: US-4 (implied by S-03 working with projects)_

- [x] 2.5 S-05: Resume Existing Session
  - **Do**:
    1. On sessions tab, tap an existing session with message history
    2. Capture `s05-history.png` — previous messages loaded
    3. Send follow-up message
    4. Capture `s05-resumed.png` — Claude responds with prior context
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots showing history load + contextual response
  - **Verify**: `ls .omc/evidence/ios-app-polish/s05-*.png | wc -l` shows 2
  - _Requirements: US-4, AC-4.1 through AC-4.4_

- [x] 2.6 S-06: Fork & Experiment
  - **Do**:
    1. In active session, tap menu button (use idb_describe for coordinates)
    2. Tap "Fork Session" in menu
    3. Capture `s06-fork-alert.png` — alert with "Open Fork" and "Stay Here"
    4. Tap "Open Fork"
    5. Capture `s06-forked-session.png` — new session with original history
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots showing fork alert + navigated to forked session
  - **Verify**: `ls .omc/evidence/ios-app-polish/s06-*.png | wc -l` shows 2
  - _Requirements: US-6, AC-6.1 through AC-6.5_

- [x] 2.7 S-07: MCP Server Management
  - **Do**:
    1. Modify selectedTab to "mcp", build, launch
    2. Capture `s07-mcp-list.png` — list of configured MCP servers
    3. Use idb to tap "+" button, capture `s07-mcp-add-form.png`
    4. If add form works, fill and save, capture `s07-mcp-added.png`
    5. Tap existing server for edit, capture `s07-mcp-edit.png`
    6. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 3-4 screenshots showing MCP list, add form, and edit
  - **Verify**: `ls .omc/evidence/ios-app-polish/s07-*.png | wc -l` shows 3+
  - _Requirements: US-7, AC-7.1 through AC-7.6_

- [x] 2.8 S-08: Settings Configuration
  - **Do**:
    1. Modify selectedTab to "settings", build, launch
    2. Capture `s08-settings.png` — clean layout, no SSH/Fleet/Config Management
    3. Verify model picker exists, connection section exists
    4. Capture `s08-about.png` — scroll to About section
    5. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots showing clean settings + about section
  - **Verify**: `ls .omc/evidence/ios-app-polish/s08-*.png | wc -l` shows 2
  - _Requirements: US-12, AC-12.1 through AC-12.5_

- [x] 2.9 S-09: Plugin Management
  - **Do**:
    1. Modify selectedTab to "plugins", build, launch
    2. Capture `s09-plugins-list.png` — installed plugins
    3. If marketplace tab exists, tap it, capture `s09-marketplace.png`
    4. Search in marketplace, capture `s09-search.png` — verify client-side filtering
    5. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 2-3 screenshots showing plugins list, marketplace, search
  - **Verify**: `ls .omc/evidence/ios-app-polish/s09-*.png | wc -l` shows 2+
  - _Requirements: US-8, AC-8.1 through AC-8.7_

- [x] 2.10 S-10: Skill Discovery & Install
  - **Do**:
    1. Modify selectedTab to "skills", build, launch
    2. Capture `s10-skills-list.png` — installed skills
    3. Tap a skill for detail, capture `s10-skill-detail.png`
    4. Use search for GitHub skills, capture `s10-search.png`
    5. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 2-3 screenshots showing skills list, detail, search
  - **Verify**: `ls .omc/evidence/ios-app-polish/s10-*.png | wc -l` shows 2+
  - _Requirements: US-9, AC-9.1 through AC-9.5_

- [x] 2.11 S-11: Projects & Project Sessions
  - **Do**:
    1. Modify selectedTab to "projects", build, launch
    2. Capture `s11-projects-list.png` — filesystem projects, no "+" button, no delete
    3. Verify deterministic IDs: `curl -s localhost:9090/api/v1/projects | jq '.data.items[0].id'` twice
    4. Tap a project for detail, capture `s11-project-detail.png`
    5. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots + curl verification of stable IDs
  - **Verify**: `ls .omc/evidence/ios-app-polish/s11-*.png | wc -l` shows 2
  - _Requirements: US-10, AC-10.1 through AC-10.6_

- [x] 2.12 S-12: Config Management
  - **Do**:
    1. Modify selectedTab to "settings", build, launch
    2. Navigate to config editor section (if present in settings)
    3. Capture `s12-config-editor.png` — raw JSON editor for user config
    4. Verify via curl: `curl -s localhost:9090/api/v1/config?scope=user`
    5. Revert selectedTab
  - **Files**: Evidence screenshots only
  - **Done when**: 1 screenshot showing config editor + curl verification
  - **Verify**: `ls .omc/evidence/ios-app-polish/s12-*.png | wc -l` shows 1+
  - _Requirements: US-12 (config subset)_

- [x] 2.13 S-13: Cancel Active Stream
  - **Do**:
    1. Open active session, send a message that triggers streaming
    2. Capture `s13-streaming.png` — typing indicator + stop button visible
    3. Tap stop button
    4. Capture `s13-cancelled.png` — stream stopped, partial response preserved, input re-enabled
  - **Files**: Evidence screenshots only
  - **Done when**: 2 screenshots showing streaming + post-cancel recovery
  - **Verify**: `ls .omc/evidence/ios-app-polish/s13-*.png | wc -l` shows 2
  - _Requirements: US-5, AC-5.1 through AC-5.5_

## Phase 3: Quality Gates & Final Verification

- [x] 3.1 [VERIFY] Full build: backend + iOS
  - **Do**: Build both targets, verify zero errors
  - **Verify**: `cd /Users/nick/Desktop/ils-ios && swift build 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | grep -E "(error:|BUILD)" | tail -5`
  - **Done when**: Both builds succeed

- [x] 3.2 [VERIFY] Evidence completeness check
  - **Do**: Count all evidence screenshots across all scenarios
  - **Verify**: `ls -la .omc/evidence/ios-app-polish/s*.png 2>/dev/null | wc -l` shows 28+ files (avg 2+ per scenario × 13 scenarios)
  - **Done when**: All 13 scenarios have at least 1 screenshot each

- [x] 3.3 [VERIFY] Final acceptance criteria checklist
  - **Do**: Programmatically verify each key AC:
    1. AC-1.1: `ls ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` — exists
    2. AC-3.3: `grep -c navigateToSession ILSApp/ILSApp/Views/Sessions/SessionsListView.swift` — > 0
    3. AC-5.2: `grep -c 'chat/cancel' ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — > 0
    4. AC-8.4: `grep -c Process Sources/ILSBackend/Controllers/PluginsController.swift` — > 0
    5. AC-10.6: `grep -c deterministicID Sources/ILSBackend/Controllers/ProjectsController.swift` — > 0
    6. AC-12.1: `grep -c SSHConnection ILSApp/ILSApp/Views/Settings/SettingsView.swift` — = 0
    7. AC-12.4: `ls ILSApp/ILSApp/Views/Settings/ConfigProfilesView.swift 2>/dev/null` — not found
    8. AC-6.3: `grep -c navigateToForked ILSApp/ILSApp/Views/Chat/ChatView.swift` — > 0
    9. AC-11.3: `grep -c NavigationLink ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` — > 0
    10. AC-8.7: `grep -c 'searchMarketplace' ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` — = 0 (removed, now client-side)
  - **Verify**: All checks pass
  - **Done when**: 10/10 acceptance criteria confirmed

---

## Notes

### Already-working features (verify-only, no code changes expected):
- MCP CRUD (NewMCPServerView, EditMCPServerView, MCPViewModel) — S-07
- Skills detail + search + install (SkillsListView, SkillsViewModel) — S-10
- External session merging in SessionsViewModel.loadSessions() — S-02
- Dashboard stats from /stats endpoint — S-01
- Plugin enable/disable/delete — S-09
- Config editor (user + project scope) — S-12
- Session resume with claudeSessionId — S-05

### Screenshot capture technique:
- For tabs other than "sessions": modify `selectedTab` default in ILSAppApp.swift, incremental build, capture, revert
- For interactive flows (chat, fork): use idb_describe for accessibility tree → idb_tap for precise element interaction
- For API verification: use curl to backend on port 9090

### Known limitations:
- Claude CLI `-p` hangs as subprocess within active Claude Code session (environment constraint)
- Chat streaming validation (S-03, S-04, S-05, S-13) may require backend running independently
- Some scenarios may produce partial evidence if Claude CLI is unavailable

### Simulator:
- UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14
- iPhone 16 Pro Max, iOS 18.6
- Logical resolution: 440x956 points
