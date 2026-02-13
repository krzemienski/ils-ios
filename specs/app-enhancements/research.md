---
spec: app-enhancements
phase: research
created: 2026-02-07T16:00:00Z
---

# Research: app-enhancements

## Executive Summary

The ILS iOS app has a functional chat interface with custom markdown parsing, basic syntax highlighting, tool call/thinking accordions, and SSE streaming. However, significant gaps remain: the markdown parser is hand-rolled and incomplete (no tables, blockquotes, horizontal rules, strikethrough, nested lists, or images), syntax highlighting is keyword-only with no language-specific grammar, tool call display lacks input detail, the streaming pipeline has no reconnection-on-resume, and backend APIs lack pagination on several endpoints, structured error middleware, and rate limiting. The remaining-audit-fixes spec (43 MEDIUM/LOW issues) is not yet implemented and overlaps with this scope.

## External Research

### Best Practices — Chat Markdown Rendering (iOS/SwiftUI)

| Approach | Pros | Cons | Source |
|----------|------|------|--------|
| **MarkdownUI** (gonzalezreal) | Full GFM support, theming, images, tables, code blocks | Dependency; in maintenance mode (moving to "Textual") | [GitHub](https://github.com/gonzalezreal/swift-markdown-ui) |
| **MarkdownView** (fatbobman) | Used by X (Grok), Hugging Face; customizable per-element | Newer, less battle-tested | [Deep Dive](https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/) |
| **Native SwiftUI Text+Markdown** | Zero deps; bold/italic/links/inline code | No tables, headers, code blocks, images | [HackingWithSwift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-render-markdown-content-in-text) |
| **Custom parser (current)** | Full control, no deps | Missing features, parsing bugs, perf overhead on re-render | Current codebase |

**Recommendation**: Either adopt MarkdownUI/Textual for full GFM, or significantly extend the custom parser. For a chat app streaming tokens, MarkdownUI's `LazyMarkdownText` addresses the re-render performance concern ([Discussion #261](https://github.com/gonzalezreal/swift-markdown-ui/discussions/261)).

### Best Practices — Syntax Highlighting

| Library | Coverage | Integration | Source |
|---------|----------|-------------|--------|
| **HighlightSwift** | 50 languages, 30 themes, AttributedString | SwiftUI native, `CodeText` view | [GitHub](https://github.com/appstefan/HighlightSwift) |
| **Splash** (JohnSundell) | Swift-only | Text output, lightweight | [GitHub](https://github.com/JohnSundell/Splash) |
| **swift-syntax** | Swift AST-level | Overkill for display | [Sahand blog](https://sahandnayebaziz.org/blog/syntax-highlighting-swiftui-with-swift-syntax) |
| **Custom keyword set (current)** | ~100 keywords, 4 colors | No grammar awareness; miscolors identifiers | Current codebase |

**Recommendation**: Adopt HighlightSwift for real syntax highlighting. Current keyword-based approach colors any identifier matching a keyword (e.g., `list` in Python highlighted as keyword even in variable context).

### Best Practices — SSE Streaming

- **Event ID mechanism**: Clients send `Last-Event-ID` on reconnect; server resumes from that point. Current implementation has no event IDs. Source: [MDN SSE](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- **Retry field**: Server can set reconnection interval via `retry:` field. Not used currently. Source: [SSE Guide](https://tigerabrodi.blog/server-sent-events-a-practical-guide-for-the-real-world)
- **HTTP compression**: SSE streams benefit from gzip (70-90% bandwidth reduction). Not configured. Source: [SSE comprehensive guide](https://medium.com/@moali314/server-sent-events-a-comprehensive-guide-e4b15d147576)
- **Heartbeat best practice**: Current 15s interval is reasonable. Source: [Vapor SSE](https://medium.com/@FitoMAD/server-sent-events-with-vapor-an-event-driven-approach-1b02694668f7)

### Best Practices — Vapor API Design

- **Error middleware**: Replace default ErrorMiddleware with structured JSON errors following RFC 9457. Source: [Vapor Errors](https://docs.vapor.codes/basics/errors/)
- **Request validation**: Use Vapor's `Validatable` protocol for input validation. Source: [Vapor docs](https://docs.vapor.codes/basics/errors/)
- **Pagination**: Cursor-based > offset-based for large datasets. Current offset-based is fine for ILS scale. Source: [API best practices](https://zuplo.com/blog/2025/02/11/best-practices-for-api-error-handling)

### Best Practices — Accordion/Collapsible UI

- SwiftUI `DisclosureGroup` is the standard pattern. Current custom implementation works but should use `DisclosureGroup` for better VoiceOver. Source: [Holy Swift](https://holyswift.app/accordion-in-swiftui-disclosuregroup-explorations/)
- Accessibility: VoiceOver needs "Expanded"/"Collapsed" state announcements. Current implementation has this. Source: [CVS Health a11y](https://github.com/cvs-health/ios-swiftui-accessibility-techniques/blob/main/iOSswiftUIa11yTechniques/Documentation/Accordions.md)

### Prior Art

- **ChatGPT iOS app**: Streams markdown, renders code blocks with language detection and copy buttons, shows thinking as expandable section, tool calls as compact cards.
- **Cursor IDE chat**: Similar streaming UX with real-time markdown rendering and file diff previews.

### Pitfalls to Avoid

- **Re-parsing markdown on every stream chunk**: Each new token triggers full re-parse. Use incremental/lazy rendering.
- **Blocking main thread with syntax highlighting**: Heavy regex on long code blocks freezes UI. Highlight on background thread.
- **SSE without reconnection IDs**: Losing connection means losing messages. Must implement event ID tracking.
- **Unbounded message history**: Loading 1000+ messages into memory. Need virtual scrolling / pagination.

## Codebase Analysis

### Chat Rendering — Current State

| Component | File | Lines | Status | Gaps |
|-----------|------|-------|--------|------|
| **MarkdownTextView** | `Views/Chat/MarkdownTextView.swift` | 299 | Working | No tables, blockquotes, HR, strikethrough, nested lists, images |
| **CodeBlockView** | `Theme/Components/CodeBlockView.swift` | 286 | Working | Keyword-only highlighting (no grammar); no line numbers; no language auto-detect |
| **ToolCallAccordion** | `Theme/Components/ToolCallAccordion.swift` | 142 | Working | No structured input display (just raw string); no output truncation; no "Expand All" |
| **ThinkingSection** | `Theme/Components/ThinkingSection.swift` | 113 | Working | No markdown in thinking text; no character count/summary |
| **MessageView** | `Views/Chat/MessageView.swift` | 289 | Working | Copy copies raw text not markdown; no message actions (edit, retry, delete) |
| **ChatView** | `Views/Chat/ChatView.swift` | 436 | Working | No image display; no file attachment; no scroll-to-unread; auto-scroll logic fragile |
| **ChatInputView** | (in ChatView.swift) | ~70 | Working | No multi-line expand indicator; no attachment button; no voice input |

**Markdown Parser Gaps** (MarkdownTextView.swift):
1. **Tables** — Not parsed at all
2. **Blockquotes** (`>`) — Not parsed
3. **Horizontal rules** (`---`, `***`) — Not parsed
4. **Strikethrough** (`~~text~~`) — Not parsed
5. **Nested lists** — Flat only; no indentation tracking
6. **Task lists** (`- [ ]`, `- [x]`) — Not parsed
7. **Images** (`![alt](url)`) — Not parsed
8. **HTML entities** — Not handled
9. **Inline bold+italic** (`***text***`) — Not handled (only `**` and `*` separately)
10. **Escaped characters** — Not handled (`\*` renders as italic trigger)

**Syntax Highlighting Gaps** (CodeBlockView.swift):
1. Keyword-only: no understanding of context (identifier vs keyword)
2. No regex/pattern support beyond keywords
3. No type highlighting (classes, protocols)
4. No function name highlighting
5. No interpolation highlighting in strings
6. Re-renders entire code on every view update (performance risk for large blocks)

### Streaming Architecture — Current State

| Component | File | Status | Issues |
|-----------|------|--------|--------|
| **SSEClient** | `Services/SSEClient.swift` | Working | No event IDs, linear (not exponential) backoff, no resume-from-last-event |
| **ChatViewModel** | `ViewModels/ChatViewModel.swift` | Working | Timer-based batching (should be Task-based per audit), mutation of `currentMessage` |
| **StreamMessage** | `ILSShared/Models/StreamMessage.swift` | Working | No partial text support (character-by-character) |
| **StreamingService** | `ILSBackend/Services/StreamingService.swift` | Working | No event IDs emitted, no compression, duplicate code in persistence vs non-persistence |
| **ClaudeExecutorService** | `ILSBackend/Services/ClaudeExecutorService.swift` | Working | `print()` debug logging, no structured logging, GCD queue for reads |

**Key streaming issues**:
1. SSE reconnection uses linear delay (2s, 4s, 6s) not exponential (2s, 4s, 8s) — documented in audit L-NET-1
2. No SSE event IDs — client cannot resume from last received event on reconnect
3. `processStreamMessages` mutates `currentMessage` via removeLast + append pattern — fragile
4. No support for `--include-partial-messages` character-by-character streaming on client side
5. Permission requests received but not actionable (handler is `break`)

### Backend API — Current State

| Controller | Endpoints | Status | Issues |
|------------|-----------|--------|--------|
| **SessionsController** | 8 routes | Good | `list` has no pagination; `transcript` offset/limit params exist but ListResponse lacks total |
| **ChatController** | 4 routes | Good | Permission handler is stub; cancel is fire-and-forget; WebSocket handler delegates to separate service |
| **ProjectsController** | 3 routes | OK | `show` calls `index` then filters — O(n) for single item; no caching of scan results |
| **SkillsController** | 6 routes | Good | Search is client-side filter; GitHub search works |
| **MCPController** | 5 routes | Good | No health check per server; `update` does remove+add (not atomic) |
| **PluginsController** | 8 routes | Good | `install` via git clone is synchronous blocking; no progress feedback |
| **SystemController** | 4 routes | Good | `UnsafeMutablePointer` for cancellation flag in liveMetrics (memory safety risk) |
| **StatsController** | (not read) | Assumed working | Aggregates counts |
| **ConfigController** | (not read) | Assumed working | CRUD for Claude config |
| **AuthController** | (not read) | Assumed working | Authentication |
| **TunnelController** | (not read) | Assumed working | Cloudflare tunnel |

**Missing backend features**:
1. **Structured error responses**: No global error middleware; errors vary between Abort() and ad-hoc JSON
2. **Request validation**: No input validation (e.g., empty prompt, invalid model name)
3. **Session pagination**: `/sessions` returns ALL sessions — will degrade with 1000+ sessions
4. **Rate limiting**: No rate limiting on any endpoint
5. **Search endpoint**: No global search across sessions/projects/messages
6. **Session status management**: No automatic status transitions (active -> completed/error)
7. **Message search**: Cannot search within message content
8. **Session export**: No export endpoint (client-side only)
9. **Batch operations**: No bulk delete for sessions
10. **API versioning**: Using `/api/v1` prefix but no version negotiation

### Architecture Quality

**Anti-patterns found**:
1. **Duplicate code in StreamingService**: `createSSEResponse` and `createSSEResponseWithPersistence` share 80% identical code — should use composition
2. **Controllers create new FileSystemService instances**: Each controller creates `let fileSystem = FileSystemService()` instead of dependency injection
3. **APIClient cache invalidation is path-prefix based**: `/sessions/123/fork` invalidates `/se` — too coarse
4. **System controller uses UnsafeMutablePointer**: For WebSocket cancellation flag — should use actor or `@Sendable` closure
5. **ChatMessage model is in MessageView.swift**: Data model mixed with view file — should be in separate Models file
6. **print() statements**: 30+ print statements across SSEClient, ILSAppApp, ChatViewModel instead of AppLogger
7. **Hardcoded colors in views**: MessageView, CodeBlockView, ToolCallAccordion define colors inline instead of using ILSTheme

### Existing Patterns (Good)

- **ILSTheme design system** with consistent spacing, typography, corner radii
- **EntityType color system** for consistent entity colors across views
- **APIClient actor** with retry logic, caching, exponential backoff
- **Accessibility identifiers** on most interactive elements
- **Reduce motion** checks in animations
- **HapticManager** for consistent feedback
- **SkeletonRow/ShimmerModifier** for loading states
- **EmptyEntityState** for empty states

### Dependencies

| Dependency | Version | Used For |
|------------|---------|----------|
| Vapor | 4.89+ | Web framework |
| Fluent | 4.9+ | ORM |
| FluentSQLiteDriver | 4.6+ | Database |
| Yams | 5.0+ | YAML parsing (skills) |
| Citadel | 0.7+ | SSH client |

**Potential new dependencies**:
- MarkdownUI or Textual (markdown rendering)
- HighlightSwift (syntax highlighting)

### Constraints

1. **Swift 5.9 minimum** (Package.swift declares this)
2. **iOS 17 minimum** (Package.swift declares this)
3. **SQLite database** — single-file, no migrations for new tables without manual migration
4. **Claude CLI subprocess** — backend depends on claude binary being in PATH
5. **No test infrastructure** — per FUNCTIONAL VALIDATION MANDATE, no unit tests; validation via real UI

## Related Specs

| Spec | Relevance | Relationship | mayNeedUpdate |
|------|-----------|--------------|---------------|
| **remaining-audit-fixes** | **HIGH** | Direct overlap — 43 MEDIUM/LOW issues covering concurrency, memory, networking, accessibility, architecture in same files this spec touches | true |
| **ios-app-polish2** | **Medium** | Predecessor — created the chat components (CodeBlockView, ToolCallAccordion, ThinkingSection) and streaming UX that this spec enhances | false |
| **ios-app-polish** | **Medium** | Predecessor — established onboarding flow, session navigation, cancel wiring | false |
| **ils-complete-rebuild** | **Medium** | Parallel effort — 42-task rebuild plan from full spec; overlaps on API completeness and design system adherence | true |
| **app-improvements** | **HIGH** | Stalled spec with same goal ("improve UX and polish") — likely superseded by this spec | true |
| **agent-teams** | **Low** | Different domain (agent team orchestration) | false |

**Key overlap**: `remaining-audit-fixes` has 21 actionable fixes (12 MEDIUM + 9 LOW) that directly affect files this spec would modify. Recommend incorporating those fixes into this spec's implementation to avoid double-touching files.

## Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | **High** | All proposed improvements use well-established patterns |
| Effort Estimate | **XL** | Full scope: 60-80 hours across markdown overhaul, syntax highlighting, streaming hardening, backend improvements, audit fixes |
| Risk Level | **Medium** | Markdown library adoption is biggest risk (dependency + migration); streaming changes need careful testing |

### Effort Breakdown

| Area | Effort | Risk |
|------|--------|------|
| Markdown rendering overhaul | L (15-20h) | Medium — library adoption or major parser extension |
| Syntax highlighting upgrade | M (8-12h) | Low — HighlightSwift is drop-in |
| Streaming reliability | M (8-12h) | Medium — event IDs, reconnection, resume |
| Backend API hardening | M (8-12h) | Low — pagination, validation, error middleware |
| Remaining audit fixes | M (4-6h) | Low — well-documented incremental fixes |
| Chat UX improvements | M (8-10h) | Low — message actions, scroll improvements, input enhancements |
| Validation & evidence | S (4-6h) | Low — standard screenshot capture |

## Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Build (Backend) | `swift build` | Package.swift |
| Build (iOS App) | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build` | Xcode project |
| Run Backend | `PORT=9090 swift run ILSBackend` | MEMORY.md |
| Lint | Not found | No SwiftLint configured |
| TypeCheck | Not found | Swift compiler handles this during build |
| Unit Test | Not applicable | FUNCTIONAL VALIDATION MANDATE |
| E2E Test | Not applicable | Manual validation with screenshots |

**Local CI**: `swift build && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build`

## Recommendations for Requirements

### Priority 1 — Chat Rendering Quality (User-Visible)

1. **Adopt MarkdownUI or extend parser for GFM support** — Tables, blockquotes, task lists, horizontal rules, strikethrough are all common in Claude responses
2. **Integrate HighlightSwift for real syntax highlighting** — Replace keyword-only approach with grammar-aware highlighting for 50+ languages
3. **Add line numbers to code blocks** — Standard in code-centric chat apps
4. **Improve tool call display** — Show structured input (key: value) instead of raw string; add output preview line in collapsed state
5. **Add message-level actions** — Copy as markdown, retry, delete individual messages

### Priority 2 — Streaming Reliability (UX Critical)

6. **Implement SSE event IDs** — Server emits sequential IDs; client sends Last-Event-ID on reconnect
7. **Fix exponential backoff** — SSEClient uses linear delay; should be exponential
8. **Add partial message streaming** — Support `--include-partial-messages` for character-by-character display
9. **Handle permission requests** — Currently ignored; need UI for approve/deny tool execution
10. **Improve streaming status UX** — Show token count, elapsed time, cost-so-far during streaming

### Priority 3 — Backend Robustness

11. **Add structured error middleware** — Global error handler returning consistent JSON with error codes
12. **Add request validation** — Validate prompt non-empty, model name valid, UUID formats
13. **Add session list pagination** — Cursor or offset-based pagination on `/sessions`
14. **Refactor StreamingService** — Extract shared SSE logic to reduce duplication
15. **Replace UnsafeMutablePointer** — In SystemController.liveMetrics with actor-safe pattern

### Priority 4 — Audit Fixes Integration

16. **Incorporate remaining-audit-fixes** — 12 MEDIUM + 9 LOW issues, especially Timer->Task migration, print->AppLogger, font theme consistency, SSE backoff fix

### Priority 5 — Polish & Completeness

17. **Add message search** — Search within chat history
18. **Improve scroll behavior** — Scroll-to-unread indicator, smooth auto-scroll during streaming
19. **Extract ChatMessage model** — Move from MessageView.swift to dedicated Models/ file
20. **Dependency injection** — Controllers should receive FileSystemService instead of creating instances

## Open Questions

1. **MarkdownUI vs custom parser**: Should we add the MarkdownUI/Textual dependency or continue extending the custom parser? Trade-off is dependency management vs development effort.
2. **Permission request UI**: How should tool permission requests be displayed? Modal alert? Inline card? This is a significant UX decision.
3. **Partial message streaming**: Is character-by-character display worth the complexity? Claude Code CLI supports it via `--include-partial-messages`.
4. **Scope boundary with remaining-audit-fixes**: Should this spec absorb all 21 audit fixes, or should they remain separate? Recommend absorbing to avoid merge conflicts.
5. **iOS 17 minimum**: Is upgrading to iOS 18 minimum acceptable? Some newer SwiftUI APIs (e.g., improved markdown in Text) require iOS 18.

## Sources

### External
- [MarkdownUI — GitHub](https://github.com/gonzalezreal/swift-markdown-ui)
- [MarkdownView Deep Dive — fatbobman](https://fatbobman.com/en/posts/a-deep-dive-into-swiftui-rich-text-layout/)
- [HighlightSwift — GitHub](https://github.com/appstefan/HighlightSwift)
- [SwiftUI Markdown Rendering — HackingWithSwift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-render-markdown-content-in-text)
- [SSE Guide — MDN](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events)
- [Vapor SSE — Medium](https://medium.com/@FitoMAD/server-sent-events-with-vapor-an-event-driven-approach-1b02694668f7)
- [SSE Comprehensive Guide — Medium](https://medium.com/@moali314/server-sent-events-a-comprehensive-guide-e4b15d147576)
- [Vapor Errors — Docs](https://docs.vapor.codes/basics/errors/)
- [API Error Handling — Zuplo](https://zuplo.com/blog/2025/02/11/best-practices-for-api-error-handling)
- [SwiftUI Accordion — Holy Swift](https://holyswift.app/accordion-in-swiftui-disclosuregroup-explorations/)
- [Accessibility Accordions — CVS Health](https://github.com/cvs-health/ios-swiftui-accessibility-techniques/blob/main/iOSswiftUIa11yTechniques/Documentation/Accordions.md)
- [Splash Syntax Highlighter — GitHub](https://github.com/JohnSundell/Splash)
- [SwiftUI Markdown — SwiftLee](https://www.avanderlee.com/swiftui/markdown-text/)

### Internal Files
- `<project-root>/ILSApp/ILSApp/Views/Chat/ChatView.swift`
- `<project-root>/ILSApp/ILSApp/Views/Chat/MessageView.swift`
- `<project-root>/ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift`
- `<project-root>/ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- `<project-root>/ILSApp/ILSApp/Services/SSEClient.swift`
- `<project-root>/ILSApp/ILSApp/Services/APIClient.swift`
- `<project-root>/ILSApp/ILSApp/Theme/Components/CodeBlockView.swift`
- `<project-root>/ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift`
- `<project-root>/ILSApp/ILSApp/Theme/Components/ThinkingSection.swift`
- `<project-root>/Sources/ILSBackend/Controllers/SessionsController.swift`
- `<project-root>/Sources/ILSBackend/Controllers/ChatController.swift`
- `<project-root>/Sources/ILSBackend/Services/StreamingService.swift`
- `<project-root>/Sources/ILSBackend/Services/ClaudeExecutorService.swift`
- `<project-root>/Sources/ILSShared/Models/StreamMessage.swift`
- `<project-root>/Sources/ILSShared/Models/Message.swift`
- `<project-root>/specs/remaining-audit-fixes/research.md`
- `<project-root>/specs/remaining-audit-fixes/requirements.md`
