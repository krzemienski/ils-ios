# Tasks: ILS iOS Alpha Release

## Phase 1: Workspace Unification (P0)

### Task 1.1: Create workspace schemes directory and ILSApp scheme
- [ ] Create `ILSFullStack.xcworkspace/xcshareddata/xcschemes/` directory
- [ ] Write `ILSApp.xcscheme` with BlueprintIdentifier `00000000000000000000000E`, ReferencedContainer `container:ILSApp/ILSApp.xcodeproj` (XML from design.md section 1.2)

**Files:** `ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSApp.xcscheme` (create)
**Verify:** `ls ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSApp.xcscheme && grep -c "00000000000000000000000E" ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSApp.xcscheme`
**Commit:** `feat(workspace): add shared ILSApp scheme`
**AC:** AC-2.1

### Task 1.2: Create ILSBackend workspace scheme
- [ ] Write `ILSBackend.xcscheme` with BlueprintIdentifier `ILSBackend`, ReferencedContainer `container:`, customWorkingDirectory `<project-root>`, PORT=9090 env var (XML from design.md section 1.3)

**Files:** `ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSBackend.xcscheme` (create)
**Verify:** `grep -c "customWorkingDirectory" ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSBackend.xcscheme && grep -c 'PORT' ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSBackend.xcscheme`
**Commit:** `feat(workspace): add shared ILSBackend scheme with PORT=9090 and working dir`
**AC:** AC-1.1, AC-1.3, AC-1.4

### Task 1.3: Update workspace navigator
- [ ] Rewrite `contents.xcworkspacedata` to add Shared group (Sources/ILSShared), Tests group (Tests/), narrow Backend group to Sources/ILSBackend, remove Package.resolved from Backend group (XML from design.md section 1.4)

**Files:** `ILSFullStack.xcworkspace/contents.xcworkspacedata` (modify)
**Verify:** `grep -c "ILSShared" ILSFullStack.xcworkspace/contents.xcworkspacedata && grep -c "Tests" ILSFullStack.xcworkspace/contents.xcworkspacedata && grep -c "Package.resolved" ILSFullStack.xcworkspace/contents.xcworkspacedata | grep "0"`
**Commit:** `feat(workspace): organize navigator with Backend, Shared, Tests groups`
**AC:** AC-3.1, AC-3.2

### Task 1.4: Cleanup -- delete SDK cache and empty directory
- [ ] `rm -rf ILSApp/build/SourcePackages/checkouts/ClaudeCodeSDK/`
- [ ] `rmdir ILSApp/ILSApp/Views/ServerConnection` (confirmed empty)

**Files:** (deletions only)
**Verify:** `ls ILSApp/build/SourcePackages/checkouts/ClaudeCodeSDK/ 2>&1 | grep -c "No such file" && ls ILSApp/ILSApp/Views/ServerConnection 2>&1 | grep -c "No such file"`
**Commit:** `chore(cleanup): remove ClaudeCodeSDK cache and empty ServerConnection dir`
**AC:** AC-15.2

