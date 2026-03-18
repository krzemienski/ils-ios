# Navigation & Deep Link Routing

**Type:** Architecture Diagram
**Last Updated:** 2026-03-18
**Related Files:**
- `ILSApp/ILSApp/Views/Root/SidebarRootView.swift`
- `ILSApp/ILSApp/Views/Root/SidebarView.swift`
- `ILSApp/ILSApp/ILSAppApp.swift`
- `ILSApp/ILSApp/AppState.swift`

## Purpose

Shows how users navigate ILS via sidebar (20 items in 2 sections), deep links (`ils://`), and programmatic routing — all converging on a single `ActiveScreen` enum with 20 cases.

## Diagram

```mermaid
graph TD
    subgraph "Front-Stage (User Experience)"
        User[User Wants to Navigate] --> Sidebar[Sidebar Sheet ⚡ Swipe from left edge]
        User --> DeepLink[Deep Link ils://route]
        User --> Palette[Command Palette ⚡ Quick jump]

        Sidebar --> NavSection[NAVIGATE Section 🎯 12 items]
        Sidebar --> ConfigSection[CONFIGURE Section 🎯 8 items]

        NavSection --> Pick[Pick Destination]
        ConfigSection --> Pick
        Pick --> Screen[Screen Renders ⚡ Instant transition]
    end

    subgraph "Back-Stage (Implementation)"
        Pick --> ActiveScreen[ActiveScreen Enum 🎯 20 cases]
        DeepLink --> URLHandler[AppState.handleURL 🛡️ Validates route]
        Palette --> ActiveScreen

        URLHandler --> ActiveScreen

        ActiveScreen --> Router{Switch on Case}
        Router -->|.home| Home[HomeView]
        Router -->|.chat| ChatView[ChatView 🎯 Full conversation UI]
        Router -->|.system| SystemView[System Monitor ⚡ Live metrics]
        Router -->|.browser| BrowserView[Browse 🎯 MCP/Skills/Plugins]
        Router -->|.terminal| TerminalView[Terminal 🎯 WebSocket PTY]
        Router -->|.settings| SettingsView[Settings ✅ Backend config]
        Router -->|.themes| ThemeView[Themes 🎯 13 built-in]
        Router -->|.hooks| HooksView[Hooks 📊 23 hooks, 9 types]
        Router -->|.analytics| AnalyticsView[Analytics 📊 22K+ sessions]
        Router -->|12 more| OtherViews[Other Screens]
    end

    URLHandler -->|Invalid route| Fallback[Ignore + Stay on Current 🔄]
    ActiveScreen -->|.chat requires session| SessionLookup[Fetch Session 💾]
    SessionLookup -->|Not found| ErrorState[Show Error 🔄 Navigate to sessions list]

    Screen --> User
```

## Sidebar Structure (Verified via Audit)

**NAVIGATE (12):** Home, System Monitor, Browse, Terminal, All Sessions, Activity Feed, Documentation, Split View, Search, Permissions, Agent Teams, Agent Queue

**CONFIGURE (8):** Usage, Host Profiles, Backends, Hooks, Themes, Settings, Analytics, Workflows

## Deep Links (Verified Working)

| Route | Screen | Status |
|-------|--------|--------|
| `ils://home` | Home | ✅ Works from foreground |
| `ils://settings` | Settings | ✅ Works from foreground |
| `ils://themes` | Themes | ✅ Works from foreground |
| `ils://fleet` | Host Profiles | ✅ Works from foreground |
| `ils://sessions/{uuid}` | ChatView | ✅ UUID must be lowercase |
| `ils://browser` | Browse | ✅ NOT `ils://browse` |
| `ils://system` | System Monitor | ✅ |

## Key Insights

- **Single State Machine**: All navigation converges to `ActiveScreen` enum — no scattered routing logic
- **20 Sidebar Items**: 12 NAVIGATE + 8 CONFIGURE, requiring scroll for items below Agent Queue
- **Deep Links Work in Foreground**: No system confirmation dialog when app is already open
- **Sidebar as Sheet**: SwiftUI `.sheet` triggered by toolbar — swipe-from-left-edge gesture opens it
- **FIXED: Sidebar from ChatView**: Previously blocked by ChatView's keyboard-dismiss DragGesture claiming the edge swipe. Fixed by replacing with `.scrollDismissesKeyboard(.interactively)`

## Change History

- **2026-03-18:** Updated with complete 20-item sidebar structure, NAVIGATE/CONFIGURE sections, verified deep links, and ChatView sidebar bug from full functional audit
- **2026-03-18:** Initial creation
