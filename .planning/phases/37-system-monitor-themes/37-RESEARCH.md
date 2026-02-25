# Phase 37: System Monitor & Themes - Research

**Researched:** 2026-02-25
**Domain:** iOS/macOS SwiftUI system monitoring + theming infrastructure
**Confidence:** HIGH

## Summary

Phase 37 addresses three requirements spanning two distinct feature areas: (1) the system monitor displaying real-time metrics from the connected host, and (2) theme reliability on fresh launch and cross-platform consistency. Both areas have mature existing implementations -- the system monitor already has a full WebSocket-based real-time pipeline (backend `SystemController` -> `MetricsWebSocketClient` -> `SystemMetricsViewModel` -> `SystemMonitorView`), and the theme system has 13 built-in themes with a `ThemeSnapshot` value-type architecture. The work here is primarily about ensuring correctness under edge conditions: host switching, fresh installs, and cross-platform parity.

The system monitor's key gap is ensuring it correctly targets the **connected host** rather than always defaulting to localhost:9999. The `SystemMetricsViewModel` hardcodes `baseURL: String = "http://localhost:9999"` in its init, and while `SystemMonitorView.onAppear` compares `metricsClient.baseURL` against `appState.serverURL`, the process endpoint in the ViewModel also hardcodes the URL. For themes, the default loading path is sound (CyberpunkTheme -> UserDefaults persistence -> ThemeManager init), but edge cases around fresh installs, missing UserDefaults keys, and light/dark theme `isLight` detection for custom themes need verification. Cross-platform consistency requires auditing that all 13 built-in themes render identically on iOS, iPadOS, and macOS since they use hardcoded hex colors (not system adaptive colors).

**Primary recommendation:** Fix the system monitor to use `appState.serverURL` consistently for all endpoints (WebSocket + REST process list), verify theme loading on fresh install produces a valid visual state, and audit macOS theme injection for parity with iOS.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SYS-01 | System monitor displays real-time metrics from connected host (CPU, memory, disk, network) | WebSocket pipeline exists and works. Fix: `SystemMetricsViewModel.init()` hardcodes localhost:9999 for process loading URL. Must use `appState.serverURL`. View already handles baseURL mismatch on appear for WebSocket client. |
| SYS-02 | Theme default loading works on fresh app launch (no blank/broken state) | `ThemeEnvironmentKey.defaultValue` = `ThemeSnapshot(CyberpunkTheme())`. `ThemeManager.init()` defaults to "cyberpunk" if no UserDefaults key. Both iOS and macOS inject `themeManager.currentSnapshot` via `.environment(\.theme,)`. Path is sound; verify no race between ThemeManager init and first view body evaluation. |
| SYS-03 | Cross-platform theme consistency (iOS, iPadOS, macOS) | All 13 built-in themes use hardcoded hex `Color(hex:)` values, not system-adaptive colors. This ensures pixel-identical rendering across platforms. macOS app (`ILSMacApp.swift`) injects theme the same way as iOS (`ILSAppApp.swift`). Risk area: `GlassCard` modifier uses `theme.glassBackground` which varies by theme; light themes (Paper, Snow) use `Color.black.opacity(0.05)` which renders correctly on both platforms. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI Charts | iOS 16+ / macOS 13+ | CPU and network time-series charts | Apple's native charting framework; already used in `SystemMonitorView` |
| URLSessionWebSocketTask | iOS 13+ / macOS 10.15+ | Real-time metrics streaming | Native WebSocket; already used in `MetricsWebSocketClient` |
| SwiftUI @Observable | iOS 17+ / macOS 14+ | ViewModel reactivity | Modern observation macro; already used throughout |
| UserDefaults | Foundation | Theme persistence | Standard persistence for theme ID selection |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Vapor WebSocket | Vapor 4 | Backend WebSocket handler for `/system/metrics/live` | Already implemented in `SystemController.liveMetrics()` |
| ILSShared DTOs | Local package | `SystemMetricsResponse`, `ProcessInfoResponse` shared models | All metric data uses these types |

### Alternatives Considered

None -- this phase uses existing infrastructure. No new dependencies needed.

## Architecture Patterns

### Existing Project Structure (relevant files)

