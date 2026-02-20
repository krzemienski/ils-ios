# Architecture Patterns

**Domain:** Native iOS/macOS client for Claude Code
**Researched:** 2026-02-19

## System Architecture

```
+-----------------------------------------------------+
|                    iOS App (SwiftUI)                  |
|  +----------+  +----------+  +------------------+   |
|  | Views    |->|ViewModels|->| Services          |   |
|  | (65+)    |  | (MVVM)   |  | APIClient (actor) |   |
|  |          |  |          |  | SSEClient         |   |
|  |          |  |          |  | MetricsWSClient   |   |
|  +----------+  +----------+  +--------+---------+   |
|                                        |              |
|  +----------------------------------+  |              |
|  | Theme System (ThemeSnapshot)     |  |              |
|  | 12 themes, 17 color + 13 typo   |  |              |
|  | + 10 spacing + 8 radius tokens  |  |              |
|  +----------------------------------+  |              |
+----------------------------------------+--------------+
                                         | HTTP/SSE/WS
                                         | localhost:9999
+----------------------------------------+--------------+
|                  Vapor Backend                        |
|  +--------------+  +--------------+                  |
|  | Controllers  |->| Services     |                  |
|  | (14)         |  | ConfigFile   |                  |
|  | /api/v1/*    |  | MCPFile      |                  |
|  |              |  | ClaudeExec   |                  |
|  +--------------+  +------+-------+                  |
|                           |                          |
|  +--------------+  +------+-------+                  |
|  | ILSShared    |  | Real Files   |                  |
|  | Models/DTOs  |  | ~/.claude/*  |                  |
|  | (shared pkg) |  | .mcp.json    |                  |
|  +--------------+  +--------------+                  |
+------------------------------------------------------+
                           |
                    +------+-------+
                    | Claude CLI   |
                    | (via python  |
                    |  sdk-wrapper)|
                    +--------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| iOS Views (65+) | User interface rendering | ViewModels via `@Observable` bindings |
| macOS Views (11) | macOS-specific UI | Same ViewModels (shared code) |
| ViewModels | Business logic, state management | Services (APIClient, SSEClient) |
| APIClient (actor) | HTTP requests to backend | Vapor backend at localhost:9999 |
| SSEClient | Server-Sent Events for chat | Backend `/api/v1/chat/stream` |
| MetricsWebSocketClient | Real-time system metrics | Backend WebSocket `/api/v1/system` |
| ThemeSnapshot | Concrete theme values | All views via `@Environment(\.theme)` |
| ILSShared | Shared models and DTOs | iOS app + Backend (SPM package) |
| Vapor Controllers (14) | API route handling | Services for file/CLI access |
| ConfigFileService | Read/write Claude config files | `~/.claude/settings.json`, `.mcp.json` |
| MCPFileService | MCP server config management | MCP config files |
| ClaudeExecutorService | Claude CLI subprocess management | Python sdk-wrapper.py |

### Data Flow

```
User taps "Send" in ChatView
  -> ChatViewModel.sendMessage()
    -> POST /api/v1/chat/stream (SSE)
      -> ClaudeExecutorService.executeWithSDK()
        -> python3 sdk-wrapper.py (subprocess)
          -> claude-agent-sdk.query() (Claude CLI)
            -> Anthropic API
          <- NDJSON stream (partial messages)
        <- NDJSON parsed to SSE events
      <- SSE events to iOS
    <- ChatViewModel updates messages array
  <- ChatView re-renders with new message
```

## Navigation Architecture

### iOS: Sidebar Navigation (Custom)

```
ILSAppApp
  +-- SidebarRootView
       |-- SidebarView (sheet, left-edge swipe)
       |    |-- Home
       |    |-- System Monitor
       |    |-- Browse (Browser)
       |    |-- Agent Teams
       |    |-- Hosts (was Fleet)
       |    +-- Settings
       +-- Content Area (activeScreen routing)
            |-- HomeView
            |-- SystemMonitorView
            |-- BrowserView (tabbed: MCP/Skills/Plugins)
            |-- AgentTeamsListView
            |-- FleetManagementView
            |-- SettingsView
            |-- ThemesListView
            +-- ChatView (via session tap)
```

Deep link scheme: `ils://` with routes: `home`, `sessions`, `sessions/{uuid}`, `browser`, `projects`, `plugins`, `mcp`, `skills`, `settings`, `system`, `fleet`, `themes`.

### macOS: NavigationSplitView

```
ILSMacApp
  +-- MacContentView
       |-- Sidebar (persistent column)
       |    |-- Dashboard
       |    |-- Sessions (grouped by project)
       |    +-- Settings
       +-- Detail Area
            |-- MacDashboardView
            |-- MacChatView
            +-- MacSettingsView
```

