# Requirements: ILS iOS Alpha Release

## Goal

Deliver a verified, unified ILS iOS app where the Xcode workspace builds both backend and iOS app via schemes, all 10 chat scenarios pass E2E with screenshot evidence, remaining stubs are fixed or removed, and code quality meets the 500-line/file limit -- validated honestly with curls, builds, and screenshots.

---

## Workstream 1: Workspace Unification (P0)

### US-1: Build Backend from Workspace

**As a** developer
**I want to** build and run the Vapor backend from ILSFullStack.xcworkspace
**So that** I don't need `swift run` in a separate terminal

**Acceptance Criteria:**
- [ ] AC-1.1: Shared scheme `ILSBackend` exists at `ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSBackend.xcscheme`
- [ ] AC-1.2: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSBackend -destination 'platform=macOS' build` succeeds
- [ ] AC-1.3: Scheme sets custom working directory to project root (`<project-root>`) so Vapor finds `ils.sqlite` and `.env`
- [ ] AC-1.4: Scheme sets environment variable `PORT=9090`
- [ ] AC-1.5: `curl http://localhost:9090/health` returns 200 after launching from scheme

### US-2: Build iOS App from Workspace

**As a** developer
**I want to** build and run the iOS app from the same workspace
**So that** I have one workspace for the entire stack

**Acceptance Criteria:**
- [ ] AC-2.1: Shared scheme `ILSApp` exists at `ILSFullStack.xcworkspace/xcshareddata/xcschemes/ILSApp.xcscheme`
- [ ] AC-2.2: `xcodebuild -workspace ILSFullStack.xcworkspace -scheme ILSApp -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` succeeds
- [ ] AC-2.3: ILSShared resolves correctly in both schemes (single source of truth via local SPM reference)

### US-3: Clean Workspace Navigator

**As a** developer
**I want** the workspace file to organize Backend, Shared, and Tests as named groups
**So that** navigation is clear when opening the workspace in Xcode