```
ILSApp/ILSApp/
├── Views/System/
│   ├── SystemMonitorView.swift    # Main system monitor screen
│   ├── ProcessListView.swift      # Process table sub-view
│   └── FileBrowserView.swift      # File browser (not in scope)
├── ViewModels/
│   └── SystemMetricsViewModel.swift  # Owns MetricsWebSocketClient + process data
├── Services/
│   └── MetricsWebSocketClient.swift  # WebSocket + REST fallback client
├── Theme/
│   ├── AppTheme.swift             # Protocol + ThemeManager + EnvironmentKey
│   ├── ThemeSnapshot.swift        # Concrete value type for environment
│   ├── CustomThemeAdapter.swift   # Adapts backend CustomTheme to AppTheme
│   ├── GlassCard.swift            # Glass morphism modifier
│   └── Themes/                    # 13 built-in theme structs
└── ILSAppApp.swift                # Root: @State themeManager, .environment injection

ILSApp/ILSMacApp/
├── ILSMacApp.swift                # Root: @State themeManager, .environment injection
└── Views/MacContentView.swift     # Uses SystemMonitorView in detail pane

Sources/ILSBackend/
├── Controllers/SystemController.swift    # REST + WebSocket endpoints
└── Services/SystemMetricsService.swift   # macOS/Linux system metrics collection

Sources/ILSShared/DTOs/
└── SystemDTOs.swift               # SystemMetricsResponse, ProcessInfoResponse, FileEntryResponse
```

### Pattern 1: Host-Aware System Monitor

**What:** The system monitor must connect to whatever host the user has activated, not a hardcoded localhost URL.

**Current flow:**
1. `SystemMetricsViewModel.init(baseURL: "http://localhost:9999")` -- hardcoded default
2. `SystemMonitorView.onAppear` checks `viewModel.metricsClient.baseURL != appState.serverURL`, replaces client if mismatch
3. Process list URL is constructed from `self.baseURL` in ViewModel -- also hardcoded

**Required fix:**
- `SystemMetricsViewModel` should NOT own a hardcoded baseURL. It should accept the URL from the view layer (which has `@Environment(AppState.self)`).
- On host switch (`onChange(of: appState.serverURL)`), the ViewModel should disconnect, update its URL, and reconnect.

**Example:**
```swift
// SystemMonitorView.swift - onAppear already handles this for WebSocket:
.onAppear {
    if viewModel.metricsClient.baseURL != appState.serverURL {
        viewModel.disconnect()
        viewModel.metricsClient = MetricsWebSocketClient(baseURL: appState.serverURL)
    }
    viewModel.connect()
}

// But process loading also needs the correct URL:
// SystemMetricsViewModel should expose a method to update baseURL
func updateBaseURL(_ url: String) {
    self.baseURL = url  // Currently 'let', needs to become 'var' or re-init pattern
    // metricsClient already replaced by view
}
```

### Pattern 2: Theme Loading on Fresh Install

**What:** The theme system must produce a valid visual state even when no UserDefaults exist.

**Current flow:**
1. `ThemeEnvironmentKey.defaultValue` = `ThemeSnapshot(CyberpunkTheme())` -- hardcoded fallback
2. `ThemeManager.init()`: reads `UserDefaults.standard.string(forKey: "selectedThemeID") ?? "cyberpunk"`
3. Finds matching theme in built-in array, or falls back to `CyberpunkTheme()`
4. Both `ILSAppApp.swift` (iOS) and `ILSMacApp.swift` (macOS) create `@State private var themeManager = ThemeManager()` at root level
5. Inject via `.environment(\.theme, themeManager.currentSnapshot)`

**This path is sound.** On fresh install:
- No "selectedThemeID" in UserDefaults -> defaults to "cyberpunk"
- CyberpunkTheme is always in the built-in array
- ThemeSnapshot is created synchronously in init -- no async race

**Potential edge case:** If `availableThemes` array is empty or CyberpunkTheme is accidentally removed, `themes.first(where:)` returns nil and we fall back to `CyberpunkTheme()` constructor directly. This is robust.

### Pattern 3: Cross-Platform Theme Injection

**What:** Both iOS and macOS must inject themes the same way for visual consistency.

**iOS path (`ILSAppApp.swift`):**
```swift
@State private var themeManager = ThemeManager()
SidebarRootView()
    .environment(themeManager)
    .environment(\.theme, themeManager.currentSnapshot)
```

