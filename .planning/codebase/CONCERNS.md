# Codebase Concerns

**Analysis Date:** 2026-02-19

## Tech Debt

**SSEClient using ObservableObject (legacy pattern):**
- Issue: `SSEClient` at `ILSApp/ILSApp/Services/SSEClient.swift:7` still uses `@ObservableObject` + `@Published` instead of `@Observable`
- Files: `ILSApp/ILSApp/Services/SSEClient.swift`
- Impact: Inconsistent with modern SwiftUI patterns; other services use `@Observable` (NetworkMonitor, ConnectionManager, MetricsWebSocketClient). Creates memory leak risk via Combine subscriptions if ChatViewModel weak references fail
- Fix approach: Migrate to `@Observable` macro with `@State` properties, remove Combine dependency, update ChatViewModel bindings

**Large monolithic view files:**
- Issue: Multiple SwiftUI views exceed 800-line guideline
  - `ThemeEditorView.swift`: 1,222 lines (80+ @State properties for theme tokens)
  - `SyntaxHighlighter.swift`: 1,177 lines (custom syntax highlighting implementation)
  - `BrowserView.swift`: 1,146 lines (combined MCP/Skills/Plugins tabs)
  - `SettingsView.swift`: 676 lines (iOS), `MacSettingsView.swift`: 485 lines
  - `ChatViewModel.swift`: 616 lines (message management + streaming + permission handling)
  - `ClaudeExecutorService.swift`: 896 lines (process management + timeout logic + message conversion)
- Files: Multiple in `ILSApp/ILSApp/Views/` and `Sources/ILSBackend/Services/`
- Impact: High cognitive load, difficult to test, refactoring risk, maintenance burden
- Fix approach:
  - `ThemeEditorView`: Split into ColorTokensView, TypographyTokensView, SpacingTokensView, RadiusTokensView (4 files)
  - `SyntaxHighlighter`: Extract tokenizer into separate SyntaxTokenizer service
  - `BrowserView`: Move Skills, MCP, Plugins to separate tab views
  - `ChatViewModel`: Extract message batching logic to MessageBatchProcessor actor
  - `ClaudeExecutorService`: Extract timeout handling to ProcessTimeoutManager, message conversion to CLIMessageConverter

**Configuration file write atomicity:**
- Issue: `ConfigFileService.swift:79-80` uses non-atomic JSON write: `encoder.encode()` followed by `Data.write()` without `.atomic` option
- Files: `Sources/ILSBackend/Services/ConfigFileService.swift`
- Impact: Process crash during write can corrupt `~/.claude/settings.json` permanently, breaking user configuration
- Fix approach: Use `Data.write(to:options:.atomic)` to ensure transactional writes. Also check MCPFileService.swift for same issue

**Connection state persistence without validation:**
- Issue: `ConnectionManager` at `ILSApp/ILSApp/Services/ConnectionManager.swift:23-27` persists server URL to UserDefaults without validating it's reachable at app startup
- Files: `ILSApp/ILSApp/Services/ConnectionManager.swift`
- Impact: If backend moves or tunnel URL expires, stale URL persists and causes silent failures on app launch. Users may see "Connection failed" without recourse
- Fix approach: Add lazy validation: if saved URL fails health check on app launch, fall back to default and prompt user to reconfigure

## Known Bugs

**SSH credential handling accepts private key files unsafely:**
- Symptoms: SSH key authentication at `CitadelSSHService.swift:35-45` reads file without validating file permissions or ownership
- Files: `ILSApp/ILSApp/Services/CitadelSSHService.swift`
- Trigger: User provides SSH key path with world-readable permissions
- Workaround: Manually verify SSH key file permissions (chmod 600)
- Fix approach: Add permission validation before reading; reject if world-readable or group-readable

**Data persistence after app termination doesn't fully drain in-flight writes:**
- Symptoms: UserDefaults + LocalDatabase writes may not complete if app is force-quit during write
- Files: `ILSApp/ILSApp/Services/LocalDatabase.swift`, `ILSApp/ILSApp/Services/ConnectionManager.swift`
- Trigger: Force-quit app during network request or cache write
- Workaround: None; data loss during in-flight operations
- Fix approach: Use `Data.write(to:options:.atomic)` throughout; wrap UserDefaults writes with synchronization barriers; add App Transport Security drain on scenePhase change to .background