### Task 1.5: [VERIFY] Workspace builds both targets
- [ ] Build backend: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' build 2>&1 | tail -5`
- [ ] Build iOS: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`

**Verify:** Both commands output `** BUILD SUCCEEDED **`
**Done when:** Backend build succeeds, iOS build succeeds, 0 errors
**Commit:** `chore(workspace): pass build verification` (only if fixes needed)
**AC:** AC-1.2, AC-2.2, AC-2.3, AC-15.4

---

## Phase 2: Streaming Heartbeat + SDK Cleanup (P1)

### Task 2.1: Add heartbeat watchdog to SSEClient
- [ ] In `SSEClient.performStream()`, add `var lastHeartbeatOrData = Date()` before the bytes loop
- [ ] Reset `lastHeartbeatOrData = Date()` on every received line (data or heartbeat comment)
- [ ] Add concurrent `heartbeatWatchdog` Task that checks every 45s, throws `URLError(.timedOut)` if stale
- [ ] Add `defer { heartbeatWatchdog.cancel() }` after creating watchdog
- [ ] Code from design.md section 3.1

**Files:** `ILSApp/ILSApp/Services/SSEClient.swift` (modify, ~15 lines added)
**Verify:** `grep -c "heartbeatWatchdog\|lastHeartbeatOrData" ILSApp/ILSApp/Services/SSEClient.swift` (expect 4+)
**Commit:** `feat(sse): add 45s heartbeat watchdog for stale connection detection`
**AC:** AC-14.2, AC-14.3

### Task 2.2: Verify SDK remnants fully cleaned
- [ ] Confirm Package.resolved clean: `grep ClaudeCodeSDK ILSFullStack.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- [ ] Confirm Package.swift clean: `grep ClaudeCodeSDK Package.swift`
- [ ] Confirm source imports clean: `grep -r "import ClaudeCodeSDK" Sources/ ILSApp/`
- [ ] Task 1.4 already deleted cache checkout

**Files:** (verification only)
**Verify:** All 3 grep commands return 0 matches
**Commit:** none (verification only)
**AC:** AC-15.1, AC-15.3, AC-3.3

### Task 2.3: [VERIFY] Heartbeat build check
- [ ] Rebuild iOS app after heartbeat changes: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3`

**Verify:** `** BUILD SUCCEEDED **`
**Done when:** iOS builds with heartbeat watchdog, no errors
**Commit:** `chore(sse): pass build after heartbeat addition` (only if fixes needed)
**AC:** AC-14.2

---

## Phase 3: Stub Audit (P1) -- parallel with Phase 2

### Task 3.1: Verify remaining stub items
- [ ] Confirm Extended Thinking/Co-Author read live config: `grep -n "alwaysThinkingEnabled\|includeCoAuthoredBy" ILSApp/ILSApp/Views/Settings/SettingsViewSections.swift`
- [ ] Confirm testConnection calls real healthCheck: `grep -A5 "func testConnection" ILSApp/ILSApp/ViewModels/SettingsViewModel.swift`
- [ ] Confirm LogViewerView reads real logs: `grep -n "AppLogger" ILSApp/ILSApp/Views/Settings/LogViewerView.swift`
- [ ] Confirm NotificationPreferencesView uses @AppStorage: `grep -n "AppStorage" ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift`
- [ ] Confirm zero remaining stub patterns: `grep -rn 'set: { _ in }\|\.disabled(true)\|sampleFleet\|sampleData\|sampleHistory' ILSApp/ILSApp/ --include="*.swift"`
- [ ] Document SessionTemplate.defaults as intentional local-first design (not a stub)

**Files:** (verification only, may create `specs/alpha/evidence/stub-audit.txt` with results)
**Verify:** All grep commands return expected matches (live config) and stub pattern grep returns 0 matches
**Commit:** none (verification only)
**AC:** AC-16.1, AC-16.2, AC-16.3, AC-16.4, AC-16.5, AC-16.6

---

## Phase 4: Code Quality (P2)

### Task 4.1: Split SettingsViewSections.swift (594 lines -> 4+1 files)
- [ ] Create `SettingsAppearanceSection.swift` (~120 lines) -- theme picker, appearance settings
- [ ] Create `SettingsConnectionSection.swift` (~130 lines) -- server URL, test connection, tunnel link
- [ ] Create `SettingsConfigSection.swift` (~150 lines) -- Claude config display, config editor link
- [ ] Create `SettingsAboutSection.swift` (~120 lines) -- about, logs, notifications, data management
- [ ] Reduce `SettingsViewSections.swift` to coordinator (~80 lines) composing the 4 sections
- [ ] Add all 4 new files to Xcode project build phases

**Files:** `ILSApp/ILSApp/Views/Settings/SettingsAppearanceSection.swift` (create), `SettingsConnectionSection.swift` (create), `SettingsConfigSection.swift` (create), `SettingsAboutSection.swift` (create), `SettingsViewSections.swift` (modify)
**Verify:** `wc -l ILSApp/ILSApp/Views/Settings/SettingsViewSections.swift ILSApp/ILSApp/Views/Settings/Settings*Section.swift` (all files <500 lines)
**Commit:** `refactor(settings): split SettingsViewSections into 4 focused section files`
**AC:** AC-17.1

### Task 4.2: Split ChatView.swift (555 lines -> 3 files)
- [ ] Create `ChatMessageList.swift` (~200 lines) -- ScrollViewReader + message list + auto-scroll
- [ ] Create `ChatInputBar.swift` (~150 lines) -- text field, send button, command palette trigger
- [ ] Reduce `ChatView.swift` to composition (~200 lines) -- toolbar, state coordination
- [ ] Add 2 new files to Xcode project build phases

**Files:** `ILSApp/ILSApp/Views/Chat/ChatMessageList.swift` (create), `ChatInputBar.swift` (create), `ChatView.swift` (modify)
**Verify:** `wc -l ILSApp/ILSApp/Views/Chat/ChatView.swift ILSApp/ILSApp/Views/Chat/ChatMessageList.swift ILSApp/ILSApp/Views/Chat/ChatInputBar.swift` (all <500)
**Commit:** `refactor(chat): extract ChatMessageList and ChatInputBar from ChatView`
**AC:** AC-17.2

### Task 4.3: [VERIFY] Quality checkpoint after 2 splits
- [ ] Build iOS: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3`