**macOS path (`ILSMacApp.swift`):**
```swift
@State private var themeManager = ThemeManager()
MacContentView()
    .environment(themeManager)
    .environment(\.theme, themeManager.currentSnapshot)
```

Both paths are identical in structure. All views read `@Environment(\.theme) private var theme: ThemeSnapshot`, which is the same concrete struct on both platforms.

**Key insight:** All 13 built-in themes use `Color(hex:)` (hardcoded sRGB values), NOT platform-adaptive colors like `Color(uiColor: .systemBackground)`. This means colors are pixel-identical across iOS, iPadOS, and macOS. The legacy `ILSTheme` enum in `ILSTheme.swift` DOES use platform-adaptive colors (`#if os(iOS)` / `#else`) but this is only used by the legacy `ErrorStateView`, `EmptyStateView`, and button styles -- not by the `AppTheme`-based system.

### Anti-Patterns to Avoid

- **Hardcoding localhost in ViewModel init:** The `SystemMetricsViewModel` defaults to `http://localhost:9999`. This breaks when connected to a remote host via tunnel or different port.
- **Creating MetricsWebSocketClient in init then replacing in onAppear:** Current pattern creates a client in init that gets immediately discarded if `appState.serverURL` differs. Wasteful but not buggy.
- **Using platform-adaptive colors in themes:** `Color(uiColor: .systemBackground)` renders differently across iOS and macOS. All themes correctly use `Color(hex:)` instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WebSocket reconnection | Custom retry logic | Existing `MetricsWebSocketClient` with exponential backoff, max 10 attempts, fallback to REST polling | Already handles disconnect, reconnect, fallback gracefully |
| Theme persistence | Custom file-based storage | `UserDefaults` + `ThemeManager` | Simple string ID; no complex serialization needed |
| System metrics collection | Shell scripts or custom parsing | `SystemMetricsService` actor (host_processor_info, host_statistics64, getifaddrs) | Mach kernel APIs are correct; shell parsing is fragile |
| Color cross-platform compat | Conditional compilation per platform | `Color(hex:)` initializer | sRGB hex values render identically everywhere |

**Key insight:** The infrastructure for all three requirements already exists and works. This phase is about fixing edge cases and verifying correctness, not building new systems.

## Common Pitfalls

### Pitfall 1: System Monitor Shows Local Metrics When Connected to Remote Host
**What goes wrong:** User activates a remote host profile, navigates to System Monitor, and sees metrics from their local machine instead of the remote host.
**Why it happens:** `SystemMetricsViewModel.init()` hardcodes `baseURL: "http://localhost:9999"`. The view's `onAppear` replaces the WebSocket client but the ViewModel's own `baseURL` property (used for process list REST calls) stays as localhost.
**How to avoid:** Make `baseURL` in `SystemMetricsViewModel` mutable or pass it as a parameter. Ensure both WebSocket and REST endpoints use `appState.serverURL`.
**Warning signs:** Process list shows local machine's processes while CPU/memory charts show remote host data (or vice versa).

### Pitfall 2: Theme Flash on Cold Launch
**What goes wrong:** User briefly sees the wrong theme (or no theme) before the correct one loads.
**Why it happens:** If `ThemeManager.init()` reads UserDefaults synchronously but the SwiftUI environment isn't fully propagated before the first frame.
**How to avoid:** The current architecture is correct -- `ThemeManager` init is synchronous, `@State` ensures it's created before first body evaluation. The `ThemeEnvironmentKey.defaultValue` is `ThemeSnapshot(CyberpunkTheme())` as a safety net. Verify this works with a real fresh install (delete app from simulator, rebuild, launch).
**Warning signs:** Brief flash of cyan/dark colors before the selected theme appears.

### Pitfall 3: Custom Themes Not Available After Host Switch
**What goes wrong:** User switches hosts, custom themes from the new host don't appear in ThemePickerView.
**Why it happens:** `loadAndRegisterCustomThemes` is called in `SidebarRootView.task` and `.onChange(of: appState.serverURL)`. But if the new host has different custom themes, old ones might persist in the `availableThemes` array.
**How to avoid:** The current `registerTheme` method only adds themes that don't already exist (dedup by ID). Since custom theme IDs are `custom-{UUID}`, different hosts produce different IDs. Themes from the old host remain registered but are harmless -- they just won't be available for editing since ThemesListView fetches its own list from the API.
**Warning signs:** Stale custom themes from a previous host appearing in the theme picker.

