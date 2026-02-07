---
spec: app-enhancements
phase: tasks
total_tasks: 42
created: 2026-02-07
---

# Tasks: App Enhancements — Chat Rendering + Backend Overhaul

## Phase 1: Foundation (Dependencies + Model Extraction + DI + Safety)

Focus: Add MarkdownUI + HighlightSwift deps, extract ChatMessage model, wire DI for FileSystemService, replace UnsafeMutablePointer. No runtime behavior changes yet.

- [x] 1.1 Add MarkdownUI + HighlightSwift SPM dependencies to Xcode project
  - **Do**:
    1. Open `ILSApp/ILSApp.xcodeproj/project.pbxproj` and add SPM package references:
       - `https://github.com/gonzalezreal/swift-markdown-ui` from `2.4.0`
       - `https://github.com/appstefan/HighlightSwift` from `1.0.0`
    2. Add both packages as dependencies of the ILSApp target
    3. Alternatively use `xcodebuild -resolvePackageDependencies` after editing
    4. Verify MarkdownUI supports iOS 17 (it does — iOS 16+)
  - **Files**: `ILSApp/ILSApp.xcodeproj/project.pbxproj`, `ILSApp/ILSApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - **Done when**: `xcodebuild build` succeeds with both packages resolved
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -resolvePackageDependencies 2>&1 | tail -3 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add MarkdownUI and HighlightSwift SPM dependencies`
  - _Requirements: FR-1, FR-2 (dep only)_
  - _Design: Phase 1 — 1.1 Package Dependencies_

- [x] 1.2 Extract ChatMessage model from MessageView to dedicated Models file
  - **Do**:
    1. Create `ILSApp/ILSApp/Models/ChatMessage.swift`
    2. Move `ChatMessage`, `ToolCall`, `ToolResult` structs from `MessageView.swift` lines 210-266
    3. Rename `ToolCall` to `ToolCallDisplay`, add `inputPairs: [(key: String, value: String)]` field alongside existing `inputPreview`
    4. Rename `ToolResult` to `ToolResultDisplay` for consistency
    5. Add `tokenCount: Int = 0` and `elapsedSeconds: Double = 0` fields to ChatMessage for streaming stats (FR-18)
    6. Remove the Data Models section from MessageView.swift
    7. Update all imports in ChatViewModel.swift and MessageView.swift
  - **Files**: `ILSApp/ILSApp/Models/ChatMessage.swift` (create), `ILSApp/ILSApp/Views/Chat/MessageView.swift` (modify), `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (modify)
  - **Done when**: Build succeeds; ChatMessage defined only in Models/ChatMessage.swift
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "struct ChatMessage" ILSApp/ILSApp/Models/ChatMessage.swift && grep -c "struct ChatMessage" ILSApp/ILSApp/Views/Chat/MessageView.swift`
  - **Commit**: `refactor(ios): extract ChatMessage model to dedicated file`
  - _Requirements: FR-29, FR-5 (prep), FR-18 (prep)_
  - _Design: Phase 1 — 1.2 ChatMessage Model Extraction_

- [x] 1.3 Add FileSystemService DI to all backend controllers
  - **Do**:
    1. In each controller that has `let fileSystem = FileSystemService()`, change to `let fileSystem: FileSystemService` with `init(fileSystem: FileSystemService)`:
       - `SessionsController.swift` (line 17)
       - `ProjectsController.swift` (line 14)
       - `MCPController.swift` (line 5)
       - `PluginsController.swift` (line 5)
       - `ConfigController.swift` (line 5)
       - `SkillsController.swift` (line 5)
       - `StatsController.swift` (line 6)
    2. Update `routes.swift` to create a single `FileSystemService()` and pass to all controllers
    3. Update each `register(collection:)` call with `fileSystem: fileSystem`
  - **Files**: `Sources/ILSBackend/App/routes.swift`, `Sources/ILSBackend/Controllers/SessionsController.swift`, `Sources/ILSBackend/Controllers/ProjectsController.swift`, `Sources/ILSBackend/Controllers/MCPController.swift`, `Sources/ILSBackend/Controllers/PluginsController.swift`, `Sources/ILSBackend/Controllers/ConfigController.swift`, `Sources/ILSBackend/Controllers/SkillsController.swift`, `Sources/ILSBackend/Controllers/StatsController.swift`
  - **Done when**: Zero inline `FileSystemService()` in controllers; single instance shared via DI
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "FileSystemService()" Sources/ILSBackend/App/routes.swift && grep -rc "= FileSystemService()" Sources/ILSBackend/Controllers/`
  - **Commit**: `refactor(backend): inject FileSystemService via DI in all controllers`
  - _Requirements: FR-26_
  - _Design: Phase 1 — 1.3 FileSystemService DI_

- [x] 1.4 Replace UnsafeMutablePointer with actor in SystemController
  - **Do**:
    1. In `SystemController.swift`, add `WebSocketCancellation` actor:
       ```
       actor WebSocketCancellation {
           private var cancelled = false
           func cancel() { cancelled = true }
           func isCancelled() -> Bool { cancelled }
       }
       ```
    2. Replace `UnsafeMutablePointer<Bool>` in `liveMetrics` (lines 132-177) with the actor
    3. Update stream loop: `guard await !cancellation.isCancelled() else { break }`
    4. Update `ws.onClose`: `Task { await cancellation.cancel(); streamTask.cancel() }`
    5. Remove pointer allocate/initialize/deinitialize/deallocate calls
    6. Also check `SystemMetricsService.swift` for any UnsafeMutablePointer usage
  - **Files**: `Sources/ILSBackend/Controllers/SystemController.swift`
  - **Done when**: Zero `UnsafeMutablePointer` in Sources/ILSBackend
  - **Verify**: `swift build 2>&1 | tail -5 && grep -rc "UnsafeMutablePointer" Sources/ILSBackend/`
  - **Commit**: `fix(backend): replace UnsafeMutablePointer with actor-safe cancellation`
  - _Requirements: FR-27_
  - _Design: Phase 1 — 1.4 SystemController Actor-Safe Cancellation_

- [x] V1 [VERIFY] Foundation checkpoint: backend + iOS builds pass
  - **Do**: Run both build commands to confirm Phase 1 foundation is solid
  - **Verify**: `swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore(app): pass foundation quality checkpoint` (only if fixes needed)

---

## Phase 2: Chat Rendering Overhaul

Focus: Replace hand-rolled markdown parser with MarkdownUI, replace keyword highlighter with HighlightSwift, enhance tool calls + thinking sections, add message actions.

- [x] 2.1 Replace MarkdownTextView with MarkdownUI wrapper
  - **Do**:
    1. Rewrite `MarkdownTextView.swift` — replace all 299 lines of custom parser with MarkdownUI:
       ```
       import MarkdownUI
       struct MarkdownTextView: View {
           let text: String
           var body: some View {
               Markdown(text)
                   .markdownTheme(.ilsChat)
                   .markdownCodeSyntaxHighlighter(ILSCodeHighlighter())
                   .textSelection(.enabled)
           }
       }
       ```
    2. Define `.ilsChat` theme extension on `MarkdownUI.Theme` per design.md section 2.1:
       - `.text` -> ILSTheme.textPrimary + bodyFont
       - `.heading1/2/3` -> system title fonts + textPrimary
       - `.blockquote` -> left bar accent + indented text
       - `.codeBlock` -> delegates to ILSCodeHighlighter/CodeBlockView
       - `.table` -> padded cells
       - `.taskListMarker` -> checkmark.square.fill / square icons
       - `.strikethrough` -> .strikethrough()
       - `.thematicBreak` -> Divider with spacing
    3. Remove `MarkdownBlock` enum, `parseBlocks()`, `inlineMarkdownText()`, all parsing helpers
  - **Files**: `ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift` (rewrite)
  - **Done when**: MarkdownTextView uses MarkdownUI with zero custom parsing code; renders tables, blockquotes, HR, strikethrough, task lists, nested lists
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "parseBlocks" ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift`
  - **Commit**: `feat(ios): replace custom markdown parser with MarkdownUI for full GFM support`
  - _Requirements: FR-1_
  - _Design: Phase 2 — 2.1 MarkdownUI Integration_

