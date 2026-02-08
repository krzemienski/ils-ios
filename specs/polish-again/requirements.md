---
spec: polish-again
phase: requirements
created: 2026-02-07T20:00:00Z
---

# Requirements: ILS iOS Front-End Polish & Evidence-Based Validation

## Goal

Fix all 28 cataloged bugs (3 critical, 8 high, 10 medium, 7 low), execute 10 complex chat test scenarios with real backend evidence, decompose God Objects, unify duplicate models, and achieve zero known defects across all 75 ILSApp Swift files — validated exclusively through simulator screenshots and real backend interaction.

## User Decisions

| Question | Decision |
|----------|----------|
| Primary user | Nick (developer) managing ILS backend via iOS app |
| Priority | Code quality and correctness over new features |
| Success criteria | Zero known bugs, 10/10 chat scenarios passing with evidence, clean architecture |
| Validation method | Real simulator + real backend + screenshots only. No mocks, no test harnesses. |
| Simulator | iPhone 16 Pro Max UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` only |
| Backend port | 9090 |

---

## User Stories

### US-1: Critical Bug Fixes (Theme Selection + Dead Code)

**As a** user selecting themes
**I want** all 12 themes to be selectable and all dead code removed
**So that** I can use Ghost Protocol and Electric Grid themes, and the codebase has no confusing artifacts

**Acceptance Criteria:**
- [ ] AC-1.1: ThemePickerView IDs match actual theme struct IDs — `"ghost-protocol"` not `"ghost"`, `"electric-grid"` not `"electric"` — both themes selectable via tap
- [ ] AC-1.2: `isServerConnected: Bool = false` removed from ILSAppApp.swift (dead code, never set/read)
- [ ] AC-1.3: `serverConnectionInfo: ConnectionResponse?` removed from ILSAppApp.swift (dead code, never used)
- [ ] AC-1.4: Screenshot evidence: Theme Picker with Ghost Protocol selected, Theme Picker with Electric Grid selected

**Priority:** P0

---

### US-2: High-Priority Architecture Fixes

**As a** developer maintaining the codebase
**I want** God Objects decomposed, leaks fixed, and inconsistencies resolved
**So that** the code is maintainable, leak-free, and behaves consistently

**Acceptance Criteria:**
- [ ] AC-2.1: AppState health checks use `self.apiClient` instead of creating new `APIClient(baseURL:)` — 4 locations fixed (checkConnection, startRetryPolling, startHealthPolling, connectToServer)
- [ ] AC-2.2: AppState decomposed into focused components (ConnectionManager, PollingManager at minimum) — no single file >300 lines with >3 responsibilities
- [ ] AC-2.3: SettingsView.swift split into separate files: SettingsView, SettingsViewModel, ConfigEditorView, ConfigEditorViewModel — each <300 lines
- [ ] AC-2.4: EntityType.color removed or aligned to use `themeColor(from:)` exclusively — no hardcoded hex in EntityType.swift
- [ ] AC-2.5: Duplicate APIResponse/APIError in APIClient.swift removed — use ILSShared definitions only, or vice versa with clear single source
- [ ] AC-2.6: StreamingIndicatorView timer invalidated on `.onDisappear` or replaced with SwiftUI `TimelineView`/animation — no timer leak
- [ ] AC-2.7: SystemMonitorView reuses existing MetricsWebSocketClient on `onAppear` instead of creating new instance
- [ ] AC-2.8: CodeBlockView checks `theme.isLight` and uses light syntax highlighting colors on Paper/Snow themes
- [ ] AC-2.9: Build compiles with zero warnings, zero errors after all changes
- [ ] AC-2.10: Screenshot evidence: code block on Paper theme readable, code block on Obsidian theme readable

**Priority:** P0

---

### US-3: Medium-Priority Cleanup

**As a** developer reading the codebase
**I want** duplicated code consolidated, dead code removed, and patterns unified
**So that** every file has a single clear purpose and no surprises

**Acceptance Criteria:**
- [ ] AC-3.1: SidebarView "wired in Phase X" comments replaced with actual implementations or removed if already wired
- [ ] AC-3.2: ShareSheet extracted to shared file (e.g., `ShareSheet.swift`) — removed from both ChatView.swift and SessionInfoView.swift
- [ ] AC-3.3: BaseListViewModel.swift deleted (dead code, never inherited)
- [ ] AC-3.4: ThemeManager.swift either populated with real logic or deleted (currently 3-line redirect)
- [ ] AC-3.5: ConnectionBanner duplicate struct/modifier consolidated — single implementation
- [ ] AC-3.6: HomeView shares ViewModels with SidebarView (injected via @EnvironmentObject or init) — no duplicate creation
- [ ] AC-3.7: ServerSetupSheet uses AppState's APIClient or receives it via injection — no standalone creation
- [ ] AC-3.8: NotificationPreferencesView persists toggle state via @AppStorage or UserDefaults — survives app relaunch
- [ ] AC-3.9: TunnelSettingsView private DTOs removed — uses ILSShared's TunnelStatusResponse, TunnelStartRequest, TunnelStopRequest
- [ ] AC-3.10: FileBrowserView uses APIClient instead of raw URLSession.shared
- [ ] AC-3.11: Screenshot evidence: Notification preferences persist after app relaunch

**Priority:** P1

---

### US-4: Duplicate Model Unification

**As a** developer working with data models
**I want** a single source of truth for each model type
**So that** I never question which struct to use or risk divergence

**Acceptance Criteria:**
- [ ] AC-4.1: `MCPServerItem` (ILSApp) removed — all views use `MCPServer` from ILSShared with appropriate adapters if needed
- [ ] AC-4.2: `PluginModels.swift` / `PluginItem` (ILSApp) removed — all views use `Plugin` from ILSShared
- [ ] AC-4.3: Single APIResponse/APIError definition — either in ILSShared or APIClient, not both
- [ ] AC-4.4: TunnelSettingsView private DTOs removed (covered in AC-3.9)
- [ ] AC-4.5: Build compiles with zero errors after model unification
- [ ] AC-4.6: All list views (MCP, Plugins) render correctly with unified models — screenshot evidence

**Priority:** P1

---

### US-5: Low-Priority Polish

**As a** user with varied theme preferences
**I want** proper contrast, distinct semantic colors, and correct input behavior
**So that** the app is usable and visually correct across all themes

**Acceptance Criteria:**
- [ ] AC-5.1: `textOnAccent` uses computed contrast color (dark text for light accents, white for dark accents) instead of hardcoded white on all themes
- [ ] AC-5.2: Crimson theme accent changed to differ from error color by at least 2 hue steps (currently both #EF4444)
- [ ] AC-5.3: Ember theme warning color adjusted to differ from accent by at least 15% perceived brightness
- [ ] AC-5.4: ChatInputBar `.onSubmit` behavior reviewed — either disabled for multiline or sends only on Cmd+Return
- [ ] AC-5.5: Token count label clarified as "~approximate" or replaced with actual tokenizer if available
- [ ] AC-5.6: ILSCodeHighlighter handles language parameter for basic keyword highlighting (or document as intentional passthrough)
- [ ] AC-5.7: DashboardViewModel sparkline data sourced from real historical metrics or clearly labeled "Sample Data" in UI
- [ ] AC-5.8: Screenshot evidence: Crimson theme with visible distinction between accent and error states

**Priority:** P2

---

### US-6: Chat Scenario 1 — Basic Send-Receive-Render

**As a** user sending a simple message
**I want** the full send-stream-render cycle to work
**So that** basic chat functionality is confirmed working end-to-end

**Acceptance Criteria:**
- [ ] AC-6.1: Navigate to session via sidebar tap
- [ ] AC-6.2: Type "What is 2+2?" in input bar, tap Send
- [ ] AC-6.3: StreamingIndicatorView visible during response (animated dots or static "Responding..." with reduce motion)
- [ ] AC-6.4: AssistantCard renders with response text containing "4"
- [ ] AC-6.5: Input bar clears and re-enables after response completes
- [ ] AC-6.6: Message count visible in session info increments by 2 (user + assistant)
- [ ] AC-6.7: Screenshot evidence: completed response visible in chat

**Priority:** P0

---

### US-7: Chat Scenario 2 — Streaming Cancellation Mid-Response

**As a** user who changes their mind
**I want** to cancel a streaming response and continue chatting
**So that** I'm not stuck waiting for unwanted output

**Acceptance Criteria:**
- [ ] AC-7.1: Send complex prompt: "Write a detailed 500-word essay about quantum computing"
- [ ] AC-7.2: Tap Stop button within 5 seconds of streaming start
- [ ] AC-7.3: Streaming stops within 2 seconds of cancel tap
- [ ] AC-7.4: Partial response remains visible in chat (not deleted)
- [ ] AC-7.5: Input bar re-enables for new messages
- [ ] AC-7.6: Follow-up message "Never mind, just say hello" sends and receives response
- [ ] AC-7.7: Screenshot evidence: partial response + successful follow-up

**Priority:** P0

---

### US-8: Chat Scenario 3 — Tool Call Rendering Chain

**As a** user requesting file operations
**I want** tool calls rendered with correct icons, inputs, and expandable output
**So that** I can see exactly what the AI did

**Acceptance Criteria:**
- [ ] AC-8.1: Send: "Read the file Package.swift and tell me what dependencies are used"
- [ ] AC-8.2: ToolCallAccordion renders with "Tool Calls (N)" header
- [ ] AC-8.3: Read tool shows doc.text icon, file_path input pair
- [ ] AC-8.4: Output section shows file content (truncated with "Show more" if >15 lines)
- [ ] AC-8.5: Green checkmark visible on completed tool call
- [ ] AC-8.6: Expand/collapse individual tool calls works
- [ ] AC-8.7: Screenshot evidence: expanded tool call accordion with inputs and output

**Priority:** P0

---

### US-9: Chat Scenario 4 — Error Recovery After Backend Restart

**As a** user whose backend temporarily goes down
**I want** the app to detect disconnection, show status, and recover automatically
**So that** I can resume work without relaunching the app

**Acceptance Criteria:**
- [ ] AC-9.1: Kill backend process while ChatView is open
- [ ] AC-9.2: ConnectionBanner appears within 10 seconds showing "Reconnecting..." with spinner
- [ ] AC-9.3: AppState.isConnected transitions to false
- [ ] AC-9.4: Restart backend on port 9090
- [ ] AC-9.5: ConnectionBanner shows "Connected" then auto-dismisses within 5 seconds
- [ ] AC-9.6: AppState.isConnected transitions back to true
- [ ] AC-9.7: Send message "Are you still there?" — receives successful response
- [ ] AC-9.8: Screenshot evidence: disconnected banner, reconnected state, successful post-recovery message

**Priority:** P0

---

### US-10: Chat Scenario 5 — Session Fork and Navigate

**As a** user branching a conversation
**I want** to fork a session and navigate to the fork
**So that** I can explore alternative conversation paths

**Acceptance Criteria:**
- [ ] AC-10.1: Open session with 3+ messages in ChatView
- [ ] AC-10.2: Tap toolbar menu -> "Fork Session"
- [ ] AC-10.3: Fork alert appears with "Session Forked" message
- [ ] AC-10.4: Tap "Open Fork" navigates to new forked session
- [ ] AC-10.5: Forked session has `forkedFrom` metadata
- [ ] AC-10.6: Original session still visible in sidebar
- [ ] AC-10.7: Screenshot evidence: fork alert, forked session with inherited messages

**Priority:** P1

---

### US-11: Chat Scenario 6 — Rapid-Fire Message Sending

**As a** user sending messages quickly
**I want** the app to handle rapid sends gracefully
**So that** messages don't get lost, duplicated, or cause crashes

**Acceptance Criteria:**
- [ ] AC-11.1: Send "Message 1", immediately type and send "Message 2"
- [ ] AC-11.2: Verify `isStreaming` guard blocks second send while first is streaming (expected behavior)
- [ ] AC-11.3: If blocked: input bar shows disabled state or visual feedback
- [ ] AC-11.4: If queued: both messages and responses appear in order
- [ ] AC-11.5: No crash, no duplicate messages in scroll view
- [ ] AC-11.6: Screenshot evidence: message sequence in chat

**Priority:** P1

---

### US-12: Chat Scenario 7 — Theme Switching During Active Chat

**As a** user changing themes mid-conversation
**I want** all chat elements to re-render with new theme colors
**So that** the visual transition is seamless

**Acceptance Criteria:**
- [ ] AC-12.1: Open chat with messages visible (Obsidian theme)
- [ ] AC-12.2: Navigate to Settings -> Theme -> select Slate
- [ ] AC-12.3: Return to chat — all elements (cards, backgrounds, text, toolbar) use Slate colors
- [ ] AC-12.4: Switch to Paper (light theme) — code blocks readable (not dark-on-dark after H8 fix)
- [ ] AC-12.5: No UI flicker, no layout jumps during switch
- [ ] AC-12.6: Theme persists after simulated app restart
- [ ] AC-12.7: Screenshot evidence: same chat in Obsidian, Slate, and Paper themes

**Priority:** P1

---

### US-13: Chat Scenario 8 — Long Message with Code Blocks and Thinking

**As a** user requesting complex code output
**I want** thinking sections, code blocks, and markdown to render correctly
**So that** I can read AI reasoning and copy code

**Acceptance Criteria:**
- [ ] AC-13.1: Send: "Think step by step about how to implement a binary search tree in Swift, then show me the code"
- [ ] AC-13.2: ThinkingSection renders collapsed with brain icon and duration
- [ ] AC-13.3: Expanding ThinkingSection shows italic thinking text
- [ ] AC-13.4: Code blocks have language header ("swift"), syntax highlighting, copy button
- [ ] AC-13.5: Tap Copy — "Copied" confirmation shown
- [ ] AC-13.6: Code blocks >15 lines show "Show more" / max height 300pt with scroll
- [ ] AC-13.7: Screenshot evidence: expanded thinking section + syntax-highlighted code block

**Priority:** P1

---

### US-14: Chat Scenario 9 — External Session (Read-Only) Browsing

**As a** user viewing external Claude Code sessions
**I want** a clear read-only indicator and disabled input
**So that** I don't accidentally try to send messages to external sessions

**Acceptance Criteria:**
- [ ] AC-14.1: External session in sidebar shows distinct icon (arrow.down.circle or similar)
- [ ] AC-14.2: Tapping external session opens ChatView with read-only banner
- [ ] AC-14.3: Input bar disabled or hidden for external sessions
- [ ] AC-14.4: Message history loads and renders correctly
- [ ] AC-14.5: Screenshot evidence: external session with read-only state visible

**Priority:** P1

---

### US-15: Chat Scenario 10 — Session Rename + Export + Info Sheet

**As a** user managing sessions
**I want** rename, export, and info to work end-to-end
**So that** I can organize and share my conversations

**Acceptance Criteria:**
- [ ] AC-15.1: Tap menu -> Rename -> enter "Test Renamed Session" -> confirm
- [ ] AC-15.2: Sidebar updates with new name
- [ ] AC-15.3: Tap menu -> Session Info -> SessionInfoView shows Name, Model, Status, Created, Last Active, Message Count, Cost
- [ ] AC-15.4: Copy Session ID button copies UUID to clipboard
- [ ] AC-15.5: Tap menu -> Export -> ShareSheet appears with session transcript
- [ ] AC-15.6: Screenshot evidence: renamed session in sidebar, info sheet with populated fields, export sheet

**Priority:** P1

---

### US-16: Evidence Collection Infrastructure

**As a** validator confirming all fixes
**I want** every change verified with a simulator screenshot and backend interaction
**So that** no claim goes unverified

**Acceptance Criteria:**
- [ ] AC-16.1: All screenshots captured on simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14`
- [ ] AC-16.2: Backend running on port 9090 for all chat scenarios
- [ ] AC-16.3: Each bug fix has at least 1 screenshot showing the fix in effect
- [ ] AC-16.4: Each chat scenario has at least 1 screenshot per expected outcome
- [ ] AC-16.5: Screenshots stored in `specs/polish-again/evidence/` with descriptive filenames
- [ ] AC-16.6: Build compiles clean (zero warnings, zero errors) — build log captured as evidence
- [ ] AC-16.7: Evidence index file lists all screenshots with descriptions