### Pitfall 4: Light Theme Glass Card Rendering Differences
**What goes wrong:** `GlassCard` looks different on macOS vs iOS for light themes.
**Why it happens:** `GlassCard` uses `theme.glassBackground` and `theme.glassBorder`. For light themes like Paper, these are `Color.black.opacity(0.05)` and `Color.black.opacity(0.10)`. On macOS, window backgrounds can differ, making these semi-transparent overlays appear slightly different.
**How to avoid:** Test light themes (Paper, Snow) specifically on macOS. If glass looks wrong, the theme may need macOS-specific glass values, but this is unlikely since we use hardcoded opacities, not platform-adaptive materials.
**Warning signs:** Glass cards appearing too dark or invisible on macOS with light themes.

### Pitfall 5: WebSocket Connection Not Resuming After Background/Foreground
**What goes wrong:** User backgrounds the app while on System Monitor, returns, and the Live indicator stays "Offline".
**Why it happens:** `onChange(of: scenePhase)` in `SystemMonitorView` calls `viewModel.disconnect()` on background and `viewModel.connect()` on active. The `connect()` method checks `guard webSocketTask == nil, pollingTask == nil` -- if the previous disconnect didn't fully clean up, reconnection is blocked.
**How to avoid:** The current `disconnect()` implementation is thorough (cancels all tasks, nils all references, resets failure state). This was previously fixed per MEMORY.md. Verify it works end-to-end.
**Warning signs:** "Offline" badge stuck after returning from background.

## Code Examples

### Current: SystemMonitorView Host URL Handling (needs fix)
```swift
// SystemMonitorView.swift — onAppear handles WebSocket URL mismatch:
.onAppear {
    if viewModel.metricsClient.baseURL != appState.serverURL {
        viewModel.disconnect()
        viewModel.metricsClient = MetricsWebSocketClient(baseURL: appState.serverURL)
    }
    viewModel.connect()
}

// But SystemMetricsViewModel.loadProcesses() uses hardcoded baseURL:
func loadProcesses() async {
    let sortParam = processSortBy == .cpu ? "cpu" : "memory"
    guard let url = URL(string: "\(baseURL)/api/v1/system/processes?sort=\(sortParam)") else { return }
    // ^^ baseURL is "http://localhost:9999" from init
}
```

### Fix Approach: Pass URL from View to ViewModel
```swift
// Option A: Make baseURL settable
class SystemMetricsViewModel {
    var baseURL: String  // Change from 'let' to 'var'

    func updateBaseURL(_ url: String) {
        guard url != baseURL else { return }
        baseURL = url
        disconnect()
        metricsClient = MetricsWebSocketClient(baseURL: url)
    }
}

// SystemMonitorView:
.onAppear {
    viewModel.updateBaseURL(appState.serverURL)
    viewModel.connect()
}
.onChange(of: appState.serverURL) { _, newURL in
    viewModel.updateBaseURL(newURL)
    viewModel.connect()
}
```

### Current: Theme Loading Chain (working correctly)
```swift
// 1. EnvironmentKey default (safety net):
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeSnapshot = ThemeSnapshot(CyberpunkTheme())
}

// 2. ThemeManager.init() (reads UserDefaults synchronously):
init() {
    var savedID = UserDefaults.standard.string(forKey: Self.themeIDKey) ?? "cyberpunk"
    // ... legacy migrations ...
    let selectedTheme = themes.first(where: { $0.id == savedID }) ?? CyberpunkTheme()
    self._currentTheme = selectedTheme
    self.currentSnapshot = ThemeSnapshot(selectedTheme)
}

// 3. Root view injection (both iOS and macOS):
@State private var themeManager = ThemeManager()
// ...
.environment(themeManager)
.environment(\.theme, themeManager.currentSnapshot)
```

