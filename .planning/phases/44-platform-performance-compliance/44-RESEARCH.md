# Phase 44: Platform & Performance Compliance - Research

**Researched:** 2026-02-25
**Domain:** iOS platform capabilities (Live Activity, TipKit, render optimization, concurrency modernization)
**Confidence:** HIGH

## Summary

Phase 44 closes 8 platform/performance gaps (PLAT-01 through PLAT-08) identified in the gap analysis. The codebase is already well-positioned: Live Activity views exist with Dynamic Island compact/expanded layouts but are never invoked from ChatViewModel's streaming path; TipKit is configured with 4 tips defined but only 2 surfaced in views; `DispatchQueue.main.asyncAfter` has already been fully eliminated (zero instances remain); `.equatable()` is not applied to any views; `drawingGroup()` is applied in CyberpunkEffects and two utility views but not on the primary shadow-heavy `GlassCard` modifier used across 30+ view instances; and `URLSession` cellular constraints are partially configured (APIClient has `allowsConstrainedNetworkAccess = true` but lacks `allowsCellularAccess` control and no user-facing preference exists).

The work divides into 5 distinct areas: (1) Wire existing Live Activity code into the ChatViewModel SSE streaming lifecycle, (2) add `NSSupportsLiveActivities` to Info.plist, (3) complete TipKit tip surfacing for Theme/MCP/Teams features, (4) apply `.equatable()` to ChatView and BrowserView bodies and `drawingGroup()` to GlassCard, (5) add a cellular data preference to Settings that controls `allowsCellularAccess` on APIClient's URLSession.

**Primary recommendation:** Wire the existing Live Activity infrastructure into the ChatViewModel streaming lifecycle, complete TipKit tip surfacing, and add render optimizations and the cellular toggle -- all changes are additive with no architectural risk.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-01 | Dynamic Island compact/expanded views verified and functional with Live Activity | Live Activity views exist (`ILSLiveActivity.swift` lines 198-318) with compact leading/trailing and expanded views. `ChatStreamingAttributes` defined. Missing: `NSSupportsLiveActivities = true` in Info.plist, and `startLiveActivity`/`updateLiveActivity`/`endLiveActivity` never called from ChatViewModel streaming path. |
| PLAT-02 | Live Activity SSE integration for active chat sessions | ChatViewModel has the extension methods (`startLiveActivity`, `updateLiveActivity`, `endLiveActivity`) at lines 334-443 of `ILSLiveActivity.swift`. They reference `streamStartTime`, `streamTokenCount`, `currentStreamingMessage` -- all exist in ChatViewModel. Missing: actual calls during SSE observation loop (lines 160-219 of ChatViewModel.swift). |
| PLAT-03 | Remaining DispatchQueue.main.asyncAfter calls replaced with Task-based equivalents | **ALREADY COMPLETE.** Zero instances of `DispatchQueue.main.asyncAfter` or `asyncAfter` found anywhere in `ILSApp/ILSApp/`. Previous audit phases eliminated all occurrences. Verification: grep confirms zero matches. |
| PLAT-04 | URLSession cellular constraints fully applied in APIClient | APIClient.swift line 81 sets `config.allowsConstrainedNetworkAccess = true`. SSEClient.swift line 53 sets `config.allowsConstrainedNetworkAccess = false`. Missing: `allowsCellularAccess` property not set on either, no user-facing preference in Settings, NetworkMonitor.swift detects `.cellular` but doesn't gate behavior. |
| PLAT-05 | .equatable() applied to complex views (ChatView, BrowserView) for render performance | Zero `.equatable()` modifiers found anywhere in the codebase. ChatView.swift (469 lines) and BrowserView.swift (900+ lines) are the two primary candidates. |
| PLAT-06 | drawingGroup() applied for shadow-heavy views to offload GPU compositing | `drawingGroup()` exists in 3 places: CyberpunkEffects.swift (GlowEffect modifier), AppIconGenerator.swift, LaunchScreenView.swift. Missing from `GlassCard` modifier which applies `.shadow()` and is used in 30+ view instances across the app. Also missing from `StatCard` which has `.shadow()`. |
| PLAT-07 | TipKit tips complete for Theme, MCP, and Teams features | TipKit configured in ILSAppApp.swift (line 42). 4 tips defined in AppTips.swift: `ServerSetupTip`, `CreateSessionTip`, `CommandPaletteTip`, `ThemeTip`. Only 2 are surfaced: `ServerSetupTip` in SettingsConnectionSection, `CreateSessionTip` in HomeView. Missing: `CommandPaletteTip` not used anywhere, `ThemeTip` not used anywhere, no MCP tip defined, no Teams tip defined. |
| PLAT-08 | Tip display rules with sequential unlock and after-N-opens triggers | Only `CreateSessionTip` has a rule (`isConnected == true`). Other tips have no rules. Missing: sequential unlock logic (e.g., "show Theme tip only after Create Session tip dismissed"), after-N-opens triggers (e.g., "show MCP tip after 3rd app launch"), event-based donation tracking. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ActivityKit | iOS 16.2+ | Live Activities and Dynamic Island | Apple first-party framework, only way to show Dynamic Island content |
| TipKit | iOS 17.0+ | In-app contextual tips | Apple first-party framework, integrated with SwiftUI |
| SwiftUI | iOS 17.0+ | `.equatable()`, `drawingGroup()` view modifiers | Built-in performance optimization APIs |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| WidgetKit | iOS 17.0+ | Widget bundle for Live Activity registration | Already imported, needed for `ActivityConfiguration` if widget extension is separated |

