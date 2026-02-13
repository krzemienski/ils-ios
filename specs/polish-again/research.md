---
spec: polish-again
phase: research
created: 2026-02-08T01:00:00Z
---

# Research: polish-again

## Executive Summary

Exhaustive audit of all 90 Swift files (75 ILSApp + 15 ILSShared) reveals **28 bugs/issues** across 6 categories: dead code (3), architecture smells (5), theme inconsistencies (6), chat system gaps (5), duplicated code (4), and unwired features (5). The chat system has a solid SSE streaming pipeline but lacks error recovery, reconnection, and edge case handling. The theme system has ID mismatches between ThemePickerView previews and actual theme structs that prevent 2 themes from being selectable.

## 1. Complete File Inventory

### ILSApp/ILSApp/ (75 Swift files)

| Category | Count | Files |
|----------|-------|-------|
| Core/App | 1 | ILSAppApp.swift (257 lines) |
| Services | 4 | APIClient (306), SSEClient (249), AppLogger (78), MetricsWebSocketClient (197) |
| ViewModels | 8 | ChatViewModel (433), DashboardViewModel (101), SessionsViewModel (160), ProjectsViewModel (142), PluginsViewModel (149), SkillsViewModel (209), MCPViewModel (203), SystemMetricsViewModel (128), BaseListViewModel (35) |
| Models | 4 | ChatMessage (79), SessionTemplate (70), PluginModels (27), MCPServerItem (23) |
| Views/Root | 3 | SidebarRootView (256), SidebarView (315), SidebarSessionRow (88) |
| Views/Home | 1 | HomeView (328) |
| Views/Chat | 7 | ChatView (561), AssistantCard (179), UserMessageCard (90), MarkdownTextView (112), StreamingIndicatorView (75), CommandPaletteView (175), ErrorMessageView (33), SystemMessageView (22) |
| Views/Sessions | 2 | NewSessionView (337), SessionInfoView (195) |
| Views/Browser | 2 | BrowserView (377), MCPServerDetailView (193) |
| Views/Settings | 5 | SettingsView (918!), TunnelSettingsView (505), ThemePickerView (198), LogViewerView (57), NotificationPreferencesView (122) |
| Views/System | 3 | SystemMonitorView (253), ProcessListView (129), FileBrowserView (293) |
| Views/Onboarding | 1 | ServerSetupSheet (518) |
| Theme/Core | 4 | AppTheme (166), ILSTheme (213), ThemeManager (3 - empty), EntityType (80), GlassCard (23) |
| Theme/Themes | 12 | Obsidian, Slate, Midnight, GhostProtocol, NeonNoir, ElectricGrid, Ember, Crimson, Carbon, Graphite, Paper, Snow (each ~60 lines) |
| Theme/Components | 14 | CodeBlockView (147), ToolCallAccordion (281), ThinkingSection (130), StatCard (68), SparklineChart (47), MetricChart (107), ProgressRing (78), ConnectionBanner (137), ConnectionSteps (98), EmptyEntityState (70), SkeletonRow (54), ShimmerModifier (48), AccentButton (33), EntityBadge (38), ILSCodeHighlighter (18) |
| Utils | 1 | DateFormatters (37) |

### Sources/ILSShared/ (15 Swift files)

| Category | Files |
|----------|-------|
| Models | Session (167), Message (51), StreamMessage (401), Project (45), Skill (81), Plugin (98), MCPServer (61), ClaudeConfig (207), ServerConnection (26) |
| DTOs | Requests (647), ConnectionResponse (73), SystemDTOs (118), TunnelDTOs (61), SearchResult (118), PaginatedResponse (14) |

**Total**: 90 files, ~9,800 lines (ILSApp) + ~2,168 lines (ILSShared) = ~11,968 lines

## 2. Navigation & Screen Map