- [x] 2.2 Replace CodeBlockView with HighlightSwift and add line numbers
  - **Do**:
    1. Rewrite `CodeBlockView.swift` — replace keyword-based highlighter (lines 71-258) with HighlightSwift:
       - Import HighlightSwift
       - Add `@State private var highlightedCode: AttributedString?` and `@State private var detectedLanguage: String?`
       - Use `Highlight().request(code, language: language)` in `.task` modifier (runs on background thread — FR-12)
       - Show `Text(highlightedCode ?? AttributedString(code))` with monospaced font
       - Keep header bar with language label (use `detectedLanguage ?? language ?? "code"`)
    2. Add line numbers column (toggleable via `@State private var showLineNumbers = true`):
       - Tap gutter to toggle
       - Line numbers in gray, right-aligned
       - Copy button copies code only (not line numbers)
    3. Remove: `keywords` set, `keywordColor/stringColor/commentColor/numberColor/defaultColor`, `syntaxHighlightedCode()`, `colorizeLine()`, `colorizeTokens()`, `findLineComment()`
    4. Replace `DispatchQueue.main.asyncAfter` in copyCode() with Task.sleep (FR-36)
  - **Files**: `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (rewrite)
  - **Done when**: CodeBlockView uses HighlightSwift; has line numbers; zero keyword-based highlight code
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "keywords" ILSApp/ILSApp/Theme/Components/CodeBlockView.swift && grep -c "HighlightSwift" ILSApp/ILSApp/Theme/Components/CodeBlockView.swift`
  - **Commit**: `feat(ios): replace keyword highlighter with HighlightSwift, add line numbers`
  - _Requirements: FR-2, FR-3, FR-4, FR-12, FR-13_
  - _Design: Phase 2 — 2.2 CodeBlockView with HighlightSwift_

- [x] 2.3 Create ILSCodeHighlighter bridge for MarkdownUI
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift`
    2. Implement `CodeSyntaxHighlighter` protocol from MarkdownUI:
       ```
       struct ILSCodeHighlighter: CodeSyntaxHighlighter {
           func highlightCode(_ code: String, language: String?) -> Text {
               Text(code)
                   .font(.system(.body, design: .monospaced))
                   .foregroundColor(ILSTheme.accent)
           }
       }
       ```
    3. This bridges MarkdownUI code blocks to HighlightSwift (full rendering done in CodeBlockView via theme's `.codeBlock` configuration)
  - **Files**: `ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift` (create)
  - **Done when**: ILSCodeHighlighter compiles and is used by MarkdownTextView
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add ILSCodeHighlighter bridge for MarkdownUI code blocks`
  - _Requirements: FR-1, FR-2_
  - _Design: Phase 2 — 2.3 ILSCodeHighlighter_

- [x] V2 [VERIFY] Quality checkpoint: iOS build after rendering overhaul
  - **Do**: Verify iOS build succeeds after major MarkdownUI + HighlightSwift integration
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Zero build errors
  - **Commit**: `chore(ios): pass chat rendering quality checkpoint` (only if fixes needed)

