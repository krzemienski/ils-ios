# ILS iOS App

A native iOS client for managing Claude Code configurations, sessions, and workflows.

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Swift 5.9+

## Quick Start

1. Open `ILSApp.xcodeproj` in Xcode
2. Start the backend server: `PORT=9999 swift run ILSBackend`
3. Select the ILSApp scheme
4. Press `Cmd+R` to build and run

## Architecture

- **Pattern:** MVVM with SwiftUI
- **Backend:** Vapor server on port 9999 (avoid 8080 - used by ralph-mobile)
- **Shared Types:** ILSShared Swift Package (DTOs, models)
- **Theme:** Cyberpunk-inspired design system with 12 built-in themes

### Directory Structure

```
ILSApp/
├── ILSAppApp.swift           # App entry point & global state
├── Info.plist               # App configuration (Bundle ID: com.ils.app)
├── ILSApp.entitlements      # App entitlements
├── PrivacyInfo.xcprivacy    # Privacy manifest
├── Assets.xcassets/         # Images and colors
├── Views/                   # SwiftUI views by feature
│   ├── Root/               # Root container views
│   ├── Home/               # Home dashboard screen
│   ├── Chat/               # Chat interface with streaming
│   ├── Sessions/           # Session list & management
│   ├── Projects/           # Project browser
│   ├── Skills/             # Skills explorer (1,500+ skills)
│   ├── Browser/            # Plugin browser & marketplace
│   ├── Plugins/            # Plugin management
│   ├── MCP/                # MCP server status
│   ├── System/             # System monitoring (CPU, memory, processes)
│   ├── Teams/              # Multi-agent team coordination
│   ├── Fleet/              # Fleet management
│   ├── Dashboard/          # Dashboard stats
│   ├── Settings/           # App configuration
│   ├── Themes/             # Custom theme management
│   ├── Onboarding/         # First-run setup flow
│   ├── Sidebar/            # Navigation sidebar
│   └── Shared/             # Reusable components
├── ViewModels/             # Business logic per feature (15 view models)
├── Services/               # API client, SSE streaming, tunnel
├── Models/                 # App-specific models
├── Theme/                  # Design system & custom themes
└── Utils/                  # Utilities and helpers
```

## Key Components

### App Entry Point (`ILSAppApp.swift`)

```swift
@main
struct ILSAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
```

**AppState** manages:
- Backend connection URL
- Connection status
- Selected tab navigation
- Deep link handling

### Navigation (`ContentView.swift`)

The app uses a sidebar-based navigation pattern:
- Sheet-based sidebar triggered by toolbar button
- Tab selection stored in `AppState.selectedTab`
- Each feature has its own view

### Views

| View | Purpose |
|------|---------|
| `DashboardView` | Overview with stats cards and recent activity |
| `SessionsListView` | List of chat sessions with create/select |
| `ChatView` | Chat interface with streaming messages |
| `ProjectsListView` | Browse Claude Code projects |
| `SkillsListView` | Search and view available skills |
| `PluginsListView` | Toggle plugins on/off |
| `MCPServerListView` | View MCP server health status |
| `SettingsView` | Configure app and connection |
| `SidebarView` | Navigation menu with all options |

### ViewModels

Each major view has a corresponding ViewModel:

```swift
@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var isLoading = false
    @Published var error: Error?

    func loadSessions() async { ... }
    func createSession(...) async -> ChatSession? { ... }
}
```

ViewModels handle:
- Data fetching from API
- State management
- Error handling
- Business logic

### Services

#### APIClient (`Services/APIClient.swift`)

REST API communication with the backend:

```swift
class APIClient {
    let baseURL: String

    func getSessions() async throws -> [ChatSession]
    func createSession(...) async throws -> ChatSession
    func getProjects() async throws -> [Project]
    func getSkills() async throws -> [Skill]
    func healthCheck() async throws -> Bool
    // ... more endpoints
}
```

#### SSEClient (`Services/SSEClient.swift`)

Server-Sent Events for real-time chat streaming:

