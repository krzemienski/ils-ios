# ILS - Intelligent Learning System

A native iOS and macOS application for managing AI-powered chat sessions, projects, skills, and system monitoring.

## Overview

ILS provides a comprehensive interface for interacting with AI assistants across multiple platforms:

- **iOS App**: Native iOS application with SwiftUI
- **macOS App**: Native macOS application with desktop-specific features
- **Backend**: Swift Vapor server providing REST API and SSE streaming

## Features

### Core Features

- **Chat Sessions**: Create and manage AI chat sessions with streaming responses
- **Projects**: Organize and track projects with sessions
- **Skills**: Browse and manage AI skills and capabilities
- **MCP Servers**: Integration with Model Context Protocol servers
- **Plugins**: Extensible plugin system for custom functionality
- **System Monitoring**: Real-time CPU, memory, disk, and network monitoring

### iOS App Features

- 5-tab navigation (Dashboard, Sessions, Projects, System, Settings)
- Native iOS UI with SwiftUI
- Real-time streaming responses
- Session management with export and sharing
- Dark mode and multiple themes
- Cloudflare tunnel integration
- Connection modes: Local, Remote, Tunnel

### macOS App Features ⭐

The macOS app provides a superior desktop experience with:

- **Native macOS UI**: NavigationSplitView with resizable sidebar (150-400pt)
- **Multi-window support**: Open sessions in separate windows
- **Full keyboard navigation**: 25+ keyboard shortcuts for efficient workflow
- **Menu bar integration**: Complete File, Edit, View, and Window menus
- **Touch Bar support**: Quick actions on MacBook Pro Touch Bar
- **Native notifications**: macOS notification center integration
- **Window state persistence**: Remembers positions, sizes, and layouts

📖 **[See full macOS app documentation →](docs/MACOS_APP.md)**

## Getting Started

### Prerequisites

- macOS 14.0 or later (for development and macOS app)
- Xcode 15.0 or later
- Swift 5.9 or later
- iOS 17.0 or later (for iOS app)

### Running the Backend

1. **Navigate to the project directory:**
   ```bash
   cd ILSApp
   ```

2. **Run the backend server:**
   ```bash
   swift run ILSBackend
   ```

   The backend will start on port 9999 by default.

3. **Verify backend is running:**
   ```bash
   curl http://localhost:9999/api/v1/health
   ```

### Running the iOS App

1. **Open the Xcode project:**
   ```bash
   open ILSApp.xcodeproj
   ```

2. **Select the iOS target:**
   - Choose `ILSApp` scheme
   - Select an iPhone simulator or device

3. **Build and run:**
   - Press `Cmd+R` or click the Run button

### Running the macOS App

1. **Open the Xcode project:**
   ```bash
   open ILSApp.xcodeproj
   ```

2. **Select the macOS target:**
   - Choose `ILSMacApp` scheme
   - Select "My Mac" as destination

3. **Build and run:**
   - Press `Cmd+R` or click the Run button

4. **On first launch:**
   - Enter backend URL (default: `http://localhost:9999`)
   - Click "Connect" to verify connection