```
ILSAppApp.swift
  |-- ServerSetupSheet (onboarding, first-time)
  |-- SidebarRootView (main container)
       |-- SidebarView (overlay on iPhone, persistent on iPad)
       |    |-- Session list grouped by project (DisclosureGroup)
       |    |-- SidebarSessionRow for each session
       |    |-- Quick actions: New Session, Settings, System
       |
       |-- ActiveScreen routing:
            |-- .home -> HomeView (dashboard, stats, recent sessions)
            |-- .chat(ChatSession) -> ChatView
            |    |-- AssistantCard -> MarkdownTextView, ThinkingSection, ToolCallAccordion, CodeBlockView
            |    |-- UserMessageCard
            |    |-- ErrorMessageView
            |    |-- SystemMessageView
            |    |-- StreamingIndicatorView
            |    |-- CommandPaletteView (sheet)
            |    |-- SessionInfoView (sheet)
            |    |-- ShareSheet (export)
            |
            |-- .browser -> BrowserView (segmented: MCP/Skills/Plugins)
            |    |-- MCPServerDetailView (NavigationLink)
            |
            |-- .system -> SystemMonitorView
            |    |-- ProcessListView (embedded)
            |    |-- FileBrowserView (NavigationLink)
            |
            |-- .settings -> SettingsView
                 |-- ThemePickerView (NavigationLink)
                 |-- TunnelSettingsView (NavigationLink)
                 |-- LogViewerView (NavigationLink)
                 |-- NotificationPreferencesView (NavigationLink)
                 |-- ConfigEditorView (sheet, inline in SettingsView)
```

## 3. Bug Catalog

### CRITICAL (3)

| # | Bug | File | Line | Impact |
|---|-----|------|------|--------|
| C1 | `isServerConnected: Bool = false` declared but NEVER set or read | ILSAppApp.swift | 46 | Dead code confuses maintainers |
| C2 | `serverConnectionInfo: ConnectionResponse?` declared but NEVER used | ILSAppApp.swift | 47 | Dead code |
| C3 | ThemePickerView preview IDs don't match actual theme IDs: `"ghost"` vs `"ghost-protocol"`, `"electric"` vs `"electric-grid"` | ThemePickerView.swift | 20,22 | Ghost Protocol and Electric Grid themes CANNOT be selected - `isAvailable` check always fails |

### HIGH (8)