**Priority:** P0

---

## Functional Requirements

### Critical (P0) — Must fix, blocks user functionality

| ID | Requirement | Bug | File(s) | Acceptance Criteria |
|----|-------------|-----|---------|---------------------|
| FR-C1 | Remove `isServerConnected: Bool = false` dead property | C1 | ILSAppApp.swift:46 | Property gone; no references in codebase; build succeeds |
| FR-C2 | Remove `serverConnectionInfo: ConnectionResponse?` dead property | C2 | ILSAppApp.swift:47 | Property gone; no references in codebase; build succeeds |
| FR-C3 | Fix ThemePickerView theme ID mismatches: `"ghost"` -> `"ghost-protocol"`, `"electric"` -> `"electric-grid"` | C3 | ThemePickerView.swift:20,22 | Both themes selectable; screenshot of each selected |

### High (P0) — Architecture/correctness, significant impact

| ID | Requirement | Bug | File(s) | Acceptance Criteria |
|----|-------------|-----|---------|---------------------|
| FR-H1 | Replace 4 redundant `APIClient(baseURL:)` creations with `self.apiClient` | H1 | ILSAppApp.swift:114,150,180,218 | Grep for `APIClient(baseURL` in ILSAppApp returns 0 matches (except initial init) |
| FR-H2 | Decompose AppState God Object into focused managers | H2 | ILSAppApp.swift (257 lines) | AppState <150 lines; ConnectionManager + PollingManager extracted; build succeeds |
| FR-H3 | Split SettingsView.swift into 4 files | H3 | SettingsView.swift (918 lines) | SettingsView.swift <300 lines; ConfigEditorView.swift, SettingsViewModel.swift, ConfigEditorViewModel.swift exist separately |
| FR-H4 | Unify EntityType colors with theme system | H4 | EntityType.swift, AppTheme.swift | EntityType.color removed or delegates to theme; grep for hardcoded hex in EntityType returns 0 |
| FR-H5 | Remove duplicate APIResponse/APIError — single source of truth | H5 | APIClient.swift, Requests.swift | Only one definition exists; all consumers use it; build succeeds |
| FR-H6 | Fix StreamingIndicatorView timer leak | H6 | StreamingIndicatorView.swift | Timer invalidated on disappear, or replaced with SwiftUI animation; no retain cycle |
| FR-H7 | Fix SystemMonitorView WebSocket recreation on every onAppear | H7 | SystemMonitorView.swift | Single WS client reused; onAppear only reconnects if disconnected |
| FR-H8 | Fix CodeBlockView dark syntax highlighting on light themes | H8 | CodeBlockView.swift:126 | `theme.isLight` checked; light themes use light color scheme; screenshot proof |