### Backend: System Metrics WebSocket Endpoint
```swift
// SystemController.swift — streams JSON every 2 seconds:
func liveMetrics(req: Request, ws: WebSocket) async {
    let streamTask = Task {
        while !Task.isCancelled {
            let stats = await service.getMetrics()
            let response = SystemMetricsResponse(
                cpu: stats.cpu,
                memory: ...,
                disk: ...,
                network: ...,
                loadAverage: stats.loadAverage
            )
            let data = try encoder.encode(response)
            try await ws.send(String(data: data, encoding: .utf8)!)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
    ws.onClose.whenComplete { _ in streamTask.cancel() }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `any AppTheme` existential in environment | `ThemeSnapshot` concrete struct | Phase 18 (v3.0) | Eliminated ~82 existential container allocations per view body |
| Hardcoded theme ID "obsidian" | UserDefaults persistence with migration | Phase 4 (v1.0) | Themes survive app restart; legacy IDs auto-migrate |
| `ILSTheme` static enum with platform-adaptive colors | `AppTheme` protocol with `Color(hex:)` | Phase 4 (v1.0) | Cross-platform color consistency; `ILSTheme` remains for legacy components only |
| Direct `Process` call for system metrics | `SystemMetricsService` actor with Mach APIs | Phase 5 (v1.0) | Thread-safe, no shell parsing for CPU/memory/disk |

**Deprecated/outdated:**
- `ILSTheme` enum (`ILSTheme.swift`): Still used by `ErrorStateView`, `EmptyStateView`, `LoadingOverlay`, `CardStyle`, `PrimaryButtonStyle`, `SecondaryButtonStyle`. These legacy components should eventually migrate to `ThemeSnapshot` but are out of scope for this phase.

## Open Questions

1. **Does the system monitor work with remote hosts (tunnel/SSH)?**
   - What we know: Backend runs on the host and collects local system metrics via Mach APIs. WebSocket URL is built from `appState.serverURL`. If the user is connected via tunnel (e.g., Cloudflare), the WebSocket needs `wss://` and the tunnel must support WebSocket upgrade.
   - What's unclear: Whether tunnel configurations properly proxy WebSocket connections. The `MetricsWebSocketClient.connectWebSocket()` method does `http -> ws` and `https -> wss` replacement, which is correct.
   - Recommendation: Verify WebSocket works through tunnel during functional validation. If not, the REST fallback polling will still work.

2. **Should stale custom themes be purged on host switch?**
   - What we know: `registerTheme` is additive only. Custom themes from a previous host persist in `ThemeManager.availableThemes` after switching hosts.
   - What's unclear: Whether this causes confusion in the ThemePickerView (showing themes that belong to a different host).
   - Recommendation: Low priority. Custom themes from other hosts are harmless in the picker. If the user selects one, it still renders correctly from its cached snapshot. Purging would add complexity without clear user benefit. Defer to v3.2+.

3. **Is `ILSTheme` legacy usage a consistency risk?**
   - What we know: `ErrorStateView`, `EmptyStateView`, and button styles use `ILSTheme` static colors, which ARE platform-adaptive (`#if os(iOS)` / `#else`). All other views use `ThemeSnapshot` with hex colors.
   - What's unclear: Whether users notice the inconsistency (legacy components use system colors while everything else uses theme colors).
   - Recommendation: Out of scope for SYS-03. The legacy components are rarely visible (error states, empty states). Full migration tracked as future work.

## Sources

### Primary (HIGH confidence)
- Codebase inspection: `SystemMonitorView.swift`, `SystemMetricsViewModel.swift`, `MetricsWebSocketClient.swift` -- full read of all three files
- Codebase inspection: `AppTheme.swift` (ThemeManager, ThemeEnvironmentKey), `ThemeSnapshot.swift`, `CustomThemeAdapter.swift` -- full read
- Codebase inspection: `SystemController.swift`, `SystemMetricsService.swift`, `SystemDTOs.swift` -- backend pipeline verified
- Codebase inspection: `ILSAppApp.swift`, `ILSMacApp.swift` -- root-level theme injection verified identical
- Codebase inspection: All 13 built-in theme files -- all use `Color(hex:)`, only Paper and Snow set `isLight = true`

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` -- Phase ordering rationale, describes system monitor & themes as "restoration work"
- MEMORY.md -- Prior validation history: "Functional Depth Validation PASS" including system monitor with real metrics

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all technologies already in use, no new dependencies
- Architecture: HIGH -- full codebase read of all relevant files, patterns well-understood
- Pitfalls: HIGH -- identified from code inspection + prior validation history in MEMORY.md
- SYS-01 fix: HIGH -- clear root cause (hardcoded baseURL in ViewModel), straightforward fix
- SYS-02 verification: HIGH -- traced the full init chain, no gaps found
- SYS-03 verification: HIGH -- all themes use hex colors, both platforms inject theme identically

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable infrastructure, no external dependencies changing)