- [x] 2.4 Enhance ToolCallAccordion with structured inputs and output truncation
  - **Do**:
    1. Update `ToolCallAccordion.swift` to accept new parameters:
       - `inputPairs: [(key: String, value: String)]` for structured key-value display (FR-5)
       - Keep `input: String?` as fallback for non-dict inputs
       - Add `@State private var showFullOutput = false`
    2. In expanded view, render inputPairs as key:value rows instead of raw string
    3. Truncate output to 5 lines when collapsed; add "Show more" / "Show less" toggle (FR-6)
    4. Add red left border accent when `isError` is true (AC-3.6)
    5. Add `@Binding var expandAll: Bool?` for batch control (FR-7) — nil = independent, true/false = batch
  - **Files**: `ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` (modify)
  - **Done when**: ToolCallAccordion renders key-value pairs, truncates output, supports expand-all binding
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): enhance ToolCallAccordion with structured inputs and output truncation`
  - _Requirements: FR-5, FR-6, FR-7_
  - _Design: Phase 2 — 2.4 Enhanced ToolCallAccordion_

- [x] 2.5 Enhance ThinkingSection with markdown rendering and character count
  - **Do**:
    1. In `ThinkingSection.swift`, import MarkdownUI
    2. Replace plain `Text(thinking)` (line 59) with `Markdown(thinking).markdownTheme(.ilsChat)` for markdown rendering (FR-8)
    3. Update header text: `Text(isActive ? "Thinking..." : "Thinking (\(thinking.count.formatted()) chars)")` (FR-9)
    4. Wrap expanded content in `ScrollView { ... }.frame(maxHeight: 400)` for scroll indicator on long blocks (AC-4.4)
    5. Keep existing reduce-motion pulse animation
  - **Files**: `ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` (modify)
  - **Done when**: Thinking text renders markdown; collapsed header shows character count; long blocks scroll
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add markdown rendering and char count to ThinkingSection`
  - _Requirements: FR-8, FR-9_
  - _Design: Phase 2 — 2.5 Enhanced ThinkingSection_

- [x] 2.6 Add message context menu and Expand All button to MessageView
  - **Do**:
    1. In `MessageView.swift`, replace simple `.contextMenu { copyButton }` with full context menu (FR-10):
       ```
       .contextMenu {
           Button(action: copyMarkdown) { Label("Copy Markdown", systemImage: "doc.on.doc") }
           if !message.isUser {
               Button(action: { onRetry?(message) }) { Label("Retry", systemImage: "arrow.counterclockwise") }
           }
           Button(role: .destructive, action: { onDelete?(message) }) { Label("Delete", systemImage: "trash") }
       }
       ```
    2. Add callback closures: `var onRetry: ((ChatMessage) -> Void)?` and `var onDelete: ((ChatMessage) -> Void)?`
    3. `copyMarkdown()` copies `message.text` (raw markdown source, not rendered) (FR-11)
    4. Add `HapticManager.notification(.success)` feedback on copy (AC-5.5)
    5. Add `@State private var expandAllToolCalls = false` and "Expand All" / "Collapse All" button when `message.toolCalls.count >= 2` (FR-7)
    6. Pass `expandAll` binding to each ToolCallAccordion
    7. Replace existing `DispatchQueue.main.asyncAfter` (line 39) with `Task { try? await Task.sleep(for: .seconds(2)); showCopyConfirmation = false }` (FR-36)
    8. Add `.accessibilityCustomContent("Actions", "Copy, Retry, Delete")` for VoiceOver (AC-5.6)
  - **Files**: `ILSApp/ILSApp/Views/Chat/MessageView.swift` (modify)
  - **Done when**: Long-press shows Copy/Retry/Delete menu; Expand All button visible with 2+ tool calls
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): add message context menu with copy/retry/delete and expand-all`
  - _Requirements: FR-10, FR-11, FR-7_
  - _Design: Phase 2 — 2.6 Message Actions, 2.7 Expand All_

- [x] 2.7 Wire message actions in ChatView and ChatViewModel
  - **Do**:
    1. Add `func retryMessage(_ message: ChatMessage)` to ChatViewModel — finds preceding user message, removes assistant response, resends
    2. Add `func deleteMessage(_ message: ChatMessage)` to ChatViewModel — removes message from `messages` array
    3. Update ChatView `messagesContent` to pass `onRetry` and `onDelete` closures to each MessageView
    4. Add confirmation dialog for delete action (AC-5.4)
  - **Files**: `ILSApp/ILSApp/Views/Chat/ChatView.swift` (modify), `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (modify)
  - **Done when**: Retry resends last user message; Delete removes message with confirmation
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `feat(ios): wire retry and delete message actions in ChatView`
  - _Requirements: FR-10_
  - _Design: Phase 2 — 2.6 Message Actions (callbacks)_

- [x] V3 [VERIFY] Phase 2 checkpoint: build + install + screenshot evidence
  - **Do**:
    1. Build and install on simulator (UDID: 50523130-57AA-48B0-ABD0-4D59CE455F14)
    2. Start backend: `PORT=9090 swift run ILSBackend &`
    3. Navigate to a chat session, send a message
    4. Capture screenshots showing: markdown rendering (if table/blockquote in response), code block with highlighting, thinking section, tool call accordion
    5. Verify long-press context menu appears
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: iOS app builds, installs, and chat rendering works with MarkdownUI + HighlightSwift
  - **Commit**: `chore(ios): capture Phase 2 chat rendering evidence`

---

## Phase 3: Streaming Hardening

Focus: Add SSE event IDs (server + client), implement exponential backoff, replace Timer with Task batching, improve auto-scroll, add streaming stats.

