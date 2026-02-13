# ILS macOS App

Native macOS application for ILS (Intelligent Learning System) with full desktop integration, keyboard shortcuts, multi-window support, and macOS-specific features.

## Overview

The ILS macOS app provides a superior desktop experience compared to the iOS app running via Catalyst. It includes:

- **Native macOS UI**: NavigationSplitView with resizable sidebar
- **Multi-window support**: Open sessions in separate windows
- **Full keyboard navigation**: Comprehensive keyboard shortcuts for all actions
- **Menu bar integration**: Native macOS menus (File, Edit, View, Window)
- **Touch Bar support**: Quick actions on MacBook Pro Touch Bar
- **Native notifications**: macOS notification center integration
- **Window state persistence**: Remembers window positions and sizes

## Building the macOS App

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- ILS Backend running (see backend documentation)

### Build Instructions

1. **Open the Xcode project:**
   ```bash
   cd ILSApp
   open ILSApp.xcodeproj
   ```

2. **Select the macOS target:**
   - In Xcode, select `ILSMacApp` from the scheme dropdown
   - Choose "My Mac" as the destination

3. **Build and run:**
   - Press `Cmd+R` to build and run
   - Or use: `Product > Run` from the menu

4. **Build from command line:**
   ```bash
   xcodebuild -project ILSApp/ILSApp.xcodeproj \
     -scheme ILSMacApp \
     -destination 'platform=macOS' \
     clean build
   ```

### First Launch Setup

On first launch, configure your ILS backend server:

1. The app will show the server setup sheet
2. Enter your backend URL (default: `http://localhost:9999`)
3. Click "Connect" to verify the connection
4. Once connected, you can start creating sessions

## Keyboard Shortcuts

The macOS app provides extensive keyboard shortcuts for efficient workflow:

### Navigation

| Shortcut | Action |
|----------|--------|
| `Cmd+1` | Show Dashboard |
| `Cmd+2` | Show Sessions |
| `Cmd+3` | Show Projects |
| `Cmd+4` | Show System |
| `Cmd+5` | Show Browser |
| `Cmd+6` | Show Settings |
| `Cmd+Ctrl+S` | Toggle Sidebar |
| `Cmd+/` | Focus Search Field |

### File Operations

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New Session / Open in New Window |
| `Cmd+O` | Open Session |
| `Cmd+S` | Save/Export Session |
| `Cmd+W` | Close Window |

### Chat Actions

| Shortcut | Action |
|----------|--------|
| `Cmd+Return` | Send Message |
| `Cmd+K` | Show Command Palette |
| `Cmd+I` | Session Info |
| `Cmd+R` | Rename Session |
| `Cmd+E` | Export Session |
| `Cmd+Shift+F` | Fork Session |

### Edit Operations

| Shortcut | Action |
|----------|--------|
| `Cmd+Z` | Undo |
| `Cmd+Shift+Z` | Redo |
| `Cmd+X` | Cut |
| `Cmd+C` | Copy |
| `Cmd+V` | Paste |
| `Cmd+A` | Select All |

### Window Management

| Shortcut | Action |
|----------|--------|
| `Cmd+M` | Minimize Window |
| `Cmd+Q` | Quit Application |

## Menu Bar Features

### File Menu

- **New Session** (`Cmd+N`): Create a new chat session
- **Open Session** (`Cmd+O`): Open an existing session from a picker
- **Close Window** (`Cmd+W`): Close the current window
- **Save** (`Cmd+S`): Export current session to file

### Edit Menu

Standard macOS edit operations:
- Undo, Redo, Cut, Copy, Paste, Select All

### View Menu

- **Toggle Sidebar** (`Cmd+Ctrl+S`): Show/hide the sidebar
- **Navigation shortcuts**: Quick access to all main sections (Dashboard, Sessions, Projects, System, Browser, Settings)

### Window Menu

- **Minimize** (`Cmd+M`): Minimize current window
- **Zoom**: Toggle window zoom
- **Bring All to Front**: Bring all ILS windows to front
- **Window List**: Automatically shows all open windows

## Multi-Window Support

The macOS app supports opening multiple windows for better multitasking:

### Opening Sessions in New Windows

**Method 1: Context Menu**
1. Right-click any session in the sessions list
2. Select "Open in New Window"
3. Session opens in a dedicated window

**Method 2: Keyboard Shortcut**
1. Select a session
2. Press `Cmd+N`
3. Session opens in a new window

**Method 3: Double-Click**
1. Double-click a session in the sessions list
2. Session opens in the current view

### Window Management

- Each session window is independent
- Windows remember their position and size
- Close windows with `Cmd+W`
- All windows appear in the Window menu
- Use `Cmd+~` to cycle between windows (standard macOS)

## Touch Bar Controls

On MacBook Pro models with Touch Bar, the following controls appear when in chat view:

| Button | Action | Shortcut |
|--------|--------|----------|
| Send | Send current message | `Cmd+Return` |
| Palette | Open command palette | `Cmd+K` |
| Info | Show session info | `Cmd+I` |
| New | Create new session | `Cmd+N` |

The Touch Bar dynamically updates based on the current view and state:
- Send button is disabled when input is empty or streaming
- All buttons show keyboard shortcuts for quick reference

## Native Notifications

The macOS app integrates with macOS Notification Center:

### Notification Types

1. **New Messages**: When a message arrives while app is in background
2. **Streaming Complete**: When a long-running AI response completes