**SSEClient reconnection may leave stale request state:**
- Symptoms: If reconnection attempt occurs while previous request is still closing, `currentRequest` state may become inconsistent
- Files: `ILSApp/ILSApp/Services/SSEClient.swift:50-67`
- Trigger: Network transitions (WiFi → cellular) during active stream
- Workaround: Manually cancel and restart stream
- Fix approach: Add explicit state machine (Idle → Connecting → Connected → Reconnecting → Disconnected) with state validation before transitions

## Security Considerations

**SSH key credentials stored in memory without cleanup:**
- Risk: SSH private key contents at `CitadelSSHService.swift:35-45` are held in `keyString` variable; if actor is deallocated unexpectedly, key may linger in freed memory
- Files: `ILSApp/ILSApp/Services/CitadelSSHService.swift`
- Current mitigation: Variable scope-limited; Citadel library handles key storage internally
- Recommendations:
  1. Explicitly zero `keyString` after use: `keyString.removeAll()` before returning
  2. Use Keychain for SSH key storage instead of accepting raw credential parameter
  3. Add `SecureString` wrapper that zeros memory on deinit

**Cloudflare tunnel credentials in environment variables:**
- Risk: `TunnelSettingsView.swift` at line 31-33 stores Cloudflare token, tunnel name, domain in @State without encryption
- Files: `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
- Current mitigation: Values only in memory during session; not persisted
- Recommendations:
  1. If values need persistence, use Keychain instead of UserDefaults
  2. Add `screenshotProtected()` modifier (already done) but also disable pasteboard access
  3. Clear fields on view disappear

**PermissionRequest handling may leak sensitive tool inputs:**
- Risk: Tool call inputs at `ILSApp/ILSApp/Views/Chat/PermissionRequestModal.swift:193` are displayed in UI without sanitization
- Files: `ILSApp/ILSApp/Views/Chat/PermissionRequestModal.swift`
- Current mitigation: Tool inputs wrapped in AnyCodable; preview generation attempted
- Recommendations:
  1. Truncate previews to 200 chars
  2. Sanitize HTML/script injection in tool names and inputs
  3. Add toggle to hide sensitive input values

**Config file paths disclosed in error messages:**
- Risk: Backend errors at `ConfigFileService.swift` may expose home directory paths in logs
- Files: `Sources/ILSBackend/Services/ConfigFileService.swift`, `Sources/ILSBackend/Services/MCPFileService.swift`
- Current mitigation: Errors logged to AppLogger (not user-facing by default)
- Recommendations:
  1. Use relative paths in error messages (e.g., `~/.claude/settings.json` not `/Users/nick/.claude/settings.json`)
  2. Strip full paths from error descriptions before sending to frontend

## Performance Bottlenecks

**External sessions cache O(n) membership test on every list operation:**
- Problem: `SessionsController.swift:79-80` builds a Set of `dbClaudeIds` on every list() call to dedup external sessions
- Files: `Sources/ILSBackend/Controllers/SessionsController.swift`
- Cause: External sessions (~22K) must be deduplicated against DB sessions (~51) on every request; set construction is O(n)
- Improvement path:
  1. Cache deduplication set with TTL (5 min) instead of rebuilding each time
  2. Lazy-load external sessions only if projectId filter is nil
  3. Consider pre-computing dedup in FileSystemService.listExternalSessionsAsChatSessions()

**Message batching interval (75ms) may cause perceptible chat lag:**
- Problem: `ChatViewModel.swift:91` batches stream messages with 75ms interval to reduce SwiftUI updates
- Files: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- Cause: Trade-off between rendering smoothness and latency; user sees 75ms+ delay between server send and UI render
- Improvement path:
  1. Reduce batch interval to 30-40ms (or measure frame time)
  2. Or implement incremental token rendering (each token appears immediately, batched in groups)
  3. Monitor FPS and adjust dynamically based on device capability

**LocalDatabase table scans on every cache operation:**
- Problem: `LocalDatabase.swift` does not use indexes on `sessionId`, `id` columns
- Files: `ILSApp/ILSApp/Services/LocalDatabase.swift`
- Cause: GRDB FetchableRecord queries without explicit index hints fall back to full table scans
- Improvement path:
  1. Add CREATE INDEX statements for frequently queried columns (sessionId, id, createdAt)
  2. Profile queries with SQLite EXPLAIN QUERY PLAN
  3. Consider pagination limit (e.g., max 1000 cached items per table)

**ProcessTimeoutManager uses DispatchQueue.global().asyncAfter() which blocks global queue:**
- Problem: `ClaudeExecutorService.swift:241` schedules long-lived timeout work on global dispatch queue
- Files: `Sources/ILSBackend/Services/ClaudeExecutorService.swift`
- Cause: Global queue is a finite pool; blocking timeout handlers starve other async work
- Improvement path:
  1. Use a dedicated DispatchQueue for timeout scheduling: `DispatchQueue(label: "ils.process-timeouts", qos: .utility)`
  2. Or migrate to async/await with `Task.sleep(nanoseconds:)` instead of GCD

## Fragile Areas

**ChatViewModel message mutation during streaming:**
- Files: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` (lines 492-612)
- Why fragile: Multiple async tasks mutate `messages` array concurrently:
  1. Stream message batch processing (every 75ms)
  2. User cancel action (immediate)
  3. User delete action (immediate)
  4. Permission response handling (async)
  Concurrent mutations may skip indices, lose message ordering, or orphan tool calls