- [x] 3.1 Add SSE event IDs and ring buffer to StreamingService (backend)
  - **Do**:
    1. In `StreamingService.swift`, add `EventCounter` actor with `func next() -> Int`
    2. Add `EventBuffer` actor with `store(id:data:)` and `eventsSince(_ lastId:)` — ring buffer capacity 1000
    3. Update `formatSSEEvent` to accept `eventId: Int` and emit `id: N\nevent: type\ndata: json\n\n` format
    4. Extract shared `writeSSEStream()` method per design.md section 4.4:
       - Both `createSSEResponse` and `createSSEResponseWithPersistence` call `writeSSEStream`
       - `createSSEResponseWithPersistence` passes `onMessage` closure for content accumulation
       - Single heartbeat, event formatting, disconnect detection path
    5. Add `Last-Event-ID` header parsing in stream handler; replay from `eventBuffer.eventsSince(lastId)`
    6. Remove `debugLog()` function (line 6-11) — use `request.logger.debug()` instead
    7. Remove inline stderr log closure (line 166-169)
  - **Files**: `Sources/ILSBackend/Services/StreamingService.swift` (major rewrite)
  - **Done when**: SSE events include `id: N`; StreamingService has single `writeSSEStream` method; ring buffer stores last 1000 events
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "writeSSEStream" Sources/ILSBackend/Services/StreamingService.swift && grep -c "debugLog" Sources/ILSBackend/Services/StreamingService.swift`
  - **Commit**: `feat(backend): add SSE event IDs, ring buffer replay, and refactor StreamingService`
  - _Requirements: FR-14, FR-16, FR-25_
  - _Design: Phase 3 — 3.1 SSE Event IDs, Phase 4 — 4.4 StreamingService Refactor_

- [x] 3.2 Add event ID tracking and exponential backoff to SSEClient (iOS)
  - **Do**:
    1. In `SSEClient.swift`, add `private var lastEventId: String?`
    2. In `performStream`, add `Last-Event-ID` header when `lastEventId` is set (FR-15)
    3. Parse `id:` lines from SSE stream: `if line.hasPrefix("id:") { lastEventId = String(line.dropFirst(3)).trimming... }`
    4. Fix `shouldReconnect` backoff: change `reconnectDelay * UInt64(reconnectAttempts)` (linear) to `min(pow(2.0, Double(reconnectAttempts)) * 1_000_000_000, 30_000_000_000)` (power-of-2 exponential, max 30s) (FR-17/FR-45)
    5. Reset `reconnectAttempts = 0` on successful connection (FR-46 — WebSocket fallback reset)
    6. Replace all 16 `print(` statements with `AppLogger.shared.debug/info/error()` (FR-34 partial)
  - **Files**: `ILSApp/ILSApp/Services/SSEClient.swift` (modify)
  - **Done when**: SSEClient sends Last-Event-ID; uses power-of-2 backoff; zero print() statements
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "print(" ILSApp/ILSApp/Services/SSEClient.swift && grep -c "lastEventId" ILSApp/ILSApp/Services/SSEClient.swift`
  - **Commit**: `feat(ios): add SSE event ID tracking, exponential backoff, replace print with AppLogger`
  - _Requirements: FR-15, FR-17, FR-45, FR-34 (SSEClient)_
  - _Design: Phase 3 — 3.2 SSEClient Event ID + Exponential Backoff_

- [x] 3.3 Replace Timer.scheduledTimer with Task-based batching in ChatViewModel
  - **Do**:
    1. In `ChatViewModel.swift`, replace `batchTimer: Timer?` with `batchTask: Task<Void, Never>?`
    2. Replace `startBatchTimer()` (lines 127-138):
       ```
       private func startBatchTask() {
           guard batchTask == nil else { return }
           batchTask = Task { @MainActor [weak self] in
               while !Task.isCancelled {
                   try? await Task.sleep(nanoseconds: 75_000_000)
                   guard !Task.isCancelled else { break }
                   self?.flushPendingMessages()
               }
           }
       }
       ```
    3. Replace `stopBatchTimer()` with `stopBatchTask()` — `batchTask?.cancel(); batchTask = nil`
    4. Update `setupBindings()` to call `startBatchTask()` / `stopBatchTask()`
    5. Update `deinit` to cancel `batchTask` instead of invalidating `batchTimer`
    6. Add `cancellables.removeAll()` in deinit (FR-37)
    7. Add streaming stats tracking: `@Published var streamTokenCount: Int = 0`, `@Published var streamElapsedSeconds: Double = 0`, `streamStartTime: Date?`
    8. In `processStreamMessages`, extract token count from `.result` message usage
    9. Replace the single `print("Session initialized...")` with `AppLogger.shared.debug(...)` (FR-34)
  - **Files**: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (modify)
  - **Done when**: Zero Timer import/usage; Task-based batching; streaming stats tracked; cancellables cleaned in deinit
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "Timer" ILSApp/ILSApp/ViewModels/ChatViewModel.swift && grep -c "batchTask" ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
  - **Commit**: `feat(ios): replace Timer with Task batching, add streaming stats, cleanup cancellables`
  - _Requirements: FR-21, FR-35, FR-37, FR-18 (prep)_
  - _Design: Phase 3 — 3.3 Task-Based Batching, 3.5 Streaming Stats_

- [x] V4 [VERIFY] Quality checkpoint: both builds pass after streaming changes
  - **Do**: Run both backend and iOS builds
  - **Verify**: `swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore(app): pass streaming quality checkpoint` (only if fixes needed)

- [ ] 3.4 Add auto-scroll tracking, jump-to-bottom FAB, and streaming stats display
  - **Do**:
    1. In `ChatView.swift`, add state: `@State private var isUserScrolledUp = false`, `@State private var showJumpToBottom = false`
    2. Add `.onScrollGeometryChange` (iOS 17+) to detect when user scrolls up from bottom
    3. Modify `scrollToBottom` call in `.onChange(of: viewModel.messages.count)` to check `!isUserScrolledUp` (FR-19)
    4. Add jump-to-bottom FAB overlay when `showJumpToBottom` is true (FR-20):
       ```
       Button(action: { scrollToBottom(proxy: proxy) }) {
           Image(systemName: "chevron.down.circle.fill")...
       }
       .transition(.scale.combined(with: .opacity))
       ```
    5. Enhance `StreamingStatusView` to show token count + elapsed time (FR-18):
       ```
       if viewModel.isStreaming && viewModel.streamTokenCount > 0 {
           Text("\(viewModel.streamTokenCount) tokens \u{2022} \(String(format: "%.1f", viewModel.streamElapsedSeconds))s")
       }
       ```
    6. Replace `DispatchQueue.main.asyncAfter` in `ChatInputView` (line 322) with Task.sleep (FR-36)
  - **Files**: `ILSApp/ILSApp/Views/Chat/ChatView.swift` (modify)
  - **Done when**: Auto-scroll pauses when user scrolls up; FAB visible during streaming; token count + elapsed shown
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "showJumpToBottom" ILSApp/ILSApp/Views/Chat/ChatView.swift && grep -c "streamTokenCount" ILSApp/ILSApp/Views/Chat/ChatView.swift`
  - **Commit**: `feat(ios): add scroll tracking, jump-to-bottom FAB, and streaming stats display`
  - _Requirements: FR-18, FR-19, FR-20_
  - _Design: Phase 3 — 3.4 Auto-Scroll + Jump-to-Bottom FAB, 3.5 Streaming Stats_

---

## Phase 4: Backend Robustness

Focus: Global ErrorMiddleware, request validation, session pagination, ProjectsController optimization, print()->logger.

- [ ] 4.1 Create global ErrorMiddleware for structured JSON errors
  - **Do**:
    1. Create `Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift`
    2. Implement `AsyncMiddleware` per design.md section 4.1:
       - Catch `Abort` -> structured `{error: true, code: "...", reason: "..."}`
       - Catch `ValidationsError` -> 422 with `VALIDATION_ERROR` code
       - Catch unknown -> 500 with `INTERNAL_ERROR` (never expose stack traces)
    3. Create `ErrorBody: Content` struct
    4. In `configure.swift`, replace `app.middleware.use(ErrorMiddleware.default(environment: app.environment))` with `app.middleware.use(ILSErrorMiddleware())`
  - **Files**: `Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift` (create), `Sources/ILSBackend/App/configure.swift` (modify)
  - **Done when**: All errors return `{error: true, code: "...", reason: "..."}` JSON; no stack traces in 500 responses
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "ILSErrorMiddleware" Sources/ILSBackend/App/configure.swift`
  - **Commit**: `feat(backend): add custom ILSErrorMiddleware for structured JSON errors`
  - _Requirements: FR-22_
  - _Design: Phase 4 — 4.1 Global ErrorMiddleware_

- [ ] 4.2 Add request validation to ChatController
  - **Do**:
    1. In `ChatController.stream()`, add validation before Claude CLI call:
       ```
       guard !input.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
           throw Abort(.unprocessableEntity, reason: "Prompt cannot be empty")
       }
       ```
    2. Validate UUID params in all controllers that use `req.parameters.get("id")`:
       ```
       guard let id = req.parameters.get("id", as: UUID.self) else {
           throw Abort(.badRequest, reason: "Invalid ID format")
       }
       ```
       (SessionsController already does this; verify ChatController cancel route)
    3. Replace `req.logger.error("[STREAM]...")` debug logs with `req.logger.debug(...)` (wrong severity)
  - **Files**: `Sources/ILSBackend/Controllers/ChatController.swift` (modify)
  - **Done when**: Empty prompt returns 422; invalid UUID returns 400; debug logs use correct severity
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "unprocessableEntity" Sources/ILSBackend/Controllers/ChatController.swift`
  - **Commit**: `feat(backend): add request validation for chat stream endpoint`
  - _Requirements: FR-23_
  - _Design: Phase 4 — 4.2 Request Validation_

- [ ] 4.3 Add pagination to SessionsController.list
  - **Do**:
    1. Add `PaginatedResponse<T>` to `Sources/ILSShared/DTOs/PaginatedResponse.swift`:
       ```
       public struct PaginatedResponse<T: Codable>: Codable where T: Sendable {
           public let items: [T]
           public let total: Int
           public let hasMore: Bool
           public init(items: [T], total: Int, hasMore: Bool) { ... }
       }
       ```
    2. Update `SessionsController.list` to accept `?page=N&limit=N`:
       - Default page=1, limit=50, max limit=100
       - Compute offset = (page-1) * limit
       - Query total count, then paginated results
       - Return `APIResponse<PaginatedResponse<ChatSession>>`
    3. Keep backward compatibility: existing callers that don't pass page/limit get all results (limit=50 default)
  - **Files**: `Sources/ILSShared/DTOs/PaginatedResponse.swift` (create), `Sources/ILSBackend/Controllers/SessionsController.swift` (modify)
  - **Done when**: `/sessions?page=1&limit=5` returns 5 items with total and hasMore
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "PaginatedResponse" Sources/ILSBackend/Controllers/SessionsController.swift`
  - **Commit**: `feat(backend): add pagination to sessions list endpoint`
  - _Requirements: FR-24_
  - _Design: Phase 4 — 4.3 Sessions Pagination_

- [ ] V5 [VERIFY] Quality checkpoint: backend builds + curl validation
  - **Do**:
    1. Build backend
    2. Start backend: `PORT=9090 swift run ILSBackend &`
    3. Test error middleware: `curl -s http://localhost:9090/api/v1/sessions/not-a-uuid | python3 -m json.tool`
    4. Test pagination: `curl -s "http://localhost:9090/api/v1/sessions?page=1&limit=2" | python3 -m json.tool`
    5. Kill backend
  - **Verify**: `swift build 2>&1 | tail -5`
  - **Done when**: Backend builds; error responses are structured JSON; pagination works
  - **Commit**: `chore(backend): pass backend robustness quality checkpoint` (only if fixes needed)

- [ ] 4.4 Optimize ProjectsController.show() with direct lookup
  - **Do**:
    1. In `ProjectsController.show()` (line 140-155), replace `index(req:)` call + filter approach
    2. Instead, scan filesystem directly for matching project ID:
       - Iterate encoded dirs, compute deterministicID for each
       - Return early on first match (avoid O(n) over all projects)
       - Fall through to notFound if no match
    3. Extract shared scanning logic to avoid duplication between `index` and `show`
  - **Files**: `Sources/ILSBackend/Controllers/ProjectsController.swift` (modify)
  - **Done when**: `show()` does NOT call `index()` internally; finds project by direct iteration with early return
  - **Verify**: `swift build 2>&1 | tail -5 && grep -c "index(req:" Sources/ILSBackend/Controllers/ProjectsController.swift`
  - **Commit**: `perf(backend): optimize ProjectsController.show with direct lookup`
  - _Requirements: FR-28_
  - _Design: Phase 4 — 4.5 ProjectsController Direct Lookup_

- [ ] 4.5 Replace print()/debugLog() with structured logging across backend
  - **Do**:
    1. `ClaudeExecutorService.swift`: Replace 24 `debugLog()` calls with `Logger` from `Logging` framework (not `req.logger` since executor isn't in request context — create static logger)
    2. `StreamingService.swift`: Already done in 3.1 (verify zero debugLog remaining)
    3. `WebSocketService.swift`: Replace 1 `print()` with logger
    4. `GitHubService.swift`: Replace 2 `print()` with `req.logger`
  - **Files**: `Sources/ILSBackend/Services/ClaudeExecutorService.swift`, `Sources/ILSBackend/Services/WebSocketService.swift`, `Sources/ILSBackend/Services/GitHubService.swift`
  - **Done when**: Zero `print(` and zero `debugLog(` in Sources/ILSBackend (excluding Python scripts)
  - **Verify**: `swift build 2>&1 | tail -5 && grep -rc "print(" Sources/ILSBackend/ --include="*.swift" && grep -rc "debugLog(" Sources/ILSBackend/ --include="*.swift"`
  - **Commit**: `refactor(backend): replace print/debugLog with structured Logger`
  - _Requirements: FR-30_
  - _Design: Phase 4 — 4.6 print() to Logger Migration_

- [ ] 4.6 Add error code mapping to iOS APIClient
  - **Do**:
    1. In `APIClient.swift`, update `validateResponse` to decode `ErrorBody` from response body when status is 4xx/5xx
    2. Add new `APIError` case: `.serverError(code: String, reason: String)` for structured backend errors
    3. Map known codes to user-facing messages:
       - `VALIDATION_ERROR` -> "Please check your input"
       - `NOT_FOUND` -> "Resource not found"
       - `INTERNAL_ERROR` -> "Something went wrong. Please try again."
    4. Update `errorDescription` to use mapped messages
  - **Files**: `ILSApp/ILSApp/Services/APIClient.swift` (modify)
  - **Done when**: APIClient parses structured error responses from backend and maps to user-facing messages
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "serverError" ILSApp/ILSApp/Services/APIClient.swift`
  - **Commit**: `feat(ios): add structured error code mapping to APIClient`
  - _Requirements: FR-22 (client side)_
  - _Design: Phase 4 — 4.1 (client mapping)_

---

## Phase 5: Audit Fixes + Polish

Focus: Absorb all remaining audit fixes — concurrency safety, memory management, architecture patterns, theming, networking, accessibility.

- [ ] 5.1 Replace print() with AppLogger across iOS app
  - **Do**:
    1. `ILSAppApp.swift`: Replace 12 `print(` with `AppLogger.shared.info/debug/error()`
    2. `CommandPaletteView.swift`: Replace 1 `print(` with `AppLogger.shared.debug()`
    3. SSEClient already done in 3.2; ChatViewModel already done in 3.3
    4. Remove 1 redundant `objectWillChange.send()` in ILSAppApp.swift (FR-42)
  - **Files**: `ILSApp/ILSApp/ILSAppApp.swift`, `ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift`
  - **Done when**: Zero `print(` in ILSApp/ILSApp/ (excluding previews); zero redundant objectWillChange
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -rc "print(" ILSApp/ILSApp/ --include="*.swift" | grep -v ":0$"`
  - **Commit**: `refactor(ios): replace all print() with AppLogger, remove redundant objectWillChange`
  - _Requirements: FR-34, FR-42_
  - _Design: Phase 5 — 5.1 Concurrency Safety, 5.4 Theming Consistency_

- [ ] 5.2 Replace DispatchQueue.asyncAfter with Task.sleep across iOS app
  - **Do**:
    1. Replace `DispatchQueue.main.asyncAfter(deadline: .now() + N) { ... }` with `Task { try? await Task.sleep(for: .seconds(N)); ... }` in:
       - `SkillsListView.swift` — search/copy confirmation delay
       - `ProjectDetailView.swift` — copy confirmation delay
       - `TunnelSettingsView.swift` — copy/status delay
       - `SessionInfoView.swift` — copy confirmation delay
       - `ILSTheme.swift` — showToast delay
    2. MessageView and CodeBlockView already done in 2.6 and 2.2 respectively
    3. ChatView already done in 3.4
    4. Ensure each Task is cancellable (store reference if in a view that could disappear)
  - **Files**: `ILSApp/ILSApp/Views/Skills/SkillsListView.swift`, `ILSApp/ILSApp/Views/Projects/ProjectDetailView.swift`, `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`, `ILSApp/ILSApp/Views/Sessions/SessionInfoView.swift`, `ILSApp/ILSApp/Theme/ILSTheme.swift`
  - **Done when**: Zero `DispatchQueue.main.asyncAfter` in ILSApp/ILSApp/
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -rc "DispatchQueue.main.asyncAfter" ILSApp/ILSApp/`
  - **Commit**: `refactor(ios): replace DispatchQueue.asyncAfter with Task.sleep`
  - _Requirements: FR-36_
  - _Design: Phase 5 — 5.2 Memory Management_

- [ ] V6 [VERIFY] Quality checkpoint: iOS build after audit fixes batch 1
  - **Do**: Build iOS after print removal and DispatchQueue replacement
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Zero build errors
  - **Commit**: `chore(ios): pass audit fixes batch 1 quality checkpoint` (only if fixes needed)

- [ ] 5.3 Concurrency safety: [weak self] audit and Decoder isolation
  - **Do**:
    1. Audit all `Task { }` blocks in ChatViewModel, SSEClient for strong self captures (FR-32):
       - Ensure `[weak self]` where the task outlives the view model
       - Mark clearly with `@MainActor` where needed
    2. Verify `jsonDecoder` in ChatViewModel (line 51) is locally scoped (FR-33):
       - It's a `private let` — safe since ChatViewModel is @MainActor
       - Add comment: `// Isolated to @MainActor — safe for Sendable`
    3. Verify URLSession instances — SSEClient already has dedicated session (line 37); ChatViewModel uses SSEClient's (FR-31)
  - **Files**: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`, `ILSApp/ILSApp/Services/SSEClient.swift`
  - **Done when**: All Task closures use [weak self]; decoder isolation documented
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Commit**: `fix(ios): audit Task captures for weak self, document decoder isolation`
  - _Requirements: FR-31, FR-32, FR-33_
  - _Design: Phase 5 — 5.1 Concurrency Safety_

- [ ] 5.4 Extract DateFormatters namespace and complex computed properties
  - **Do**:
    1. Create `ILSApp/ILSApp/Utils/DateFormatters.swift` with static formatters (FR-39):
       ```
       enum DateFormatters {
           static let relativeDateTime: RelativeDateTimeFormatter = { ... }()
           static let time: DateFormatter = { ... }()
           static let dateTime: DateFormatter = { ... }()
       }
       ```
    2. Update MessageView.swift to use `DateFormatters.time` and `DateFormatters.dateTime` instead of inline static formatters (lines 9-20)
    3. Scan for computed properties >15 lines and extract to ViewModel methods (FR-40) — check ChatViewModel, SessionsViewModel
  - **Files**: `ILSApp/ILSApp/Utils/DateFormatters.swift` (create), `ILSApp/ILSApp/Views/Chat/MessageView.swift` (modify)
  - **Done when**: DateFormatters namespace exists; MessageView uses shared formatters
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -c "DateFormatters" ILSApp/ILSApp/Utils/DateFormatters.swift`
  - **Commit**: `refactor(ios): extract DateFormatters namespace, simplify computed properties`
  - _Requirements: FR-39, FR-40_
  - _Design: Phase 5 — 5.3 Architecture Cleanup_

- [ ] 5.5 Replace hardcoded fonts with ILSTheme and scope cache invalidation
  - **Do**:
    1. Replace 6 `.font(.system(size:))` occurrences with ILSTheme equivalents (FR-41, FR-48):
       - `ServerSetupSheet.swift:107` — `.font(.system(size: 44))` -> `.font(ILSTheme.displayFont)` (add if needed)
       - `ServerSetupSheet.swift:267` — `.font(.system(size: 36))` -> `.font(ILSTheme.largeTitleFont)` (add if needed)
       - `MCPServerListView.swift:230` — `.font(.system(size: 9))` -> `.font(ILSTheme.microFont)` (add if needed)
       - `EmptyEntityState.swift:29` — `.font(.system(size: 48))` -> `.font(ILSTheme.iconLargeFont)` (add if needed)
       - `ConnectionSteps.swift:66,70` — `.font(.system(size: 20))` -> `.font(ILSTheme.iconMediumFont)` (add if needed)
    2. Add any missing font constants to ILSTheme.swift (displayFont, largeTitleFont, microFont, iconLargeFont, iconMediumFont)
    3. In `APIClient.swift`, fix cache invalidation (FR-43):
       - Change `cache.removeValue(forKey: "/\(basePath)")` to `invalidateRelatedCaches(for: path)` — invalidate exact key, not prefix-based
    4. In `APIClient.performWithRetry`, skip sleep on final attempt (FR-44):
       - Add `guard attempt < maxAttempts else { throw }` before the backoff sleep
  - **Files**: `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`, `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`, `ILSApp/ILSApp/Theme/Components/EmptyEntityState.swift`, `ILSApp/ILSApp/Theme/Components/ConnectionSteps.swift`, `ILSApp/ILSApp/Theme/ILSTheme.swift`, `ILSApp/ILSApp/Services/APIClient.swift`
  - **Done when**: Zero `.font(.system(size:` in app code; cache invalidation scoped; retry skips final sleep
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -rc ".font(.system(size:" ILSApp/ILSApp/ --include="*.swift"`
  - **Commit**: `fix(ios): replace hardcoded fonts with ILSTheme, scope cache invalidation, fix retry sleep`
  - _Requirements: FR-41, FR-43, FR-44, FR-48_
  - _Design: Phase 5 — 5.4 Theming, 5.5 Network Reliability_

- [ ] 5.6 Add missing accessibility labels and color-only indicator fixes
  - **Do**:
    1. Audit all Toggle, TextField, Button elements across views for missing `.accessibilityLabel()` (FR-47):
       - `SettingsView.swift` — toggles need labels
       - `TunnelSettingsView.swift` — text fields need labels
       - `NewSessionView.swift` — form fields need labels
       - `SessionTemplatesView.swift` — buttons need labels
       - `MCPImportExportView.swift` — buttons need labels
       - `EditMCPServerView.swift` — text fields need labels
       - `NotificationPreferencesView.swift` — toggles need labels
       - Target 8+ new labels minimum
    2. Verify color-only indicators have shape/text augmentation (FR-49):
       - StatusBadge already uses text+circle — verify
       - StreamingStatusView (ChatView.swift) — ProgressView + "Reconnecting" text — OK
       - ConnectionBanner — uses icon + text — OK
       - Check if any tool call error indicator is color-only (red border needs additional cue)
    3. Add `.accessibilityLabel("Actions available: Copy, Retry, Delete")` to message bubbles
  - **Files**: `ILSApp/ILSApp/Views/Settings/SettingsView.swift`, `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`, `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift`, `ILSApp/ILSApp/Views/Sessions/SessionTemplatesView.swift`, `ILSApp/ILSApp/Views/MCP/MCPImportExportView.swift`, `ILSApp/ILSApp/Views/MCP/EditMCPServerView.swift`, `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift`
  - **Done when**: 8+ new accessibilityLabels added; no color-only indicators without text/shape
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5 && grep -rc "accessibilityLabel" ILSApp/ILSApp/ --include="*.swift" | awk -F: '{s+=$2} END {print "Total labels:", s}'`
  - **Commit**: `fix(ios): add 8+ missing accessibility labels, augment color-only indicators`
  - _Requirements: FR-47, FR-49_
  - _Design: Phase 5 — 5.6 Accessibility_

- [ ] V7 [VERIFY] Quality checkpoint: full iOS + backend build
  - **Do**: Run complete build for both targets after all audit fixes
  - **Verify**: `swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both builds succeed with zero errors
  - **Commit**: `chore(app): pass full audit quality checkpoint` (only if fixes needed)

---

## Phase 4.5: Quality Gates

- [ ] 4G.1 [VERIFY] Full local CI: build both targets
  - **Do**: Run complete local CI suite
  - **Verify**: `swift build 2>&1 | tail -5 && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build 2>&1 | tail -5`
  - **Done when**: Both build succeed, zero errors
  - **Commit**: `chore(app): pass local CI` (if fixes needed)

- [ ] 4G.2 Create PR and verify CI
  - **Do**:
    1. Verify current branch is `design/v2-redesign`: `git branch --show-current`
    2. Stage and commit any remaining changes
    3. Push branch: `git push -u origin design/v2-redesign`
    4. Create PR: `gh pr create --title "feat: chat rendering overhaul + backend hardening" --body "..."`
    5. If gh CLI unavailable, provide URL for manual PR creation
  - **Verify**: `gh pr checks --watch` or `gh pr checks` (poll)
  - **Done when**: All CI checks green, PR ready for review
  - **If CI fails**: Read failure, fix locally, push, re-verify

---

## Phase 5.5: PR Lifecycle

- [ ] 5P.1 [VERIFY] CI pipeline passes
  - **Do**: Verify GitHub Actions/CI passes after push
  - **Verify**: `gh pr checks` shows all green
  - **Done when**: CI pipeline passes
  - **Commit**: None

- [ ] 5P.2 [VERIFY] AC checklist — verify all 49 FRs
  - **Do**: Programmatically verify each FR is satisfied:
    1. **FR-1**: `grep -c "import MarkdownUI" ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift` (should be 1)
    2. **FR-2**: `grep -c "import HighlightSwift" ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (should be 1)
    3. **FR-3**: `grep -c "showLineNumbers" ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (should be >0)
    4. **FR-5**: `grep -c "inputPairs" ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` (should be >0)
    5. **FR-6**: `grep -c "showFullOutput" ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` (should be >0)
    6. **FR-8**: `grep -c "Markdown(" ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` (should be >0)
    7. **FR-9**: `grep -c "chars" ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` (should be >0)
    8. **FR-10**: `grep -c "contextMenu" ILSApp/ILSApp/Views/Chat/MessageView.swift` (should be >0)
    9. **FR-13**: `grep -c "keywords" ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (should be 0)
    10. **FR-14**: `grep -c "eventId" Sources/ILSBackend/Services/StreamingService.swift` (should be >0)
    11. **FR-17/FR-45**: `grep -c "pow(2" ILSApp/ILSApp/Services/SSEClient.swift` (should be >0)
    12. **FR-21/FR-35**: `grep -c "Timer" ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (should be 0)
    13. **FR-22**: `grep -c "ILSErrorMiddleware" Sources/ILSBackend/Middleware/ILSErrorMiddleware.swift` (should be >0)
    14. **FR-24**: `grep -c "PaginatedResponse" Sources/ILSBackend/Controllers/SessionsController.swift` (should be >0)
    15. **FR-25**: `grep -c "writeSSEStream" Sources/ILSBackend/Services/StreamingService.swift` (should be >0)
    16. **FR-26**: `grep -rc "= FileSystemService()" Sources/ILSBackend/Controllers/` (should be 0)
    17. **FR-27**: `grep -rc "UnsafeMutablePointer" Sources/ILSBackend/` (should be 0)
    18. **FR-29**: `grep -c "struct ChatMessage" ILSApp/ILSApp/Models/ChatMessage.swift` (should be 1)
    19. **FR-30**: `grep -rc "print(" Sources/ILSBackend/ --include="*.swift"` (should be 0)
    20. **FR-34**: `grep -rc "print(" ILSApp/ILSApp/ --include="*.swift"` (should be 0, excluding previews)
    21. **FR-36**: `grep -rc "DispatchQueue.main.asyncAfter" ILSApp/ILSApp/` (should be 0)
    22. **FR-41**: `grep -rc ".font(.system(size:" ILSApp/ILSApp/ --include="*.swift"` (should be 0)
    23. **FR-42**: `grep -c "objectWillChange.send" ILSApp/ILSApp/ILSAppApp.swift` (should be 0)
  - **Verify**: Run all grep commands above; all should match expected values
  - **Done when**: All 49 FRs confirmed met via automated checks
  - **Commit**: None

- [ ] 5P.3 [VERIFY] Visual evidence capture
  - **Do**:
    1. Build, install on simulator UDID 50523130-57AA-48B0-ABD0-4D59CE455F14
    2. Start backend: `PORT=9090 swift run ILSBackend`
    3. Navigate to sessions, open a chat, send a message that will trigger markdown rendering
    4. Capture screenshots of:
       - Chat with markdown (table/blockquote if in response)
       - Code block with HighlightSwift coloring + line numbers
       - Tool call accordion expanded with key-value pairs
       - Thinking section with char count
       - Streaming indicator with token count
       - Long-press context menu on message
       - Jump-to-bottom FAB during streaming (if achievable)
    5. Save to `specs/app-enhancements/evidence/`
  - **Verify**: Screenshot files exist in evidence directory
  - **Done when**: 6+ evidence screenshots captured showing new features
  - **Commit**: `chore(spec): capture app-enhancements evidence screenshots`

---

## Notes

- **POC shortcuts**: None — quality-first approach per interview decision
- **Deduplication**: FR-21/FR-35 (Timer->Task) handled in task 3.3; FR-17/FR-45 (exponential backoff) handled in task 3.2
- **Dependencies**: MarkdownUI iOS-only (Xcode SPM), HighlightSwift iOS-only (Xcode SPM) — not added to root Package.swift which is backend-only
- **FileSystemService DI**: 7 controllers all create inline instances — single task 1.3 addresses all
- **Backend print() count**: 4 in Swift files (GitHubService:2, WebSocketService:1, plus debugLog wrapper) + 24 debugLog in ClaudeExecutor
- **iOS print() count**: 30 total (SSEClient:16, ILSAppApp:12, ChatVM:1, CommandPalette:1)
- **DispatchQueue.asyncAfter count**: 8 files — addressed across tasks 2.2 (CodeBlockView), 2.6 (MessageView), 3.4 (ChatView), 5.2 (remaining 5 files)
- **Hardcoded .font(.system(size:))**: 6 occurrences in 4 files — all addressed in task 5.5
- **Published+didSet**: grep found zero instances — already clean
- **Risk area**: MarkdownUI streaming re-render performance — monitor in Phase 2 screenshots; 75ms batch flush should mitigate
- **ListResponse compatibility**: iOS APIClient has its own `ListResponse` (line 203) and backend uses ILSShared's `ListResponse` — pagination adds `PaginatedResponse` alongside, not replacing