```swift
class SSEClient {
    func streamChat(sessionId: UUID, prompt: String, projectId: UUID?) -> AsyncThrowingStream<StreamMessage, Error>
}
```

### Theme (`Theme/ILSTheme.swift`)

Centralized design system:

```swift
struct ILSTheme {
    // Colors
    static let primaryText = Color.white
    static let secondaryText = Color.gray
    static let accent = Color.orange
    static let background = Color.black
    static let secondaryBackground = Color(white: 0.1)

    // Typography
    static let titleFont = Font.title.bold()
    static let bodyFont = Font.body
    static let captionFont = Font.caption

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24

    // Corner Radius
    static let cornerRadiusS: CGFloat = 8
    static let cornerRadiusM: CGFloat = 12
    static let cornerRadiusL: CGFloat = 16
}
```

## Features

- **Chat with Claude**: Real-time streaming responses via SSE with markdown rendering, code blocks, tool calls, and thinking sections
- **Session Management**: Create, view, fork, rename, export, and delete chat sessions
- **Project Browser**: Browse and manage Claude Code projects with deterministic IDs
- **Skills Explorer**: Search and view 1,500+ available Claude Code skills
- **Plugin Management**: Browse marketplace, install, enable/disable plugins (real git clone)
- **MCP Server Status**: Monitor Model Context Protocol servers
- **System Monitoring**: View CPU, memory, disk, network metrics and running processes with live charts
- **Team Coordination**: Manage multi-agent teams with tasks and messaging
- **Custom Themes**: Create and customize your own themes or choose from 12 built-in themes
- **Cloudflare Tunnel**: Expose your local backend via secure tunnel (TunnelService)
- **Connection Modes**: Local, Remote, or Tunnel connection with ServerSetupSheet onboarding
- **Dashboard**: Overview stats, entity colors, sparkline charts, and recent activity
- **Accessibility**: Full accessibility labels and reduce motion support

### Chat Interface

The chat system supports:
- Real-time streaming via SSE with `SSEClient`
- Markdown rendering with code syntax highlighting (Splash)
- Code blocks with copy functionality (`CodeBlockView`)
- Tool call accordion display (`ToolCallAccordion`)
- Thinking sections for extended reasoning (`ThinkingSection`)
- Message history persistence in SQLite
- User/assistant message styling with avatars
- Typing indicator during streaming (●●●)
- Stop button with 30s timeout handling
- Session info modal and forking
- Command palette for quick actions (Cmd+K)
- Cost display per message

### Dashboard

Shows key metrics:
- Total projects count with StatCard
- Active sessions count
- Available skills count (1,500+)
- MCP server health status (20 servers)
- Recent activity timeline with sparkline charts
- Entity color system (6 types: session, project, skill, plugin, mcp, team)
- Empty states with EmptyEntityState component
- Skeleton loading with ShimmerModifier

### System Monitoring

Live system metrics:
- CPU usage charts with SparklineChart
- Memory usage visualization
- Disk space monitoring
- Network I/O tracking
- Running processes list with filtering
- File browser for directory navigation
- WebSocket live metrics stream (`/api/v1/system/metrics/live`)

### Settings

Configurable options:
- Backend host and port (default: localhost:9999)
- Connection testing with health check
- Connection mode: Local/Remote/Tunnel
- Cloudflare tunnel configuration (TunnelSettingsView)
- Theme customization (12 built-in + custom themes)
- ServerSetupSheet for first-run onboarding
- Connection diagnostics and retry

## Deep Linking

The app responds to `ils://` URLs (URL scheme registered in Info.plist):

| URL | Action |
|-----|--------|
| `ils://home` | Navigate to Home |
| `ils://sessions` | Navigate to Sessions |
| `ils://projects` | Navigate to Projects |
| `ils://skills` | Navigate to Skills |
| `ils://plugins` | Navigate to Plugins (Browser) |
| `ils://mcp` | Navigate to MCP Servers |
| `ils://system` | Navigate to System Monitoring |
| `ils://fleet` | Navigate to Fleet Management |
| `ils://teams` | Navigate to Teams |
| `ils://settings` | Navigate to Settings |