📖 **[See full macOS setup instructions →](docs/MACOS_APP.md#building-the-macos-app)**

## Project Structure

```
ILSApp/
├── ILSApp/                    # iOS app target
│   ├── Views/                 # iOS-specific views
│   ├── ViewModels/            # Shared view models
│   ├── Services/              # API and networking
│   └── Models/                # Data models
├── ILSMacApp/                 # macOS app target
│   ├── Views/                 # macOS-specific views
│   ├── Managers/              # Window & notification managers
│   ├── TouchBar/              # Touch Bar integration
│   └── AppDelegate.swift      # Menu bar customization
├── ILSShared/                 # Shared package
│   ├── Sources/
│   │   ├── Models/           # Shared data models
│   │   ├── Services/         # Shared services
│   │   └── ViewModels/       # Shared view models
│   └── Package.swift
├── ILSBackend/                # Vapor backend
│   ├── Sources/
│   │   ├── Controllers/      # API controllers
│   │   ├── Models/           # Database models
│   │   └── Services/         # Backend services
│   └── Package.swift
└── docs/                      # Documentation
    └── MACOS_APP.md          # macOS app guide
```

## Architecture

### iOS/macOS Apps

Built with SwiftUI and following modern iOS/macOS patterns:

- **MVVM architecture**: Clear separation of concerns
- **Async/await**: Modern concurrency for networking
- **Combine**: Reactive data flow
- **SwiftUI**: Declarative UI framework
- **Shared code**: Maximum code reuse between iOS and macOS

### Backend

Built with Swift Vapor:

- **RESTful API**: Standard REST endpoints for all operations
- **SSE Streaming**: Server-sent events for real-time chat responses
- **Fluent ORM**: Database abstraction layer
- **SQLite**: Embedded database for development

### Communication

- **REST API**: CRUD operations for sessions, projects, skills, etc.
- **Server-Sent Events (SSE)**: Real-time streaming for chat responses
- **JSON**: Standard data exchange format

## Key Technologies

- **Swift**: Primary language for all platforms
- **SwiftUI**: UI framework for iOS and macOS
- **Vapor**: Backend web framework
- **Fluent**: ORM for database access
- **Combine**: Reactive programming framework
- **URLSession**: Networking layer
- **UserNotifications**: Native notifications framework

## Configuration

### Backend Configuration

Default backend runs on `http://localhost:9999`. Configure in the apps:

- **iOS**: Settings > Connection > Server URL
- **macOS**: Settings > Connection > Server URL

### Connection Modes

- **Local**: Direct connection to localhost backend
- **Remote**: Connection to remote server via URL
- **Tunnel** (iOS only): Cloudflare tunnel integration

## Development

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for code quality
- Maximum line length: 120 characters
- Use `// MARK:` for code organization

### Platform-Specific Code

Use compiler directives for platform-specific code:

```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

### Shared Code

Maximize code sharing via ILSShared package:

- ViewModels (cross-platform business logic)
- Services (networking, SSE, connection management)
- Models (data structures)

Only create platform-specific views when necessary for native UX.

## Testing

### Run iOS Tests

```bash
xcodebuild test \
  -project ILSApp.xcodeproj \
  -scheme ILSApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Run macOS Tests

```bash
xcodebuild test \
  -project ILSApp.xcodeproj \
  -scheme ILSMacApp \
  -destination 'platform=macOS'
```

### Manual Testing

1. Start the backend server
2. Launch the iOS or macOS app
3. Verify connection indicator shows "Connected"
4. Create a new session
5. Send a message and verify streaming response
6. Test navigation between sections
7. Test keyboard shortcuts (macOS)
8. Test multi-window support (macOS)

## Keyboard Shortcuts (macOS)

The macOS app provides extensive keyboard shortcuts:

| Category | Shortcut | Action |
|----------|----------|--------|
| **Navigation** | `Cmd+1-6` | Switch between sections |
| **Session** | `Cmd+N` | New session / Open in new window |
| **Chat** | `Cmd+Return` | Send message |
| **Chat** | `Cmd+K` | Command palette |
| **View** | `Cmd+Ctrl+S` | Toggle sidebar |
| **Search** | `Cmd+/` | Focus search |

📖 **[See complete keyboard shortcuts →](docs/MACOS_APP.md#keyboard-shortcuts)**

## Troubleshooting

### Backend Issues

**Backend won't start:**
- Check port 9999 is not in use: `lsof -i :9999`
- Try a different port: `PORT=8080 swift run ILSBackend`

### App Issues

**Can't connect to backend:**
- Verify backend is running
- Check backend URL matches in app settings
- Test connection: `curl http://localhost:9999/api/v1/health`

**Build errors:**
- Clean build folder: `Cmd+Shift+K` in Xcode
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Resolve packages: `File > Packages > Resolve Package Versions`

**macOS app specific issues:**

📖 **[See macOS troubleshooting guide →](docs/MACOS_APP.md#troubleshooting)**

## Documentation

- **[macOS App Guide](docs/MACOS_APP.md)**: Complete macOS app documentation
  - Build instructions
  - Keyboard shortcuts reference
  - Menu bar features
  - Multi-window usage
  - Touch Bar controls
  - Troubleshooting

## Contributing

We welcome contributions! To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes following the code style
4. Add tests for new functionality
5. Update documentation as needed
6. Submit a pull request

### Contribution Guidelines

- Follow existing code patterns and architecture
- Maintain iOS/macOS code sharing where possible
- Add keyboard shortcuts for new macOS features
- Update documentation for user-facing changes
- Test on both iOS and macOS when applicable

## License

[License information to be added]

## Support

For issues or questions:

- Check the troubleshooting section above
- Review the [macOS app documentation](docs/MACOS_APP.md)
- Create an issue on GitHub with:
  - Platform (iOS/macOS) and version
  - Xcode version
  - Steps to reproduce
  - Expected vs actual behavior
  - Relevant logs or screenshots

## Roadmap

### Upcoming Features

- [ ] iCloud sync for sessions across devices
- [ ] Widgets for iOS and macOS
- [ ] Shortcuts app integration
- [ ] Handoff support between iOS and macOS
- [ ] Advanced Touch Bar customization
- [ ] Plugin marketplace
- [ ] Custom themes and appearance
- [ ] Accessibility enhancements
- [ ] watchOS companion app

## Acknowledgments

Built with:
- [Swift](https://swift.org) - Programming language
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - UI framework
- [Vapor](https://vapor.codes) - Backend web framework
- [Fluent](https://docs.vapor.codes/fluent/overview/) - ORM framework

---

**Note**: This is a native macOS and iOS application. For the best desktop experience, use the **macOS app** which includes multi-window support, full keyboard navigation, Touch Bar integration, and native macOS menus.

📖 **[Get started with the macOS app →](docs/MACOS_APP.md)**