| # | Bug | File | Impact |
|---|-----|------|--------|
| H1 | Redundant APIClient creation in `checkConnection()`, `startRetryPolling()`, `startHealthPolling()`, `connectToServer()` - each creates `let client = APIClient(baseURL:)` instead of using `self.apiClient` | ILSAppApp.swift lines 114,150,180,218 | Each call creates new actor instance, bypasses caching, potential state inconsistency |
| H2 | AppState is a God Object (257 lines) handling 7+ responsibilities: connection, URL, health polling, retry polling, scene phase, deep linking, onboarding | ILSAppApp.swift | Maintenance burden, untestable |
| H3 | SettingsView.swift is 918 lines with 4 types in one file (SettingsView + ConfigEditorView + SettingsViewModel + ConfigEditorViewModel) | SettingsView.swift | Violates single-responsibility, hard to navigate |
| H4 | EntityType.color uses DIFFERENT hex values than AppTheme protocol extension defaults (e.g., sessions: #007AFF vs #3B82F6, projects: #5856D6 vs #8B5CF6) | EntityType.swift vs AppTheme.swift | Inconsistent entity colors depending on which path is used |
| H5 | APIResponse and APIError types defined in BOTH ILSShared/DTOs/Requests.swift AND APIClient.swift | APIClient.swift + Requests.swift | Dual definitions may diverge, confusion about which to use |
| H6 | StreamingIndicatorView uses `Timer.scheduledTimer` (UIKit pattern) without invalidation on disappear | StreamingIndicatorView.swift | Timer leak, potential retain cycle, dots animation continues after view dismissed |
| H7 | SystemMonitorView creates new MetricsWebSocketClient on every `onAppear` (line ~125), replacing the one from init | SystemMonitorView.swift | Multiple WS connections, memory churn |
| H8 | CodeBlockView always uses `.dark(.xcode)` highlighting even on light themes (Paper, Snow) | CodeBlockView.swift line 126 | Dark syntax colors on light background = unreadable code blocks |

### MEDIUM (10)

| # | Bug | File | Impact |
|---|-----|------|--------|
| M1 | SidebarView has unwired buttons with "wired in Phase 5/3" comments | SidebarView.swift | New Session, Rename, Export context menu items may be no-ops |
| M2 | ShareSheet UIViewControllerRepresentable defined in BOTH ChatView.swift and SessionInfoView.swift | ChatView + SessionInfoView | Duplicated code |
| M3 | BaseListViewModel not inherited by ANY existing ViewModel - comment says "NOT yet inherited" | BaseListViewModel.swift | Dead code, 35 lines |
| M4 | ThemeManager.swift is essentially empty (3 lines, redirect comment) | ThemeManager.swift | Confusing file that does nothing |
| M5 | ConnectionBanner has duplicated view code - `ConnectionBanner` struct AND `ConnectionBannerModifier` with identical UI | ConnectionBanner.swift | ~80 lines of duplicated view hierarchy |
| M6 | HomeView creates its OWN SessionsViewModel and DashboardViewModel, not shared with SidebarView's | HomeView.swift | Duplicate data fetching, inconsistent state |
| M7 | ServerSetupSheet creates standalone APIClient (line 458) bypassing AppState | ServerSetupSheet.swift | Inconsistent with app's client management |
| M8 | NotificationPreferencesView state is all `@State` (local) - toggles reset on every appear | NotificationPreferencesView.swift | Settings don't persist |
| M9 | TunnelSettingsView defines private duplicate DTOs (TunnelStatusDTO, TunnelStartDTO, TunnelStopDTO) instead of using ILSShared's TunnelStatusResponse etc. | TunnelSettingsView.swift lines 479-496 | Duplicated types, may diverge from backend |
| M10 | FileBrowserView uses raw URLSession.shared bypassing APIClient entirely | FileBrowserView.swift lines 248-260 | No auth, no caching, no retry logic |

### LOW (7)

| # | Bug | File | Impact |
|---|-----|------|--------|
| L1 | DashboardViewModel generates synthetic sparkline data from seed values (not real trends) | DashboardViewModel.swift | Sparklines show fake data |
| L2 | `textOnAccent = Color.white` on ALL themes including light themes | All theme files | May cause contrast issues on light accent colors (Ghost Protocol's cyan, Electric Grid's green) |
| L3 | Crimson theme `accent == error` (both #EF4444) | CrimsonTheme.swift | Error states indistinguishable from normal accent |
| L4 | Ember theme warning (#EAB308) very close to accent (#F59E0B) | EmberTheme.swift | Warning states blend with accent |
| L5 | ChatInputBar `.onSubmit` fires on Return key | ChatView.swift | May send on Enter in multiline context |
| L6 | Token count approximation: `text.count / 4` | ChatViewModel.swift | Rough estimate, could be off by 2-3x |
| L7 | ILSCodeHighlighter ignores language parameter, returns unstyled Text | ILSCodeHighlighter.swift | Inline code has no syntax highlighting (only fenced blocks do via CodeBlockView) |

## 4. Chat System Deep Audit

### Architecture Flow

```
User types message
  -> ChatView.sendMessage()
    -> ChatViewModel.sendMessage(text)
      -> APIClient.post("/sessions/{id}/chat/stream", body: ChatStreamRequest)
      -> SSEClient.connect(url) -- Server-Sent Events
        -> SSEClient parses event/data/id fields
        -> ChatViewModel.processStreamMessage(StreamMessage)
          -> .system: stores claudeSessionId
          -> .assistant: iterates ContentBlock array
            -> .text: appends to current message text (batched 75ms)
            -> .toolUse: creates ToolCallDisplay with parsed input pairs
            -> .toolResult: matches by toolUseId, sets output
            -> .thinking: appends thinking text
          -> .result: finalizes message, updates cost/usage
          -> .error: creates error ChatMessage
          -> .permission: creates permission-type ChatMessage
```

### Chat System Issues

| Issue | Severity | Detail |
|-------|----------|--------|
| No reconnection on stream drop | HIGH | If SSE connection drops mid-stream, no retry. Message stuck in "streaming" state. |
| Cancel is fire-and-forget | MEDIUM | `cancel()` calls POST to backend but doesn't verify success or handle failure |
| No message persistence to local storage | MEDIUM | Messages only in memory (@Published). App termination = lost conversation |
| No duplicate message prevention | LOW | Rapid tapping "Send" could send same message twice |
| No input validation | LOW | Empty messages, whitespace-only, or extremely long messages not blocked |
| `loadMessageHistory()` branches on external vs ILS but both hit same API | INFO | Code structure suggests different handling was planned |

### SSE Client Robustness

| Feature | Status |
|---------|--------|
| Connection timeout | 60s via task group race |
| Reconnection attempts | 3 with exponential backoff (1s, 2s, 4s up to 30s) |
| Event ID tracking | Yes, lastEventId for resume |
| Cancel cleanup | Clears all state including lastEventId |
| Error propagation | Via Combine PassthroughSubject |
| Connection state | Enum: disconnected/connecting/connected/reconnecting |

### Message Batching

ChatViewModel uses 75ms batch intervals for smooth streaming UI:
- `pendingText` accumulates text deltas
- Timer fires every 75ms to flush to published message
- Prevents UI thrashing from rapid SSE events

## 5. Theme System Audit

### Architecture

- `AppTheme` protocol: 40+ properties (backgrounds, accents, text, semantic, borders, entities, glass, geometry, spacing, typography)
- `ThemeManager`: ObservableObject holding `currentTheme: any AppTheme`, persists to UserDefaults
- `ThemeEnvironmentKey`: SwiftUI environment key for `\.theme`
- 12 concrete themes: 10 dark + 2 light (Paper, Snow)

### Issues Found

| # | Issue | Severity |
|---|-------|----------|
| T1 | ThemePickerView IDs mismatch: `"ghost"` should be `"ghost-protocol"`, `"electric"` should be `"electric-grid"` | CRITICAL - prevents selection |
| T2 | ThemePickerView has DUPLICATE color definitions that don't exactly match actual theme files (e.g., textPrimary hex differences) | MEDIUM |
| T3 | EntityType.swift defines `color` property with system colors (#007AFF) while AppTheme uses different hex (#3B82F6) | HIGH |
| T4 | All 12 themes share identical geometry/spacing/typography values - could be extracted to protocol extension defaults | LOW (not a bug) |
| T5 | Glass effects use Color.white.opacity on dark themes and Color.black.opacity on light themes - correct but hardcoded | LOW |
| T6 | `isLight` property defaults to `false` in protocol, overridden only in Paper/Snow. CodeBlockView doesn't check it. | MEDIUM |

### Theme Token Coverage

All views use `@Environment(\.theme)` correctly. No remaining hardcoded `ILSTheme.` static color references (migration complete). Entity colors accessed via `entityType.themeColor(from: theme)` in most places except `EntityType.color` (hardcoded path).

## 6. API Integration Patterns

### APIClient (actor-based)

- Generic GET/POST/PUT/DELETE with `performWithRetry`
- 3 retry attempts with exponential backoff
- 30-second cache TTL with invalidation on mutations
- `validateResponse` checks HTTP status codes

### Inconsistencies

| Pattern | Where | Issue |
|---------|-------|-------|
| Uses APIClient | Most ViewModels, TunnelSettingsView | Correct path |
| Creates standalone APIClient | ILSAppApp.swift health checks, ServerSetupSheet | Bypasses shared instance |
| Uses raw URLSession.shared | FileBrowserView, SystemMetricsViewModel (processes) | No auth, no retry |
| Duplicates its own DTOs | TunnelSettingsView (3 private structs) | Should use ILSShared types |
| Duplicates APIResponse/APIError | APIClient.swift + ILSShared/Requests.swift | Dual definitions |

## 7. Reflection Issues Confirmed

| Issue from Reflection | Status | Detail |
|----------------------|--------|--------|
| `isServerConnected` vs `isConnected` | CONFIRMED | `isServerConnected` on line 46 is dead code. `isConnected` (line 41) is the real property. |
| Redundant APIClient creation | CONFIRMED | 4 locations create new `APIClient(baseURL:)` instead of using `self.apiClient` |
| Stale CLAUDE.md | CONFIRMED | References old ContentView/TabView architecture, not current sidebar system |
| AppState God Object | CONFIRMED | 257 lines, 7+ responsibilities. Could decompose into ConnectionManager, NavigationManager, PollingManager |
| Dirty git status | CONFIRMED | Deleted .omc files, untracked .claude/ and design-system/ directories |
| existential `any AppTheme` boxing overhead | CONFIRMED but LOW | All 40+ property accesses go through protocol witness table. Performance impact negligible for UI rendering frequency. |

## 8. Duplicate Model Problem

| Model | ILSShared | ILSApp (local) | Conflict |
|-------|-----------|-----------------|----------|
| Plugin | `Plugin` struct (69 lines) | `PluginItem` struct (15 lines) in PluginModels.swift | Different field names (Plugin.isEnabled vs PluginItem.isEnabled), different decodable shape |
| MCPServer | `MCPServer` struct with typed enums (MCPScope, MCPStatus) | `MCPServerItem` struct with raw Strings for scope/status | Type mismatch: enum vs string |
| APIResponse | In Requests.swift | In APIClient.swift | Two definitions of same concept |
| TunnelStatus | TunnelStatusResponse in TunnelDTOs.swift | TunnelStatusDTO in TunnelSettingsView.swift | Private duplicate |
| ServerConnection | In ServerConnection.swift (SSH-oriented) | Not used anywhere in ILSApp | Dead shared model |

## 9. Ten Complex Chat Test Scenarios

### Scenario 1: Basic Send-Receive-Render

**Preconditions**: Backend running on port 9090, active session exists
**Steps**:
1. Navigate to existing session via sidebar
2. Type "What is 2+2?" in input bar
3. Tap Send button
4. Observe streaming indicator appears
5. Wait for response to complete
**Expected**:
- StreamingIndicatorView visible during response
- AssistantCard renders with markdown text
- Message count increments
- Input bar clears and re-enables
- Jump-to-bottom button appears if scrolled up
**Evidence**: Screenshot of complete response with "4" visible

### Scenario 2: Streaming Cancellation Mid-Response

**Preconditions**: Backend running, active session
**Steps**:
1. Send a complex prompt: "Write a detailed 500-word essay about quantum computing"
2. While streaming indicator is active (within first 5 seconds), tap Stop button
3. Observe the streaming stops
4. Send a follow-up message: "Never mind, just say hello"
**Expected**:
- Streaming stops within 2 seconds of cancel
- Partial response remains visible in chat
- Input bar re-enables for new messages
- Follow-up message sends successfully
- Backend receives cancel POST at `/sessions/{id}/chat/cancel`
**Evidence**: Screenshot of partial response + follow-up response

### Scenario 3: Tool Call Rendering Chain

**Preconditions**: Backend running, active session in a project directory
**Steps**:
1. Send: "Read the file Package.swift and tell me what dependencies are used"
2. Wait for full response
3. Expand tool call accordion(s)
4. Verify tool call shows Read tool with file_path input
5. Verify output section shows file content
**Expected**:
- ToolCallAccordion renders with "doc.text" icon (Read tool)
- Input pairs show `file_path: /path/to/Package.swift`
- Output section shows file content (truncated to 5 lines, "Show more" button)
- Expand All / Collapse All buttons work
- Tool call has green checkmark when complete
**Evidence**: Screenshot of expanded tool call accordion

### Scenario 4: Error Recovery After Backend Restart

**Preconditions**: Backend running, connected, active session open in ChatView
**Steps**:
1. Stop the backend process (kill PORT=9090)
2. Observe ConnectionBanner appears ("Reconnecting...")
3. Wait 10 seconds (2 retry cycles at 5s intervals)
4. Restart backend: `PORT=9090 swift run ILSBackend`
5. Wait for health check to succeed
6. Send a message: "Are you still there?"
**Expected**:
- ConnectionBanner shows "Reconnecting..." with spinner
- After backend restart, banner briefly shows "Connected" (green) then auto-dismisses (2s)
- AppState.isConnected transitions: true -> false -> true
- Retry polling at 5-second intervals during disconnect
- Health polling resumes at 30-second intervals after reconnect
- New message sends successfully
**Evidence**: Screenshots of disconnected state, reconnected state, successful message

### Scenario 5: Session Fork and Navigate

**Preconditions**: Session with at least 3 messages
**Steps**:
1. Open session in ChatView
2. Tap toolbar menu (three dots)
3. Tap "Fork Session"
4. Observe fork alert appears
5. Tap "Open Fork" in the alert
6. Verify navigated to new forked session
7. Verify original session still exists in sidebar
**Expected**:
- Fork creates new session via POST to backend
- Alert shows "Session Forked" with "Open Fork" button
- Navigation switches to forked session (new ChatView instance)
- Forked session has `forkedFrom` set to original session ID
- Original session unchanged in sidebar list
- Forked session inherits message history
**Evidence**: Screenshot of fork alert, forked session with inherited messages

### Scenario 6: Rapid-Fire Message Sending

**Preconditions**: Active session, backend running
**Steps**:
1. Type "Message 1" and tap Send
2. Immediately type "Message 2" and tap Send (before first response completes)
3. Type "Message 3" and tap Send
4. Wait for all responses to complete
**Expected Behavior to Verify**:
- Does input bar disable during streaming? (Check `isStreaming` guard)
- If not disabled, do messages queue or fail?
- Does ChatViewModel handle concurrent SSE streams?
- Are all 3 user messages visible in scroll?
- Are responses properly ordered?
**Known Risk**: ChatViewModel has single `isStreaming` flag - second send while streaming may be blocked by guard. Need to verify the actual behavior.
**Evidence**: Screenshot showing message sequence

### Scenario 7: Theme Switching During Active Chat

**Preconditions**: Active chat session with messages visible, using Obsidian theme
**Steps**:
1. Note current colors of chat elements
2. Navigate to Settings -> Theme
3. Switch to Slate theme
4. Navigate back to chat session
5. Switch to Paper (light theme)
6. Verify all chat elements re-render with new theme
**Expected**:
- All text colors update (bgPrimary, textPrimary, accent)
- AssistantCard backgrounds change
- Tool call accordion borders update
- Code blocks maintain readability (BUG: dark highlighting on light theme)
- No UI flicker or layout jumps
- Theme persists across app restart
**Evidence**: Screenshots of same chat in 3 different themes

### Scenario 8: Long Message with Code Blocks and Thinking

**Preconditions**: Active session, backend running with thinking-capable model
**Steps**:
1. Send: "Think step by step about how to implement a binary search tree in Swift, then show me the code"
2. Wait for full response including thinking blocks
3. Expand ThinkingSection
4. Scroll through code blocks
5. Tap "Copy" on a code block
6. Verify "Show more" appears on long code blocks (>15 lines)
**Expected**:
- ThinkingSection renders with brain icon, collapsed by default
- Expanding shows italic thinking text
- Duration text shows character count ("Xk chars")
- Code blocks have language header, syntax highlighting
- Copy button copies to clipboard, shows "Copied" confirmation
- "Show more" button on code blocks >15 lines
- Horizontal scroll on wide code lines
**Evidence**: Screenshot of expanded thinking + code block

### Scenario 9: External Session (Read-Only) Browsing

**Preconditions**: Backend has external Claude Code sessions discovered (source: .external)
**Steps**:
1. Open sidebar
2. Find an external session (marked with arrow.down.circle icon)
3. Tap to open in ChatView
4. Verify read-only banner appears
5. Verify input bar is disabled or hidden
6. Try to send a message (should be blocked)
**Expected**:
- External session shows "External session" indicator in SidebarSessionRow
- ChatView shows read-only banner at top
- Message history loads from backend
- Input bar is disabled for external sessions
- No Send button or dimmed Send button
- Menu items (Rename, Delete, Fork) may still work or be hidden
**Evidence**: Screenshot of external session with read-only banner

### Scenario 10: Session Rename + Export + Info Sheet

**Preconditions**: Active session with messages
**Steps**:
1. Open session in ChatView
2. Tap menu -> Rename
3. Enter new name "Test Renamed Session"
4. Confirm rename
5. Verify sidebar updates with new name
6. Tap menu -> Session Info
7. Verify SessionInfoView shows: Name, Model, Status, Created, Last Active, Message Count, Cost
8. Dismiss info sheet
9. Tap menu -> Export
10. Verify ShareSheet appears with session content
**Expected**:
- Rename calls PUT to backend, sidebar reflects change
- Session Info sheet loads lazily from backend
- All LabeledContent fields populated
- Export generates text content and presents UIActivityViewController
- Copy Session ID button works (copies UUID to clipboard)
**Evidence**: Screenshots of rename, info sheet, export sheet

## 10. Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Build | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'platform=iOS Simulator,id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` | Xcode project |
| Build (quiet) | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -quiet build 2>&1 \| tail -5` | Xcode project |
| Install | `xcrun simctl install 50523130-57AA-48B0-ABD0-4D59CE455F14 <path-to-app>` | simctl |
| Launch | `xcrun simctl launch 50523130-57AA-48B0-ABD0-4D59CE455F14 com.ils.app` | simctl |
| Screenshot | `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot <path>.png` | simctl |
| Backend | `cd <project-root> && PORT=9090 swift run ILSBackend` | docs/RUNNING_BACKEND.md |
| Lint | Not found | N/A |
| TypeCheck | Not found (Swift compiler handles this during build) | N/A |
| Unit Test | Not found (project has no test targets configured) | N/A |
| E2E Test | Not found | N/A |

**Local CI**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -quiet build 2>&1 | tail -5`

## 11. Related Specs

| Spec | Relevance | Relationship | mayNeedUpdate |
|------|-----------|--------------|---------------|
| rebuild-ground-up | HIGH | Direct predecessor - this spec's bugs are the output of that rebuild | false |
| app-enhancements | MEDIUM | 42-task plan that was partially executed before rebuild-ground-up replaced it. Some tasks may still apply (markdown rendering improvements were completed) | false |
| ios-app-polish | LOW | Earlier polish pass, fully superseded by rebuild-ground-up | false |
| ios-app-polish2 | LOW | Second polish pass, also superseded | false |
| agent-teams | NONE | Unrelated (backend orchestration) | false |

## 12. Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | HIGH | All bugs are fixable with straightforward code changes |
| Effort Estimate | L | 28 bugs across 90 files, 10 test scenarios, refactoring SettingsView + AppState |
| Risk Level | MEDIUM | Theme ID mismatch is user-facing. AppState refactoring could introduce regressions |

## 13. Recommendations for Requirements

1. **Fix Critical Theme ID Mismatch First** (C3) - Ghost Protocol and Electric Grid themes are broken for users
2. **Remove Dead Code** (C1, C2, M3, M4) - Clean up isServerConnected, serverConnectionInfo, BaseListViewModel, empty ThemeManager.swift
3. **Unify Duplicate Models** - Replace PluginItem/MCPServerItem with ILSShared types; remove duplicate APIResponse/APIError; remove TunnelSettingsView private DTOs
4. **Fix StreamingIndicatorView Timer Leak** (H6) - Replace Timer.scheduledTimer with SwiftUI animation or invalidate on disappear
5. **Fix CodeBlockView Light Theme** (H8) - Check `theme.isLight` and use `.light(.xcode)` colors accordingly
6. **Decompose AppState** (H2) - Extract ConnectionManager, PollingManager, NavigationManager
7. **Split SettingsView.swift** (H3) - Extract SettingsViewModel, ConfigEditorView, ConfigEditorViewModel into separate files
8. **Unify EntityType Colors** (H4) - Remove hardcoded hex in EntityType.color, use only theme-based path
9. **Persist Notification Preferences** (M8) - Move from @State to @AppStorage or UserDefaults
10. **Execute All 10 Chat Test Scenarios** - With real backend, real simulator, real screenshots

## 14. Open Questions

1. Are the SidebarView "wired in Phase X" comments still accurate, or were those features actually implemented during rebuild-ground-up?
2. Should external sessions support any write operations (fork, rename)?
3. Is the 75ms message batching interval optimal, or should it be configurable?
4. Should FileBrowserView use APIClient instead of raw URLSession for consistency?
5. Should notification preferences be stored server-side or client-only?

## Sources

- All 75 ILSApp Swift files read in full
- All 15 ILSShared Swift files read in full
- specs/rebuild-ground-up/.progress.md
- specs/app-enhancements/tasks.md
- Project MEMORY.md (simulator UDID, port config, known issues)