**Verify:** `** BUILD SUCCEEDED **`
**Done when:** App builds cleanly after SettingsViewSections + ChatView splits
**Commit:** `chore(quality): pass build checkpoint after file splits` (only if fixes needed)

### Task 4.4: Split ServerSetupSheet.swift (518 lines -> 3+1 files)
- [ ] Create `LocalConnectionView.swift` (~150 lines) -- local mode setup, health check
- [ ] Create `RemoteConnectionView.swift` (~130 lines) -- remote URL input, connection test
- [ ] Create `TunnelConnectionView.swift` (~120 lines) -- tunnel mode setup
- [ ] Reduce `ServerSetupSheet.swift` to outer sheet with mode selector (~120 lines)
- [ ] Add 3 new files to Xcode project build phases

**Files:** `ILSApp/ILSApp/Views/Onboarding/LocalConnectionView.swift` (create), `RemoteConnectionView.swift` (create), `TunnelConnectionView.swift` (create), `ServerSetupSheet.swift` (modify)
**Verify:** `wc -l ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift ILSApp/ILSApp/Views/Onboarding/*ConnectionView.swift` (all <500)
**Commit:** `refactor(onboarding): extract 3 connection mode views from ServerSetupSheet`
**AC:** AC-17.3

### Task 4.5: Split TunnelSettingsView.swift (483 lines -> 2+1 files)
- [ ] Create `TunnelStatusSection.swift` (~200 lines) -- tunnel running state, metrics, URL
- [ ] Create `TunnelConfigSection.swift` (~200 lines) -- token, hostname, route, advanced
- [ ] Reduce `TunnelSettingsView.swift` to coordinator (~80 lines)
- [ ] Add 2 new files to Xcode project build phases

**Files:** `ILSApp/ILSApp/Views/Settings/TunnelStatusSection.swift` (create), `TunnelConfigSection.swift` (create), `TunnelSettingsView.swift` (modify)
**Verify:** `wc -l ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift ILSApp/ILSApp/Views/Settings/Tunnel*Section.swift` (all <500)
**Commit:** `refactor(tunnel): extract TunnelStatusSection and TunnelConfigSection`
**AC:** AC-17.4

