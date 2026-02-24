# Phase 14: SSE & Background Lifecycle - Research

**Researched:** 2026-02-23
**Domain:** iOS/macOS app lifecycle, Low Power Mode, background suspension, persistent connection management
**Confidence:** HIGH

## Summary

Phase 14 addresses two v2.0 performance requirements (BATT-01, BATT-02) that focus on battery efficiency through Low Power Mode adaptive polling and comprehensive background suspend/resume for all persistent connections. Prior work in v3.0 Phase 22 (ENRG-05) already implemented SSE background disconnect via `NotificationCenter.didEnterBackgroundNotification` in `SSEClient.init()`, and `PollingManager.handleScenePhase(.background)` already stops health/retry polling. However, significant gaps remain: (1) no Low Power Mode awareness exists anywhere in the codebase, (2) `MetricsWebSocketClient` has no background suspension at all, and (3) there is no foreground resume logic for SSE streams that were active when the user backgrounded.

The implementation requires zero new SPM dependencies -- all APIs are Foundation/UIKit (`ProcessInfo.processInfo.isLowPowerModeEnabled`, `NSProcessInfoPowerStateDidChangeNotification`, `UIApplication.didEnterBackgroundNotification/willEnterForegroundNotification`). The primary risk is SSE resume correctness: when the app returns to foreground, ChatViewModel must decide whether to reload history (if the stream completed server-side) or re-initiate streaming. The safest approach is to always reload history on foreground return (already implemented in ChatView's `scenePhase` handler) and let the user re-send if they want to continue streaming.

**Primary recommendation:** Add a `LowPowerModeMonitor` observable singleton (modeled after the existing `NetworkMonitor`), wire it into `PollingManager` and `MetricsWebSocketClient` to double polling intervals, add `MetricsWebSocketClient` background disconnect via `AppState.handleScenePhase()`, and add SSE suspend/resume methods for foreground transitions.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BATT-01 | With Low Power Mode enabled, PollingManager and MetricsWebSocketClient poll at 2x their normal interval (e.g., 60s becomes 120s) | Low Power Mode Monitor pattern (Section: Architecture Patterns #1), ProcessInfo API (Section: Standard Stack), PollingManager/MetricsWebSocketClient current intervals documented |
| BATT-02 | When the app moves to background, SSE and WebSocket connections disconnect within 5 seconds; when it returns to foreground, connections resume automatically and data is current | Background suspension pattern (Section: Architecture Patterns #2), SSEClient already has partial implementation (ENRG-05), MetricsWebSocketClient gap identified, foreground resume via ChatViewModel.refreshMessages() already exists |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation `ProcessInfo` | iOS 9+ / macOS 12+ | `isLowPowerModeEnabled` property + `NSProcessInfoPowerStateDidChangeNotification` | Apple's official API for Low Power Mode detection; synchronously readable, notification-based updates |
| UIKit `UIApplication` | iOS 4+ | `didEnterBackgroundNotification` / `willEnterForegroundNotification` | Already used by SSEClient (ENRG-05); standard iOS lifecycle notifications |
| SwiftUI `ScenePhase` | iOS 14+ / macOS 11+ | `.active` / `.inactive` / `.background` environment value | Already used by AppState, ChatView, SystemMonitorView; the canonical SwiftUI lifecycle hook |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `NWPathMonitor` (Network framework) | iOS 12+ | Network connectivity state | Already used by `NetworkMonitor.swift`; pattern to replicate for `LowPowerModeMonitor` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated `LowPowerModeMonitor` class | Inline `ProcessInfo` checks in each service | Monitor centralizes state and notification handling; inline checks miss reactive updates when user toggles LPM mid-session |
| `NotificationCenter` observer in each service | Centralized `AppState.handleScenePhase()` dispatch | SSEClient already uses NotificationCenter directly (ENRG-05); PollingManager already uses `handleScenePhase()` dispatch. Use whichever pattern each component already follows |

## Architecture Patterns

### Current State Map

```
ILSAppApp.swift
  └── .onChange(of: scenePhase) → appState.handleScenePhase(newPhase)
        └── PollingManager.handleScenePhase(.background)
              ├── stopHealthPolling()     ✅ Already works
              └── stopRetryPolling()      ✅ Already works

SSEClient.init()
  └── NotificationCenter didEnterBackgroundNotification → cancel()  ✅ ENRG-05 done

MetricsWebSocketClient
  └── connect()/disconnect() called by SystemMonitorView onAppear/onDisappear
  └── NO background disconnect                                      ❌ GAP

ChatView
  └── .onChange(of: scenePhase) .active → viewModel.refreshMessages()  ✅ Already works
  └── NO SSE resume on foreground (correct — reload history instead)   ✅ By design

Low Power Mode
  └── ProcessInfo.processInfo.isLowPowerModeEnabled — NOT read anywhere  ❌ GAP
```

### Pattern 1: Low Power Mode Monitor (BATT-01)

**What:** A singleton `@Observable` class that tracks `ProcessInfo.processInfo.isLowPowerModeEnabled` and broadcasts changes via Swift Observation.

**When to use:** Any service or view that needs to adapt behavior based on Low Power Mode state.

**Design:**
```swift
// Modeled on existing NetworkMonitor.swift singleton pattern
@MainActor
@Observable
final class LowPowerModeMonitor {
    static let shared = LowPowerModeMonitor()

    private(set) var isLowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
```

**Consumer pattern in PollingManager:**
```swift
// In startHealthPolling():
let interval: UInt64 = LowPowerModeMonitor.shared.isLowPowerModeEnabled
    ? 120_000_000_000  // 120s in LPM
    : 60_000_000_000   // 60s normal

// In startRetryPolling():
var delay: UInt64 = LowPowerModeMonitor.shared.isLowPowerModeEnabled
    ? 10_000_000_000   // Start at 10s in LPM
    : 5_000_000_000    // Start at 5s normal
```

**Consumer pattern in MetricsWebSocketClient:**
```swift
// In startHeartbeat():
let interval = LowPowerModeMonitor.shared.isLowPowerModeEnabled
    ? heartbeatInterval * 2  // 30s in LPM
    : heartbeatInterval      // 15s normal

// In startPolling() (fallback REST):
let pollInterval: UInt64 = LowPowerModeMonitor.shared.isLowPowerModeEnabled
    ? 60_000_000_000   // 60s in LPM
    : 30_000_000_000   // 30s normal
```

**macOS note:** `ProcessInfo.processInfo.isLowPowerModeEnabled` is available on macOS 12+ (Monterey). The app targets macOS 14+, so it works on both platforms. On Macs without Low Power Mode (desktops), it returns `false`.

### Pattern 2: Background Suspend / Foreground Resume (BATT-02)

**What:** Extend `AppState.handleScenePhase()` to suspend MetricsWebSocketClient on background and resume on foreground. SSE is already handled by ENRG-05.

**Current `AppState.handleScenePhase()` only dispatches to `PollingManager`:**
```swift
// Current (iOS):
func handleScenePhase(_ phase: ScenePhase) {
    let appPhase: PollingManager.AppPhase
    // ... maps ScenePhase → AppPhase
    pollingManager.handleScenePhase(appPhase)
}
```

**Extended pattern:**
```swift
func handleScenePhase(_ phase: ScenePhase) {
    let appPhase: PollingManager.AppPhase
    switch phase {
    case .active: appPhase = .active
    case .inactive: appPhase = .inactive
    case .background: appPhase = .background
    @unknown default: appPhase = .inactive
    }
    pollingManager.handleScenePhase(appPhase)

    // BATT-02: Background suspend for MetricsWebSocketClient not owned by AppState.
    // MetricsWebSocketClient is owned by SystemMetricsViewModel, which is @State in
    // SystemMonitorView. It already disconnects on onDisappear. The gap is: if the
    // user is ON the System Monitor screen and backgrounds, onDisappear does NOT fire.
    // Solution: SystemMonitorView's scenePhase handler must disconnect on background.
}
```

**SystemMonitorView scenePhase extension:**
```swift
// Current:
.onChange(of: scenePhase) { _, phase in
    if phase == .active {
        if viewModel.isConnected { livePulse = true }
    } else {
        livePulse = false
    }
}

// Extended:
.onChange(of: scenePhase) { _, phase in
    switch phase {
    case .active:
        viewModel.connect()  // Resume WebSocket
        if viewModel.isConnected { livePulse = true }
    case .background:
        viewModel.disconnect()  // BATT-02: Suspend WebSocket
        livePulse = false
    default:
        livePulse = false
    }
}
```

### Anti-Patterns to Avoid

- **Do NOT add suspend/resume to SSEClient for foreground transitions.** SSE streams are request-initiated (user sends a chat message), not persistent connections. The ENRG-05 implementation correctly cancels the stream on background. On foreground return, `ChatView.onChange(of: scenePhase) .active` calls `viewModel.refreshMessages()` which reloads history from the API. The user can re-send if they want to continue streaming. Adding auto-resume would re-initiate a POST to `/chat/stream` which could create duplicate responses.

- **Do NOT check `isLowPowerModeEnabled` inside every `Task.sleep` call.** Check it once when starting a polling loop. If LPM changes mid-loop, the notification fires and services can restart their loops with the new interval. Checking on every sleep iteration adds unnecessary overhead.

- **Do NOT use `DispatchQueue.main.async` for MainActor transitions.** The project has already migrated to `Task { @MainActor in }` pattern (Phase 19 work). Follow the established pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Low Power Mode detection | Custom battery monitoring with `UIDevice.current.batteryLevel` | `ProcessInfo.processInfo.isLowPowerModeEnabled` + notification | ProcessInfo is the official API; batteryLevel requires additional entitlements and monitoring |
| Background detection in services | Custom RunLoop observers or `DispatchSource` timers | `UIApplication.didEnterBackgroundNotification` or `ScenePhase` via dispatch | Already proven patterns in the codebase (ENRG-05, PollingManager) |
| Network state gating | Manual reachability checks before each request | `NetworkMonitor.shared.isConnected` | Already implemented and integrated with PollingManager |

## Common Pitfalls

### Pitfall 1: ScenePhase Boundary Unreliability
**What goes wrong:** SwiftUI's `.inactive` and `.background` boundary is unreliable. A rapid foreground-background-foreground cycle can leave a task running when it should have been cancelled.
**Why it happens:** The `.inactive` state fires for many transient situations (notification center pull-down, app switcher peek) that don't actually background the app.
**How to avoid:** Only disconnect on `.background`, not `.inactive`. Resume on `.active`. Never use `.inactive` as a trigger for teardown.
**Warning signs:** WebSocket/SSE disconnects when the user pulls down notification center.

### Pitfall 2: MetricsWebSocketClient Double-Connect on Foreground
**What goes wrong:** If `SystemMonitorView.onAppear` fires AND `scenePhase == .active` handler fires when returning from background, `connect()` is called twice, creating duplicate WebSocket connections.
**Why it happens:** SwiftUI may fire both `onAppear` (if the view was removed from hierarchy) and `onChange(of: scenePhase)` during the same foreground transition.
**How to avoid:** `MetricsWebSocketClient.connect()` already has a guard: `guard webSocketTask == nil, pollingTask == nil else { return }`. This prevents double-connect. Verify this guard remains in place.
**Warning signs:** Duplicate metrics data points in charts.

### Pitfall 3: LPM Toggle Mid-Polling-Loop
**What goes wrong:** User enables Low Power Mode while a polling loop is in the middle of a `Task.sleep(60s)`. The loop continues at the old interval until the current sleep completes.
**Why it happens:** `Task.sleep` is not interruptible by external events (only by task cancellation).
**How to avoid:** When LPM state changes, cancel and restart the polling task with the new interval. Add a notification observer that calls `stopHealthPolling()` + `startHealthPolling()` to pick up the new interval.
**Warning signs:** Polling continues at 60s for up to 60s after LPM is enabled.

### Pitfall 4: macOS Low Power Mode Differences
**What goes wrong:** `isLowPowerModeEnabled` on macOS only returns `true` for MacBooks on battery with Low Power Mode enabled in System Settings. Mac desktops always return `false`. iPad always returns `false`.
**Why it happens:** Low Power Mode is hardware-dependent, not a universal iOS/macOS feature.
**How to avoid:** This is expected behavior. No special handling needed. The code should work correctly on all platforms -- it just won't activate LPM adjustments on desktops/iPads.

### Pitfall 5: SSE Background Cancel Loses In-Progress Response
**What goes wrong:** If Claude is mid-response when the user backgrounds the app, the ENRG-05 cancel kills the stream. When the user returns, the partial response is lost and history reload may not include it (it wasn't persisted server-side yet).
**Why it happens:** The SSE cancel in `SSEClient.cancel()` clears `messages`, `currentRequest`, and all state.
**How to avoid:** This is acceptable behavior -- battery savings outweigh the lost partial response. The user sees the refreshed history on foreground return. If the Claude CLI completed the response while backgrounded, it will appear in the history reload. Document this as expected behavior.

## Code Examples

### Low Power Mode Observer (Foundation API)
```swift
// Source: Apple Developer Documentation — ProcessInfo.isLowPowerModeEnabled
// Available: iOS 9+, macOS 12+
let isLPM = ProcessInfo.processInfo.isLowPowerModeEnabled

NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange,
    object: nil,
    queue: .main
) { _ in
    let isLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
    // React to LPM toggle
}
```

### Background Notification (UIKit)
```swift
// Source: Already used in SSEClient.swift (ENRG-05)
#if os(iOS)
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.disconnect()
    }
}
#endif
```

### Adaptive Polling Interval
```swift
// Pattern: read LPM state at loop start, restart loop on LPM change
func startHealthPolling() {
    guard healthPollTask == nil else { return }
    let interval: UInt64 = LowPowerModeMonitor.shared.isLowPowerModeEnabled
        ? 120_000_000_000 : 60_000_000_000
    healthPollTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: interval)
            guard !Task.isCancelled else { break }
            // ... health check
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DispatchQueue.main.async` for MainActor | `Task { @MainActor in }` | Phase 19 (2026-02-22) | All MainActor transitions use structured concurrency |
| `Timer.scheduledTimer` for polling | `Task` + `Task.sleep(nanoseconds:)` | Phase 19 (2026-02-22) | All polling uses async Task loops |
| No background handling for SSE | `NotificationCenter.didEnterBackgroundNotification` cancel | Phase 22 (2026-02-22) | SSEClient cancels on background |
| No network state gating | `NetworkMonitor.shared.isConnected` guard | Phase 23 (2026-02-22) | PollingManager skips requests when offline |
| SwiftUI `ScenePhase` in PollingManager | `PollingManager.AppPhase` enum | Phase 20 (2026-02-22) | PollingManager has no SwiftUI import |

## Files to Modify

| File | Change | Risk |
|------|--------|------|
| `ILSApp/ILSApp/Services/LowPowerModeMonitor.swift` | **NEW** — singleton observer for `isLowPowerModeEnabled` | LOW — isolated singleton, no existing code touched |
| `ILSApp/ILSApp/Services/PollingManager.swift` | Adaptive health poll interval (60s normal / 120s LPM), LPM notification restarts polling loop | LOW — interval change only |
| `ILSApp/ILSApp/Services/MetricsWebSocketClient.swift` | Adaptive heartbeat (15s/30s) and fallback poll (30s/60s) intervals | LOW — interval change only |
| `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` | Extend `scenePhase` handler to disconnect on `.background`, reconnect on `.active` | MEDIUM — must avoid double-connect |
| `ILSApp/ILSApp/Services/SSEClient.swift` | Extend heartbeat watchdog interval in LPM (45s -> 90s) | LOW — watchdog timeout change only |
| `ILSApp/ILSMacApp/ILSMacApp.swift` | Ensure macOS AppState.handleScenePhase coverage (already present) | LOW — verify only |

**Files NOT modified (already correct):**
- `ILSApp/ILSApp/ILSAppApp.swift` — `handleScenePhase` already dispatches to PollingManager; SSE background cancel is in SSEClient itself
- `ILSApp/ILSApp/Views/Chat/ChatView.swift` — `scenePhase .active` already calls `refreshMessages()`; no SSE resume needed
- `ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — `refreshMessages()` already reloads history; no changes needed

## Open Questions

1. **Should LPM restart active SSE watchdog with new timeout?**
   - What we know: The heartbeat watchdog is created per-stream in `performStream()` with a hardcoded 45s timeout. If LPM is toggled mid-stream, the watchdog continues with 45s.
   - What's unclear: Whether it's worth adding complexity to restart the watchdog mid-stream.
   - Recommendation: Read LPM state at watchdog creation time. Don't restart mid-stream -- the stream will either complete or the user will background (which cancels it). LOW priority.

2. **Should MetricsWebSocketClient also observe LPM notification to restart heartbeat?**
   - What we know: Heartbeat interval is set once in `startHeartbeat()`. If LPM changes, the old interval persists.
   - Recommendation: For simplicity, read LPM state when `startHeartbeat()` is called. The next `connect()` call (e.g., on foreground resume) will pick up the new interval naturally. Adding a mid-connection restart adds complexity for marginal gain.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation: ProcessInfo.isLowPowerModeEnabled](https://developer.apple.com/documentation/foundation/processinfo/islowpowermodeenabled) — API availability, behavior on macOS/iPad
- [Apple Energy Efficiency Guide: Low Power Mode](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/LowPowerMode.html) — official guidance on adapting to LPM
- Project source: `SSEClient.swift` lines 51-64 (ENRG-05 implementation), `PollingManager.swift` lines 135-146 (handleScenePhase), `MetricsWebSocketClient.swift` (no background handling)
- Project research: `.planning/research/ARCHITECTURE.md` section 5 (Low Power Mode) and section 6 (Background Suspension)
- Project research: `.planning/research/STACK.md` section 3 (Low Power Mode Awareness)
- Project research: `.planning/research/PITFALLS.md` pitfall 12 (Battery Optimization Breaking ScenePhase)

### Secondary (MEDIUM confidence)
- [Hacking with Swift: Detecting Low Power Mode](https://www.hackingwithswift.com/example-code/system/how-to-detect-low-power-mode-is-enabled) — confirmed iOS 9+ availability, iPad always returns false
- [Use Your Loaf: Detecting Low Power Mode](https://useyourloaf.com/blog/detecting-low-power-mode/) — confirmed notification pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Foundation/UIKit APIs, stable since iOS 9, already used patterns in codebase
- Architecture: HIGH — extends existing patterns (NetworkMonitor singleton, PollingManager.handleScenePhase, SSEClient NotificationCenter observer)
- Pitfalls: HIGH — derived from project-specific prior research (PITFALLS.md pitfall 12) and actual codebase analysis of guard conditions

**Research date:** 2026-02-23
**Valid until:** 2026-04-23 (stable APIs, no expected changes)