## Patterns to Follow

### Pattern 1: ThemeSnapshot Environment

**What:** Concrete `ThemeSnapshot` struct injected via `@Environment(\.theme)`.
**When:** Every view that uses any visual token (color, font, spacing, radius).
**Example:**
```swift
struct MyView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        Text("Hello")
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(theme.textPrimary)
            .padding(theme.spacingMD)
    }
}
```

### Pattern 2: GlassCard Modifier

**What:** Consistent card styling across all list/detail views.
**When:** Any content card or section container.
**Example:**
```swift
VStack { /* content */ }
    .padding(theme.spacingMD)
    .modifier(GlassCard())
```

### Pattern 3: Actor-Based APIClient

**What:** Thread-safe networking via Swift actor.
**When:** All backend API calls.
**Example:**
```swift
// In ViewModel
func loadData() async {
    do {
        let items = try await apiClient.fetchSkills()
        self.skills = items
    } catch {
        self.error = error
    }
}
```

### Pattern 4: Host Default Badge

**What:** Read-only settings with "Host Default" badge for CLI-inherited values.
**When:** Settings that come from the host CLI config (model, theme, thinking, coauthor).
**Example:**
```swift
HStack {
    Text("Extended Thinking")
    Spacer()
    hostDefaultBadge
    Text(thinkingValue)
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: UIScreen.main.bounds
**What:** Using `UIScreen.main.bounds` for layout calculations.
**Why bad:** Breaks iPad Split View, multitasking, and external displays.
**Instead:** Use `containerRelativeFrame(.horizontal)` or GeometryReader.
**Affected:** `UserMessageCard.swift:15` (CRITICAL backlog C4).

### Anti-Pattern 2: Animation Without Reduce Motion Check
**What:** Calling `withAnimation` or `.animation()` without checking `accessibilityReduceMotion`.
**Why bad:** Accessibility violation, potential App Store rejection.
**Instead:** Gate all animations: `if !accessibilityReduceMotion { withAnimation { ... } }`.
**Affected:** C1, C2, C3, H12 in audit backlog.

### Anti-Pattern 3: Computed Property Every Body Evaluation
**What:** Expensive computations in computed properties that run on every SwiftUI body evaluation.
**Why bad:** Performance regression -- `MarkdownParser.parse()` and `filteredThemes` run unnecessarily.
**Instead:** Cache in `@State` + update via `.task(id:)` or `.onChange`.
**Affected:** C5, C6 in audit backlog.

### Anti-Pattern 4: `nonisolated(unsafe)` on Task Properties
**What:** Marking Task properties as `nonisolated(unsafe)` when they should be actor-isolated.
**Why bad:** Data race risk. Compiler suggests `nonisolated` but that breaks `@ObservationTracked`.
**Instead:** For `@Observable @MainActor` classes, `nonisolated(unsafe)` IS needed for Task properties accessed in `deinit`. But for ViewModel search tasks (H10, H11), remove the annotation.
**Affected:** H8, H10, H11 in audit backlog.

### Anti-Pattern 5: `onAppear { Task { } }` Instead of `.task`
**What:** Creating unstructured Tasks in `onAppear`.
**Why bad:** Task is not automatically cancelled when view disappears.
**Instead:** Use SwiftUI `.task` modifier which auto-cancels on disappear.
**Affected:** M11 in audit backlog.

## Scalability Considerations

| Concern | Current (Local) | At Scale (Remote) |
|---------|-----------------|-------------------|
| Sessions | 22K+ (SQLite) | Fine -- SQLite handles millions of rows |
| Skills | 3K+ (filesystem scan) | Fine -- cached in ViewModel |
| MCP Servers | 15-20 (config files) | Fine -- small count |
| Real-time metrics | WebSocket to localhost | Cloudflare Tunnel for remote access |
| Chat streaming | SSE via localhost | SSE via Cloudflare Tunnel |
| Build time | ~90s iOS, ~60s backend | N/A -- local development only |

## Sources

- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` -- iOS navigation architecture
- `ILSApp/ILSMacApp/Views/MacContentView.swift` -- macOS navigation architecture
- `ILSApp/ILSApp/ILSAppApp.swift` -- App entry point, deep link handling
- `ILSApp/ILSApp/Theme/` -- ThemeSnapshot and GlassCard patterns
- `Sources/ILSBackend/Controllers/` -- 14 backend controllers
- `Sources/ILSBackend/Services/ClaudeExecutorService.swift` -- Chat integration
- `.claude/skills/ils-ios-project/references/audit-backlog.md` -- Anti-pattern sources
