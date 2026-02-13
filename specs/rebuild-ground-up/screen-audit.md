# ILS iOS App - Complete Screen Audit

**Generated:** 2026-02-07
**Platform:** iOS (SwiftUI)
**Architecture:** MVVM + Tab Navigation
**Backend:** Vapor server on port 9090

---

## Table of Contents

1. [App Architecture](#app-architecture)
2. [Navigation Graph](#navigation-graph)
3. [Screen Inventory](#screen-inventory)
4. [Shared Components](#shared-components)
5. [Data Models](#data-models)
6. [API Endpoints](#api-endpoints)
7. [Theme System](#theme-system)
8. [Future Features](#future-features)

---

## App Architecture

### Entry Point: `ILSAppApp.swift`

**Location:** `<project-root>/ILSApp/ILSApp/ILSAppApp.swift`

**Purpose:** App entry point, global state management, URL scheme handling

**Global State (AppState):**
- `selectedTab: String` - Active tab ("dashboard", "sessions", "projects", "system", "settings")
- `isConnected: Bool` - Backend connection status
- `serverURL: String` - Backend server URL (persisted to UserDefaults)
- `selectedProject: Project?` - Currently selected project
- `lastSessionId: UUID?` - Last active session
- `showOnboarding: Bool` - First-run onboarding visibility
- `apiClient: APIClient` - HTTP client (actor-based with caching)
- `sseClient: SSEClient` - Server-sent events streaming client

**Services:**
- Health check polling (30s when connected, 5s retry when disconnected)
- URL scheme handler (`ils://` - projects, sessions, mcp, skills, settings, system)
- Color scheme preference management (@AppStorage)
- Onboarding presentation logic

**Dependencies:**
- APIClient (actor with 30s cache TTL, 3x retry on transient errors)
- SSEClient (60s connection timeout, 3x reconnect with exponential backoff)

---

### Root Navigation: `ContentView.swift`

**Location:** `<project-root>/ILSApp/ILSApp/ContentView.swift`

**Purpose:** Tab-based navigation container

**Structure:**
```
TabView (5 tabs)
├─ Dashboard (NavigationStack)
├─ Sessions (NavigationStack)
├─ Projects (NavigationStack)
├─ System (NavigationStack)
└─ Settings (NavigationStack)
```

**Features:**
- Connection banner (top overlay when disconnected)
- Tab bar at y=873, h=83 (centers at y=914)
- Tab positions: x=44, 132, 220, 308, 396
- White tint color
- Ultra-thin material background

---

## Navigation Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                         ILSAppApp                                │
│  (Global State: AppState, URL Handler, Onboarding)              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │ ContentView  │ (TabView)
              └──────┬───────┘
                     │
        ┌────────────┼────────────┬────────────┬──────────┐
        │            │            │            │          │
        ▼            ▼            ▼            ▼          ▼
   Dashboard    Sessions     Projects      System    Settings
        │            │            │            │          │
        │            ├─ ChatView  ├─ ProjectDetail  │    ├─ SkillsListView
        │            │    │       │    │            │    ├─ MCPServerListView
        │            │    ├─ MessageView  │         │    ├─ PluginsListView
        │            │    ├─ SessionInfo  │         │    ├─ TunnelSettings
        │            │    └─ CommandPalette│         │    ├─ NotificationPrefs
        │            │                    │         │    ├─ LogViewer
        │            ├─ NewSession        │         │    └─ ConfigEditor
        │            └─ SessionTemplates  │         │
        │                                 │         │
        │                        ProjectSessionsList│
        │                                           │
        │                                  ProcessListView
        │                                  FileBrowserView
        │
        └─ (Opens sheets for Projects, Sessions, Skills, MCP)

First-Run Only:
└─ ServerSetupSheet (modal, non-dismissible until connected)
```

---

## Screen Inventory

### 1. Dashboard Tab

#### **DashboardView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Dashboard/DashboardView.swift`
**ViewModel:** `DashboardViewModel.swift`

**Purpose:** Overview of system stats, recent activity, quick actions

**Data Displayed:**
- **2x2 Stat Cards Grid:**
  - Sessions (total, sparkline)
  - Projects (total, sparkline)
  - Skills (total, sparkline)
  - MCP Servers (total, sparkline)
- **Quick Actions:**
  - New Session button → navigates to sessions tab
  - Total Cost display (formatted USD)
- **Recent Sessions (5 most recent):**
  - Session name
  - Model badge
  - Message count
  - Status indicator (active = blue dot, inactive = gray dot)
  - Relative timestamp
  - Tappable → navigates to ChatView
- **System Health Strip:**
  - Active sessions progress bar
  - MCP health progress bar
  - Enabled plugins progress bar
- **Greeting header** (time-based: morning/afternoon/evening/night)
- **Connection status dot** (green/red with "Online"/"Offline")
- **Last updated timestamp** (relative)

**Interactive Elements:**
- Stat cards are tappable → opens sheet with corresponding list
- Pull-to-refresh
- Recent session rows → NavigationLink to ChatView
- Quick action buttons

**API Endpoints:**
- `GET /api/v1/stats` → StatsResponse (with session/project/skill/mcp counts)
- `GET /api/v1/stats/recent` → RecentSessionsResponse (last 5 sessions)

**Dependencies:**
- DashboardViewModel (synthetic sparkline generation)
- StatCard component
- SparklineChart component
- EmptyEntityState component
- SkeletonRow (loading state)

**Empty/Error States:**
- Loading: skeleton cards + skeleton rows
- Error: ErrorStateView with retry button
- Empty data: EmptyEntityState

**Navigation FROM:**
- ContentView (tab selection)

**Navigation TO:**
- Sessions sheet (tap session stat card)
- Projects sheet (tap projects stat card)
- Skills sheet (tap skills stat card)
- MCP sheet (tap MCP stat card)
- ChatView (tap recent session row)
- Sessions tab (tap "New Session" quick action)

---

### 2. Sessions Tab

#### **SessionsListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Sessions/SessionsListView.swift`
**ViewModel:** `SessionsViewModel.swift`

**Purpose:** List all chat sessions (ILS database + external Claude Code sessions)

**Data Displayed:**
- **Session rows (sorted by lastActiveAt DESC):**
  - Status indicator (Active/Idle with icon + pulsing animation)
  - Session name (or "Claude Code Session" / "Unnamed Session")
  - External badge (terminal icon for Claude Code sessions)
  - Model badge (sonnet/opus/haiku)
  - Project name (if associated)
  - Message count
  - Cost (if available)
  - Relative timestamp
  - External sessions show "Claude Code" badge

**Interactive Elements:**
- Searchable (searches name, project, firstPrompt, model)
- Pull-to-refresh (rescans external sessions)
- FAB (floating action button) → "+" to create new session
- Swipe actions:
  - Leading: Rename (blue)
  - Trailing: Delete (red)
- Context menu:
  - Rename
  - Copy Session ID
  - Delete
- Tap row → NavigationLink to ChatView

**API Endpoints:**
- `GET /api/v1/sessions?limit=50&offset=0` → ListResponse<ChatSession>
- `GET /api/v1/sessions/scan` → SessionScanResponse (external sessions)
- `POST /api/v1/sessions` → APIResponse<ChatSession> (create)
- `DELETE /api/v1/sessions/{id}` → APIResponse<DeletedResponse>
- `PUT /api/v1/sessions/{id}` → APIResponse<ChatSession> (rename)

**Dependencies:**
- SessionsViewModel (dual-mode: ILS + external)
- EntityType.sessions color (#007AFF)
- PulsingBadgeView (active sessions)
- EmptyEntityState
- SkeletonListView

**Empty/Error States:**
- Loading: SkeletonListView overlay
- Error: ErrorStateView with retry
- Empty: EmptyEntityState with "New Chat" action
- Search no results: ContentUnavailableView.search

**Navigation FROM:**
- ContentView (tab selection)
- Dashboard (tap session stat card or recent session)

**Navigation TO:**
- ChatView (tap session row)
- NewSessionView (sheet, tap FAB or empty state action)

---

#### **NewSessionView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Sessions/NewSessionView.swift`

**Purpose:** Create new chat session with advanced configuration

**Data Displayed:**
- **Session Details:**
  - Name (optional text field)
  - Project picker (nil or project list)
- **Model picker (segmented):**
  - Sonnet, Opus, Haiku
- **Permissions picker:**
  - Default, Accept Edits, Plan Mode, Bypass All, Delegate, Don't Ask
  - Description text (explains each mode)
- **System Prompt:**
  - Multi-line TextEditor
  - Placeholder: "Custom instructions for Claude (optional)"
- **Limits:**
  - Max Budget (USD decimal)
  - Max Turns (integer)
- **Advanced (DisclosureGroup):**
  - Fallback Model
  - Include Partial Messages toggle
  - Continue Previous Session toggle

**Interactive Elements:**
- "Start from Template" button → opens SessionTemplatesView
- Model segmented control
- Permission mode picker
- Form text fields
- Cancel button (dismisses)
- Create button (disabled until valid, shows ProgressView when creating)

**API Endpoints:**
- `POST /api/v1/sessions` → APIResponse<ChatSession>

**Dependencies:**
- ProjectsViewModel (loads project list)
- SessionTemplate model

**Navigation FROM:**
- SessionsListView (sheet)

**Navigation TO:**
- SessionTemplatesView (sheet)
- ChatView (auto-navigate after creation via navigateToSession)

---

#### **ChatView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Chat/ChatView.swift`
**ViewModel:** `ChatViewModel.swift`

**Purpose:** Real-time chat interface with Claude, SSE streaming, message history

**Data Displayed:**
- **Status banner (top, conditional):**
  - Connection state (Connecting... / Claude is responding... / Reconnecting)
  - "Taking longer than expected..." (after 5s connecting)
  - Token count + elapsed time (during streaming)
- **Messages scroll view:**
  - MessageView components (user + assistant bubbles)
  - Typing indicator (3 animated dots when streaming + empty message)
  - Auto-scroll to bottom (unless user scrolled up)
  - Jump-to-bottom FAB (36pt chevron, shows when scrolled up + streaming)
- **Input bar (bottom):**
  - Command palette button (left)
  - Multi-line text field (1-5 lines)
  - Send button (blue arrow, or red stop when streaming)
  - Haptic feedback on send
  - Spring animation on send (respects reduce motion)
- **External session banner:**
  - "Read-only Claude Code session" (instead of input bar)
  - Message count display

**Interactive Elements:**
- Toolbar menu (ellipsis):
  - Fork Session (creates copy)
  - Session Info (shows detail sheet)
  - Cost display
  - Model display
  - Project name (external sessions only)
- Message context menus:
  - Copy Markdown
  - Retry (assistant messages)
  - Delete
- Command palette button
- Send/Cancel toggle
- Jump-to-bottom FAB
- Pull-to-refresh (reloads history when not streaming)

**API Endpoints:**
- `GET /api/v1/sessions/{id}/messages` → ListResponse<Message> (ILS sessions)
- `GET /api/v1/sessions/transcript/{encodedPath}/{claudeSessionId}` → ListResponse<Message> (external)
- `POST /api/v1/chat/stream` (SSE) → StreamMessage events
- `POST /api/v1/chat/cancel/{sessionId}` → APIResponse<DeletedResponse>
- `POST /api/v1/sessions/{id}/fork` → APIResponse<ChatSession>

**Dependencies:**
- ChatViewModel (SSE streaming, message batching 75ms interval)
- SSEClient (connection states, reconnect logic)
- MessageView component
- CommandPaletteView (sheet)
- SessionInfoView (sheet)
- TypingIndicatorView
- StreamingStatusView

**Empty/Error States:**
- Loading history: "Loading history..." status banner
- Empty ILS session: Welcome message ("Hello! I'm Claude...")
- Empty external session: "This session transcript contains no readable messages."
- Connection error: Alert with retry option
- Streaming timeout: Error message in chat

**Special Features:**
- **SSE Streaming:** Batched message updates (75ms), token counting, elapsed time tracking
- **Dual-mode message loading:** ILS database vs. JSONL transcripts (external sessions)
- **Auto-scroll management:** Tracks user scroll position, shows FAB when scrolled up
- **Keyboard dismissal:** Drag gesture on scroll view
- **Fork alert:** Shows "Session Forked" alert with "Open Fork" / "Stay Here" options
- **Read-only mode:** External sessions show banner instead of input

**Navigation FROM:**
- SessionsListView (tap session)
- Dashboard (tap recent session)
- Forked session alert ("Open Fork" button)

**Navigation TO:**
- SessionInfoView (sheet, toolbar menu)
- CommandPaletteView (sheet, input bar button)
- Forked ChatView (navigationDestination)

---

#### **SessionInfoView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Sessions/SessionInfoView.swift`

**Purpose:** Display session metadata and export functionality

**Data Displayed:**
- **Session Details:**
  - Name (or "Unnamed")
  - Model (capitalized)
  - Status (capitalized)
  - Message count
- **Cost & Usage:**
  - Total cost (USD, 4 decimals) or "N/A"
- **Timestamps:**
  - Created (formatted date/time)
  - Last Active (formatted date/time)
- **Configuration:**
  - Permission mode
  - Source (ils/external)
  - Project name (if associated)
- **Internal (if available):**
  - Claude Session ID (caption font)

**Interactive Elements:**
- Export button (square.and.arrow.up) → generates markdown, opens share sheet
- Copy ID button (doc.on.doc) → copies session UUID to clipboard, shows toast
- Done button (closes sheet)

**API Endpoints:**
- `GET /api/v1/sessions/{id}` → APIResponse<ChatSession> (refresh session data)
- `GET /api/v1/sessions/{id}/messages?limit=500` → APIResponse<ListResponse<Message>> (for export)

**Dependencies:**
- ShareSheet (UIViewControllerRepresentable for UIActivityViewController)

**Empty/Error States:**
- Loading: ProgressView with "Loading session details..."
- Error: Exclamation icon, error message, Retry button

**Navigation FROM:**
- ChatView (toolbar menu)

**Navigation TO:**
- ShareSheet (iOS system share UI)

---

#### **CommandPaletteView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Chat/CommandPaletteView.swift`

**Purpose:** Quick access to common Claude commands

**Data Displayed:**
- List of predefined commands (button rows)
- Search/filter capability

**Interactive Elements:**
- Command buttons → fills input text and dismisses
- Cancel button

**Navigation FROM:**
- ChatView (input bar button)

**Navigation TO:**
- (Dismisses back to ChatView with command text)

---

#### **SessionTemplatesView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Sessions/SessionTemplatesView.swift`

**Purpose:** Select predefined session configurations

**Data Displayed:**
- List of SessionTemplate items
- Template metadata (model, permissions, prompts, limits)

**Interactive Elements:**
- Template selection → applies to NewSessionView form

**Navigation FROM:**
- NewSessionView ("Start from Template" button)

**Navigation TO:**
- (Dismisses back to NewSessionView with template applied)

---

### 3. Projects Tab

#### **ProjectsListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Projects/ProjectsListView.swift`
**ViewModel:** `ProjectsViewModel.swift`

**Purpose:** List all Claude Code projects discovered from filesystem

**Data Displayed:**
- **Project rows:**
  - Green folder icon (EntityType.projects.color #34C759)
  - Project name
  - Default model badge
  - File path (monospaced, truncated)
  - Description (2 lines max)
  - Session count + relative timestamp

**Interactive Elements:**
- Searchable (name, path, description, model)
- Pull-to-refresh
- Tap row → NavigationLink to ProjectDetailView
- Context menu:
  - Copy Path

**API Endpoints:**
- `GET /api/v1/projects?limit=50&offset=0` → ListResponse<Project>

**Dependencies:**
- ProjectsViewModel
- EntityType.projects

**Empty/Error States:**
- Loading: SkeletonListView overlay
- Error: ErrorStateView with retry
- Empty: EmptyEntityState "No Projects"
- Search no results: ContentUnavailableView.search

**Navigation FROM:**
- ContentView (tab selection)
- Dashboard (tap project stat card)

**Navigation TO:**
- ProjectDetailView (tap row)

---

#### **ProjectDetailView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Projects/ProjectDetailView.swift`

**Purpose:** View/edit project details, access project sessions

**Data Displayed:**
- **Project Info (Form):**
  - Name (editable when editing)
  - Path (read-only, LabeledContent)
  - Default Model (picker when editing, else LabeledContent)
  - Description (editable when editing)
- **Sessions section:**
  - Session count NavigationLink → ProjectSessionsListView
  - "No sessions" if count is 0
- **Details section:**
  - Created timestamp
  - Last Accessed timestamp
  - Encoded path (directory)
- **Delete button** (destructive, when not editing)

**Interactive Elements:**
- Cancel/Done button (toggles edit mode)
- Save button (when editing)
- Edit button (in menu when not editing)
- Copy Path / Copy Name (menu options)
- Pull-to-refresh
- Delete Project button

**API Endpoints:**
- `PUT /api/v1/projects/{id}` → APIResponse<Project> (update)
- `DELETE /api/v1/projects/{id}` → APIResponse<DeletedResponse>

**Dependencies:**
- ProjectsViewModel (passed from parent)

**Navigation FROM:**
- ProjectsListView (tap row)

**Navigation TO:**
- ProjectSessionsListView (tap session count)

---

#### **ProjectSessionsListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Projects/ProjectSessionsListView.swift`

**Purpose:** List all sessions for a specific project

**Data Displayed:**
- Sessions filtered by project ID
- Same row format as SessionsListView

**Interactive Elements:**
- Same as SessionsListView

**API Endpoints:**
- `GET /api/v1/projects/{id}/sessions` → ListResponse<ChatSession>

**Navigation FROM:**
- ProjectDetailView (tap session count)

**Navigation TO:**
- ChatView (tap session)

---

### 4. System Tab

#### **SystemMonitorView**

**File:** `<project-root>/ILSApp/ILSApp/Views/System/SystemMonitorView.swift`
**ViewModel:** `SystemMetricsViewModel.swift`

**Purpose:** Real-time system performance monitoring via WebSocket

**Data Displayed:**
- **CPU Usage Chart:**
  - Line chart with history (Cyan #30B0C7)
  - Current percentage
- **Load Average (3 cards):**
  - 1m, 5m, 15m load values
- **Memory Ring (ProgressRing):**
  - Used / Total GB
  - Percentage progress
- **Disk Ring (ProgressRing):**
  - Used / Total GB (orange gradient)
  - Percentage progress
- **Network Chart (dual-line):**
  - Download (cyan) and Upload (blue) rates
  - Current bytes/s
- **Live indicator:**
  - Green pulsing dot + "Live" (when connected)
  - Red dot + "Offline" (when disconnected)

**Interactive Elements:**
- NavigationLink to ProcessListView
- NavigationLink to FileBrowserView
- Live WebSocket connection (auto-connects onAppear, disconnects onDisappear)

**API Endpoints:**
- WebSocket: `ws://{serverURL}/api/v1/metrics/stream` → SystemMetrics events

**Dependencies:**
- SystemMetricsViewModel
- MetricsWebSocketClient
- MetricChart component
- ProgressRing component
- EntityType.system color

**Empty/Error States:**
- No data: "Waiting for data..." placeholder in charts

**Navigation FROM:**
- ContentView (tab selection)

**Navigation TO:**
- ProcessListView (tap file browser link)
- FileBrowserView (tap file browser link)

---

#### **ProcessListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/System/ProcessListView.swift`

**Purpose:** List running system processes

**Data Displayed:**
- Process list with PID, name, CPU%, memory

**Interactive Elements:**
- Refresh button
- Kill process actions

**API Endpoints:**
- `GET /api/v1/system/processes` → ListResponse<ProcessInfo>

**Navigation FROM:**
- SystemMonitorView

**Navigation TO:**
- (None, detail view)

---

#### **FileBrowserView**

**File:** `<project-root>/ILSApp/ILSApp/Views/System/FileBrowserView.swift`

**Purpose:** Browse filesystem directories and files

**Data Displayed:**
- File/folder list
- File metadata (size, modified date)

**Interactive Elements:**
- Navigate into folders
- File preview
- Breadcrumb navigation

**API Endpoints:**
- `GET /api/v1/filesystem/browse?path={path}` → ListResponse<FileItem>

**Navigation FROM:**
- SystemMonitorView

**Navigation TO:**
- Recursive (subfolder navigation)

---

### 5. Settings Tab

#### **SettingsView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Settings/SettingsView.swift`
**ViewModel:** `SettingsViewModel.swift`

**Purpose:** App configuration, backend connection, Claude Code settings

**Data Displayed:**
- **Backend Connection:**
  - Server URL text field
  - Connection status (dot + Connected/Disconnected)
  - Test Connection button
- **Remote Access:**
  - Cloudflare Tunnel link → TunnelSettingsView
- **Manage (NavigationLinks with counts):**
  - Skills ({count}) → SkillsListView
  - MCP Servers ({count}) → MCPServerListView
  - Plugins ({count}) → PluginsListView
- **General:**
  - Default Model picker (auto-saves)
  - Color Scheme picker (system/light/dark)
  - Auto Updates Channel (read-only)
  - Extended Thinking toggle (read-only)
  - Include Co-Author toggle (read-only)
  - Scope + path footer
- **API Key:**
  - Status (configured/not configured icon)
  - Masked key display
  - Source (environment/file)
  - Footer: "For security, API keys cannot be edited..."
- **Permissions:**
  - Default Mode (read-only)
  - Allowed rules DisclosureGroup
  - Denied rules DisclosureGroup
- **Advanced:**
  - Hooks Configured count
  - Enabled Plugins count
  - Status Line type
  - Environment Vars count
  - Edit User Settings → ConfigEditorView
  - Edit Project Settings → ConfigEditorView
- **Statistics:**
  - Projects, Sessions, Skills, MCP, Plugins counts
- **Diagnostics:**
  - Analytics toggle
  - View Logs → LogViewerView
  - Notifications → NotificationPreferencesView
- **About:**
  - App Version (1.0.0)
  - Build (1)
  - Claude CLI version
  - Backend URL
  - Documentation link (external)

**Interactive Elements:**
- Server URL field (onSubmit saves)
- Test Connection button
- Model picker (auto-saves to backend)
- Color scheme picker (saves to UserDefaults)
- Navigation links to sub-settings
- Pull-to-refresh

**API Endpoints:**
- `GET /health` → HealthResponse (Claude version)
- `GET /api/v1/stats` → StatsResponse
- `GET /api/v1/config?scope=user` → ConfigInfo
- `PUT /api/v1/config` → APIResponse<ConfigInfo> (save model/theme)

**Dependencies:**
- SettingsViewModel
- ConfigEditorViewModel

**Empty/Error States:**
- Loading config: ProgressView + "Loading configuration..."
- No config: "No configuration loaded"

**Navigation FROM:**
- ContentView (tab selection)

**Navigation TO:**
- TunnelSettingsView
- SkillsListView
- MCPServerListView
- PluginsListView
- ConfigEditorView (user/project scopes)
- LogViewerView
- NotificationPreferencesView

---

#### **SkillsListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Skills/SkillsListView.swift`
**ViewModel:** `SkillsViewModel.swift`

**Purpose:** Manage Claude Code skills (from ~/.claude/skills/)

**Data Displayed:**
- **Installed Skills section:**
  - Skill name (/name)
  - Active/inactive toggle (checkmark circle)
  - Description (2 lines)
  - Tags (scrollable chips, max 5 shown)
  - Source + path (caption)
  - Section header: "Installed ({count})"
- **GitHub Search section:**
  - Search field ("Search GitHub skills...")
  - GitHub results (repository, stars, description)
  - Install button per result
  - "Installed" badge when done

**Interactive Elements:**
- Searchable (name, description, tags)
- Pull-to-refresh (rescans ~/.claude/skills/)
- FAB "+" → new skill creation
- Active toggle (tappable icon)
- Swipe to delete
- Context menu:
  - Copy Name
  - Delete
- Tap row → NavigationLink to SkillDetailView
- GitHub search (debounced 300ms)
- Install from GitHub button

**API Endpoints:**
- `GET /api/v1/skills?refresh=true` → ListResponse<Skill>
- `GET /api/v1/skills/{name}` → APIResponse<Skill> (full content)
- `POST /api/v1/skills` → APIResponse<Skill> (create)
- `PUT /api/v1/skills/{name}` → APIResponse<Skill> (update)
- `DELETE /api/v1/skills/{name}` → APIResponse<DeletedResponse>
- `POST /api/v1/skills/{name}/enable` → APIResponse<Skill>
- `POST /api/v1/skills/{name}/disable` → APIResponse<Skill>
- `GET /api/v1/skills/search?q={query}` → ListResponse<GitHubSearchResult>
- `POST /api/v1/skills/install` → APIResponse<Skill> (from GitHub)

**Dependencies:**
- SkillsViewModel (search cache, GitHub integration)
- EntityType.skills color (#AF52DE purple)
- SkillEditorView (sheet for create/edit)
- SkillDetailView

**Empty/Error States:**
- Loading: SkeletonListView overlay
- Error: ErrorStateView with retry
- Empty: EmptyEntityState with "Create Skill" action
- Search no results: ContentUnavailableView.search

**Navigation FROM:**
- SettingsView (Manage section)

**Navigation TO:**
- SkillDetailView (NavigationLink)
- SkillEditorView (sheet, create/edit modes)

---

#### **MCPServerListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/MCP/MCPServerListView.swift`
**ViewModel:** `MCPViewModel.swift`

**Purpose:** Manage MCP (Model Context Protocol) servers

**Data Displayed:**
- **Scope picker (segmented):**
  - User, Project, Local
- **Server rows:**
  - Server name
  - Status badge (Healthy/Unhealthy/Unknown with icons)
  - Command + args (monospaced, truncated)
  - Scope badge
  - Environment variables count badge (if any)
- **Health polling:**
  - Auto-refreshes every 30s
  - Last health check timestamp

**Interactive Elements:**
- Scope picker (triggers reload)
- Searchable (name, command, scope, args)
- Pull-to-refresh
- Menu button:
  - Add Server
  - Import / Export
  - Select Multiple
- Selection mode:
  - Select All / None toggle
  - Delete selected (trash icon, disabled until selection)
  - Done button (exits selection mode)
- Swipe actions:
  - Delete (red)
  - Edit (orange)
- Context menu:
  - Copy Command
  - Edit
  - Delete
- Tap row → NavigationLink to MCPServerDetailView

**API Endpoints:**
- `GET /api/v1/mcp?scope={scope}` → ListResponse<MCPServerItem>
- `POST /api/v1/mcp` → APIResponse<MCPServerItem> (create)
- `PUT /api/v1/mcp/{name}` → APIResponse<MCPServerItem> (update)
- `DELETE /api/v1/mcp/{name}?scope={scope}` → APIResponse<DeletedResponse>

**Dependencies:**
- MCPViewModel (health polling task, batch selection)
- EntityType.mcp color (#FF9500 orange)
- NewMCPServerView (sheet)
- EditMCPServerView (sheet)
- MCPImportExportView (sheet)

**Empty/Error States:**
- Loading: SkeletonListView overlay
- Error: ErrorStateView with retry
- Empty: EmptyEntityState with "Add Server" action
- Search no results: ContentUnavailableView.search

**Special Features:**
- **Health polling:** 30s interval, auto-start/stop on appear/disappear
- **Batch operations:** Multi-select with "Select All"/"None" toggle
- **Scope filtering:** User/Project/Local configurations

**Navigation FROM:**
- SettingsView (Manage section)

**Navigation TO:**
- MCPServerDetailView (NavigationLink)
- NewMCPServerView (sheet)
- EditMCPServerView (sheet)
- MCPImportExportView (sheet)

---

#### **PluginsListView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Plugins/PluginsListView.swift`
**ViewModel:** `PluginsViewModel.swift`

**Purpose:** Manage Claude Code plugins

**Data Displayed:**
- **Plugin rows:**
  - Plugin name
  - Enable/disable toggle (inline)
  - Description
  - Command badges (max 3 shown, +N for overflow)
- **Marketplace (sheet):**
  - Category chips (All, Productivity, DevOps, Testing, etc.)
  - Marketplace sections
  - Plugin rows with Install button
  - "Add from GitHub" section (owner/repo field)

**Interactive Elements:**
- Searchable (name, description)
- Pull-to-refresh
- Marketplace button (bag icon) → opens MarketplaceView sheet
- Enable/disable toggle (per plugin)
- Swipe to uninstall
- Category filter chips (marketplace)
- Install button (marketplace)
- Add from GitHub (marketplace)

**API Endpoints:**
- `GET /api/v1/plugins` → ListResponse<PluginItem>
- `POST /api/v1/plugins/install` → APIResponse<PluginItem>
- `DELETE /api/v1/plugins/{name}` → APIResponse<DeletedResponse>
- `POST /api/v1/plugins/{name}/enable` → APIResponse<EnabledResponse>
- `POST /api/v1/plugins/{name}/disable` → APIResponse<EnabledResponse>
- `GET /api/v1/plugins/marketplace` → APIResponse<[MarketplaceInfo]>
- `POST /api/v1/marketplaces` → APIResponse<MarketplaceInfo> (add GitHub repo)

**Dependencies:**
- PluginsViewModel
- EntityType.plugins color (#FFD60A yellow)
- MarketplaceView (sheet)

**Empty/Error States:**
- Loading: SkeletonListView overlay
- Error: ErrorStateView with retry
- Empty: EmptyEntityState with "Browse Marketplace" action
- Search no results: ContentUnavailableView.search

**Special Features:**
- **Marketplace integration:** Category filtering, GitHub repo addition
- **Real-time enable/disable:** Optimistic UI updates
- **Installing states:** Per-plugin progress indicator

**Navigation FROM:**
- SettingsView (Manage section)

**Navigation TO:**
- MarketplaceView (sheet)

---

#### **TunnelSettingsView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift`

**Purpose:** Configure Cloudflare Tunnel for remote access

**Data Displayed:**
- Tunnel configuration fields
- Status indicators
- Connection instructions

**Interactive Elements:**
- Configuration form
- Start/Stop tunnel buttons
- Copy tunnel URL

**API Endpoints:**
- `GET /api/v1/tunnel/status` → TunnelStatus
- `POST /api/v1/tunnel/start` → APIResponse<TunnelInfo>
- `POST /api/v1/tunnel/stop` → APIResponse<DeletedResponse>

**Navigation FROM:**
- SettingsView (Remote Access section)

**Navigation TO:**
- (None, settings detail)

---

#### **LogViewerView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Settings/LogViewerView.swift`

**Purpose:** View application logs for debugging

**Data Displayed:**
- Log entries (timestamp, category, level, message)
- Filter by category/level

**Interactive Elements:**
- Category filter
- Level filter
- Clear logs button
- Export logs button

**Dependencies:**
- AppLogger.shared

**Navigation FROM:**
- SettingsView (Diagnostics section)

**Navigation TO:**
- (None, log viewer)

---

#### **NotificationPreferencesView**

**File:** `<project-root>/ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift`

**Purpose:** Configure notification preferences

**Data Displayed:**
- Notification toggles
- Sound preferences
- Badge preferences

**Interactive Elements:**
- Toggle switches
- Pickers

**Navigation FROM:**
- SettingsView (Diagnostics section)

**Navigation TO:**
- (None, preferences detail)

---

#### **ConfigEditorView** (sub-view of SettingsView)

**File:** `<project-root>/ILSApp/ILSApp/Views/Settings/SettingsView.swift` (embedded)
**ViewModel:** `ConfigEditorViewModel.swift`

**Purpose:** Raw JSON editor for Claude Code configuration

**Data Displayed:**
- TextEditor with JSON configuration
- JSON validation indicator (checkmark/xmark)
- Validation errors (if any)

**Interactive Elements:**
- TextEditor (code font)
- Save button (disabled when invalid JSON or no changes)
- Cancel button
- Unsaved changes alert (on dismiss)

**API Endpoints:**
- `GET /api/v1/config?scope={scope}` → ConfigInfo
- `PUT /api/v1/config` → APIResponse<ConfigInfo>

**Dependencies:**
- ConfigEditorViewModel

**Special Features:**
- **JSON validation:** Real-time syntax checking
- **Unsaved changes protection:** Alert on dismiss, interactiveDismissDisabled
- **Scope-specific:** User vs. Project configurations

**Navigation FROM:**
- SettingsView (Advanced section)

**Navigation TO:**
- (None, editor detail)

---

### 6. Onboarding (First-Run)

#### **ServerSetupSheet**

**File:** `<project-root>/ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift`

**Purpose:** First-run backend connection setup

**Data Displayed:**
- **Branding header:**
  - Server rack icon (gradient)
  - "Welcome to ILS"
  - Subtitle
- **Connection mode picker (segmented):**
  - Local (desktopcomputer icon)
  - Remote (network icon)
  - Tunnel (globe icon)
- **Mode-specific forms:**
  - Local: Server URL field (http://localhost:9090)
  - Remote: Hostname + Port fields
  - Tunnel: Cloudflare URL field (validation for trycloudflare.com or https://)
- **Connection steps (during connection):**
  - DNS Resolve (network icon)
  - TCP Connect (cable.connector icon)
  - Health Check (heart.fill icon)
  - Status: pending/inProgress/success/failure
- **Result states:**
  - Success banner (checkmark.circle.fill, green)
  - Failure banner (xmark.circle.fill, red)
  - Backend info card (Claude version, status)
- **Recent connections:**
  - History list (last 5)
  - Tappable to fill form

**Interactive Elements:**
- Mode picker
- URL/hostname/port fields
- Connect button (disabled until valid)
- Recent connection rows (fill form on tap)
- Auto-dismisses after 1.5s on success

**API Endpoints:**
- `GET /health` → String (simple check)
- `GET /health` → HealthResponse (structured with Claude version)

**Dependencies:**
- ConnectionStepsView component
- UserDefaults ("connectionHistory", "hasConnectedBefore")

**Special Features:**
- **Non-dismissible:** interactiveDismissDisabled(true) until first successful connection
- **Connection animation:** 3-step progress with icons and status
- **Validation:** URL format, trycloudflare.com detection
- **History persistence:** Last 5 connections, move to top on reuse
- **Auto-navigation:** Dismisses automatically after successful connection

**Navigation FROM:**
- ILSAppApp (sheet, when `showOnboarding == true`)

**Navigation TO:**
- (Dismisses to ContentView after connection)

---

## Shared Components

### Theme Components

**Location:** `<project-root>/ILSApp/ILSApp/Theme/Components/`

#### **StatCard**
- **Purpose:** Dashboard stat display with sparkline
- **Props:** title, count, entityType, sparklineData
- **Features:** Entity color border, gradient shadow, tap gesture support

#### **SparklineChart**
- **Purpose:** Mini line chart for stat cards
- **Props:** data (array of doubles), color
- **Features:** SwiftUI Charts integration, smooth curves

#### **ProgressRing**
- **Purpose:** Circular progress indicator
- **Props:** progress (0-1), gradient, title, subtitle
- **Features:** Animated progress, entity color gradients

#### **MetricChart**
- **Purpose:** Full-width line chart for system metrics
- **Props:** title, data, color, unit, currentValue
- **Features:** Time-series x-axis, auto-scaling y-axis

#### **CodeBlockView**
- **Purpose:** Syntax-highlighted code display
- **Props:** code, language
- **Features:** ILSCodeHighlighter integration, scroll view, copy button

#### **ToolCallAccordion**
- **Purpose:** Collapsible tool call/result display
- **Props:** toolName, input, inputPairs, output, isError, expandAll binding
- **Features:** Auto-expand on error, expand all control, JSON pretty-print

#### **ThinkingSection**
- **Purpose:** Claude's thinking process display
- **Props:** thinking (text), isActive (bool)
- **Features:** Brain icon, pulsing animation when active, collapsible

#### **EmptyEntityState**
- **Purpose:** Contextual empty state
- **Props:** entityType, title, description, actionTitle, action
- **Features:** Entity color icon, ContentUnavailableView API

#### **SkeletonRow**
- **Purpose:** Loading placeholder row
- **Features:** Shimmer animation, entity color accent

#### **ConnectionBanner**
- **Purpose:** Top banner for connection status
- **Props:** isConnected (bool)
- **Features:** "Configure" vs "Retry" based on first-run status

#### **ConnectionSteps**
- **Purpose:** Multi-step connection progress
- **Props:** steps (array of ConnectionStep)
- **Features:** Icon, status color, progress animation

#### **ShimmerModifier**
- **Purpose:** Shimmer loading effect
- **Features:** Reduce motion support, gradient animation

---

### Message Components

**Location:** `<project-root>/ILSApp/ILSApp/Views/Chat/`

#### **MessageView**
- **Purpose:** Chat message bubble (user/assistant)
- **Props:** message, onRetry, onDelete
- **Features:**
  - User bubbles: Blue gradient (#007AFF → #0056B3), rounded with 4pt bottom-right
  - Assistant bubbles: Dark gray (#111827), white border 6%, rounded with 4pt bottom-left
  - Markdown rendering (MarkdownTextView)
  - Tool calls (ToolCallAccordion array)
  - Tool results (ToolCallAccordion array)
  - Thinking section (ThinkingSection)
  - Context menu (Copy, Retry, Delete)
  - Expand All / Collapse All for tool calls
  - Timestamp + cost metadata
  - Historical message border indicator

#### **MarkdownTextView**
- **Purpose:** Render markdown content
- **Props:** text
- **Features:** Links, code blocks, lists, bold/italic

---

## Data Models

### Core Models (ILSShared)

**Location:** `<project-root>/Sources/ILSShared/Models/`

#### **ChatSession**
- `id: UUID` - Unique identifier
- `claudeSessionId: String?` - Claude Code session ID
- `name: String?` - User-provided name
- `projectId: UUID?` - Associated project
- `projectName: String?` - Project display name
- `model: String` - Claude model (sonnet/opus/haiku)
- `permissionMode: PermissionMode` - Permission settings
- `status: SessionStatus` - active/completed/cancelled/error
- `messageCount: Int` - Message count
- `totalCostUSD: Double?` - Total cost
- `source: SessionSource` - ils/external
- `forkedFrom: UUID?` - Parent session ID
- `createdAt: Date` - Creation timestamp
- `lastActiveAt: Date` - Last activity timestamp
- `encodedProjectPath: String?` - URL-encoded path (external sessions)
- `firstPrompt: String?` - First user message (external sessions)

#### **Project**
- `id: UUID`
- `name: String`
- `path: String` - Filesystem path
- `defaultModel: String`
- `description: String?`
- `createdAt: Date`
- `lastAccessedAt: Date`
- `sessionCount: Int?`
- `encodedPath: String?` - URL-encoded directory name

#### **Skill**
- `id: UUID`
- `name: String` - Skill command name
- `description: String?`
- `content: String?` - Skill implementation
- `tags: [String]`
- `source: SkillSource` - user/system/github
- `path: String` - Filesystem path
- `version: String?`
- `isActive: Bool`

#### **MCPServerItem**
- `id: UUID`
- `name: String`
- `command: String`
- `args: [String]`
- `env: [String: String]?`
- `scope: String` - user/project/local
- `status: String` - healthy/unhealthy/unknown
- `configPath: String?`

#### **PluginItem**
- `id: UUID`
- `name: String`
- `description: String?`
- `marketplace: String?`
- `isInstalled: Bool`
- `isEnabled: Bool`
- `version: String?`
- `commands: [String]?`
- `agents: [String]?`

#### **Message**
- `id: UUID`
- `sessionId: UUID`
- `role: MessageRole` - user/assistant/system
- `content: String`
- `toolCalls: String?` - JSON encoded tool use blocks
- `toolResults: String?` - JSON encoded tool result blocks
- `thinking: String?` - Claude's thinking process
- `costUSD: Double?`
- `createdAt: Date`

### View Models (ChatMessage)

**Location:** `<project-root>/ILSApp/ILSApp/Models/ChatMessage.swift`

#### **ChatMessage**
- `id: UUID`
- `isUser: Bool`
- `text: String`
- `toolCalls: [ToolCallDisplay]`
- `toolResults: [ToolResultDisplay]`
- `thinking: String?`
- `cost: Double?`
- `timestamp: Date?`
- `isFromHistory: Bool` - Distinguishes loaded vs. streamed

#### **ToolCallDisplay**
- `id: String`
- `name: String` - Tool name (Read, Grep, Edit, etc.)
- `inputPreview: String?` - Summary line
- `inputPairs: [(String, String)]?` - Key-value pairs

#### **ToolResultDisplay**
- `toolUseId: String`
- `content: String`
- `isError: Bool`

---

## API Endpoints

### Base URL
All endpoints prefixed with `/api/v1` unless noted.

### Sessions
- `GET /sessions?limit={n}&offset={m}` → ListResponse<ChatSession>
- `GET /sessions/scan` → SessionScanResponse (external Claude Code sessions)
- `GET /sessions/{id}` → APIResponse<ChatSession>
- `GET /sessions/{id}/messages` → ListResponse<Message>
- `GET /sessions/transcript/{encodedPath}/{claudeSessionId}` → ListResponse<Message>
- `POST /sessions` → APIResponse<ChatSession>
- `PUT /sessions/{id}` → APIResponse<ChatSession> (rename)
- `DELETE /sessions/{id}` → APIResponse<DeletedResponse>
- `POST /sessions/{id}/fork` → APIResponse<ChatSession>

### Chat
- `POST /chat/stream` (SSE) → StreamMessage events
- `POST /chat/cancel/{sessionId}` → APIResponse<DeletedResponse>

### Projects
- `GET /projects?limit={n}&offset={m}` → ListResponse<Project>
- `GET /projects/{id}` → APIResponse<Project>
- `GET /projects/{id}/sessions` → ListResponse<ChatSession>
- `POST /projects` → APIResponse<Project>
- `PUT /projects/{id}` → APIResponse<Project>
- `DELETE /projects/{id}` → APIResponse<DeletedResponse>

### Skills
- `GET /skills` → ListResponse<Skill>
- `GET /skills?refresh=true` → ListResponse<Skill> (rescan filesystem)
- `GET /skills/{name}` → APIResponse<Skill> (full content)
- `POST /skills` → APIResponse<Skill>
- `PUT /skills/{name}` → APIResponse<Skill>
- `DELETE /skills/{name}` → APIResponse<DeletedResponse>
- `POST /skills/{name}/enable` → APIResponse<Skill>
- `POST /skills/{name}/disable` → APIResponse<Skill>
- `GET /skills/search?q={query}` → ListResponse<GitHubSearchResult>
- `POST /skills/install` → APIResponse<Skill> (from GitHub)

### MCP
- `GET /mcp` → ListResponse<MCPServerItem>
- `GET /mcp?scope={scope}` → ListResponse<MCPServerItem>
- `GET /mcp?refresh=true` → ListResponse<MCPServerItem>
- `POST /mcp` → APIResponse<MCPServerItem>
- `PUT /mcp/{name}` → APIResponse<MCPServerItem>
- `DELETE /mcp/{name}?scope={scope}` → APIResponse<DeletedResponse>

### Plugins
- `GET /plugins` → ListResponse<PluginItem>
- `POST /plugins/install` → APIResponse<PluginItem>
- `DELETE /plugins/{name}` → APIResponse<DeletedResponse>
- `POST /plugins/{name}/enable` → APIResponse<EnabledResponse>
- `POST /plugins/{name}/disable` → APIResponse<EnabledResponse>
- `GET /plugins/marketplace` → APIResponse<[MarketplaceInfo]>
- `POST /marketplaces` → APIResponse<MarketplaceInfo>

### Configuration
- `GET /config?scope={scope}` → ConfigInfo (user/project/local)
- `PUT /config` → APIResponse<ConfigInfo>

### Statistics
- `GET /stats` → StatsResponse
- `GET /stats/recent` → RecentSessionsResponse

### System
- `GET /system/processes` → ListResponse<ProcessInfo>
- `GET /filesystem/browse?path={path}` → ListResponse<FileItem>
- `WebSocket /metrics/stream` → SystemMetrics events

### Tunnel
- `GET /tunnel/status` → TunnelStatus
- `POST /tunnel/start` → APIResponse<TunnelInfo>
- `POST /tunnel/stop` → APIResponse<DeletedResponse>

### Health
- `GET /health` → String ("OK") or HealthResponse

---

## Theme System

### Color Palette (ILSTheme)

**Location:** `<project-root>/ILSApp/ILSApp/Theme/ILSTheme.swift`

#### Background Scale
- `bg0: #000000` - Pure black
- `bg1: #0A0E1A` - Very dark blue-gray
- `bg2: #111827` - Dark slate
- `bg3: #1E293B` - Slate
- `bg4: #334155` - Medium slate

#### Text Scale
- `textPrimary: #F1F5F9` - Almost white
- `textSecondary: #94A3B8` - Light gray
- `textTertiary: #64748B` - Medium gray

#### Accent Colors
- `accent: #FF6B35` - Hot orange (primary CTA)
- `accentSecondary: #FF8C5A` - Light orange
- `accentTertiary: #FF4500` - Red-orange

#### Status Colors
- `success: #4CAF50` - Green
- `warning: #FFA726` - Orange
- `error: #EF5350` - Red
- `info: #007AFF` - Blue

#### Entity Colors (EntityType)
- `sessions: #007AFF` - Blue
- `projects: #34C759` - Green
- `skills: #AF52DE` - Purple
- `mcp: #FF9500` - Orange
- `plugins: #FFD60A` - Yellow
- `system: #30B0C7` - Cyan

#### Spacing
- `space2XS: 2pt`
- `spaceXS: 4pt`
- `spaceS: 8pt`
- `spaceM: 12pt`
- `spaceL: 16pt`
- `spaceXL: 20pt`
- `space2XL: 24pt`
- `space3XL: 32pt`

#### Corner Radius
- `radiusXS: 6pt`
- `radiusS: 10pt`
- `radiusM: 14pt`
- `radiusL: 20pt`
- `radiusXL: 28pt`

#### Typography
- `titleFont: .title .bold`
- `headlineFont: .headline .semibold`
- `bodyFont: .body`
- `captionFont: .caption`
- `codeFont: .body .monospaced`
- `fabIconFont: 36pt` - Jump-to-bottom FAB

### View Modifiers
- `CardStyle` - Background bg2, border, shadow
- `DarkListStyle` - Hidden scroll background, bg0
- `PrimaryButtonStyle` - Orange accent, white text
- `SecondaryButtonStyle` - Gray bg, orange text
- `LoadingOverlay` - Semi-transparent overlay with spinner
- `ToastModifier` - Bottom toast (info/success/warning/error variants)

---

## Future Features

### From `specs/ils-complete-rebuild/`

**Not yet implemented:**

1. **Agent Teams (specs/agent-teams/):**
   - Teammate management UI
   - Real-time collaboration indicators
   - Team chat integration
   - Shared task lists
   - Agent status monitoring

2. **Enhanced Dashboard:**
   - Cost tracking charts (timeline view)
   - Project activity timeline
   - Session analytics
   - Model usage statistics

3. **Advanced Search:**
   - Cross-entity search
   - Semantic search integration
   - Filter by date ranges
   - Sort by various metrics

4. **Export/Import:**
   - Session export (markdown/JSON)
   - Skill backup/restore
   - Configuration sync
   - Project templates

5. **Notifications:**
   - Session completion alerts
   - Error notifications
   - Cost threshold warnings
   - Agent status updates

6. **Offline Mode:**
   - Local caching
   - Offline session viewing
   - Sync on reconnect

### From `specs/app-enhancements/`

**Planned enhancements:**

1. **Chat Improvements:**
   - Voice input
   - Image attachments
   - File uploads
   - Code execution preview

2. **Project Features:**
   - Git integration
   - Branch management
   - Commit history view
   - Diff visualization

3. **Skills Marketplace:**
   - Ratings and reviews
   - Categories and tags
   - Version management
   - Auto-updates

4. **System Monitoring:**
   - Process management (kill/restart)
   - Resource alerts
   - Log streaming
   - Performance profiling

5. **Settings:**
   - Keyboard shortcuts
   - Custom themes
   - Accessibility options
   - Data export tools

---

## Summary Statistics

### Screens Count
- **Primary Tabs:** 5 (Dashboard, Sessions, Projects, System, Settings)
- **List Views:** 6 (Sessions, Projects, Skills, MCP, Plugins, Processes)
- **Detail Views:** 6 (Chat, Session Info, Project Detail, Skill Detail, MCP Detail, File Browser)
- **Creation Forms:** 4 (New Session, New Skill, New MCP, Edit Config)
- **Settings Views:** 5 (Main, Tunnel, Logs, Notifications, Config Editor)
- **Onboarding:** 1 (Server Setup)
- **Sheets/Modals:** 8 (Command Palette, Session Templates, Marketplace, Import/Export, etc.)

**Total:** ~35 distinct screens/views

### Data Models
- **Core Entities:** 6 (ChatSession, Project, Skill, MCPServer, Plugin, Message)
- **Configuration:** 3 (ClaudeConfig, PermissionsConfig, ThemeConfig)
- **System:** 4 (ProcessInfo, FileItem, SystemMetrics, TunnelInfo)
- **View Models:** 8 (Dashboard, Sessions, Projects, Skills, MCP, Plugins, Chat, SystemMetrics)

**Total:** ~21 model types

### API Endpoints
- **Sessions:** 8 endpoints
- **Chat:** 2 endpoints
- **Projects:** 6 endpoints
- **Skills:** 8 endpoints
- **MCP:** 6 endpoints
- **Plugins:** 6 endpoints
- **Config:** 2 endpoints
- **Stats:** 2 endpoints
- **System:** 2 endpoints + 1 WebSocket
- **Tunnel:** 3 endpoints
- **Health:** 1 endpoint

**Total:** ~47 endpoints (46 HTTP + 1 WebSocket)

### Components
- **Theme Components:** 12 (StatCard, SparklineChart, ProgressRing, etc.)
- **Message Components:** 6 (MessageView, ToolCallAccordion, ThinkingSection, etc.)
- **Utility Components:** 8 (EmptyEntityState, ErrorStateView, SkeletonRow, etc.)

**Total:** ~26 reusable components

---

## Navigation Patterns

### Tab-Based Root
- 5 primary tabs with independent NavigationStacks
- Tab bar persistence across navigation
- Deep linking via `ils://` URL scheme

### Stack Navigation
- Each tab uses NavigationStack for hierarchical navigation
- NavigationLink for push navigation
- `.sheet()` for modal presentation
- `.navigationDestination()` for programmatic navigation

### State Management
- AppState (@EnvironmentObject) - Global app state
- ViewModels (@StateObject) - Per-screen business logic
- @Published properties for reactive UI updates
- Combine publishers for async data streams

### Data Flow
```
Backend (Vapor)
    ↓ HTTP/SSE
APIClient/SSEClient (actor-based)
    ↓ async/await
ViewModel (@MainActor)
    ↓ @Published
View (SwiftUI)
```

---

**End of Audit**
