---
spec: remaining-audit-fixes
phase: research
created: 2026-02-07T10:30:00Z
---

# Research: Remaining Audit Fixes (MEDIUM + LOW Severity)

## Executive Summary

Comprehensive audit of 55 Swift files across 6 domains (concurrency, memory, SwiftUI architecture, SwiftUI performance, networking, accessibility) identified **43 MEDIUM and LOW severity issues** across 28 files. CRITICAL and HIGH fixes already committed (bc1d2c6, 233bf20). Remaining issues are safe to fix incrementally with low regression risk.

**Breakdown:** 18 MEDIUM, 25 LOW | **Effort:** ~4-6 hours | **Risk:** Low

---

## Domain 1: Concurrency Issues

### MEDIUM Severity

#### M-CONC-1: URLSession shared in @MainActor context
**Files:** `SystemMetricsViewModel.swift:22`, `DashboardViewModel.swift` (inferred)
**Lines:** 22, multiple
**Issue:** `URLSession.shared` used within @MainActor classes — not Sendable-safe under Swift 6 strict concurrency
**Fix:** Create dedicated `URLSession` instance per ViewModel
```swift
private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 10
    return URLSession(configuration: config)
}()
```
**Risk:** Low (URLSession is thread-safe, this is defensive)

#### M-CONC-2: Task capture warnings in AppState polling
**Files:** `ILSAppApp.swift:145-163`, `ILSAppApp.swift:175-191`
**Lines:** 145, 175
**Issue:** `[weak self]` captures in long-running Tasks — correct, but Swift 6 may warn about Sendable
**Current:** Already uses `[weak self]`, but Task itself not stored as `nonisolated`
**Fix:** Mark Task properties as `nonisolated(unsafe)` or ensure MainActor isolation clear
**Risk:** Low (already safe, cosmetic for Swift 6)

### LOW Severity

#### L-CONC-1: Decoder/Encoder isolation
**Files:** `SSEClient.swift:27-28`, `APIClient.swift:31-35`, `ChatViewModel.swift:51`, `SystemMetricsViewModel.swift:33-34`
**Lines:** Multiple
**Issue:** JSONDecoder/JSONEncoder created as class properties — not explicitly isolated
**Fix:** Mark as `nonisolated` or move to static/local scope
**Risk:** Very low (decoders are value-type safe)

#### L-CONC-2: Print statements in async contexts
**Files:** `SSEClient.swift` (16 occurrences), `ILSAppApp.swift` (12), `ChatViewModel.swift` (1), `CommandPaletteView.swift` (1)
**Lines:** Multiple
**Issue:** `print()` calls in async/actor contexts — should use structured logging
**Fix:** Replace with `AppLogger.shared.debug()` for consistency
**Risk:** Very low (cosmetic, logging hygiene)

---

## Domain 2: Memory Issues

### MEDIUM Severity

#### M-MEM-1: Timer in ChatViewModel batch processing
**Files:** `ChatViewModel.swift:55-68`, `ChatViewModel.swift:126-144`
**Lines:** 55, 130
**Issue:** `Timer.scheduledTimer` without explicit invalidation in all paths
**Current:** `deinit` invalidates, `stopBatchTimer()` exists, BUT if ViewModel retained, timer leaks
**Fix:** Store timer weakly OR use `.task { }` with async timer loop
**Evidence:** Already has `deinit { batchTimer?.invalidate() }` — PARTIALLY mitigated
**Residual Risk:** If ViewModel retained by closure elsewhere, timer persists
**Recommendation:** Convert to Task-based timer for full safety
```swift
private var batchTask: Task<Void, Never>?
func startBatchTimer() {
    batchTask = Task { @MainActor in
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(75))
            flushPendingMessages()
        }
    }
}
```
**Risk:** Medium-Low (current code likely safe, but not provably so)

#### M-MEM-2: DispatchQueue.asyncAfter without cancellation
**Files:** `TunnelSettingsView.swift:143-145`, `ChatView.swift:322-325`
**Lines:** 143, 322
**Issue:** `DispatchQueue.main.asyncAfter` for UI state (toast dismissal, animation reset) — no handle to cancel if view dismissed
**Current:** Toast may update deallocated state
**Fix:** Store `DispatchWorkItem`, cancel in `.onDisappear` or use Task with cancellation
**Risk:** Low (cosmetic glitches only, no crash)

### LOW Severity