- Safe modification: Always use index-based mutations, never removeLast+append. Consider wrapping in serial actor queue for serialized mutations
- Test coverage: No unit tests for concurrent mutation scenarios

**SSEClient reconnection retry logic with exponential backoff not implemented:**
- Files: `ILSApp/ILSApp/Services/SSEClient.swift` (lines 98-170)
- Why fragile: Reconnection uses fixed 2s delay; no exponential backoff. If backend is overwhelmed, client hammers with constant QPS
- Safe modification: Add exponential backoff (2s → 4s → 8s → 16s, capped at 60s) with jitter (±10%)
- Test coverage: Manual integration test only; no unit test for retry logic

**ThemeEditorView has 88 @State properties with manual synchronization:**
- Files: `ILSApp/ILSApp/Views/Themes/ThemeEditorView.swift` (lines 11-88)
- Why fragile: Color picker changes not immediately reflected in preview; manual `onChange` handlers required
- Safe modification: Use a single `@State var themeSnapshot: ThemeSnapshot` and derive preview reactively
- Test coverage: No automated UI tests; manual verification only

**ConfigFileService assumes `~/.claude` always writable:**
- Files: `Sources/ILSBackend/Services/ConfigFileService.swift` (lines 74-76)
- Why fragile: `createDirectory()` call may fail silently if home directory is on read-only filesystem (e.g., sandboxed environment, NFS mount)
- Safe modification: Check directory writability before attempting create; provide clear error if not writable
- Test coverage: No test for read-only filesystem scenarios

## Scaling Limits

**External sessions cache (22K+ items) grows unbounded:**
- Current capacity: ~22K external sessions cached in FileSystemService
- Limit: Memory usage could exceed 500MB if users accumulate 100K+ sessions; JSON deserialization becomes O(n) slow
- Scaling path:
  1. Implement sliding window cache (keep only last 10K sessions)
  2. Paginate external session scan endpoint instead of loading all at once
  3. Add lazy-load on demand (user explicitly clicks "Load more")

**Database connection pool not configurable:**
- Current capacity: Vapor default of 2-4 concurrent database connections
- Limit: Under load (10+ concurrent users), connection pool exhaustion causes request queuing
- Scaling path:
  1. Make connection pool size configurable via environment variable (e.g., `DATABASE_POOL_SIZE=20`)
  2. Add metrics to monitor pool utilization
  3. Implement connection timeout + retry logic for failed acquisitions

