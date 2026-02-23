# Phase 13: ViewModel & Model Optimization - Research

**Researched:** 2026-02-23
**Domain:** Swift iOS ViewModel lifecycle, SSE buffer management, chat message windowing, WebSocket reconnection
**Confidence:** HIGH

## Summary

Phase 13 focuses on three optimization areas within the ViewModel and model layer: (1) MetricsWebSocketClient reconnection timeout (NET-02), (2) SystemMetricsViewModel deinit cancellation (MEM-03), and (3) SSE buffer management and chat message windowing for large histories.

Key finding: Several success criteria from the original roadmap are already satisfied by completed phases. Dashboard parallelization (SPERF-04) was done in Phase 20 via `async let`. MEM-02 (WindowFrameDelegate cleanup) was resolved in Phase 19. NET-02 (MetricsWebSocketClient reconnection timeout) was partially resolved in Phase 23 with `maxReconnectAttempts = 10`. The remaining work is: (a) verify NET-02 completeness and add a total reconnection timeout (wall-clock cap), (b) add MEM-03 deinit cancellation for SystemMetricsViewModel, (c) ensure SSE `pendingStreamMessages` buffer is cleared after processing to prevent unbounded growth, and (d) implement chat message windowing for sessions with 200+ messages.

**Primary recommendation:** Focus on the three open items -- MEM-03 deinit cancellation (small, safe), SSE buffer flush verification (small, verify existing code), and chat message windowing (medium, requires backend pagination awareness and UI scroll-up loading). NET-02 is already resolved in code -- verify and close.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NET-02 | Add reconnection timeout to MetricsWebSocketClient | ALREADY RESOLVED in Phase 23: `maxReconnectAttempts = 10` with exponential backoff (1s, 2s, 4s... max 30s). After 10 attempts, stops retrying. Code at lines 29-30 and 209-212 of MetricsWebSocketClient.swift. Phase 13 should verify and optionally add a wall-clock timeout cap. |
| MEM-02 | Clean up WindowFrameDelegate when OS closes window | ALREADY RESOLVED in Phase 19 (commit in Phase 19-02). Out of scope for Phase 13. |
| MEM-03 | Add SystemMetricsViewModel deinit cancellation | OPEN: SystemMetricsViewModel has no deinit. The `processRefreshTask` and `metricsClient` are cleaned up via `disconnect()` called from `SystemMonitorView.onDisappear`, but if the view is deallocated without `onDisappear` firing (e.g., navigation stack pop during background), tasks leak. Need explicit cleanup path. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Observation | 5.10+ | @Observable ViewModel pattern | Already used throughout; ChatViewModel, SystemMetricsViewModel, DashboardViewModel all use @Observable |
| SwiftUI LazyVStack | iOS 17+ | Lazy rendering for chat messages | Already used in ChatMessageList; key for windowing performance |
| URLSession WebSocket | iOS 17+ | WebSocket connections | Already used in MetricsWebSocketClient |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ScrollViewReader | iOS 17+ | Programmatic scroll control | Already used in ChatMessageList for jump-to-bottom; needed for scroll-up loading |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LazyVStack windowing | UIKit UITableView via UIViewRepresentable | Much more complex, but gives prefetching delegate; LazyVStack is sufficient for 200 messages |
| Manual pagination state | Combine publishers | Observation framework is already the pattern; no Combine needed |

## Architecture Patterns

### Pattern 1: ViewModel Cleanup via onDisappear + Explicit cleanup()
**What:** Since @MainActor @Observable classes cannot safely access properties in `deinit` (deinit is nonisolated), cleanup is done via explicit `cleanup()` or `disconnect()` called from view lifecycle.
**When to use:** All ViewModels that own async Task properties or network connections.
**Current state:** SystemMetricsViewModel uses `disconnect()` called from `SystemMonitorView.onDisappear`. MetricsWebSocketClient has `cleanup()`. SSEClient has `cleanup()`.
**Gap for MEM-03:** SystemMetricsViewModel.disconnect() cancels `processRefreshTask` and calls `metricsClient.disconnect()`, but there is no guard against the view being deallocated without onDisappear. The fix is to add `@ObservationIgnored` on the cleanup-sensitive task and ensure `disconnect()` is idempotent (it already is).