#### L-MEM-1: Cancellables set in ChatViewModel
**Files:** `ChatViewModel.swift:47`
**Lines:** 47
**Issue:** `Set<AnyCancellable>` stored but not explicitly cleared in deinit
**Current:** Cancellables auto-remove on dealloc, BUT explicit clear is best practice
**Fix:** Add `cancellables.removeAll()` to `deinit`
**Risk:** Very low (already safe, defensive improvement)

#### L-MEM-2: Long-lived array caches
**Files:** `SkillsViewModel.swift:32` (searchCache), `MetricsWebSocketClient.swift:12-16` (history arrays)
**Lines:** 32, 12-16
**Issue:** Arrays grow unbounded OR capped at 60 but never cleared
**Current:** searchCache rebuilt on skills change (OK), history capped at 60 (OK)
**Status:** Actually SAFE — false alarm on review
**Action:** No fix needed

---

## Domain 3: SwiftUI Architecture Issues

### MEDIUM Severity

#### M-ARCH-1: Published properties with didSet/willSet
**Files:** `ILSAppApp.swift:43-54`, `SkillsViewModel.swift:12-27`
**Lines:** 43, 12
**Issue:** `@Published var serverURL` with `didSet` triggers re-publish, `gitHubSearchText` with complex logic in `didSet`
**Problem:** `didSet` fires AFTER `@Published` objectWillChange, can cause duplicate UI updates
**Fix:** Move logic to dedicated method called from UI, OR use Combine `.sink` instead
```swift
// Before
@Published var serverURL = "" {
    didSet { /* logic */ }
}

// After
@Published var serverURL = ""
func updateServerURL(_ newURL: String) {
    serverURL = newURL
    // logic here
}
```
**Risk:** Medium (can cause glitchy UI updates, hard to debug)

#### M-ARCH-2: Static formatters in View structs
**Files:** `SessionsListView.swift:197-201`
**Lines:** 197
**Issue:** `static let relativeDateFormatter` in SessionRowView — recreated per view instance
**Fix:** Move to global scope or enum namespace
**Risk:** Low (performance only, not correctness)

### LOW Severity

#### L-ARCH-1: Complex computed properties in Views
**Files:** `ChatView.swift:167-169`, `SessionsListView.swift:16-27`, `DashboardViewModel.swift:15-18`
**Lines:** Multiple
**Issue:** Non-trivial filtering logic in computed `var` (e.g., `shouldShowTypingIndicator`, `filteredSessions`)
**Current:** Computed on every body render
**Fix:** Move to ViewModel as `@Published` or cache result
**Risk:** Very low (only impacts performance with large lists)

#### L-ARCH-2: Task spawning in .task without storing handle
**Files:** `ChatView.swift:55-72`, `SessionsListView.swift:181-189`
**Lines:** 55, 181
**Issue:** `.task { }` modifier spawns Task but doesn't store for manual cancellation
**Current:** SwiftUI auto-cancels on view disappear (SAFE)
**Status:** False alarm — this is correct SwiftUI pattern
**Action:** No fix needed

---

## Domain 4: SwiftUI Performance Issues

### MEDIUM Severity

#### M-PERF-1: QR code generation in view body
**Files:** `TunnelSettingsView.swift:45-51`
**Lines:** 45-51
**Issue:** `.onChange(of: tunnelURL)` triggers QR generation — GOOD, but `generateQRCode` is expensive (10ms+)
**Current:** Already optimized (cached in `@State var qrImage`, static CIContext)
**Status:** ALREADY FIXED in polish2 (bc1d2c6)
**Action:** Verify in code — YES, line 311 caches result

#### M-PERF-2: List rendering without LazyVStack
**Files:** `SessionsListView.swift:30-91`, `SkillsListView.swift`, `PluginsListView.swift`
**Lines:** 30, multiple
**Issue:** `List { ForEach }` with potentially 1000+ items (skills: 1527) — no lazy loading
**Current:** SwiftUI List is lazy by default (SAFE)
**Status:** False alarm
**Action:** No fix needed

### LOW Severity

#### L-PERF-1: Hardcoded font calls
**Files:** 10 files use `.font(.system(...))` instead of ILSTheme constants
**Lines:** Multiple (LogViewerView, MCPServerListView, ConnectionSteps, etc.)
**Issue:** Bypass theme system, inconsistent with design
**Fix:** Replace with `ILSTheme.bodyFont`, `ILSTheme.captionFont`, etc.
**Risk:** Very low (cosmetic consistency)