### Medium (P1) — Duplication, dead code, inconsistency

| ID | Requirement | Bug | File(s) | Acceptance Criteria |
|----|-------------|-----|---------|---------------------|
| FR-M1 | Wire or remove SidebarView "Phase X" placeholder comments | M1 | SidebarView.swift | Zero "wired in Phase" comments; buttons either functional or removed |
| FR-M2 | Extract ShareSheet to shared file | M2 | ChatView.swift, SessionInfoView.swift | Single `ShareSheet.swift`; both views import it; grep shows 1 definition |
| FR-M3 | Delete BaseListViewModel.swift (dead code) | M3 | BaseListViewModel.swift (35 lines) | File deleted; build succeeds |
| FR-M4 | Delete or populate ThemeManager.swift (3-line empty redirect) | M4 | ThemeManager.swift | File deleted or contains real logic; no empty redirect |
| FR-M5 | Consolidate ConnectionBanner struct + modifier duplicate | M5 | ConnectionBanner.swift | Single implementation; ~40 lines saved; build succeeds |
| FR-M6 | Share ViewModels between HomeView and SidebarView | M6 | HomeView.swift | HomeView receives injected VMs; no `= SessionsViewModel()` inside HomeView |
| FR-M7 | ServerSetupSheet uses injected/shared APIClient | M7 | ServerSetupSheet.swift:458 | No standalone `APIClient(baseURL:)` in ServerSetupSheet; uses AppState's client |
| FR-M8 | Persist NotificationPreferencesView toggles | M8 | NotificationPreferencesView.swift | Toggles use @AppStorage; values survive app relaunch; screenshot proof |
| FR-M9 | Remove TunnelSettingsView private DTOs, use ILSShared types | M9 | TunnelSettingsView.swift:479-496 | Private TunnelStatusDTO/TunnelStartDTO/TunnelStopDTO deleted; ILSShared types used |
| FR-M10 | FileBrowserView uses APIClient instead of raw URLSession | M10 | FileBrowserView.swift:248-260 | Zero `URLSession.shared` in FileBrowserView; uses APIClient methods |