```swift
// Pattern: ViewModel with explicit cleanup
@MainActor @Observable
final class SystemMetricsViewModel {
    @ObservationIgnored private var processRefreshTask: Task<Void, Never>?  // Already done

    func disconnect() {
        metricsClient.disconnect()
        stopProcessAutoRefresh()  // Already cancels processRefreshTask
    }

    // MEM-03: Add nonisolated deinit that cancels the task
    // Task.cancel() is safe to call from nonisolated context
    deinit {
        processRefreshTask?.cancel()
    }
}
```

### Pattern 2: SSE Buffer Flush After Processing
**What:** ChatViewModel batches incoming SSE messages in `pendingStreamMessages` and flushes them on a 75ms timer via `flushPendingMessages()`.
**Current state:** The buffer IS already cleared after processing:
- `flushPendingMessages()` at line 222-229 copies `pendingStreamMessages`, calls `removeAll()`, then processes
- When streaming ends, `setupBindings()` calls `self.flushPendingMessages()` then `self.stopBatchTimer()`
- `stopBatchTimer()` cancels and nils the batchTask

**Assessment:** The SSE buffer management is already correct. The `pendingStreamMessages` array is flushed on every batch tick and on stream end. The `batchTask` is cancelled when streaming stops. No unbounded growth path exists. This success criterion is already met.

### Pattern 3: Chat Message Windowing for Large Histories
**What:** For sessions with 200+ messages, load only the most recent ~50 messages initially and load older messages on scroll-up.
**When to use:** When `loadMessageHistory()` returns a large result set.
**Backend support:** Both `/sessions/:id/messages` and `/sessions/transcript/:path/:id` already support `limit` and `offset` query parameters. The backend returns `ListResponse<Message>` with `total` count.

```swift
// Pattern: Windowed message loading
@Observable @MainActor
class ChatViewModel {
    private let messageWindowSize = 50
    private var totalMessageCount = 0
    private var oldestLoadedOffset = 0
    var canLoadMore: Bool { oldestLoadedOffset > 0 }

    func loadMessageHistory() async {
        // Load last N messages using offset = max(0, total - windowSize)
        // Store totalMessageCount and oldestLoadedOffset for pagination
    }

    func loadOlderMessages() async {
        // Load previous batch: offset = max(0, oldestLoadedOffset - windowSize)
        // Prepend to messages array
    }
}
```

### Anti-Patterns to Avoid
- **Loading all messages then slicing in-memory:** The backend already supports server-side pagination. Use it. Do not fetch 500 messages and display 50.
- **Replacing messages array on load-more:** Prepend older messages, do not replace. The user is viewing current messages while older ones load.
- **Using deinit for @MainActor cleanup:** deinit is nonisolated. Only `Task.cancel()` is safe from deinit. All other cleanup must go through view lifecycle (onDisappear).
- **Resetting scroll position on prepend:** When older messages are prepended, the scroll position must be preserved so the user doesn't jump. Use `ScrollViewReader` to maintain anchor on the previously-first visible message.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Pagination state machine | Custom offset/limit tracker | Simple Int properties (totalMessageCount, oldestLoadedOffset) | The state is simple: two integers. No state machine needed. |
| WebSocket reconnection | Custom reconnection logic | Already built in MetricsWebSocketClient with exponential backoff | Phase 23 already added maxReconnectAttempts = 10 |
| Message diff/merge | Custom array diffing for prepend | Array concatenation with `oldMessages + existingMessages` | LazyVStack handles identity via ForEach id; no diff needed |

**Key insight:** The existing codebase already has the foundational patterns. This phase is about completing edge cases (MEM-03 deinit), verifying existing behavior (SSE buffer, NET-02), and adding one new feature (message windowing).

## Common Pitfalls

### Pitfall 1: Scroll Position Jump on Message Prepend
**What goes wrong:** When older messages are prepended to the array, SwiftUI re-renders the LazyVStack and scrolls to the top (or jumps unpredictably).
**Why it happens:** ForEach identity changes cause SwiftUI to re-layout. The scroll offset is not preserved relative to visible content.
**How to avoid:** Before prepending, capture the ID of the first currently-visible message. After prepending, use `ScrollViewReader.scrollTo(savedId, anchor: .top)` without animation. Alternatively, use `.scrollPosition(id:)` (iOS 17+) to maintain position.
**Warning signs:** User reports that tapping "load more" causes the view to jump to the top or flash.