### Alternatives Considered

None -- all requirements use Apple first-party frameworks already present in the project.

## Architecture Patterns

### Recommended Project Structure

No new directories needed. All changes fit within existing structure:

```
ILSApp/
├── LiveActivity/
│   └── ILSLiveActivity.swift     # Existing -- add NSSupportsLiveActivities to Info.plist
├── Views/
│   ├── Tips/
│   │   └── AppTips.swift          # Existing -- add MCP, Teams tips + rules
│   ├── Chat/
│   │   └── ChatView.swift         # Add .equatable()
│   ├── Browser/
│   │   └── BrowserView.swift      # Add .equatable()
│   └── Settings/
│       └── SettingsView.swift     # Add cellular data preference section
├── ViewModels/
│   └── ChatViewModel.swift        # Wire Live Activity calls into SSE loop
├── Services/
│   └── APIClient.swift            # Add allowsCellularAccess toggle
└── Theme/
    ├── GlassCard.swift            # Add drawingGroup()
    └── Components/StatCard.swift  # Add drawingGroup()
```

### Pattern 1: Live Activity SSE Wiring

**What:** Call `startLiveActivity()` when streaming begins, `updateLiveActivity()` on each SSE message batch, and `endLiveActivity()` when streaming completes.

**When to use:** In ChatViewModel's SSE observation loop where `isStreaming` transitions from false to true and back.

**Example:**
```swift
// In ChatViewModel SSE observation loop (around line 175-188)
if streaming != lastStreaming {
    self.isStreaming = streaming
    if streaming {
        self.streamTokenCount = 0
        self.streamElapsedSeconds = 0
        self.streamStartTime = Date()
        lastMessageCount = 0
        // Wire Live Activity start
        #if os(iOS)
        if #available(iOS 16.2, *) {
            let sessionName = /* session display name */
            let model = /* session model */
            self.startLiveActivity(sessionName: sessionName, model: model)
        }
        #endif
    } else {
        self.flushPendingMessages()
        self.stopBatchTimer()
        self.lastProcessedMessageIndex = 0
        self.streamStartTime = nil
        lastMessageCount = 0
        // Wire Live Activity end
        #if os(iOS)
        if #available(iOS 16.2, *) {
            self.endLiveActivity()
        }
        #endif
    }
    lastStreaming = streaming
}
```

### Pattern 2: TipKit Event-Based Rules

**What:** Use TipKit's `@Parameter` and `#Rule` system for sequential unlock and event-based triggers.

**When to use:** When tips should appear only after certain conditions are met (previous tip dismissed, N app opens).

**Example:**
```swift
struct MCPBrowserTip: Tip {
    var title: Text { Text("Browse MCP Servers") }
    var message: Text? { Text("View and manage your MCP server configurations.") }
    var image: Image? { Image(systemName: "server.rack") }

    @Parameter
    static var hasCreatedSession: Bool = false

    @Parameter
    static var appOpenCount: Int = 0

    var rules: [Rule] {
        #Rule(Self.$hasCreatedSession) { $0 == true }
        #Rule(Self.$appOpenCount) { $0 >= 3 }
    }
}
```

