---
spec: app-enhancements
phase: requirements
created: 2026-02-07
---

# Requirements: App Enhancements — Chat Rendering + Backend Overhaul

## Goal

Overhaul chat rendering (markdown, syntax highlighting, tool calls, streaming UX) and harden backend APIs (error middleware, validation, pagination, performance) to production quality. Absorb all 21 remaining audit fixes (12 MEDIUM + 9 LOW) to avoid double-touching files.

## User Decisions (from Interview)

| Question | Answer | Impact |
|----------|--------|--------|
| Primary users | End users via App Store | Polish and accessibility are P0 |
| Priority tradeoffs | Feature completeness over speed | Cover all gaps before shipping |
| Success criteria | Full overhaul + absorb 43 audit issues | Single mega-spec, no leftover specs |
| Validation approach | Functional only (no unit tests) | Screenshots + real UI per project mandate |

---

## User Stories

### US-1: Rich Markdown in Chat Messages
**As a** user reading Claude responses
**I want** tables, blockquotes, task lists, strikethrough, and horizontal rules rendered correctly
**So that** formatted responses display as intended, not as raw text

**Acceptance Criteria:**
- [ ] AC-1.1: Tables render with headers, alignment, and cell borders
- [ ] AC-1.2: Blockquotes render with left bar and indentation
- [ ] AC-1.3: Horizontal rules (`---`, `***`) render as divider lines
- [ ] AC-1.4: Strikethrough (`~~text~~`) renders with line-through style
- [ ] AC-1.5: Nested lists render with proper indentation (2+ levels)
- [ ] AC-1.6: Task lists (`- [ ]`, `- [x]`) render with checkboxes
- [ ] AC-1.7: Combined bold+italic (`***text***`) renders correctly
- [ ] AC-1.8: Escaped characters (`\*`, `\#`) render as literals
- [ ] AC-1.9: MarkdownUI (or equivalent) added to Package.swift with iOS 17+ target
- [ ] AC-1.10: Streaming messages re-render incrementally without full re-parse flicker

### US-2: Syntax-Highlighted Code Blocks
**As a** user reading code in chat
**I want** grammar-aware syntax highlighting with language detection
**So that** code is readable and visually distinct by token type

**Acceptance Criteria:**
- [ ] AC-2.1: HighlightSwift integrated — 50+ languages supported
- [ ] AC-2.2: Language label shown in code block header (auto-detected if not specified)
- [ ] AC-2.3: Line numbers displayed (toggleable via tap)
- [ ] AC-2.4: Copy button copies code content only (not line numbers)
- [ ] AC-2.5: Highlighting runs on background thread (no main-thread blocking on long blocks)
- [ ] AC-2.6: Theme colors consistent with ILSTheme dark mode palette
- [ ] AC-2.7: Old keyword-only highlighter fully removed

### US-3: Improved Tool Call Display
**As a** user monitoring Claude's tool usage
**I want** structured input/output display with expand/collapse controls
**So that** I can quickly understand what tools did without reading raw JSON

**Acceptance Criteria:**
- [ ] AC-3.1: Tool inputs shown as key-value pairs (not raw string)
- [ ] AC-3.2: Tool outputs truncated to 5 lines in collapsed state with "Show more"
- [ ] AC-3.3: "Expand All" / "Collapse All" button for multiple tool calls in one message
- [ ] AC-3.4: Collapsed state shows 1-line summary (tool name + status icon)
- [ ] AC-3.5: Output content searchable via Cmd+F / in-app search
- [ ] AC-3.6: Error tool calls highlighted with red accent

### US-4: Enhanced Thinking Sections
**As a** user observing Claude's reasoning
**I want** markdown rendering inside thinking blocks with length indicator
**So that** I can read structured thinking and know how much reasoning occurred