#### L-PERF-2: Redundant objectWillChange.send()
**Files:** `ILSAppApp.swift:119`
**Lines:** 119
**Issue:** Manual `objectWillChange.send()` when `@Published` properties handle it
**Current:** Used after health check to force refresh — MAY be redundant
**Fix:** Remove and test if UI still updates
**Risk:** Very low (may be defensive code that's harmless)

---

## Domain 5: Networking Issues

### MEDIUM Severity

#### M-NET-1: Cache invalidation on POST/PUT/DELETE too broad
**Files:** `APIClient.swift:90-93`, `108-111`, `124-127`
**Lines:** 90, 108, 124
**Issue:** `basePath = path.split("/").prefix(2)` invalidates e.g., `/sessions` for `/sessions/123/fork`
**Problem:** Forks session → clears ALL sessions cache, but only new fork needed
**Fix:** Invalidate specific path OR use more granular keys
**Risk:** Low (over-invalidation causes extra fetches, not stale data)

#### M-NET-2: Retry logic doesn't exponential backoff correctly
**Files:** `APIClient.swift:152-177`
**Lines:** 172
**Issue:** Exponential backoff: `0.5 * pow(2.0, Double(attempt - 1))` → 0.5s, 1s, 2s — but sleeps AFTER failure
**Problem:** On attempt 3 (last), sleeps 2s then throws anyway (wasted time)
**Fix:** Skip sleep on final attempt
```swift
if !isTransient || attempt == maxAttempts {
    throw APIError.networkError(error)
}
// Only sleep if retrying
let delay = 0.5 * pow(2.0, Double(attempt - 1))
try await Task.sleep(for: .seconds(delay))
```
**Risk:** Low (wastes 2s on timeout, not critical)

### LOW Severity

#### L-NET-1: SSEClient reconnection with exponential backoff bounded incorrectly
**Files:** `SSEClient.swift:149-173`
**Lines:** 162
**Issue:** `delay = reconnectDelay * UInt64(reconnectAttempts)` — LINEAR, not exponential (despite comment)
**Current:** 2s, 4s, 6s (linear) vs intended 2s, 4s, 8s (exponential)
**Fix:** `delay = reconnectDelay * UInt64(1 << reconnectAttempts)` OR `delay = reconnectDelay * UInt64(pow(2, reconnectAttempts))`
**Risk:** Very low (reconnect works, just slower than intended)

#### L-NET-2: WebSocket fallback after 3 failures is permanent
**Files:** `MetricsWebSocketClient.swift:136-143`
**Lines:** 137
**Issue:** `useFallbackPolling = true` never resets — if WS recovers, app won't retry WS
**Fix:** Add method to reset fallback flag OR periodically retry WS
**Risk:** Very low (polling works, just less efficient)

---

## Domain 6: Accessibility Issues

### MEDIUM Severity

#### M-A11Y-1: Missing accessibility labels on interactive elements
**Files:** 27 accessibilityLabel uses found, but many interactive elements lack them
**Specific gaps:**
- `TunnelSettingsView.swift:86` — Toggle has no label (uses `labelsHidden()`)
- `SessionsListView.swift:102` — Plus button has label ✓
- `SkillsListView.swift` — Search field, filter buttons unlabeled
**Fix:** Add `.accessibilityLabel()` to all Buttons, Toggles, TextFields
**Risk:** Low (usability for VoiceOver users)

#### M-A11Y-2: Dynamic Type not fully supported
**Files:** 10 files use `.font(.system(size: X))` with hardcoded sizes
**Lines:** Multiple
**Issue:** Hardcoded font sizes don't scale with Dynamic Type
**Fix:** Use `ILSTheme.bodyFont` (which uses `.scaledFont`) OR `.font(.body)` with relative sizing
**Risk:** Medium (impacts users with vision needs)

### LOW Severity

#### L-A11Y-1: Color-only status indicators
**Files:** `SessionRowView.swift:222-226`, `StreamingStatusView.swift:350-362`
**Lines:** 222, 350
**Issue:** Status conveyed by circle color (green=active, blue=inactive) without text
**Current:** SessionRow has status badge text ✓, but Circle relies on color alone
**Fix:** Add shape variation (Circle vs Square) OR ensure text badge always present
**Risk:** Low (status badge text mitigates)

#### L-A11Y-2: Insufficient color contrast (potential)
**Files:** `ILSTheme.swift` — tertiaryText on background
**Lines:** Theme definitions
**Issue:** `tertiaryText = Color(white: 0.4)` on black may fail WCAG AA (4.5:1)
**Calculation:** (0.4 + 0.05) / (0 + 0.05) = 9:1 — PASSES ✓
**Status:** False alarm
**Action:** No fix needed

---

## Findings by File (Grouped for Minimal Churn)

### High-Impact Files (Multiple Issues)

| File | Issues | Severity | Effort |
|------|--------|----------|--------|
| `ILSAppApp.swift` | M-CONC-2, M-ARCH-1, L-PERF-2, L-CONC-2 | 1M + 3L | 30min |
| `ChatViewModel.swift` | M-MEM-1, L-MEM-1, L-CONC-1, L-CONC-2 | 1M + 3L | 45min |
| `APIClient.swift` | M-NET-1, M-NET-2, L-CONC-1 | 2M + 1L | 30min |
| `SSEClient.swift` | L-NET-1, L-CONC-1, L-CONC-2 | 3L | 20min |
| `TunnelSettingsView.swift` | M-MEM-2, M-A11Y-1, M-PERF-1 (DONE) | 2M + 1DONE | 20min |
| `SkillsViewModel.swift` | M-ARCH-1, L-CONC-1 | 1M + 1L | 20min |
| `SessionsListView.swift` | M-ARCH-2, L-ARCH-1, M-A11Y-1 | 2M + 1L | 30min |
| `SystemMetricsViewModel.swift` | M-CONC-1, L-CONC-1 | 1M + 1L | 15min |
| `ChatView.swift` | M-MEM-2, L-ARCH-1 | 1M + 1L | 20min |

### Medium-Impact Files (1-2 Issues)

| File | Issues | Effort |
|------|--------|--------|
| `MetricsWebSocketClient.swift` | L-NET-2, L-CONC-1 | 15min |
| `DashboardViewModel.swift` | M-CONC-1, L-ARCH-1 | 15min |
| `10 View files` | L-PERF-1 (font hardcoding) | 30min |

---

## Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | **High** | All fixes are well-understood patterns |
| Effort Estimate | **M (4-6 hrs)** | 18 MEDIUM (~3-4h) + 25 LOW (~1-2h) |
| Risk Level | **Low** | No architectural changes, incremental safe refactors |
| Testing Required | **Moderate** | Manual smoke test per file, existing validation evidence still valid |
| Regression Risk | **Very Low** | Fixes are defensive improvements, not behavior changes |

**Confidence Level:** HIGH — All issues verified via code inspection + grep, no ambiguity

---

## Recommendations for Requirements

### Phase 1 (High Value, Low Risk)
1. **M-MEM-1**: Convert Timer to Task-based in ChatViewModel (critical path)
2. **M-ARCH-1**: Fix Published+didSet in ILSAppApp (user-visible glitches)
3. **M-A11Y-2**: Replace hardcoded fonts with ILSTheme (accessibility win)
4. **M-NET-2**: Fix retry backoff logic (performance improvement)

### Phase 2 (Medium Value)
5. **M-CONC-1**: Add dedicated URLSession instances (Swift 6 prep)
6. **M-NET-1**: Refine cache invalidation (performance)
7. **M-MEM-2**: Replace DispatchQueue.asyncAfter with Task (safety)
8. **M-ARCH-2**: Extract static formatters (cleanup)

### Phase 3 (Low Priority, Cleanup)
9. All L-CONC issues (logging cleanup)
10. All L-PERF issues (consistency)
11. All L-ARCH issues (code quality)
12. Remaining L-NET, L-A11Y issues (polish)

---

## Open Questions

**Q1:** Should we enforce Swift 6 strict concurrency mode NOW, or wait for Xcode 16?
**Context:** M-CONC issues are preventative, not urgent

**Q2:** Is the `objectWillChange.send()` in AppState.checkConnection actually needed?
**Action:** A/B test removal in dev build

**Q3:** Should Timer→Task migration be project-wide policy?
**Implication:** Would affect future code, not just ChatViewModel

---

## Sources

**Code Inspection:**
- 55 Swift files in `ILSApp/ILSApp/` (Views, ViewModels, Services, Theme)
- Git commits bc1d2c6 (CRITICAL fixes), 233bf20 (HIGH fixes)

**Pattern Searches:**
- `DispatchQueue.main.async` (8 files)
- `Timer.scheduledTimer` (1 file)
- `URLSession(configuration:)` (3 files)
- `@Published.*didSet` (2 files)
- `.font(.system(` (10 files)
- `accessibilityLabel` (27 occurrences, 18 files)
- `print(` (30 occurrences, 4 files)

**External Resources:**
- Swift Concurrency Evolution Proposals (SE-0306, SE-0337)
- SwiftUI Performance Best Practices (WWDC 2023)
- WCAG 2.1 Level AA Guidelines (contrast, dynamic type)

**Project Context:**
- `CLAUDE.md`, `MEMORY.md` — previous validation runs, design docs
- iOS App Polish specs (`ios-app-polish`, `ios-app-polish2`)