### Low (P2) — Visual polish, minor UX

| ID | Requirement | Bug | File(s) | Acceptance Criteria |
|----|-------------|-----|---------|---------------------|
| FR-L1 | DashboardViewModel sparklines use real data or label "Sample" | L1 | DashboardViewModel.swift | Real metrics endpoint data or "Sample Data" label visible |
| FR-L2 | Compute textOnAccent based on accent luminance | L2 | All 12 theme files | Light accent themes use dark textOnAccent; WCAG AA contrast met |
| FR-L3 | Crimson theme: differentiate accent from error | L3 | CrimsonTheme.swift | Accent and error differ by at least 2 hue steps; visually distinct |
| FR-L4 | Ember theme: differentiate warning from accent | L4 | EmberTheme.swift | Warning and accent differ by >15% perceived brightness |
| FR-L5 | ChatInputBar .onSubmit behavior fix | L5 | ChatView.swift | Return key inserts newline; Cmd+Return or Send button sends |
| FR-L6 | Token count labeled approximate | L6 | ChatViewModel.swift | Display shows "~N tokens" or tooltip explains approximation |
| FR-L7 | ILSCodeHighlighter handles language parameter | L7 | ILSCodeHighlighter.swift | Basic keyword coloring for common languages (Swift, Python, JS) or documented as passthrough |