**Acceptance Criteria:**
- [ ] AC-4.1: Thinking text supports markdown (bold, italic, lists, code spans)
- [ ] AC-4.2: Character count shown in collapsed header (e.g., "Thinking (2,431 chars)")
- [ ] AC-4.3: Expand/collapse animates smoothly (respects reduce-motion)
- [ ] AC-4.4: Long thinking blocks (>50 lines) show scroll indicator

### US-5: Message-Level Actions
**As a** user managing chat messages
**I want** copy-as-markdown, retry, and delete actions on individual messages
**So that** I can reuse content and manage conversation flow

**Acceptance Criteria:**
- [ ] AC-5.1: Long-press on message shows action menu (Copy, Retry, Delete)
- [ ] AC-5.2: "Copy" copies markdown source, not rendered plain text
- [ ] AC-5.3: "Retry" resends the preceding user message and removes assistant response
- [ ] AC-5.4: "Delete" removes message from local display with confirmation
- [ ] AC-5.5: Actions use HapticManager feedback
- [ ] AC-5.6: VoiceOver announces available actions via accessibilityCustomContent

### US-6: Reliable SSE Streaming
**As a** user with intermittent connectivity
**I want** the app to reconnect seamlessly and resume from the last received event
**So that** I never lose streamed content during network blips

**Acceptance Criteria:**
- [ ] AC-6.1: Server emits sequential event IDs on each SSE message
- [ ] AC-6.2: Client sends `Last-Event-ID` header on reconnect
- [ ] AC-6.3: Server resumes from requested event ID (replays missed events)
- [ ] AC-6.4: Reconnection uses true exponential backoff (2s, 4s, 8s, 16s, max 30s)
- [ ] AC-6.5: Connection status shown in UI (Connected / Reconnecting / Disconnected)
- [ ] AC-6.6: Heartbeat (15s) timeout triggers reconnect attempt

### US-7: Streaming UX Improvements
**As a** user waiting for Claude's response
**I want** visible progress indicators and smooth auto-scroll
**So that** I know the system is working and can follow output in real-time

**Acceptance Criteria:**
- [ ] AC-7.1: Token count and elapsed time shown during streaming
- [ ] AC-7.2: Auto-scroll follows new content unless user has scrolled up
- [ ] AC-7.3: "Jump to bottom" button appears when scrolled up during streaming
- [ ] AC-7.4: Scroll-to-bottom animates smoothly (no jarring jumps)
- [ ] AC-7.5: Timer-based batch processing replaced with Task-based (from audit M-MEM-1)

### US-8: Backend Error Consistency
**As a** developer consuming the API
**I want** structured JSON error responses with error codes on every endpoint
**So that** the iOS app can display meaningful error messages

**Acceptance Criteria:**
- [ ] AC-8.1: Global `ErrorMiddleware` returns `{ "error": true, "reason": "...", "code": "..." }`
- [ ] AC-8.2: All `Abort` throws include machine-readable error code string
- [ ] AC-8.3: Validation errors return 422 with field-level detail
- [ ] AC-8.4: 500 errors never expose internal stack traces
- [ ] AC-8.5: iOS APIClient maps error codes to user-facing messages

### US-9: API Pagination and Validation
**As a** user with hundreds of sessions
**I want** paginated session lists and validated inputs
**So that** the app stays responsive and rejects malformed requests

**Acceptance Criteria:**
- [ ] AC-9.1: `/sessions` supports `?page=1&limit=20` with default limit 50
- [ ] AC-9.2: Response includes `total` count and `hasMore` boolean
- [ ] AC-9.3: iOS SessionsListView loads pages on scroll (infinite scroll)
- [ ] AC-9.4: Empty prompt rejected with 422 before reaching Claude CLI
- [ ] AC-9.5: Invalid UUID path params return 400 (not 500)

### US-10: Backend Code Quality
**As a** developer maintaining the backend
**I want** DRY streaming code, proper DI, and no unsafe pointers
**So that** the codebase is safe, readable, and extensible