### Task 4.6: [VERIFY] Full build after all 4 file splits
- [ ] Build iOS: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3`
- [ ] Build Backend: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' -quiet build 2>&1 | tail -3`
- [ ] File length audit: `find ILSApp/ILSApp -name "*.swift" -exec wc -l {} + | sort -rn | head -10`

**Verify:** Both builds succeed. No .swift file exceeds 500 lines.
**Done when:** 0 errors, top file <500 lines
**Commit:** `chore(quality): pass build + file length audit after all splits` (only if fixes needed)
**AC:** AC-17.5

### Task 4.7: Create .swiftlint.yml and run SwiftLint
- [ ] Create `.swiftlint.yml` at project root (config from design.md section 5.3)
- [ ] Run `swiftlint --fix --path ILSApp/ILSApp/` to auto-fix
- [ ] Run `swiftlint lint --path ILSApp/ILSApp/ --quiet` to check remaining violations
- [ ] Fix any remaining violations manually

**Files:** `.swiftlint.yml` (create), various Swift files (auto-fix modifications)
**Verify:** `swiftlint lint --path ILSApp/ILSApp/ --quiet 2>&1 | wc -l` (expect 0 or minimal warnings)
**Commit:** `chore(lint): add SwiftLint config and fix violations`
**AC:** AC-19.1, AC-19.2, AC-19.3

### Task 4.8: Run Periphery and remove dead code
- [ ] Run `periphery scan --project ILSApp/ILSApp.xcodeproj --schemes ILSApp --targets ILSApp --format xcode 2>&1 | head -50`
- [ ] Review results, skip SwiftUI @State/@Environment/@Published false positives
- [ ] Remove confirmed-dead declarations
- [ ] Check for duplicate APIResponse/ListResponse: `grep -n "struct APIResponse\|struct ListResponse" ILSApp/ILSApp/Services/APIClient.swift Sources/ILSShared/DTOs/Requests.swift`
- [ ] Consolidate duplicates if found (keep ILSShared version)

**Files:** Various Swift files (dead code removal), possibly `APIClient.swift` (modify)
**Verify:** `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3`
**Commit:** `refactor(cleanup): remove dead code identified by Periphery`
**AC:** AC-18.1, AC-18.2, AC-18.3, AC-18.4

### Task 4.9: [VERIFY] Full quality checkpoint: build + lint + file lengths
- [ ] iOS build: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -3`
- [ ] Backend build: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' -quiet build 2>&1 | tail -3`
- [ ] SwiftLint: `swiftlint lint --path ILSApp/ILSApp/ --quiet 2>&1 | wc -l`
- [ ] File lengths: `find ILSApp/ILSApp -name "*.swift" -exec wc -l {} + | awk '$1 > 500 {print}' | wc -l` (expect 0)

**Verify:** All 4 commands pass (builds succeed, 0 lint violations, 0 files >500 lines)
**Done when:** Code quality gates all green
**Commit:** `chore(quality): pass full quality checkpoint` (only if fixes needed)
**AC:** AC-17.5, AC-19.1

---

## Phase 5: E2E Chat Validation (P0) -- CS1-CS10

### Task 5.0: Setup -- evidence directory, backend, build, install, launch
- [ ] `mkdir -p specs/alpha/evidence`
- [ ] Start backend: `PORT=9090 swift run ILSBackend &` then `sleep 5`
- [ ] Verify health: `curl -s http://localhost:9090/health | python3 -m json.tool`
- [ ] Build iOS: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build`
- [ ] Boot simulator: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14 2>/dev/null; echo "booted"`
- [ ] Install app: `xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 ~/Library/Developer/Xcode/DerivedData/ILSApp-*/Build/Products/Debug-iphonesimulator/ILSApp.app`
- [ ] Launch app: `xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app`

**Files:** `specs/alpha/evidence/` (create dir)
**Verify:** `curl -s http://localhost:9090/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('status')=='ok' else 'FAIL')"`
**Commit:** none (setup only)
**AC:** FR-3, AC-1.5