### Duplicate Model Unification (P1)

| ID | Requirement | Files | Acceptance Criteria |
|----|-------------|-------|---------------------|
| FR-DM1 | Remove MCPServerItem, use MCPServer from ILSShared | MCPServerItem.swift, MCPViewModel.swift, BrowserView.swift | MCPServerItem.swift deleted; all references use MCPServer; build succeeds |
| FR-DM2 | Remove PluginModels.swift/PluginItem, use Plugin from ILSShared | PluginModels.swift, PluginsViewModel.swift, BrowserView.swift | PluginModels.swift deleted; all references use Plugin; build succeeds |
| FR-DM3 | Single APIResponse/APIError definition | APIClient.swift, Requests.swift | One definition; consumers unified; build succeeds |
| FR-DM4 | Remove TunnelSettingsView private DTOs | TunnelSettingsView.swift | Use ILSShared TunnelDTOs; private structs deleted |

### Chat Test Scenarios (P0/P1)

| ID | Scenario | Priority | Acceptance Criteria Reference |
|----|----------|----------|-------------------------------|
| FR-CS1 | Basic Send-Receive-Render | P0 | AC-6.1 through AC-6.7 |
| FR-CS2 | Streaming Cancellation Mid-Response | P0 | AC-7.1 through AC-7.7 |
| FR-CS3 | Tool Call Rendering Chain | P0 | AC-8.1 through AC-8.7 |
| FR-CS4 | Error Recovery After Backend Restart | P0 | AC-9.1 through AC-9.8 |
| FR-CS5 | Session Fork and Navigate | P1 | AC-10.1 through AC-10.7 |
| FR-CS6 | Rapid-Fire Message Sending | P1 | AC-11.1 through AC-11.6 |
| FR-CS7 | Theme Switching During Active Chat | P1 | AC-12.1 through AC-12.7 |
| FR-CS8 | Long Message with Code Blocks + Thinking | P1 | AC-13.1 through AC-13.7 |
| FR-CS9 | External Session (Read-Only) Browsing | P1 | AC-14.1 through AC-14.5 |
| FR-CS10 | Session Rename + Export + Info Sheet | P1 | AC-15.1 through AC-15.6 |

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | Clean build | Compiler warnings + errors | 0 warnings, 0 errors after all changes |
| NFR-2 | File size discipline | Lines per file | No file >500 lines (current max: SettingsView 918 lines) |
| NFR-3 | Single responsibility | Responsibilities per type | No type handles >3 distinct concerns |
| NFR-4 | No dead code | Unused declarations | Zero unreferenced properties, types, or files |
| NFR-5 | No duplicate types | Model definitions | Each concept has exactly 1 struct definition |
| NFR-6 | API consistency | URLSession bypass count | Zero raw URLSession.shared calls in view code |
| NFR-7 | Memory safety | Timer/subscription leaks | All timers invalidated on disappear; all subscriptions cancelled |
| NFR-8 | Theme correctness | WCAG AA contrast | 4.5:1 body text, 3:1 large text on all 12 themes |
| NFR-9 | Evidence completeness | Screenshot coverage | Every bug fix + every chat scenario has screenshot proof |
| NFR-10 | No regressions | Existing features | SSE streaming, sidebar navigation, onboarding all still work after refactoring |