**Acceptance Criteria:**
- [ ] AC-10.1: StreamingService refactored — shared SSE logic extracted (eliminate 80% duplication)
- [ ] AC-10.2: Controllers receive FileSystemService via DI (not `let fs = FileSystemService()`)
- [ ] AC-10.3: SystemController.liveMetrics uses actor-safe cancellation (no UnsafeMutablePointer)
- [ ] AC-10.4: ProjectsController.show() uses direct lookup (not O(n) filter)
- [ ] AC-10.5: ChatMessage model extracted from MessageView.swift to Models/ChatMessage.swift
- [ ] AC-10.6: All 30+ print() statements replaced with AppLogger

### US-11: Concurrency and Memory Safety (Audit Absorption)
**As a** developer preparing for Swift 6
**I want** Sendable-safe concurrency patterns and no leaked timers
**So that** the codebase compiles cleanly under strict concurrency

**Acceptance Criteria:**
- [ ] AC-11.1: URLSession instances dedicated per-ViewModel (not .shared in @MainActor) — M-CONC-1
- [ ] AC-11.2: Task captures use [weak self] with nonisolated clarity — M-CONC-2
- [ ] AC-11.3: Decoder/Encoder instances marked nonisolated or scoped locally — L-CONC-1
- [ ] AC-11.4: Timer.scheduledTimer replaced with Task-based loop in ChatViewModel — M-MEM-1
- [ ] AC-11.5: DispatchQueue.asyncAfter replaced with Task.sleep + cancellation — M-MEM-2
- [ ] AC-11.6: cancellables.removeAll() in ChatViewModel deinit — L-MEM-1

### US-12: Architecture and Theming (Audit Absorption)
**As a** developer working on the UI
**I want** clean Published patterns, extracted formatters, and theme-consistent fonts
**So that** code is maintainable and visually consistent

**Acceptance Criteria:**
- [ ] AC-12.1: Published+didSet refactored to explicit update methods — M-ARCH-1
- [ ] AC-12.2: RelativeDateTimeFormatter extracted to DateFormatters namespace — M-ARCH-2
- [ ] AC-12.3: Complex computed properties (>15 lines) extracted to ViewModel methods — L-ARCH-1
- [ ] AC-12.4: 10 hardcoded .font(.system(size:)) replaced with ILSTheme — L-PERF-1
- [ ] AC-12.5: Redundant objectWillChange.send() removed — L-PERF-2
- [ ] AC-12.6: Screenshots confirm no visual regression after font changes

### US-13: Network Reliability (Audit Absorption)
**As a** user on unreliable networks
**I want** smarter caching, optimized retries, and resilient fallbacks
**So that** the app recovers faster from failures

**Acceptance Criteria:**
- [ ] AC-13.1: APIClient cache invalidation scoped to specific URL path — M-NET-1
- [ ] AC-13.2: Retry logic skips sleep on final attempt — M-NET-2
- [ ] AC-13.3: SSEClient uses true exponential backoff (power-of-2) — L-NET-1
- [ ] AC-13.4: WebSocket fallback resets after SSE reconnection succeeds — L-NET-2

### US-14: Accessibility Completeness (Audit Absorption)
**As a** user relying on VoiceOver and Dynamic Type
**I want** all interactive elements labeled and fonts scaling properly
**So that** the app is fully usable with assistive technology

**Acceptance Criteria:**
- [ ] AC-14.1: 8+ missing accessibilityLabels added (Toggles, TextFields, Buttons) — M-A11Y-1
- [ ] AC-14.2: Dynamic Type applied via ILSTheme across 10 files — M-A11Y-2
- [ ] AC-14.3: Color-only status indicators augmented with shape or text — L-A11Y-1
- [ ] AC-14.4: VoiceOver navigates all screens without dead ends

---

## Functional Requirements