### Pattern 3: Equatable View Optimization

**What:** Apply `.equatable()` to views whose body re-renders frequently but whose inputs rarely change.

**When to use:** On complex views like ChatView and BrowserView that have many child views.

**Example:**
```swift
// ChatView body -- wrap the main content
var body: some View {
    mainContent
        .equatable()
        // ... modifiers
}
```

**Important caveat:** `.equatable()` requires the view to conform to `Equatable`. For views with `@State`, `@Environment`, or `@Binding` properties, the `Equatable` conformance must compare only the relevant input properties, not internal state. An alternative approach is to apply `.equatable()` to specific expensive subviews (e.g., `ChatMessageList`, individual `BrowserView` content sections) rather than the top-level view.

### Pattern 4: drawingGroup() for Shadow Compositing

**What:** `drawingGroup()` flattens the view hierarchy into a single Metal-rendered texture before compositing, eliminating per-frame shadow blur recalculation.

**When to use:** On views with `.shadow()` that appear in scrollable lists (GlassCard, StatCard).

**Example:**
```swift
// GlassCard modifier
func body(content: Content) -> some View {
    content
        .padding(padding ?? theme.spacingMD)
        .background(theme.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .stroke(theme.glassBorder, lineWidth: 0.5)
        )
        .shadow(color: theme.accent.opacity(0.08), radius: 8, x: 0, y: 0)
        .drawingGroup() // Offload shadow compositing to Metal
}
```

### Pattern 5: Cellular Data Preference

**What:** Store a user preference for allowing cellular data access, wire it to URLSession configuration.

**When to use:** When the app should respect the user's desire to limit cellular data usage.

**Example:**
```swift
// In APIClient init, read UserDefaults
@AppStorage("allowCellularData") var allowCellularData: Bool = true

// In URLSession configuration:
config.allowsCellularAccess = allowCellularData
```

### Anti-Patterns to Avoid

- **Applying `.equatable()` to the entire ChatView body:** ChatView has `@State`, `@FocusState`, `@Environment` properties that change independently. Apply `.equatable()` to stable subviews instead.
- **Calling `startLiveActivity()` from UI thread without `#available` check:** ActivityKit requires iOS 16.2+ availability check with `#if os(iOS)` guard.
- **Using `Tips.resetDatastore()` in production:** Only for testing. Use `Tips.configure()` with `.displayFrequency(.daily)` (already configured).
- **Adding `drawingGroup()` to views with interactive content (text fields, buttons):** `drawingGroup()` rasterizes the view -- interactive elements inside may lose hit-testing fidelity. Apply to decorative/display-only containers.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sequential tip ordering | Custom tip state machine | TipKit `@Parameter` + `#Rule` | Apple handles persistence, display frequency, dismissal tracking |
| App open counting | Manual UserDefaults counter | TipKit `Tips.Event` donations | TipKit tracks events internally and handles edge cases |
| Dynamic Island layout | Custom overlay window | ActivityKit `ActivityConfiguration` | Only official API for Dynamic Island content |
| Shadow render optimization | Manual layer caching | SwiftUI `drawingGroup()` | Built-in Metal compositing pipeline |

**Key insight:** All 8 requirements use Apple first-party APIs. No third-party libraries are needed, and the project already imports every required framework.

## Common Pitfalls

### Pitfall 1: NSSupportsLiveActivities Missing from Info.plist

**What goes wrong:** `Activity.request()` silently fails or throws "Live Activities not supported" even though ActivityKit code compiles fine.
**Why it happens:** Info.plist must explicitly declare `NSSupportsLiveActivities = YES` for ActivityKit to function at runtime.
**How to avoid:** Add the key to Info.plist AND to `project.yml` info properties section.
**Warning signs:** `ActivityAuthorizationInfo().areActivitiesEnabled` returns false on a device that supports Live Activities.

### Pitfall 2: Widget Extension Required for Lock Screen Live Activities