---

## Glossary

- **God Object**: Class/struct with too many responsibilities (>3), violating single-responsibility principle
- **God File**: Source file containing multiple unrelated types (>500 lines)
- **Dead Code**: Declarations never referenced anywhere in the codebase
- **Evidence**: Simulator screenshot or build log proving a claim
- **SSE**: Server-Sent Events — streaming protocol for real-time AI responses over HTTP
- **ILSShared**: Swift package containing models/DTOs shared between iOS app and backend
- **EntityType**: Enum defining 6 colored entity categories (session, project, skill, mcp, plugin, system)
- **AppTheme**: Protocol defining 40+ visual design tokens (colors, spacing, typography)
- **ThemePickerView**: Grid UI for selecting one of 12 themes
- **StreamingIndicatorView**: Animated dots shown while AI response streams
- **ToolCallAccordion**: Expandable UI component showing AI tool operations (Read, Write, Bash, etc.)
- **ConnectionBanner**: Top-of-screen banner showing backend connection status
- **Fire-and-forget**: Async call that ignores success/failure — no error handling
- **WCAG AA**: Web Content Accessibility Guidelines level AA — minimum contrast ratios for readable text

---

## Out of Scope

- New features or screens (this is polish, not feature development)
- Backend code changes (controllers, routes, services, migrations)
- ILSShared model changes (read-only dependency for this spec)
- New backend API endpoints
- Push notifications implementation
- Authentication / login system
- App Store submission (TestFlight, certificates, provisioning)
- Localization / internationalization
- watchOS or macOS companion apps
- Performance profiling with Instruments (unless a specific perf bug surfaces)
- iPad-specific layout changes (beyond verifying existing layout isn't broken)
- Offline caching improvements
- Custom font loading
- Unit tests, integration tests, or test frameworks of any kind

---

## Dependencies

| Dependency | Type | Impact if Missing |
|------------|------|-------------------|
| Backend running on port 9090 | Runtime | Cannot execute any of the 10 chat scenarios |
| Simulator UDID `50523130-57AA-48B0-ABD0-4D59CE455F14` | Tooling | Cannot capture evidence screenshots |
| ILSShared package (read-only) | Code | Model unification must use existing ILSShared types as-is |
| Xcode build system | Tooling | Cannot validate build cleanliness |
| Existing SSE streaming pipeline | Code | Chat scenarios depend on ChatViewModel/SSEClient working |
| `@Environment(\.theme)` infrastructure | Code | Theme fixes depend on existing EnvironmentKey plumbing |

---

## Risk Assessment

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| AppState decomposition breaks navigation or connection | Critical | Medium | Extract one manager at a time; rebuild + test after each extraction; keep AppState as thin coordinator |
| Model unification breaks decoding from backend JSON | High | Medium | Verify ILSShared types decode same JSON as removed ILSApp types before deleting; test with real backend data |
| SettingsView split introduces missing @Binding or @EnvironmentObject | High | Low | Extract one type at a time; build after each; verify Settings screen navigates correctly |
| EntityType.color removal breaks views using it | Medium | Medium | Grep all callers before removing; provide theme-based replacement |
| StreamingIndicatorView animation change affects UX | Low | Low | Match existing visual behavior; screenshot before/after comparison |
| Theme ID fix changes persisted UserDefaults value | Medium | Medium | Handle migration: if stored theme ID is "ghost", map to "ghost-protocol" on load |
| Backend unavailable during chat scenario testing | High | Low | Document exact backend startup command; verify health before each scenario |
| Rapid-fire test (CS6) exposes concurrency bug | Medium | Medium | Document actual behavior even if suboptimal; file follow-up if crash found |
| External session test (CS9) requires external sessions in backend data | Medium | Medium | Verify backend has external sessions; create test data if needed |

---

## Success Criteria

| Criterion | Measurement | Target |
|-----------|-------------|--------|
| Bug fixes complete | Bugs remaining | 0 of 28 |
| Chat scenarios passing | Scenarios with evidence | 10 of 10 |
| Build cleanliness | Compiler output | 0 warnings, 0 errors |
| Dead code eliminated | Unreferenced declarations | 0 dead properties, 0 dead files |
| Duplicate models unified | Duplicate type count | 0 (every concept has 1 definition) |
| God Objects decomposed | Max file size | No file >500 lines |
| Evidence collected | Screenshots | 1+ per bug fix, 1+ per chat scenario step |
| No regressions | Existing features | SSE streaming, navigation, onboarding all verified working |

---

## Unresolved Questions

1. **Theme ID migration**: If a user has `"ghost"` stored in UserDefaults from before the fix, should ThemeManager auto-migrate to `"ghost-protocol"`, or will they just get the default theme?
2. **SidebarView "Phase X" comments**: Are these buttons actually wired from the rebuild-ground-up work, or are they truly dead? Need to trace each button's action closure.
3. **External sessions in test data**: Does the current backend on port 9090 have any `.external` source sessions, or do we need to create test data for Chat Scenario 9?
4. **NotificationPreferencesView scope**: Should notifications be stored server-side (for cross-device sync) or client-only (@AppStorage)? User decision defaulted to @AppStorage.
5. **BaseListViewModel intent**: Was this scaffolding for future use, or truly dead? Deleting is safe since nothing inherits it, but worth noting.
6. **FileBrowserView auth**: When switching from URLSession to APIClient, does the file browser endpoint require any auth headers the raw URLSession is missing?

---

## Execution Order Recommendation

| Phase | Work | Priority | Dependencies |
|-------|------|----------|--------------|
| 1 | Critical bug fixes (C1-C3) + theme ID migration | P0 | None |
| 2 | High bug fixes (H1-H8) — timer leak, CodeBlockView, entity colors, redundant APIClient | P0 | Phase 1 |
| 3 | AppState decomposition (H2) | P0 | Phase 2 (so other H-fixes are stable first) |
| 4 | SettingsView split (H3) | P0 | Phase 3 |
| 5 | Medium bug fixes (M1-M10) | P1 | Phase 4 |
| 6 | Duplicate model unification (DM1-DM4) | P1 | Phase 5 |
| 7 | Low bug fixes (L1-L7) | P2 | Phase 6 |
| 8 | Chat Scenarios 1-4 (P0 scenarios) | P0 | Phase 2 (code fixes needed first) |
| 9 | Chat Scenarios 5-10 (P1 scenarios) | P1 | Phase 7 |
| 10 | Final evidence collection + build verification | P0 | All phases |

---

## Next Steps

1. User approves requirements (this document)
2. Generate task breakdown from phases above — one task per FR or small FR group
3. Begin Phase 1: critical theme ID fix + dead code removal
4. Execute each phase with build verification after every change
5. Run all 10 chat scenarios with real backend and capture evidence
6. Final architect verification of zero warnings, zero dead code, zero duplicates