### Task 5.1: CS1 -- Basic Send-Receive-Render
- [ ] curl verify: `curl -s -X POST http://localhost:9090/api/v1/chat/stream -H 'Content-Type: application/json' -d '{"prompt":"What is 2+2?"}' --max-time 60 > specs/alpha/evidence/curl-cs1.txt 2>&1`
- [ ] Navigate to session, type "What is 2+2?", tap Send
- [ ] Capture screenshots: `cs1-sessions.png`, `cs1-sent.png`, `cs1-streaming.png`, `cs1-response.png`
- [ ] READ each screenshot and describe what it shows
- [ ] PASS criteria: response shows "4" rendered via MarkdownUI, message persists

**Files:** `specs/alpha/evidence/cs1-*.png`, `specs/alpha/evidence/curl-cs1.txt`
**Verify:** `ls specs/alpha/evidence/cs1-*.png | wc -l` (expect 3-4 files) AND `cat specs/alpha/evidence/curl-cs1.txt | head -5` (expect SSE event data)
**Commit:** `feat(alpha): CS1 basic send-receive-render validated`
**AC:** AC-4.1, AC-4.2, AC-4.3, AC-4.4, AC-4.5, AC-4.6, AC-4.7

### Task 5.2: CS2 -- Streaming Cancellation
- [ ] curl cancel endpoint: `curl -s -X POST http://localhost:9090/api/v1/chat/cancel/SESSION_UUID` (use real UUID from CS1)
- [ ] Send long prompt, tap Stop within 5s
- [ ] Capture: `cs2-streaming.png`, `cs2-cancelled.png`, `cs2-followup.png`
- [ ] READ screenshots, confirm partial text visible, input re-enabled

**Files:** `specs/alpha/evidence/cs2-*.png`
**Verify:** `ls specs/alpha/evidence/cs2-*.png | wc -l` (expect 2-3)
**Commit:** `feat(alpha): CS2 streaming cancellation validated`
**AC:** AC-5.1, AC-5.2, AC-5.3, AC-5.4, AC-5.5, AC-5.6

### Task 5.3: CS3 -- Tool Call Rendering
- [ ] Send "Read the Package.swift file" (triggers tool_use)
- [ ] Capture: `cs3-tool-collapsed.png`, `cs3-tool-expanded.png`
- [ ] READ screenshots, confirm tool name visible, expand shows inputs/outputs

**Files:** `specs/alpha/evidence/cs3-*.png`
**Verify:** `ls specs/alpha/evidence/cs3-*.png | wc -l` (expect 2)
**Commit:** `feat(alpha): CS3 tool call rendering validated`
**AC:** AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5

### Task 5.4: [VERIFY] Evidence checkpoint CS1-CS3
- [ ] Verify all evidence files exist: `ls -la specs/alpha/evidence/cs{1,2,3}*`
- [ ] Verify curl evidence: `wc -c specs/alpha/evidence/curl-cs1.txt` (non-zero)

**Verify:** All expected files present, non-zero sizes
**Done when:** CS1-CS3 evidence complete and reviewed
**Commit:** none (checkpoint)

### Task 5.5: CS4 -- Error Recovery After Backend Restart
- [ ] Kill backend: `kill $(pgrep -f ILSBackend)`
- [ ] Capture: `cs4-disconnected.png` (ConnectionBanner visible)
- [ ] Restart: `PORT=9090 swift run ILSBackend &` then `sleep 5`
- [ ] Wait up to 30s for reconnection
- [ ] Capture: `cs4-reconnected.png`, `cs4-message-after.png`
- [ ] READ screenshots, confirm disconnect/reconnect banner cycle