**What goes wrong:** Live Activity code in the main app target compiles but doesn't render on the lock screen.
**Why it happens:** Lock screen and Dynamic Island presentations require an `ActivityConfiguration` in a Widget Extension target, NOT just views in the main app.
**How to avoid:** The current codebase has widgets inside the main app target (WidgetBundle.swift notes "When moved to a dedicated Widget Extension target, uncomment @main"). For Live Activities to work on real devices, the `ChatStreamingAttributes` views need to be in a widget extension. However, for spec compliance verification, the views exist and are structurally correct. The SSE wiring should still be implemented in ChatViewModel so that when a widget extension is created, the data flow is ready.
**Warning signs:** `Activity.request()` succeeds (returns an Activity ID) but nothing appears on lock screen or Dynamic Island.

### Pitfall 3: .equatable() Requires Equatable Conformance

**What goes wrong:** Compile error "Type does not conform to protocol 'Equatable'" when adding `.equatable()`.
**Why it happens:** `.equatable()` requires the view struct to conform to `Equatable`. Views with non-Equatable properties (closures, `@Environment`, certain `@State` types) cannot trivially conform.
**How to avoid:** Apply `.equatable()` to leaf subviews that have simple Equatable inputs, not to top-level views with rich state. Good candidates: `ChatMessageList`, individual row views in BrowserView, `StatCard`.
**Warning signs:** Extensive boilerplate `static func ==` implementations that compare only some properties.

### Pitfall 4: drawingGroup() Breaks Interactive Views