**SSEClient URLSession not reused across sessions:**
- Current capacity: One URLSession per ChatViewModel instance
- Limit: Opening 100+ chat windows may spawn 100+ URLSessions, each with TCP connection overhead
- Scaling path:
  1. Implement singleton URLSession pool: `URLSessionPool.shared.get(forHostname:)`
  2. Reuse sessions across ChatViewModels
  3. Add connection keepalive (HTTP/1.1 persistent connections) via URLSessionConfiguration

## Dependencies at Risk

**Citadel SSH library (0.x version):**
- Risk: Citadel is pre-1.0 and may have breaking API changes
- Impact: SSH connection code at `CitadelSSHService.swift` would break on upgrade
- Migration plan:
  1. Evaluate mature SSH alternatives: `libssh2-swift`, `paramiko` (via Python subprocess)
  2. Abstract SSH operations behind protocol so implementation is swappable
  3. Add integration tests for SSH to detect breaking changes early

**GRDB database library (heavy dependency):**
- Risk: GRDB is well-maintained but adds 300KB to app binary
- Impact: LocalDatabase at `LocalDatabase.swift` is tightly coupled to GRDB types (FetchableRecord, PersistableRecord)
- Migration plan:
  1. Consider lightweight alternatives: SQLite.swift, plain SQLite bindings
  2. Or evaluate if simple in-memory caching suffices (eliminate GRDB dependency entirely for offline cache)
  3. Measure actual cache hit rate; if <20%, GRDB may be premature optimization

## Missing Critical Features

**No offline mode fallback for external session scanning:**
- Problem: SessionsController.swift list() endpoint fails entirely if external session filesystem is unreachable
- Blocks: Users with disconnected Claude Code directories cannot use app at all
- Fix: Add `includeExternal` query parameter to conditionally skip external sessions; show cached results with stale warning

**No rate limiting on file operations:**
- Problem: Rapid GET /sessions requests trigger repeated FileSystemService.listExternalSessions() scans
- Blocks: Performance degrades under load; filesystem thrashing
- Fix: Implement request coalescing (if scan in progress, wait for result instead of launching new scan)

**No message deduplication in SSE stream:**
- Problem: Network retries or reconnection may cause duplicate StreamMessage entries
- Blocks: Chat history shows same message twice or more
- Fix: Add idempotency key (e.g., `streamId-messageIndex`) and deduplicate on receipt

## Test Coverage Gaps

**Concurrent ChatViewModel mutations not tested:**
- What's not tested: Race conditions between user actions (cancel, delete) and stream message batching
- Files: `ILSApp/ILSApp/ViewModels/ChatViewModel.swift`
- Risk: Concurrent mutations may silently corrupt message ordering or lose data
- Priority: HIGH — affects data integrity

**ClaudeExecutorService timeout handling not tested:**
- What's not tested: 30s initial timeout, 5min total timeout, timeout cancellation, stderr capture during timeout
- Files: `Sources/ILSBackend/Services/ClaudeExecutorService.swift`
- Risk: Process may hang indefinitely or be killed before cleanup
- Priority: HIGH — affects process lifecycle

**SSEClient reconnection logic not tested:**
- What's not tested: Reconnection retry count, exponential backoff, stream restart, max reconnect attempts exceeded
- Files: `ILSApp/ILSApp/Services/SSEClient.swift`
- Risk: Connection state may become inconsistent after network transitions
- Priority: MEDIUM — affects connectivity resilience

**TunnelSettingsView custom domain flow not tested:**
- What's not tested: Keychain save/load of tunnel credentials, QR code generation, URL persistence
- Files: `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`
- Risk: Credentials may fail to persist or be lost on app restart
- Priority: MEDIUM — affects tunnel configuration

**LocalDatabase atomic writes not tested:**
- What's not tested: App crash during database write, recovery from corrupted database files
- Files: `ILSApp/ILSApp/Services/LocalDatabase.swift`
- Risk: Database corruption on force-quit during write
- Priority: MEDIUM — affects offline cache reliability

---

*Concerns audit: 2026-02-19*