### Pitfall 2: Double-Loading Messages on Rapid Scroll
**What goes wrong:** User scrolls up quickly, triggering multiple `loadOlderMessages()` calls before the first completes.
**Why it happens:** No guard against concurrent load-more requests.
**How to avoid:** Add `isLoadingOlderMessages` flag, checked at the top of `loadOlderMessages()`. Already have `isLoadingHistory` for initial load; add a separate flag for pagination.
**Warning signs:** Duplicate messages appearing in the list, or messages in wrong order.

### Pitfall 3: deinit Task.cancel() Not Sufficient Alone
**What goes wrong:** Relying solely on deinit to cancel tasks, but the object is retained by the Task closure itself (retain cycle).
**Why it happens:** `Task { [weak self] in ... }` creates a weak capture, but if the task body holds a strong reference through other means (e.g., capturing `self.someProperty`), the ViewModel is never deallocated.
**How to avoid:** Always use `[weak self]` in Task closures. The existing code already does this correctly. The deinit cancellation is a safety net, not the primary cleanup path -- onDisappear remains the primary path.
**Warning signs:** Memory growth when navigating away from System Monitor repeatedly.

### Pitfall 4: Backend Transcript Endpoint Reads Entire File
**What goes wrong:** The `/sessions/transcript/:path/:id` endpoint reads the entire JSONL file into memory, parses all lines, then applies offset/limit at the end (lines 316-320 of SessionFileService.swift).
**Why it happens:** JSONL files cannot be randomly accessed without reading from the start.
**How to avoid:** For Phase 13 (client-side windowing), this is acceptable because: (a) transcript files are typically <1MB, (b) the backend caches aggressively, (c) the iOS client calls this once per session open. If transcript files grow very large, a future phase could add reverse-reading (read last N lines) or server-side caching. Do not optimize this in Phase 13.
**Warning signs:** Slow transcript loading for sessions with 1000+ messages.

## Code Examples

### MEM-03: SystemMetricsViewModel deinit Cancellation

```swift
// File: ILSApp/ILSApp/ViewModels/SystemMetricsViewModel.swift
// Add deinit after init

deinit {
    // Task.cancel() is safe from nonisolated deinit context.
    // This is a safety net for cases where onDisappear doesn't fire
    // (e.g., navigation stack deallocated during background).
    // Primary cleanup remains disconnect() called from onDisappear.
    processRefreshTask?.cancel()
}
```

### NET-02: Verification (Already Resolved)

```swift
// File: ILSApp/ILSApp/Services/MetricsWebSocketClient.swift
// Lines 29-30: Already present from Phase 23
private let maxReconnectAttempts = 10

// Lines 209-212: Already present from Phase 23
guard reconnectAttempts <= maxReconnectAttempts else {
    isConnected = false
    return
}
```

### Chat Message Windowing: loadMessageHistory with Pagination

```swift
// File: ILSApp/ILSApp/ViewModels/ChatViewModel.swift
// Modified loadMessageHistory to support windowed loading

private let messageWindowSize = 50
private(set) var totalMessageCount = 0
private var currentOffset = 0
var canLoadOlderMessages: Bool { currentOffset > 0 }
var isLoadingOlderMessages = false

func loadMessageHistory() async {
    guard let apiClient else { return }
    isLoadingHistory = true
    error = nil

    do {
        if let encodedProjectPath, let claudeSessionId {
            let path = "/sessions/transcript/\(encodedProjectPath)/\(claudeSessionId)"
            // First, get total count with limit=0 or a small request
            let response: APIResponse<ListResponse<Message>> = try await apiClient.get(
                "\(path)?limit=\(messageWindowSize)"
            )
            if let data = response.data {
                totalMessageCount = data.total
                currentOffset = max(0, data.total - messageWindowSize)
                // Re-fetch from the correct offset for the last N messages
                let windowResponse: APIResponse<ListResponse<Message>> = try await apiClient.get(
                    "\(path)?limit=\(messageWindowSize)&offset=\(currentOffset)"
                )
                if let windowData = windowResponse.data {
                    messages = windowData.items.map { /* convert to ChatMessage */ }
                }
            }
        }
        // ... similar for ILS sessions via /sessions/:id/messages
    } catch { /* existing error handling */ }

    isLoadingHistory = false
}

func loadOlderMessages() async {
    guard canLoadOlderMessages, !isLoadingOlderMessages else { return }
    isLoadingOlderMessages = true

    let newOffset = max(0, currentOffset - messageWindowSize)
    let fetchLimit = currentOffset - newOffset

    // Fetch older batch and prepend
    // ... API call with offset=newOffset, limit=fetchLimit
    // messages = olderMessages + messages

    currentOffset = newOffset
    isLoadingOlderMessages = false
}
```