**What goes wrong:** Buttons or text fields inside a `drawingGroup()` stop responding to taps or keyboard input.
**Why it happens:** `drawingGroup()` renders the entire subtree into a Metal texture. Hit-testing can become unreliable for interactive elements within the rasterized layer.
**How to avoid:** Apply `drawingGroup()` only to decorative/display containers (GlassCard's shadow+background layer) and NOT to the content passed to the modifier. The `GlassCard` pattern is safe because `.shadow()` is on the outer container, not on interactive children.
**Warning signs:** Tap gestures on buttons inside glass cards stop working after adding `drawingGroup()`.

### Pitfall 5: TipKit Tips Not Appearing

**What goes wrong:** `TipView(myTip)` shows nothing even though the tip is defined.
**Why it happens:** TipKit respects `.displayFrequency(.daily)` -- if a tip was shown or dismissed, it won't reappear until the next day. Also, tip rules must ALL evaluate to true.
**How to avoid:** During development, use `Tips.showAllTipsForTesting()` after `Tips.configure()`. For production, ensure all `@Parameter` values are donated correctly via `TipParameter.setValue()` calls.
**Warning signs:** Tips work in fresh installs but never appear in subsequent launches.

### Pitfall 6: Cellular Constraint vs Constrained Network

**What goes wrong:** Confusing `allowsCellularAccess` with `allowsConstrainedNetworkAccess` -- they control different things.
**Why it happens:** `allowsCellularAccess` controls whether the session uses cellular at all. `allowsConstrainedNetworkAccess` controls whether it works in Low Data Mode. Both exist on URLSessionConfiguration.
**How to avoid:** The user-facing toggle should control `allowsCellularAccess`. The existing `allowsConstrainedNetworkAccess` settings should be left as-is (APIClient: true, SSEClient: false -- meaning SSE won't stream in Low Data Mode but API calls will work).
**Warning signs:** Users on cellular can't use the app at all when they only wanted to limit background data.

## Code Examples

### Live Activity Info.plist Entry

```xml
<!-- Add to Info.plist -->
<key>NSSupportsLiveActivities</key>
<true/>
```

```yaml
# Add to project.yml under ILSApp target info properties
NSSupportsLiveActivities: true
```

### TipKit New Tips with Rules

```swift
// AppTips.swift -- new tips for MCP, Teams
struct MCPBrowserTip: Tip {
    var title: Text { Text("Explore MCP Servers") }
    var message: Text? { Text("Browse and manage your Model Context Protocol server configurations.") }
    var image: Image? { Image(systemName: "server.rack") }

    @Parameter
    static var hasCreatedSession: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasCreatedSession) { $0 == true }
    }
}

struct TeamsTip: Tip {
    var title: Text { Text("Agent Teams") }
    var message: Text? { Text("Coordinate multiple Claude agents working together on complex tasks.") }
    var image: Image? { Image(systemName: "person.3") }

    @Parameter
    static var hasViewedMCP: Bool = false

    var rules: [Rule] {
        #Rule(Self.$hasViewedMCP) { $0 == true }
    }
}
```

### Cellular Data Preference in Settings

```swift
// In SettingsView, add a new section
Section {
    Toggle("Allow Cellular Data", isOn: $allowCellularData)
        .onChange(of: allowCellularData) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "allowCellularData")
            // APIClient will pick up on next request
        }
} header: {
    Label("Data Usage", systemImage: "antenna.radiowaves.left.and.right")
}
```

### equatable() on Subviews

```swift
// Apply to stable leaf views, not top-level ChatView
struct ChatMessageRow: View, Equatable {
    let message: ChatMessage
    let isStreaming: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.message.id == rhs.message.id &&
        lhs.message.text == rhs.message.text &&
        lhs.isStreaming == rhs.isStreaming
    }

    var body: some View {
        // ... message rendering
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DispatchQueue.main.asyncAfter` | `Task { try? await Task.sleep(for:) }` | Already migrated (prior phases) | PLAT-03 is already complete |
| No Live Activity integration | Views exist but unwired | Current state | Need to wire SSE -> Live Activity calls |
| Manual onboarding tips | TipKit framework | iOS 17 (2023) | Already imported, partially implemented |
| CPU shadow compositing | `drawingGroup()` Metal offload | SwiftUI 2+ | Applied in 3 places, needs GlassCard |

**Deprecated/outdated:**
- `DispatchQueue.main.asyncAfter` -- already eliminated, no action needed
- Manual tip state management -- TipKit handles persistence internally

## Open Questions

1. **Widget Extension for Live Activity rendering**
   - What we know: Live Activity views are defined in the main app target. The WidgetBundle comment says "When moved to a dedicated Widget Extension target, uncomment @main."
   - What's unclear: Whether Live Activities will actually render on the lock screen/Dynamic Island without a separate Widget Extension target. The SSE wiring and `Activity.request()` calls will work from the main app, but the presentation views may not appear.
   - Recommendation: Wire the SSE integration (it's the hard part and is spec-compliant). Note in the plan that a Widget Extension target creation may be needed for full device-level rendering. The views and data flow will be correct either way.

2. **ChatViewModel session name access for Live Activity**
   - What we know: `startLiveActivity(sessionName:model:)` needs the session display name and model. ChatViewModel has `sessionId` but doesn't directly hold the session's `displayName` or `model`.
   - What's unclear: Whether to pass these values into ChatViewModel or look them up.
   - Recommendation: Pass `session.displayName` and `session.model` from ChatView into ChatViewModel (e.g., store as properties during `configure()` or `setupChatView()`).

3. **drawingGroup() impact on GlassCard interactivity**
   - What we know: GlassCard wraps content with padding, background, clip, overlay, and shadow. The content inside can be interactive (buttons, toggles, text fields).
   - What's unclear: Whether `drawingGroup()` on the entire GlassCard modifier will break interactivity of child content.
   - Recommendation: Test thoroughly. If interactivity breaks, apply `drawingGroup()` only to the background+shadow layer, not the entire content. Alternatively, create a separate `GlassCardBackground` that applies shadow+drawingGroup behind the interactive content using a `ZStack`.

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `ILSLiveActivity.swift` (447 lines, complete Dynamic Island views)
- Codebase analysis: `AppTips.swift` (45 lines, 4 tip definitions, 2 surfaced)
- Codebase analysis: `APIClient.swift` (545 lines, URLSession configuration at line 76-82)
- Codebase analysis: `ChatViewModel.swift` (SSE observation loop lines 160-219)
- Codebase analysis: `GlassCard.swift` (47 lines, shadow at line 16)
- Codebase grep: zero `asyncAfter` matches in `ILSApp/ILSApp/`

### Secondary (MEDIUM confidence)
- Apple Developer Documentation: TipKit `@Parameter` and `#Rule` system
- Apple Developer Documentation: `drawingGroup()` Metal compositing behavior
- Apple Developer Documentation: `NSSupportsLiveActivities` Info.plist key requirement

### Tertiary (LOW confidence)
- Widget Extension requirement for Live Activity lock screen rendering (needs device-level validation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all Apple first-party, already imported
- Architecture: HIGH - existing code patterns are clear, changes are additive
- Pitfalls: HIGH - well-documented Apple frameworks, common issues well-known

**Research date:** 2026-02-25
**Valid until:** 2026-03-25 (stable Apple frameworks, unlikely to change)