### Chat Rendering (Phase 2)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-1 | Integrate MarkdownUI for full GFM rendering (tables, blockquotes, HR, strikethrough, nested lists, task lists, images) | P0 | Screenshot: Claude response with table + blockquote renders correctly |
| FR-2 | Integrate HighlightSwift for grammar-aware syntax highlighting (50+ languages) | P0 | Screenshot: Python + Swift code blocks with correct token colors |
| FR-3 | Add line numbers to CodeBlockView (toggleable) | P1 | Screenshot: code block with line numbers visible |
| FR-4 | Show language label and copy button in code block header | P1 | Screenshot: header shows "python" label + copy icon |
| FR-5 | Render tool call inputs as structured key-value pairs | P1 | Screenshot: tool call expanded with key:value layout |
| FR-6 | Add output truncation (5 lines) + "Show more" to ToolCallAccordion | P1 | Screenshot: collapsed tool call with truncated output |
| FR-7 | Add "Expand All" / "Collapse All" for tool calls | P2 | Screenshot: button visible when 2+ tool calls |
| FR-8 | Render markdown inside ThinkingSection text | P1 | Screenshot: thinking block with bold/list content |
| FR-9 | Show character count in ThinkingSection header | P2 | Screenshot: header shows "(2,431 chars)" |
| FR-10 | Add message context menu (Copy markdown, Retry, Delete) | P1 | Screenshot: long-press menu visible on message |
| FR-11 | Copy action copies markdown source, not plain text | P1 | Paste into Notes app shows markdown formatting |
| FR-12 | Highlight on background thread for large code blocks | P1 | No main-thread hang on 500+ line code block |
| FR-13 | Remove old keyword-only syntax highlighter | P1 | grep confirms no keyword highlight code remains |

### Streaming (Phase 3)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-14 | Server emits sequential SSE event IDs | P0 | curl SSE stream shows `id: N` on each event |
| FR-15 | Client sends Last-Event-ID on reconnect | P0 | Network log shows header on reconnection |
| FR-16 | Server replays missed events from Last-Event-ID | P1 | Kill/resume connection; missed content appears |
| FR-17 | SSEClient exponential backoff (2s, 4s, 8s, 16s, max 30s) | P1 | Log output shows doubling intervals |
| FR-18 | Show token count + elapsed time during streaming | P2 | Screenshot: streaming indicator with "142 tokens, 3.2s" |
| FR-19 | Auto-scroll follows new content, pauses when user scrolls up | P1 | Scroll up during stream; content keeps arriving but scroll stays |
| FR-20 | "Jump to bottom" FAB appears when scrolled up during streaming | P2 | Screenshot: FAB visible during active stream |
| FR-21 | Replace Timer.scheduledTimer with Task-based batching in ChatViewModel | P1 | Code inspection: no Timer import in ChatViewModel |

### Backend (Phase 4)

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-22 | Global ErrorMiddleware returning structured JSON errors | P0 | curl invalid endpoint returns `{"error":true,"reason":"...","code":"..."}` |
| FR-23 | Request validation: empty prompt → 422, invalid UUID → 400 | P0 | curl empty body to /chat returns 422 with field detail |
| FR-24 | Sessions list pagination (?page, ?limit, total, hasMore) | P0 | curl `/sessions?page=1&limit=5` returns 5 items + total |
| FR-25 | StreamingService refactor: extract shared SSE logic | P1 | Code: single `sendSSEEvent()` used by both paths |
| FR-26 | DI for FileSystemService in controllers | P1 | Code: controllers accept service in init, no inline `FileSystemService()` |
| FR-27 | Replace UnsafeMutablePointer in SystemController with actor | P1 | Code: grep confirms zero UnsafeMutablePointer |
| FR-28 | ProjectsController.show() direct lookup (not O(n)) | P1 | Response time <50ms for single project fetch |
| FR-29 | Extract ChatMessage model to Models/ChatMessage.swift | P2 | Code: MessageView.swift imports ChatMessage, doesn't define it |
| FR-30 | Replace 30+ print() with AppLogger across backend | P1 | grep `print(` in Sources/ returns zero hits |