### Notification Permissions

- On first launch, the app requests notification permissions
- Grant permissions to receive notifications
- Configure notification style in System Settings > Notifications > ILS

### Notification Actions

- Click a notification to open the app and jump to the session
- Notifications are automatically cleared when you interact with them

## Sidebar

### Resizable Sidebar

The sidebar can be resized to your preference:

1. Hover over the divider between sidebar and main content
2. Drag to resize (minimum: 150pt, maximum: 400pt)
3. The size persists across app launches

### Sidebar Sections

- **Navigation**: Quick access to all main sections
- **Connection Status**: Shows server connection state
- **Sessions List**: Browse and search sessions

## Window State Persistence

The macOS app remembers your window layout:

### What's Saved

- Window positions (x, y coordinates)
- Window sizes (width, height)
- Sidebar width
- Last active session
- Connection settings

### How It Works

- Automatic saving on window resize/move
- Restoration on app relaunch
- Per-session window positions (multi-window)
- Main window state

## Architecture

### App Structure

```
ILSMacApp/
├── ILSMacApp.swift           # App entry point
├── AppDelegate.swift         # Menu bar & lifecycle
├── Views/
│   ├── MacContentView.swift      # Main 3-column layout
│   ├── MacChatView.swift         # Chat interface
│   ├── MacSessionsListView.swift # Sessions list
│   ├── SessionWindowView.swift   # Multi-window sessions
│   ├── MacDashboardView.swift    # Dashboard
│   ├── MacProjectsListView.swift # Projects list
│   └── MacSettingsView.swift     # Settings
├── Managers/
│   ├── WindowManager.swift       # Multi-window coordination
│   └── NotificationManager.swift # Notification handling
└── TouchBar/
    └── ChatTouchBarProvider.swift # Touch Bar integration
```

### Shared Code

The macOS app shares ViewModels, Services, and Models with the iOS app via the `ILSShared` package:

- **ViewModels**: ChatViewModel, SessionsViewModel, ProjectsViewModel, etc.
- **Services**: APIClient, SSEClient, ConnectionManager, PollingManager
- **Models**: ChatSession, Project, Message, etc.

Platform-specific code is isolated using `#if os(macOS)` compiler directives.

## Troubleshooting

### Build Issues

**Error: ILSMacApp target not found**
- Ensure you've opened `ILSApp.xcodeproj` in Xcode
- Verify the ILSMacApp target exists in the project
- Try cleaning the build folder: `Product > Clean Build Folder`

**Error: ILSShared not found**
- Ensure the ILSShared package is properly linked
- Check `File > Swift Packages > Resolve Package Versions`

### Runtime Issues

**Can't connect to backend**
- Verify the backend is running: `swift run ILSBackend`
- Check the backend port (default: 9999)
- Verify the server URL in Settings matches your backend

**Notifications not appearing**
- Check System Settings > Notifications > ILS
- Ensure notifications are allowed
- Verify the app is in background when messages arrive

**Window positions not saving**
- Ensure the app has full disk access (System Settings > Security & Privacy)
- Check that WindowManager is properly initialized

**Touch Bar not showing**
- Touch Bar only appears on MacBook Pro models with Touch Bar hardware
- Ensure you're in chat view (Touch Bar is context-specific)

### Performance

**App feels slow**
- Check backend connection latency
- Review System monitor in app for resource usage
- Try clearing app cache in Settings > Advanced

## Development

### Adding New Views

1. Create view file in `ILSMacApp/Views/`
2. Follow naming convention: `Mac[ViewName]View.swift`
3. Use `#if os(macOS)` for platform-specific code
4. Add to MacContentView or SessionWindowView
5. Update menu bar if needed (AppDelegate.swift)

### Adding New Keyboard Shortcuts

1. Add to appropriate menu in `AppDelegate.swift`
2. Add `.keyboardShortcut()` modifier to button/action
3. Use `.onKeyPress()` for custom key handling
4. Document in this file and in-app help

### Testing

Run UI tests:
```bash
xcodebuild test \
  -project ILSApp/ILSApp.xcodeproj \
  -scheme ILSMacApp \
  -destination 'platform=macOS'
```

## Distribution

### App Store Distribution

1. Configure signing in Xcode
2. Archive the app: `Product > Archive`
3. Distribute via App Store Connect
4. Follow Apple's macOS app submission guidelines

### Direct Distribution

1. Archive the app
2. Export as macOS app
3. Notarize with Apple (required for macOS 10.15+)
4. Distribute DMG or PKG installer

## Contributing

When contributing to the macOS app:

1. Follow the existing code patterns
2. Maintain iOS/macOS code sharing where possible
3. Use platform-specific code only when necessary
4. Update this documentation for new features
5. Add keyboard shortcuts for all major actions
6. Test on multiple macOS versions

## Support

For issues or questions:

- Check the troubleshooting section above
- Review existing issues on GitHub
- Create a new issue with detailed reproduction steps
- Include macOS version, Xcode version, and logs

## Future Enhancements

Planned features for future releases:

- [ ] iCloud sync for sessions across devices
- [ ] Widgets for quick stats
- [ ] Shortcuts app integration
- [ ] Handoff support with iOS app
- [ ] Advanced Touch Bar customization
- [ ] Plugin system for third-party extensions
- [ ] Custom themes and appearance options
- [ ] Accessibility enhancements