### ChatMessageList: Scroll-Up Loading Trigger

```swift
// File: ILSApp/ILSApp/Views/Chat/ChatMessageList.swift
// Add a "load more" indicator at the top of the LazyVStack

LazyVStack(spacing: 0) {
    if canLoadMore {
        Button("Load earlier messages") {
            Task { await onLoadMore() }
        }
        .padding()
    }

    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
        // ... existing message rendering
    }

    // ... existing bottom anchor
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Timer.scheduledTimer` for polling | `Task` + `Task.sleep(for:)` | Phase 19 | Eliminates RunLoop dependency, proper cancellation |
| `deinit { disconnect() }` | `onDisappear { viewModel.disconnect() }` | Phase 19 | @MainActor safety -- deinit is nonisolated |
| Unguarded reconnection loops | `maxReconnectAttempts = 10` | Phase 23 | Prevents infinite reconnect burn |
| Load all messages eagerly | Paginated with `limit`/`offset` | Backend already supports | Enables windowed display |

**Deprecated/outdated:**
- `Timer.scheduledTimer` in ViewModels: Replaced with Task-based polling in Phase 19
- Direct `DispatchQueue.main.async` in @MainActor classes: Replaced with `Task { @MainActor in }` in Phase 19

## Open Questions

1. **Optimal window size for chat messages**
   - What we know: 50 messages is a common default (similar to Slack, Discord). The existing LazyVStack handles 50 messages without performance issues.
   - What's unclear: Whether 50 is too few for users who frequently reference earlier context. Whether the scroll-to-anchor technique works reliably with LazyVStack prepend.
   - Recommendation: Start with 50, make it configurable. Test scroll preservation with real data before finalizing.

2. **Should loadOlderMessages be automatic or manual?**
   - What we know: Two approaches: (a) "Load more" button at top, (b) automatic prefetch when user scrolls near the top.
   - What's unclear: SwiftUI LazyVStack doesn't expose a prefetch callback like UITableView.
   - Recommendation: Start with a manual "Load earlier messages" button. Simpler, more predictable. Automatic prefetch can be added in Phase 15 (View Layer Rendering) if needed.

3. **Transcript endpoint efficiency for windowed loading**
   - What we know: The backend reads the entire JSONL file and slices at the end. For windowed loading, the client makes two requests (one to get total, one with offset).
   - What's unclear: Whether this adds noticeable latency for large transcripts.
   - Recommendation: For Phase 13, accept the two-request pattern. The backend is local (localhost:9999), so latency is negligible. Optimize in a future phase if profiling shows issues.

## Sources

### Primary (HIGH confidence)
- Source code analysis of MetricsWebSocketClient.swift (252 lines), SystemMetricsViewModel.swift (174 lines), ChatViewModel.swift (618 lines), SSEClient.swift (326 lines), ChatMessageList.swift (203 lines), ChatView.swift (441 lines)
- Source code analysis of SessionsController.swift messages endpoint (lines 406-475) -- confirms limit/offset pagination
- Source code analysis of SessionFileService.swift readTranscriptMessages (lines 210-321) -- confirms limit/offset support
- Phase 23-06-PLAN.md confirming NET-MED-1 (NET-02) was addressed with maxReconnectAttempts = 10

### Secondary (MEDIUM confidence)
- Phase 19, 20, 22 decision records in STATE.md confirming prior work on related patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all patterns already exist in codebase, no new dependencies
- Architecture: HIGH -- pagination support exists in backend, ViewModel patterns well-established
- Pitfalls: HIGH -- scroll position preservation is the main risk; well-documented in SwiftUI community

**Research date:** 2026-02-23
**Valid until:** 2026-03-23 (stable domain, no external dependency changes expected)