### Audit Absorption (Phase 5)

| ID | Requirement | Priority | Origin |
|----|-------------|----------|--------|
| FR-31 | Dedicated URLSession per ViewModel (not .shared) | P1 | M-CONC-1 |
| FR-32 | Task capture [weak self] with nonisolated clarity | P1 | M-CONC-2 |
| FR-33 | Decoder/Encoder instances nonisolated or local-scoped | P2 | L-CONC-1 |
| FR-34 | print() → AppLogger in SSEClient, ILSAppApp, ChatViewModel, CommandPaletteView | P2 | L-CONC-2 |
| FR-35 | Timer.scheduledTimer → Task-based in ChatViewModel | P1 | M-MEM-1 (= FR-21) |
| FR-36 | DispatchQueue.asyncAfter → Task.sleep with cancellation | P1 | M-MEM-2 |
| FR-37 | cancellables.removeAll() in ChatViewModel deinit | P2 | L-MEM-1 |
| FR-38 | Published+didSet → explicit update methods | P1 | M-ARCH-1 |
| FR-39 | Extract RelativeDateTimeFormatter to namespace | P1 | M-ARCH-2 |
| FR-40 | Extract complex computed properties to ViewModel methods | P2 | L-ARCH-1 |
| FR-41 | Replace 10 hardcoded fonts with ILSTheme | P2 | L-PERF-1 |
| FR-42 | Remove redundant objectWillChange.send() | P3 | L-PERF-2 |
| FR-43 | Scope cache invalidation to specific URL path | P1 | M-NET-1 |
| FR-44 | Skip retry sleep on final attempt | P1 | M-NET-2 |
| FR-45 | SSEClient true exponential backoff (power-of-2) | P1 | L-NET-1 (= FR-17) |
| FR-46 | WebSocket fallback resets after SSE success | P2 | L-NET-2 |
| FR-47 | Add 8+ missing accessibility labels | P1 | M-A11Y-1 |
| FR-48 | Dynamic Type via ILSTheme across 10 files | P1 | M-A11Y-2 |
| FR-49 | Color-only indicators augmented with shape/text | P2 | L-A11Y-1 |

**Note:** FR-21/FR-35 (Timer→Task) and FR-17/FR-45 (exponential backoff) are deduplicated — implemented once, counted in both contexts.

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | Chat scroll performance | FPS during 100-message streaming | 60fps, no dropped frames |
| NFR-2 | Code block highlighting latency | Time to highlight 500-line block | <200ms (background thread) |
| NFR-3 | App launch time | Cold start to interactive | No increase >500ms from new dependencies |
| NFR-4 | Memory footprint | Peak memory during 200-message chat | <150MB |
| NFR-5 | API response time | Sessions list with pagination | <100ms for 50-item page |
| NFR-6 | SSE reconnection time | Time from disconnect detection to resumed stream | <5s on stable network |
| NFR-7 | Accessibility conformance | VoiceOver navigation completeness | 100% screens navigable |
| NFR-8 | Build time | Clean build with new deps | <60s increase over baseline |
| NFR-9 | Binary size | App Store binary | <10MB increase from MarkdownUI + HighlightSwift |
| NFR-10 | Visual regression | Screenshot comparison | Zero unintended pixel changes outside enhanced components |

---

## Implementation Phases

### Phase 1: Foundation (Dependencies + Model Extraction + DI)
**Scope:** Add MarkdownUI and HighlightSwift to Package.swift. Extract ChatMessage model. Set up FileSystemService DI in controllers. Replace UnsafeMutablePointer.

**Key FRs:** FR-1 (dep only), FR-2 (dep only), FR-26, FR-27, FR-29
**Estimated effort:** 4-6 hours
**Validation:** `swift build` and `xcodebuild build` succeed with new deps. No runtime changes yet.

