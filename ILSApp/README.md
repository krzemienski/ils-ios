# ILS iOS App

A native iOS client for managing Claude Code configurations, sessions, and workflows.

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Swift 5.9+

## Quick Start

1. Open `ILSApp.xcodeproj` in Xcode
2. Start the backend server: `PORT=9090 swift run ILSBackend`
3. Select the ILSApp scheme
4. Press `Cmd+R` to build and run

## Architecture

- **Pattern:** MVVM with SwiftUI
- **Backend:** Vapor server on port 9090
- **Shared Types:** ILSShared Swift Package (DTOs, models)
- **Theme:** Dark-first design system (ILSTheme)

### Directory Structure

```
ILSApp/
├── ILSAppApp.swift           # App entry point
├── ContentView.swift         # Root navigation container
├── Info.plist               # App configuration
├── Assets.xcassets/         # Images and colors
├── Views/                   # SwiftUI views by feature
│   ├── Chat/               # Chat interface
│   ├── Dashboard/          # Overview stats
│   ├── Sessions/           # Session management
│   ├── Projects/           # Project browser
│   ├── Plugins/            # Plugin management
│   ├── MCP/                # MCP server status
│   ├── Skills/             # Skills explorer
│   ├── Settings/           # App configuration
│   └── Sidebar/            # Navigation sidebar
├── ViewModels/             # Business logic
├── Services/               # API and networking
└── Theme/                  # Design system
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

- **Sessions**: Create, manage, and chat with Claude Code sessions
- **Projects**: Browse and manage project directories
- **Skills**: View, search, and toggle Claude Code skills
- **MCP Servers**: Monitor health, import/export, batch manage MCP servers
- **Plugins**: Browse, enable/disable, and install from marketplace
- **Settings**: Full Claude Code configuration management
- **Dashboard**: Overview stats and recent activity

### Chat Interface

The chat system supports:
- Real-time streaming via SSE
- Message history persistence
- User/assistant message styling
- Typing indicator during streaming
- Session info and forking
- Command palette for quick actions

### Dashboard

Shows key metrics:
- Total projects count
- Active sessions count
- Available skills count
- MCP server health status
- Recent activity feed

### Settings

Configurable options:
- Backend host and port
- Connection testing
- Default model selection
- SSH connections and fleet management
- Config profiles and overrides
- Log viewer and analytics

## Deep Linking

The app responds to `ils://` URLs:

| URL | Action |
|-----|--------|
| `ils://sessions` | Navigate to Sessions |
| `ils://projects` | Navigate to Projects |
| `ils://plugins` | Navigate to Plugins |
| `ils://mcp` | Navigate to MCP Servers |
| `ils://skills` | Navigate to Skills |
| `ils://settings` | Navigate to Settings |

Handled in `AppState.handleURL(_:)`.

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

1. Verify backend is running: `curl http://localhost:9090/health`
2. Check Settings for correct host/port
3. For physical device, use Mac's IP address

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

`com.ils.app`

## URL Scheme

`ils://` — supports deep linking to tabs:
- `ils://sessions` - Navigate to Sessions
- `ils://projects` - Navigate to Projects
- `ils://skills` - Navigate to Skills
- `ils://mcp` - Navigate to MCP Servers
- `ils://plugins` - Navigate to Plugins
- `ils://settings` - Navigate to Settings

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
- **ILSShared** - Shared models (local Swift Package)
- SwiftUI (system)
- Combine (system)

No external dependencies required.