**Files:** `specs/alpha/evidence/cs4-*.png`
**Verify:** `ls specs/alpha/evidence/cs4-*.png | wc -l` (expect 2-3)
**Commit:** `feat(alpha): CS4 error recovery validated`
**AC:** AC-7.1, AC-7.2, AC-7.3, AC-7.4, AC-7.5, AC-7.6

### Task 5.6: CS5 -- Session Fork and Navigate
- [ ] curl fork: `curl -s -X POST http://localhost:9090/api/v1/sessions/SESSION_UUID/fork` (use session with 3+ messages)
- [ ] Trigger fork via menu in app
- [ ] Capture: `cs5-fork-alert.png`, `cs5-forked-session.png`
- [ ] READ screenshots, confirm fork alert + copied messages

**Files:** `specs/alpha/evidence/cs5-*.png`
**Verify:** `ls specs/alpha/evidence/cs5-*.png | wc -l` (expect 2)
**Commit:** `feat(alpha): CS5 session fork validated`
**AC:** AC-8.1, AC-8.2, AC-8.3, AC-8.4, AC-8.5, AC-8.6

### Task 5.7: CS6 -- Rapid-Fire Message Sending
- [ ] Send "Message 1" then immediately "Message 2"
- [ ] Capture: `cs6-rapid.png`
- [ ] READ screenshot, confirm no crash, no duplicates

**Files:** `specs/alpha/evidence/cs6-rapid.png`
**Verify:** `ls specs/alpha/evidence/cs6-rapid.png`
**Commit:** `feat(alpha): CS6 rapid-fire handling validated`
**AC:** AC-9.1, AC-9.2, AC-9.3, AC-9.4

### Task 5.8: CS7 -- Theme Switching During Active Chat
- [ ] Open session with existing messages
- [ ] Switch to Obsidian theme, capture: `cs7-obsidian.png`
- [ ] Switch to Paper theme, capture: `cs7-paper.png`
- [ ] READ screenshots, confirm re-render, no layout corruption

**Files:** `specs/alpha/evidence/cs7-*.png`
**Verify:** `ls specs/alpha/evidence/cs7-*.png | wc -l` (expect 2)
**Commit:** `feat(alpha): CS7 theme switching validated`
**AC:** AC-10.1, AC-10.2, AC-10.3, AC-10.4, AC-10.5, AC-10.6

### Task 5.9: [VERIFY] Evidence checkpoint CS4-CS7
- [ ] `ls -la specs/alpha/evidence/cs{4,5,6,7}*`
- [ ] Count total evidence so far: `ls specs/alpha/evidence/*.png | wc -l` (expect 12-16)

**Verify:** All CS4-CS7 evidence present
**Done when:** Mid-validation checkpoint passes
**Commit:** none (checkpoint)

### Task 5.10: CS8 -- Long Message with Code Blocks and Thinking
- [ ] Send "Implement a binary search tree in Swift with insert, delete, and search"
- [ ] Capture thinking section (if available): `cs8-thinking.png` or create `cs8-thinking-na.txt`
- [ ] Capture code block rendering: `cs8-code.png`
- [ ] READ screenshots, confirm syntax highlighting, line numbers, auto-scroll

**Files:** `specs/alpha/evidence/cs8-*.png` (or `cs8-thinking-na.txt`)
**Verify:** `ls specs/alpha/evidence/cs8-* | wc -l` (expect 2)
**Commit:** `feat(alpha): CS8 code blocks and thinking validated`
**AC:** AC-11.1, AC-11.2, AC-11.3, AC-11.4, AC-11.5

### Task 5.11: CS9 -- External Session Browsing
- [ ] curl scan: `curl -s http://localhost:9090/api/v1/sessions/scan > specs/alpha/evidence/curl-cs9.txt`
- [ ] If sessions exist, browse one, capture: `cs9-external.png`
- [ ] If empty, create `specs/alpha/evidence/cs9-na.txt` documenting "N/A -- no external sessions found"