### Phase 2: Chat Rendering Overhaul
**Scope:** Replace MarkdownTextView with MarkdownUI renderer. Replace keyword highlighter with HighlightSwift. Enhance ToolCallAccordion and ThinkingSection. Add message actions. Background highlighting.

**Key FRs:** FR-1 through FR-13
**Estimated effort:** 15-20 hours
**Validation:** Screenshots of chat with:
- Table + blockquote message
- Multi-language code blocks with line numbers
- Expanded tool call with structured input
- Thinking section with markdown content
- Long-press message menu

### Phase 3: Streaming Hardening
**Scope:** Add SSE event IDs (server + client). Implement exponential backoff. Add Last-Event-ID reconnection. Replace Timer with Task batching. Improve auto-scroll and add streaming stats.

**Key FRs:** FR-14 through FR-21
**Estimated effort:** 8-12 hours
**Validation:**
- curl SSE stream shows event IDs
- Kill network during stream; reconnect replays missed content
- Screenshot: streaming indicator with token count + elapsed time
- Screenshot: "Jump to bottom" FAB during active stream

### Phase 4: Backend Robustness
**Scope:** Global ErrorMiddleware. Request validation. Session pagination. StreamingService refactor. ProjectsController optimization. print() → AppLogger.

**Key FRs:** FR-22 through FR-30
**Estimated effort:** 8-12 hours
**Validation:**
- curl tests for error responses (400, 404, 422, 500)
- curl paginated sessions
- Code review: StreamingService has single SSE send method
- Code review: zero print() in Sources/

### Phase 5: Audit Fixes + Polish
**Scope:** All remaining-audit-fixes items (FR-31 through FR-49). Concurrency safety, memory management, architecture patterns, theming, networking, accessibility.

**Key FRs:** FR-31 through FR-49
**Estimated effort:** 6-8 hours
**Validation:**
- Build succeeds with zero new warnings
- Screenshots: 6 tabs + 2 modals match existing appearance
- VoiceOver: navigate all screens end-to-end
- Memory Instruments: no timer leaks after rapid view push/pop
- grep: zero `print(` in app code, zero hardcoded `.font(.system(size:))`

---

## Glossary

- **GFM**: GitHub Flavored Markdown — extended markdown with tables, task lists, strikethrough, fenced code blocks
- **MarkdownUI**: Third-party SwiftUI library (gonzalezreal) for rendering full GFM
- **HighlightSwift**: Third-party library (appstefan) for grammar-aware syntax highlighting in SwiftUI
- **SSE**: Server-Sent Events — HTTP-based one-way streaming protocol
- **Event ID**: Sequential identifier on SSE messages enabling resume-on-reconnect
- **Last-Event-ID**: HTTP header sent by client on SSE reconnect to request replay
- **Exponential backoff**: Retry delay that doubles each attempt (2s → 4s → 8s → 16s)
- **DI**: Dependency Injection — passing services to constructors instead of creating inline
- **AppLogger**: Existing structured logging utility in the codebase
- **ILSTheme**: Existing design system with spacing, typography, colors, corner radii
- **EntityType**: Existing enum mapping entity types to consistent colors
- **Dynamic Type**: iOS system feature that scales fonts based on user accessibility settings
- **Swift 6 strict concurrency**: Upcoming compiler mode enforcing Sendable checks at compile time
- **Task-based timer**: Using `Task { while !isCancelled { try await Task.sleep(...) } }` instead of `Timer.scheduledTimer`

## Out of Scope