**Note:** Deep link UUIDs must be lowercase. System shows "Open in ILSApp?" dialog.

Handled via SwiftUI `.onOpenURL` modifier in `ILSAppApp.swift`.

## Adding a New Feature

### 1. Create the ViewModel

```swift
// ViewModels/NewFeatureViewModel.swift
@MainActor
class NewFeatureViewModel: ObservableObject {
    @Published var data: [YourModel] = []
    @Published var isLoading = false

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        // Fetch data...
    }
}
```

### 2. Create the View

```swift
// Views/NewFeature/NewFeatureView.swift
struct NewFeatureView: View {
    @StateObject private var viewModel = NewFeatureViewModel()

    var body: some View {
        List(viewModel.data) { item in
            Text(item.name)
        }
        .navigationTitle("New Feature")
        .task {
            await viewModel.loadData()
        }
    }
}
```

### 3. Add Navigation

Update `ContentView.swift` to include the new view in the navigation switch:

```swift
case "newfeature":
    NewFeatureView()
```

Update `SidebarView.swift` to add the sidebar item.

### 4. Add Deep Link (Optional)

Update `AppState.handleURL(_:)` to handle `ils://newfeature`.

## Testing

### UI Testing

```bash
xcodebuild test \
  -project ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Manual Testing Checklist

- [ ] App launches without crash
- [ ] Backend connection established (green indicator)
- [ ] All navigation tabs load
- [ ] Sessions list shows data
- [ ] Chat streaming works
- [ ] Projects list loads
- [ ] Skills search works
- [ ] Settings save correctly
- [ ] Deep links navigate correctly

## Troubleshooting

### App shows "Disconnected"

1. Verify backend is running: `curl http://localhost:9999/health`
2. Check that you're running the correct backend binary:
   ```bash
   lsof -i :9999 -P -n
   # Binary path MUST be in ils-ios, NOT ils/ILSBackend
   ```
3. Check Settings for correct host/port (default: localhost:9999)
4. For physical device, use Mac's IP address (Settings > Connection > Remote)
5. Use ServerSetupSheet for guided setup on first run

### Build Errors

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*

# Clean build folder in Xcode
Product > Clean Build Folder (Cmd+Shift+K)
```

### Simulator Issues

```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all
```

## Bundle ID

`com.ils.app` (iOS) / `com.ils.mac` (macOS)

## URL Scheme

`ils://` — supports deep linking to all tabs (see Deep Linking section above)

## Navigation

The app uses a 5-tab TabView navigation pattern:
- Tab bar at bottom (iOS) or top (macOS)
- `selectedTab` in `ILSAppApp.swift` controls active tab
- Sheet-based sidebar for additional navigation
- Sidebar button in toolbar triggers `.sheet` presentation
- Each tab has its own view hierarchy with NavigationStack

## Key Files

| Area | Path |
|------|------|
| App Entry | `ILSApp/ILSAppApp.swift` |
| Navigation | `ILSApp/ContentView.swift` |
| Theme | `ILSApp/Theme/ILSTheme.swift` |
| ViewModels | `ILSApp/ViewModels/` |
| Views | `ILSApp/Views/` |
| Services | `ILSApp/Services/` |
| Shared Models | `../Sources/ILSShared/` |
| Backend | `../Sources/ILSBackend/` |

## API Reference

See [API-REFERENCE.md](../docs/API-REFERENCE.md) for complete backend API documentation.

## Dependencies

The iOS app uses:
- **ILSShared** - Shared models, DTOs (local Swift Package)
  - Includes `Splash` for syntax highlighting
- SwiftUI (system)
- Combine (system)
- Foundation (system)

The ILSShared package includes:
- Models: Session, Message, Project, Skill, Plugin, MCPServer, CustomTheme, FleetHost, etc.
- DTOs: Request/Response types for API communication
- Syntax highlighting via Splash library

No other external dependencies required for the iOS app.
