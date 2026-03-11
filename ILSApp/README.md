# ILS iOS/macOS App

Native iOS and macOS client for managing Claude Code sessions, workflows, and system monitoring.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 16.0+
- Swift 5.10+
- ILS Backend running on port 9999

## Quick Start

```bash
# 1. Start the backend
PORT=9999 swift run ILSBackend

# 2. Open in Xcode
open ILSApp.xcodeproj

# 3. Select ILSApp scheme → Cmd+R  (iOS)
#    Select ILSMacApp scheme → Cmd+R  (macOS)
```

Build from command line:
```bash
# iOS (dedicated simulator)
xcodebuild -project ILSApp.xcodeproj -scheme ILSApp \
  -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' -quiet 2>&1 | tail -5

# macOS
xcodebuild -project ILSApp.xcodeproj -scheme ILSMacApp \
  -destination 'platform=macOS' -quiet 2>&1 | tail -5
```

## Targets

| Target | Bundle ID | Min OS | Scheme |
|--------|-----------|--------|--------|
| iOS App | `com.ils.app` | iOS 17+ | `ILSApp` |
| macOS App | `com.ils.mac` | macOS 14+ | `ILSMacApp` |

## Directory Structure

```
ILSApp/
├── ILSApp/
│   ├── ILSAppApp.swift          # App entry, deep link handling
│   ├── Info.plist               # Bundle ID: com.ils.app, URL scheme: ils://
│   ├── ILSApp.entitlements
│   ├── PrivacyInfo.xcprivacy
│   ├── Assets.xcassets/
│   ├── Views/                   # 38 screen directories
│   │   ├── Root/                # SidebarRootView, ContentView
│   │   ├── Home/                # Home dashboard
│   │   ├── Chat/                # Chat + streaming
│   │   ├── Sessions/            # Session list & management
│   │   ├── Projects/            # Project browser
│   │   ├── Skills/              # Skills explorer (1,500+ skills)
│   │   ├── Browser/             # Unified browser (MCP/Skills/Plugins)
│   │   ├── Plugins/             # Plugin management & marketplace
│   │   ├── MCP/                 # MCP server status
│   │   ├── System/              # CPU, memory, disk, process monitoring
│   │   ├── Teams/               # Multi-agent team coordination
│   │   ├── Fleet/               # Host profile management
│   │   ├── AgentQueue/          # Background agent task queue
│   │   ├── Workflows/           # Workflow automation
│   │   ├── Analytics/           # Usage analytics dashboard
│   │   ├── ActivityFeed/        # Session event timeline
│   │   ├── Audit/               # Audit trail & one-tap rollback
│   │   ├── Hooks/               # Claude Code hook configuration
│   │   ├── Permissions/         # Permission request management
│   │   ├── Search/              # Cross-session full-text search
│   │   ├── Themes/              # Theme browser & custom editor
│   │   ├── Settings/            # App & connection settings
│   │   ├── Terminal/            # Terminal emulator
│   │   ├── Documentation/       # In-app docs browser
│   │   ├── Premium/             # Feature gate + paywall
│   │   └── Shared/              # Reusable components
│   ├── ViewModels/              # 30+ @Observable @MainActor ViewModels
│   ├── Services/                # 50+ services
│   │   ├── APIClient.swift      # REST client (auto-prefixes /api/v1)
│   │   ├── SSEClient.swift      # Server-Sent Events streaming
│   │   ├── FeatureGate.swift    # Premium feature gating
│   │   ├── SubscriptionManager.swift  # StoreKit 2
│   │   ├── ICloudSyncManager.swift    # iCloud CloudKit sync
│   │   ├── TunnelService.swift  # Cloudflare tunnel management
│   │   └── ...
│   ├── Theme/                   # ThemeSnapshot struct + 13 built-in themes
│   ├── Widgets/                 # WidgetKit extensions
│   ├── LiveActivity/            # Live Activity support
│   └── Intents/                 # App Intents + Shortcuts
├── ILSMacApp/                   # macOS app (NavigationSplitView, AppKit bridges)
│   ├── ILSMacApp.swift
│   ├── AppDelegate.swift
│   ├── Views/                   # macOS-specific views
│   ├── ViewModels/
│   └── Services/
└── ILSApp.xcodeproj             # Xcode project (also project.yml for XcodeGen)
```

## Architecture

- **Pattern:** MVVM with `@Observable @MainActor` ViewModels
- **Navigation (iOS):** `SidebarRootView.ActiveScreen` enum drives routing — NOT `selectedTab`
- **Navigation (macOS):** `NavigationSplitView` with 3-column layout
- **Theme:** `@Environment(\.theme) private var theme: ThemeSnapshot` — concrete struct, not protocol
- **API:** `APIClient` adds `/api/v1` prefix automatically — never double-prefix paths
- **Concurrency:** Swift actors, `@MainActor`, async/await throughout

## Key Services

| Service | Purpose |
|---------|---------|
| `APIClient` | REST communication, auto-prefixes `/api/v1` |
| `SSEClient` | Server-Sent Events for chat streaming |
| `FeatureGate` | Premium feature availability checks |
| `SubscriptionManager` | StoreKit 2 subscription state |
| `MetricsWebSocketClient` | Live system metrics via WebSocket |
| `TunnelService` | Cloudflare tunnel process management |
| `ICloudSyncManager` | iCloud sync with graceful degradation |
| `CitadelSSHService` | SSH remote connections |

## Feature Gating

Premium features use `FeatureGate` — never add `if isPremium` directly in views:

```swift
// Declarative (views)
FeatureGateView(feature: .chatExport) {
    ExportButton()
}

// Imperative (ViewModels/Services)
if FeatureGate.shared.isAvailable(.chatExport) { ... }
```

## Deep Links (`ils://`)

| URL | Screen |
|-----|--------|
| `ils://home` | Home dashboard |
| `ils://sessions/{uuid}` | Specific chat session (UUID must be lowercase) |
| `ils://browser` | Browser (MCP/Skills/Plugins) |
| `ils://system` | System monitor |
| `ils://fleet` | Host profiles |
| `ils://teams` | Agent teams |
| `ils://agent-queue` | Agent queue |
| `ils://workflows` | Workflow automation |
| `ils://hooks` | Hooks configuration |
| `ils://themes` | Theme browser |
| `ils://settings` | Settings |
| `ils://analytics` | Analytics |
| `ils://permissions` | Permissions |
| `ils://search` | Cross-session search |

## Troubleshooting

```bash
# App shows "Disconnected"
curl http://localhost:9999/health
lsof -i :9999 -P -n  # Binary path must be in ils-ios/, NOT ils/ILSBackend

# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/ILSApp-*

# Verify correct simulator (NEVER use any other)
xcrun simctl list devices | grep 50523130-57AA-48B0-ABD0-4D59CE455F14
```

## Dependencies

- **ILSShared** — shared models and DTOs (local Swift Package)
- **Splash** — syntax highlighting for code blocks
- **swift-markdown-ui** — markdown rendering
- **HighlightSwift** — additional syntax highlighting
- **NetworkImage** — async image loading
- **Citadel** — SSH client

See `../Package.swift` for full dependency list.