- Image display in chat messages (requires file upload API not yet built)
- File attachment in chat input (requires upload endpoint)
- Voice input for chat
- Partial character-by-character streaming (`--include-partial-messages` flag)
- Permission request UI (tool approve/deny) — separate feature spec needed
- Rate limiting on API endpoints (requires auth/session tracking first)
- Global search endpoint across entities
- Session export endpoint (server-side)
- Batch operations (bulk delete)
- API version negotiation
- WebSocket-based streaming as primary (SSE remains primary)
- iOS 18 minimum upgrade (staying on iOS 17)
- SwiftLint or static analysis tooling setup
- Unit/integration/E2E test infrastructure (per FUNCTIONAL VALIDATION MANDATE)

## Dependencies

| Dependency | Type | Status | Risk |
|------------|------|--------|------|
| MarkdownUI (gonzalezreal/swift-markdown-ui) | SPM package | Not added | Medium — must verify iOS 17 compat and streaming perf |
| HighlightSwift (appstefan/HighlightSwift) | SPM package | Not added | Low — drop-in replacement |
| AppLogger | Internal | Exists | None |
| ILSTheme | Internal | Exists | None |
| HapticManager | Internal | Exists | None |
| Claude CLI binary | External | Required at runtime | High — subprocess dependency for chat |
| SQLite | Internal | No migration framework | Medium — schema changes need manual SQL |

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| MarkdownUI breaks streaming perf (re-render on each token) | Medium | High | Use LazyMarkdownText; benchmark with 100-token-per-second stream; fallback to extended custom parser |
| HighlightSwift binary size bloat (50 language grammars) | Low | Medium | Measure before/after; can subset languages if >5MB |
| SSE event ID implementation requires schema change | Medium | Medium | Store event IDs in memory buffer (ring buffer, last 1000 events) not DB |
| StreamingService refactor introduces regression | Medium | High | Test both persistence and non-persistence paths with real Claude session |
| Published+didSet refactor changes observable timing | Low | Medium | A/B screenshot comparison before and after |
| Timer→Task migration changes batch flush behavior | Low | Medium | Monitor streaming smoothness in real chat session |
| MarkdownUI iOS 17 compatibility issue | Low | High | Verify before committing; MarkdownUI 3.x supports iOS 16+ |
| DI refactor in controllers breaks route registration | Low | High | Build verification after each controller change |

## Success Criteria

- [ ] All 49 functional requirements implemented (FR-1 through FR-49)
- [ ] Chat renders tables, blockquotes, strikethrough, task lists, code blocks with real highlighting
- [ ] SSE streaming recovers from disconnection with event replay
- [ ] Backend returns structured JSON errors on all endpoints
- [ ] Sessions list paginates correctly
- [ ] Zero print() statements in app or backend code
- [ ] Zero hardcoded fonts — all via ILSTheme
- [ ] VoiceOver navigates every screen end-to-end
- [ ] Build succeeds with zero new warnings
- [ ] 15+ evidence screenshots captured and reviewed

---

## Unresolved Questions

1. **MarkdownUI vs MarkdownView (fatbobman)**: Research found both viable. MarkdownUI has broader adoption but is "moving to Textual". MarkdownView used by X/Grok. Decision: default to MarkdownUI unless iOS 17 compat fails during Phase 1.
2. **Highlighting theme mapping**: HighlightSwift has 30 themes. Need to pick one that matches ILSTheme dark palette, or create custom mapping. Decision deferred to Phase 2 design.
3. **Event ID storage strategy**: Ring buffer in memory (fast, lost on restart) vs SQLite (persistent, schema change). Recommend memory buffer since chat sessions are ephemeral.
4. **Pagination cursor vs offset**: Research recommends cursor-based for large datasets. At ILS scale (<10K sessions), offset is fine. Decision: offset-based for simplicity.
5. **MarkdownUI streaming integration**: Need to verify `LazyMarkdownText` exists in current MarkdownUI release and handles incremental text appends without full re-layout.

## Next Steps

1. Approve requirements or request changes
2. Proceed to design phase — component diagrams, API contracts, dependency wiring
3. Phase 1 implementation (foundation + dependencies)
4. Phase 2-5 implementation with evidence capture per phase
5. Final validation and evidence review