**Acceptance Criteria:**
- [ ] AC-3.1: `ILSFullStack.xcworkspace/contents.xcworkspacedata` has named groups: "Backend" (Sources/ILSBackend), "Shared" (Sources/ILSShared), "Tests" (Tests/)
- [ ] AC-3.2: `ILSApp.xcodeproj` reference present at workspace root
- [ ] AC-3.3: ClaudeCodeSDK removed from `ILSFullStack.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- [ ] AC-3.4: `ils.sqlite` added to `.gitignore`

---

## Workstream 2: E2E Chat Validation (P0)

> The single most important gap. Every scenario requires: backend running on 9090, app installed on simulator 50523130, real Claude CLI interaction, screenshot evidence.

### US-4: CS1 -- Basic Send-Receive-Render

**As a** user
**I want to** send a message and see Claude's response rendered with markdown
**So that** basic chat works end-to-end

**Acceptance Criteria:**
- [ ] AC-4.1: Navigate to a session in the app (screenshot: session list visible)
- [ ] AC-4.2: Type "What is 2+2?" and tap Send (screenshot: message sent)
- [ ] AC-4.3: StreamingIndicator appears while Claude responds (screenshot: streaming state)
- [ ] AC-4.4: Claude's response appears rendered via MarkdownUI (screenshot: response visible)
- [ ] AC-4.5: Message persists after navigating away and back
- [ ] AC-4.6: `curl POST /api/v1/chat/stream` returns SSE events (curl evidence)
- [ ] AC-4.7: Evidence files: `cs1-sent.png`, `cs1-streaming.png`, `cs1-response.png`

### US-5: CS2 -- Streaming Cancellation Mid-Response

**As a** user
**I want to** cancel a streaming response mid-generation
**So that** I can stop unwanted output

**Acceptance Criteria:**
- [ ] AC-5.1: Send a long prompt ("Write a 500-word essay about recursion")
- [ ] AC-5.2: Tap Stop button within 5 seconds of streaming start (screenshot: stop button visible)
- [ ] AC-5.3: Streaming stops, partial response preserved (screenshot: partial text visible)
- [ ] AC-5.4: `POST /api/v1/chat/cancel` returns 200 (curl evidence)
- [ ] AC-5.5: Input field re-enabled after cancel, can send follow-up message
- [ ] AC-5.6: Evidence files: `cs2-streaming.png`, `cs2-cancelled.png`, `cs2-followup.png`

### US-6: CS3 -- Tool Call Rendering

**As a** user
**I want to** see tool calls rendered in expandable accordions
**So that** I understand what Claude is doing

**Acceptance Criteria:**
- [ ] AC-6.1: Send "Read the Package.swift file" (triggers tool_use)
- [ ] AC-6.2: ToolCallAccordion renders with tool name and expand chevron (screenshot)
- [ ] AC-6.3: Tapping accordion expands to show tool inputs and outputs (screenshot)
- [ ] AC-6.4: Text content after tool call renders normally
- [ ] AC-6.5: Evidence files: `cs3-tool-collapsed.png`, `cs3-tool-expanded.png`

### US-7: CS4 -- Error Recovery After Backend Restart

**As a** user
**I want** the app to recover gracefully when the backend goes down and comes back
**So that** temporary outages don't break my session

**Acceptance Criteria:**
- [ ] AC-7.1: Kill backend process while app is open
- [ ] AC-7.2: ConnectionBanner shows disconnected state (screenshot: banner visible)
- [ ] AC-7.3: Restart backend (`PORT=9090 swift run ILSBackend`)
- [ ] AC-7.4: App reconnects automatically within 30 seconds (screenshot: connected state)
- [ ] AC-7.5: Send a message after reconnection -- it succeeds (screenshot)
- [ ] AC-7.6: Evidence files: `cs4-disconnected.png`, `cs4-reconnected.png`, `cs4-message-after.png`

### US-8: CS5 -- Session Fork and Navigate

**As a** user
**I want to** fork a session and navigate to the forked copy
**So that** I can branch a conversation

**Acceptance Criteria:**
- [ ] AC-8.1: Open a session with 3+ messages
- [ ] AC-8.2: Trigger fork (via menu or API)
- [ ] AC-8.3: Fork alert appears with "Open Fork" button (screenshot)
- [ ] AC-8.4: Tapping "Open Fork" navigates to the forked session (screenshot: new session with copied messages)
- [ ] AC-8.5: `POST /api/v1/sessions/:id/fork` returns new session ID (curl evidence)
- [ ] AC-8.6: Evidence files: `cs5-fork-alert.png`, `cs5-forked-session.png`

### US-9: CS6 -- Rapid-Fire Message Sending

**As a** user
**I want** the app to handle rapid consecutive messages without crashing
**So that** accidental double-sends don't break the UI

**Acceptance Criteria:**
- [ ] AC-9.1: Send "Message 1" then immediately tap Send again with "Message 2"
- [ ] AC-9.2: App does not crash or show duplicate messages
- [ ] AC-9.3: Either queues second message or shows "wait for response" guard (screenshot)
- [ ] AC-9.4: Evidence files: `cs6-rapid.png`

### US-10: CS7 -- Theme Switching During Active Chat

**As a** user
**I want to** switch themes while viewing a chat session
**So that** messages re-render correctly in the new theme

**Acceptance Criteria:**
- [ ] AC-10.1: Open a chat with existing messages
- [ ] AC-10.2: Switch to "Obsidian" theme (screenshot: dark theme)
- [ ] AC-10.3: Switch to "Paper" theme (screenshot: light theme)
- [ ] AC-10.4: Code blocks re-highlight with correct light/dark syntax colors
- [ ] AC-10.5: No layout corruption or missing text after switch
- [ ] AC-10.6: Evidence files: `cs7-obsidian.png`, `cs7-paper.png`

### US-11: CS8 -- Long Message with Code Blocks and Thinking

**As a** user
**I want** long responses with code blocks and thinking sections to render correctly
**So that** complex AI output is readable

**Acceptance Criteria:**
- [ ] AC-11.1: Send "Implement a binary search tree in Swift with insert, delete, and search"
- [ ] AC-11.2: ThinkingSection appears (if extended thinking enabled) with expand/collapse (screenshot)
- [ ] AC-11.3: CodeBlockView renders with HighlightSwift syntax coloring and line numbers (screenshot)
- [ ] AC-11.4: Long response scrolls smoothly, auto-scroll tracks bottom
- [ ] AC-11.5: Evidence files: `cs8-thinking.png`, `cs8-code.png`

### US-12: CS9 -- External Session Browsing

**As a** user
**I want to** browse Claude Code sessions created outside the iOS app
**So that** I can view my CLI-created sessions

**Acceptance Criteria:**
- [ ] AC-12.1: `GET /api/v1/sessions/scan` returns external sessions (curl evidence)
- [ ] AC-12.2: External sessions appear in sessions list with distinct indicator
- [ ] AC-12.3: Tapping an external session shows read-only message history (screenshot)
- [ ] AC-12.4: If no external sessions exist, document in evidence as "N/A -- no external sessions found"
- [ ] AC-12.5: Evidence files: `cs9-external.png` (or `cs9-na.txt`)

### US-13: CS10 -- Session Rename, Export, Info Sheet

**As a** user
**I want to** rename a session, view its info, and export the transcript
**So that** I can organize and share my conversations

**Acceptance Criteria:**
- [ ] AC-13.1: Rename a session via UI (screenshot: new name in sidebar/list)
- [ ] AC-13.2: `PUT /api/v1/sessions/:id` with new name returns 200 (curl evidence)
- [ ] AC-13.3: Session info sheet shows: name, model, message count, created/updated dates (screenshot)
- [ ] AC-13.4: Export triggers iOS share sheet (screenshot)
- [ ] AC-13.5: Evidence files: `cs10-renamed.png`, `cs10-info.png`, `cs10-export.png`

---

## Workstream 3: Streaming Reliability (P1)

### US-14: SSE Heartbeat/Keepalive

**As a** user
**I want** the app to detect stale SSE connections
**So that** I don't stare at a "connecting" spinner forever

**Acceptance Criteria:**
- [ ] AC-14.1: Backend sends SSE comment (`:heartbeat`) every 15 seconds during idle streaming
- [ ] AC-14.2: SSEClient treats missing heartbeat for >45s as connection error
- [ ] AC-14.3: On stale connection, SSEClient triggers reconnection with exponential backoff
- [ ] AC-14.4: Verify via curl: `curl -N POST /api/v1/chat/stream` shows `:heartbeat` comments

### US-15: SDK Remnant Cleanup

**As a** developer
**I want** all ClaudeCodeSDK references removed from the project
**So that** the build graph is clean

**Acceptance Criteria:**
- [ ] AC-15.1: `ClaudeCodeSDK` removed from `Package.resolved`
- [ ] AC-15.2: `ILSApp/build/SourcePackages/checkouts/ClaudeCodeSDK/` directory deleted (if exists)
- [ ] AC-15.3: `grep -r ClaudeCodeSDK .` returns 0 matches (excluding `.git/` and research docs)
- [ ] AC-15.4: Clean build succeeds after removal

---

## Workstream 4: Stub Cleanup (P1)

> Many stubs identified in agent-teams audit have been **deleted** (Fleet, SSH views, ConfigProfiles, ConfigOverrides, ConfigHistory, CloudSync, AutomationScripts). Remaining stubs are minimal.

### US-16: Remove or Wire Remaining Stubs

**As a** user
**I want** every visible UI element to either work or be clearly marked as planned
**So that** I'm never deceived by non-functional controls

**Acceptance Criteria:**
- [ ] AC-16.1: Extended Thinking and Co-Author rows in Settings show real values from `GET /api/v1/config` (currently display-only -- verify they read live config state)
- [ ] AC-16.2: SessionTemplate.defaults (4 hardcoded templates) documented as intentional local defaults (not a bug -- templates are local-first by design)
- [ ] AC-16.3: `testConnection()` in SettingsViewSections calls real health check endpoint (verify it uses `APIClient.healthCheck()`, not simulated delay)
- [ ] AC-16.4: LogViewerView reads from AppLogger or is hidden if non-functional (screenshot evidence)
- [ ] AC-16.5: NotificationPreferencesView persists preferences to UserDefaults (already implemented -- verify with screenshot)
- [ ] AC-16.6: No remaining `set: { _ in }`, `.disabled(true)`, `sampleFleet`, `sampleData`, `sampleHistory` patterns in codebase (`grep` returns 0)

---

## Workstream 5: Code Quality (P2)

### US-17: Split Large Files

**As a** developer
**I want** no Swift file to exceed 500 lines
**So that** the codebase stays maintainable

**Acceptance Criteria:**
- [ ] AC-17.1: `SettingsViewSections.swift` (594 lines) split into focused sections (Appearance, Connection, Config, About)
- [ ] AC-17.2: `ChatView.swift` (555 lines) split -- extract message list, input bar, or toolbar into sub-views
- [ ] AC-17.3: `ServerSetupSheet.swift` (518 lines) split -- extract connection mode views
- [ ] AC-17.4: `TunnelSettingsView.swift` (483 lines) split -- extract tunnel status, config sections
- [ ] AC-17.5: `wc -l` on every `.swift` file shows none exceeding 500 lines

### US-18: Dead Code Removal

**As a** developer
**I want** dead code removed
**So that** the codebase is lean

**Acceptance Criteria:**
- [ ] AC-18.1: Run Periphery dead code detection: `periphery scan --project ILSApp/ILSApp.xcodeproj --schemes ILSApp --targets ILSApp`
- [ ] AC-18.2: Remove confirmed-dead declarations (not false positives from dynamic SwiftUI usage)
- [ ] AC-18.3: Duplicate `APIResponse`/`ListResponse` types consolidated (ILSShared vs APIClient)
- [ ] AC-18.4: Build succeeds after removals
- [ ] AC-18.5: Empty view directories (`Views/Dashboard/`, `Views/MCP/`, `Views/Plugins/`, etc.) deleted if they contain no Swift files

### US-19: SwiftLint Pass

**As a** developer
**I want** zero SwiftLint violations on the iOS app
**So that** code style is consistent

**Acceptance Criteria:**
- [ ] AC-19.1: `swiftlint lint --path ILSApp/ILSApp/ --quiet` returns 0 violations (or only disabled rules)
- [ ] AC-19.2: `.swiftlint.yml` config exists with project-appropriate rules
- [ ] AC-19.3: Any auto-fixable violations corrected via `swiftlint --fix`

---

## Functional Requirements

| ID | Requirement | Priority | Verification |
|----|-------------|----------|-------------|
| FR-1 | Workspace builds backend on macOS | P0 | `xcodebuild -workspace -scheme ILSBackend` succeeds |
| FR-2 | Workspace builds iOS app on simulator | P0 | `xcodebuild -workspace -scheme ILSApp` succeeds |
| FR-3 | Backend health check passes | P0 | `curl localhost:9090/health` returns 200 |
| FR-4 | CS1: Basic send-receive-render | P0 | 3 screenshots + curl |
| FR-5 | CS2: Streaming cancellation | P0 | 3 screenshots + curl |
| FR-6 | CS3: Tool call rendering | P0 | 2 screenshots |
| FR-7 | CS4: Error recovery | P0 | 3 screenshots |
| FR-8 | CS5: Session fork + navigate | P1 | 2 screenshots + curl |
| FR-9 | CS6: Rapid-fire handling | P1 | 1 screenshot |
| FR-10 | CS7: Theme switching in chat | P1 | 2 screenshots |
| FR-11 | CS8: Code blocks + thinking | P1 | 2 screenshots |
| FR-12 | CS9: External session browsing | P1 | 1 screenshot + curl |
| FR-13 | CS10: Rename + export + info | P1 | 3 screenshots + curl |
| FR-14 | SSE heartbeat in streaming | P1 | curl shows `:heartbeat` |
| FR-15 | ClaudeCodeSDK remnants removed | P1 | grep returns 0 |
| FR-16 | No deceptive stubs remain | P1 | grep + screenshots |
| FR-17 | No file >500 lines | P2 | `wc -l` check |
| FR-18 | Dead code removed | P2 | Periphery scan clean |
| FR-19 | SwiftLint clean | P2 | `swiftlint` returns 0 |

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | Chat streaming latency | Time from Send to first token | <3 seconds (on local backend) |
| NFR-2 | App launch to interactive | Cold launch time | <2 seconds |
| NFR-3 | Backend memory footprint | RSS during idle | <100MB |
| NFR-4 | Build time (iOS) | Clean build time | <120 seconds |
| NFR-5 | Build time (Backend) | Clean build time | <60 seconds |
| NFR-6 | Code line limit | Max lines per file | 500 |

---

## Glossary

- **SSE**: Server-Sent Events -- HTTP streaming protocol used for chat responses
- **CS1-CS10**: Chat Scenarios 1-10 -- the 10 E2E validation scenarios from polish-again spec
- **ILSShared**: SPM library shared between backend and iOS app (models, DTOs)
- **Scheme**: Xcode build configuration specifying target, destination, environment
- **MarkdownUI**: Third-party SwiftUI markdown renderer replacing custom parser
- **HighlightSwift**: Third-party syntax highlighting library for code blocks
- **Periphery**: Dead code detection tool for Swift
- **NIO**: SwiftNIO -- async networking framework underlying Vapor
- **ClaudeCodeSDK**: Removed dependency (RunLoop/NIO incompatible) -- our Process+DispatchQueue replaces it

---

## Out of Scope

- **Agent Teams feature** -- 38-task new feature (separate spec, agent-teams)
- **App Store preparation** -- Privacy Manifest, screenshots, metadata (future spec)
- **SSH remote management** -- Backend SSHService exists but iOS integration deferred
- **iCloud sync** -- No implementation exists; future feature
- **XcodeGen/Tuist migration** -- Overkill for 2 targets; manual workspace is correct
- **swift-subprocess migration** -- Requires Package.swift tools-version upgrade; future improvement
- **WebSocket chat upgrade** -- SSE works; WebSocket is a future enhancement
- **Authentication/authorization** -- AuthController stub acknowledged but not alpha-blocking
- **Rate limiting / CORS hardening** -- Security improvements for production, not alpha
- **CI/CD pipeline** -- No git remote configured; PR workflow deferred

---

## Dependencies

- **Claude CLI v2.1.37+** installed and on PATH (backend subprocess execution)
- **Backend running on port 9090** for all E2E chat scenarios
- **Simulator 50523130-57AA-48B0-ABD0-4D59CE455F14** (iPhone 16 Pro Max, iOS 18.6)
- **Swift 6.2.4 / Xcode 26.3** toolchain
- **Network access** for SPM package resolution on first build

---

## Validation Protocol

Every claim of completion must follow this sequence:

1. **curl first** -- verify backend endpoint returns expected data
2. **build second** -- `xcodebuild` succeeds with 0 errors, 0 warnings
3. **install + launch** -- app installed and launched on dedicated simulator
4. **screenshot evidence** -- captured via `simulator_screenshot` and READ by the validator
5. **evidence reviewed** -- validator must open and describe what the screenshot shows before marking PASS

No claim without evidence. No evidence without review.

---

## Success Criteria

| Criterion | Measurement |
|-----------|-------------|
| Workspace builds both targets | 2 xcodebuild commands succeed |
| All 10 chat scenarios pass | 20+ screenshots in `specs/alpha/evidence/` |
| Zero deceptive stubs | grep audit returns 0 matches |
| All files <500 lines | wc -l audit passes |
| Backend healthy | curl /health returns 200 with Claude CLI version |
| Clean build | 0 errors, 0 warnings |

---

## Unresolved Questions

1. **CS2 streaming cancellation**: Claude CLI `-p` may hang as subprocess within active Claude Code session (known environment constraint). If so, document the limitation and validate cancel via curl only.
2. **CS9 external sessions**: Backend may not have external session data. If `/sessions/scan` returns empty, document as N/A rather than creating fake sessions.
3. **Extended Thinking toggle**: Currently display-only. Should it become a functional toggle (writes to config) or remain informational? Needs user decision.
4. **LogViewerView**: File exists but unclear if it reads real log data. Needs inspection during stub audit.
5. **Periphery false positives**: SwiftUI `@State`/`@Environment` properties often flagged as unused. May need suppression rules.

## Next Steps

1. Approve these requirements (or provide feedback for revision)
2. Generate design document with implementation plan
3. Generate task list with per-task verification commands
4. Execute Workstream 1 (Workspace) first -- unblocks all other work
5. Execute Workstream 2 (Chat Validation) -- the most important deliverable
6. Execute Workstreams 3-5 in parallel where possible