**Files:** `specs/alpha/evidence/cs9-external.png` OR `cs9-na.txt`, plus `curl-cs9.txt`
**Verify:** `ls specs/alpha/evidence/cs9-* | wc -l` (expect 1-2)
**Commit:** `feat(alpha): CS9 external session browsing validated`
**AC:** AC-12.1, AC-12.2, AC-12.3, AC-12.4, AC-12.5

### Task 5.12: CS10 -- Session Rename, Export, Info Sheet
- [ ] curl rename: `curl -s -X PUT http://localhost:9090/api/v1/sessions/SESSION_UUID -H 'Content-Type: application/json' -d '{"name":"Alpha Test"}'`
- [ ] Rename via UI, capture: `cs10-renamed.png`
- [ ] Open info sheet, capture: `cs10-info.png`
- [ ] Trigger export/share, capture: `cs10-export.png`
- [ ] READ screenshots, confirm name visible, info shows metadata, share sheet appears

**Files:** `specs/alpha/evidence/cs10-*.png`
**Verify:** `ls specs/alpha/evidence/cs10-*.png | wc -l` (expect 3)
**Commit:** `feat(alpha): CS10 session rename, export, info validated`
**AC:** AC-13.1, AC-13.2, AC-13.3, AC-13.4, AC-13.5

### Task 5.13: Verify backend heartbeat via curl
- [ ] `curl -N -X POST http://localhost:9090/api/v1/chat/stream -H 'Content-Type: application/json' -d '{"prompt":"hello"}' --max-time 30 2>&1 | grep -c "ping" > specs/alpha/evidence/curl-heartbeat.txt`
- [ ] Expect >0 ping heartbeat comments during streaming

**Files:** `specs/alpha/evidence/curl-heartbeat.txt`
**Verify:** `cat specs/alpha/evidence/curl-heartbeat.txt` (expect number > 0)
**Commit:** none (verification)
**AC:** AC-14.1, AC-14.4

---

## Phase 6: Final Verification

### Task 6.1: [VERIFY] Full build -- 0 errors, 0 warnings
- [ ] Clean build iOS: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' clean build 2>&1 | tail -10`
- [ ] Clean build Backend: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' clean build 2>&1 | tail -10`

**Verify:** Both output `** BUILD SUCCEEDED **`, grep for `warning:` returns 0
**Done when:** Clean builds with 0 errors, 0 warnings
**Commit:** `chore(alpha): pass final clean build` (only if fixes needed)
**AC:** FR-1, FR-2

### Task 6.2: [VERIFY] Final file length audit
- [ ] `find ILSApp/ILSApp -name "*.swift" -exec wc -l {} + | sort -rn | head -10`
- [ ] Confirm no file exceeds 500 lines

**Verify:** `find ILSApp/ILSApp -name "*.swift" -exec wc -l {} + | awk '$1 > 500 {print}' | grep -v total | wc -l` returns 0
**Done when:** All Swift files under 500-line limit
**Commit:** none (verification)
**AC:** AC-17.5, NFR-6

### Task 6.3: [VERIFY] Evidence review -- all CS screenshots present
- [ ] `ls -la specs/alpha/evidence/ | wc -l` (expect 20-30 files)
- [ ] Verify each CS has minimum evidence: `for cs in cs1 cs2 cs3 cs4 cs5 cs6 cs7 cs8 cs9 cs10; do echo "$cs: $(ls specs/alpha/evidence/${cs}* 2>/dev/null | wc -l) files"; done`
- [ ] Verify curl evidence: `ls specs/alpha/evidence/curl-*.txt | wc -l` (expect 2-3)

**Verify:** All 10 scenarios have evidence files, total 20+ files in evidence directory
**Done when:** Complete evidence coverage for alpha release
**Commit:** none (verification)
**AC:** FR-4 through FR-13

### Task 6.4: [VERIFY] Acceptance criteria checklist
- [ ] Workspace builds backend (AC-1.2): `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' -quiet build 2>&1 | tail -1`
- [ ] Workspace builds iOS (AC-2.2): `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet build 2>&1 | tail -1`
- [ ] No ClaudeCodeSDK: `grep -r ClaudeCodeSDK Sources/ ILSApp/ Package.swift 2>/dev/null | wc -l` returns 0
- [ ] No stub patterns: `grep -rn 'set: { _ in }\|sampleFleet\|sampleData' ILSApp/ILSApp/ --include="*.swift" | wc -l` returns 0
- [ ] No file >500 lines: `find ILSApp/ILSApp -name "*.swift" -exec wc -l {} + | awk '$1 > 500' | grep -v total | wc -l` returns 0
- [ ] SwiftLint clean: `swiftlint lint --path ILSApp/ILSApp/ --quiet 2>&1 | wc -l` returns 0
- [ ] Evidence directory populated: `ls specs/alpha/evidence/*.png | wc -l` (expect 15+)

**Verify:** All 7 checks pass
**Done when:** All acceptance criteria programmatically confirmed
**Commit:** `feat(alpha): complete alpha release -- workspace, chat validation, code quality`
**AC:** All

---

## Phase 7: PR Lifecycle

### Task 7.1: Create PR
- [ ] Verify on feature branch: `git branch --show-current` (should NOT be main)
- [ ] Stage all changes: `git add -A`
- [ ] Create final commit if not already committed
- [ ] Push: `git push -u origin $(git branch --show-current)`
- [ ] Create PR: `gh pr create --title "feat(alpha): ILS iOS alpha release" --body "..."`

**Verify:** `gh pr view --json url -q .url` returns PR URL
**Done when:** PR created and pushed
**Commit:** none (PR creation)

### Task 7.2: [VERIFY] CI pipeline passes
- [ ] `gh pr checks --watch` (wait for CI)
- [ ] If failures, read logs: `gh pr checks`, fix, push, re-verify

**Verify:** All CI checks green
**Done when:** CI passes
**Commit:** `fix(alpha): address CI feedback` (only if fixes needed)

### Task 7.3: [VERIFY] Final AC checklist on PR
- [ ] Re-run acceptance criteria checks from Task 6.4
- [ ] Confirm evidence directory is in the PR diff
- [ ] Confirm zero test regressions

**Verify:** All checks from 6.4 still pass after any CI fixes
**Done when:** PR is review-ready with all ACs met
**Commit:** none

---

## Notes

### POC shortcuts taken
- Backend scheme uses absolute path `<project-root>` (machine-specific, acceptable for single-dev alpha)
- CS2/CS3 may be limited by Claude CLI subprocess constraint in active CC session -- curl validates API independently
- CS9 may document N/A if no external sessions exist
- CS8 thinking section depends on model config -- may be N/A

### Production TODOs
- Replace absolute working directory path with `$(SRCROOT)` or env-var approach
- Add ILSFullStack combined scheme (both targets)
- Investigate swift-subprocess migration (Swift 6.2.4 available)
- Add structured error types to streaming pipeline
- Authentication (AuthController currently stub)
- Rate limiting and CORS hardening
- CI/CD pipeline (no git remote currently configured)

### Evidence collection
- Total expected: 20-25 screenshots + 2-4 text files in `specs/alpha/evidence/`
- Every screenshot must be READ by validator before marking PASS
- curl evidence provides API-level verification independent of simulator state

### Task count summary
- Phase 1 (Workspace): 5 tasks
- Phase 2 (Heartbeat): 3 tasks
- Phase 3 (Stub Audit): 1 task
- Phase 4 (Code Quality): 9 tasks
- Phase 5 (Chat Validation): 14 tasks (CS1-CS10 + setup + checkpoints + heartbeat curl)
- Phase 6 (Final Verification): 4 tasks
- Phase 7 (PR Lifecycle): 3 tasks
- **Total: 39 tasks**
