---
spec: rebuild-ground-up
phase: design
created: 2026-02-07T17:00:00Z
---

# Design Specification: ILS iOS Complete Rebuild

## 1. Design Philosophy

**Direction:** Ghost Protocol (user-selected) — Ultra-minimal stealth cyber with professional polish.

**Core Principles:**
- Surgical precision: Every pixel intentional, zero visual noise
- Context-shifting accents: Color changes per entity type, not per-screen
- Glassmorphism depth: Layered translucent cards for spatial hierarchy
- Information-first: Data readable at a glance, chrome minimized
- Swappable design system: 12 themes that change aesthetics, not functionality

**Typography:** SF Mono (data/code/labels) + SF Pro (body/headings) — system fonts, zero custom font loading.

**Chat Style:** AI Assistant Cards — responses in styled cards, not chat bubbles. Better for rich content (code blocks, tool calls, thinking sections).

**Animation Density:** Subtle everywhere — 0.25s ease-out transitions, glass blur on appear, accent color morphing between contexts. No particles, no glow pulses.

---

## 2. Information Architecture

### Design Rationale

Based on competitive analysis of 9 AI coding apps (ChatGPT, Claude, Cursor, Windsurf, GitHub Copilot, Replit, Perplexity, v0, Bolt.new):

- **No competitor has a separate Projects screen on mobile** — Projects are folders (ChatGPT), desktop-only (Claude), or implicit (Replit)
- **Sessions ARE the primary unit** — users want flat, fast access to conversations
- **Projects are organizational metadata**, not navigation structure
- **Sidebar-first navigation** was user-selected and matches the Stitch-generated design

### Screen Hierarchy

```
ROOT (SidebarRootView)
├── SIDEBAR (overlay on iPhone, persistent on iPad)
│   ├── Server Connection Status + Name
│   ├── Search Sessions
│   ├── SESSION LIST (grouped by project directory)
│   │   ├── Group: "ils-ios"
│   │   │   ├── Architecture Review (2h ago)
│   │   │   └── Bug Fix Sprint (6h ago)
│   │   ├── Group: "backend-api"
│   │   │   └── API Design (1d ago)
│   │   └── Group: "External Sessions"
│   │       └── Claude Desktop (3d ago)
│   ├── System Health (compact)
│   └── + New Session (CTA button)
│
├── MAIN CONTENT AREA
│   ├── Home Dashboard (default when no session selected)
│   ├── Chat View (when session selected)
│   ├── System Monitor (from sidebar or home)
│   ├── Settings (from sidebar gear icon)
│   ├── MCP/Skills/Plugins Browser (from sidebar or home)
│   └── New Session Sheet (modal)
│
└── iPad: Sidebar (30-40% width, always visible) + Content (60-70%)
    iPhone: Sidebar as overlay sheet, swipe from left edge to reveal
```

### Navigation Flows

**Primary flow (80% of usage):**
1. Open app → See sidebar with recent sessions
2. Tap session → Chat view opens
3. Send message → See response with tool calls
4. Swipe left edge / tap hamburger → Return to sidebar

**New session flow:**
1. Tap "+ New Session" in sidebar
2. Sheet presents: project directory picker, optional name, model selection
3. Confirm → Auto-navigate to new chat view

**System/Settings flow:**
1. Tap System Health in sidebar → Full system monitor
2. Tap gear icon in sidebar → Settings view
3. Back via navigation stack or swipe

---

## 3. Design System: AppTheme Protocol

### Token Architecture

```swift
protocol AppTheme {
    var name: String { get }
    var id: String { get }

    // Backgrounds
    var bgPrimary: Color { get }       // Main background
    var bgSecondary: Color { get }     // Card/surface background
    var bgTertiary: Color { get }      // Elevated surfaces
    var bgSidebar: Color { get }       // Sidebar background

    // Accent
    var accent: Color { get }          // Primary accent (buttons, links, highlights)
    var accentSecondary: Color { get } // Secondary accent (less emphasis)
    var accentGradient: LinearGradient { get } // Gradient variant

    // Text
    var textPrimary: Color { get }     // Main text
    var textSecondary: Color { get }   // Muted/secondary text
    var textTertiary: Color { get }    // Placeholder/hint text
    var textOnAccent: Color { get }    // Text on accent-colored backgrounds

    // Semantic
    var success: Color { get }         // Success states
    var warning: Color { get }         // Warning states
    var error: Color { get }           // Error states
    var info: Color { get }            // Informational

    // Borders & Dividers
    var border: Color { get }          // Default border
    var borderSubtle: Color { get }    // Very subtle borders
    var divider: Color { get }         // Section dividers

    // Entity Colors (consistent across themes)
    var entitySession: Color { get }
    var entityProject: Color { get }
    var entitySkill: Color { get }
    var entityMCP: Color { get }
    var entityPlugin: Color { get }
    var entitySystem: Color { get }

    // Glass
    var glassBackground: Color { get } // White/black at 5-8% opacity
    var glassBorder: Color { get }     // White/black at 10-15% opacity

    // Geometry
    var cornerRadius: CGFloat { get }       // Cards: 12-16pt
    var cornerRadiusSmall: CGFloat { get }  // Buttons/badges: 8pt
    var cornerRadiusLarge: CGFloat { get }  // Sheets/modals: 20pt

    // Spacing
    var spacingXS: CGFloat { get }     // 4pt
    var spacingSM: CGFloat { get }     // 8pt
    var spacingMD: CGFloat { get }     // 16pt
    var spacingLG: CGFloat { get }     // 24pt
    var spacingXL: CGFloat { get }     // 32pt

    // Typography sizes
    var fontCaption: CGFloat { get }   // 11pt
    var fontBody: CGFloat { get }      // 15pt
    var fontTitle3: CGFloat { get }    // 18pt
    var fontTitle2: CGFloat { get }    // 22pt
    var fontTitle1: CGFloat { get }    // 28pt
}
```

### 12 Theme Definitions

#### Dark Themes (10)

| # | Name | ID | Accent | BgPrimary | Vibe |
|---|------|----|--------|-----------|------|
| 1 | **Obsidian** | `obsidian` | `#FF6933` (Orange) | `#0A0A0F` | Default. Professional dark with warm orange pop |
| 2 | **Slate** | `slate` | `#3B82F6` (Blue) | `#0F1117` | Cool, corporate, trustworthy |
| 3 | **Midnight** | `midnight` | `#10B981` (Emerald) | `#0A0F0D` | Calm, focused, nature-tech hybrid |
| 4 | **Ghost Protocol** | `ghost` | `#7DF9FF` (Ice Blue) | `#08080C` | Stealth cyber, context-shifting accent |
| 5 | **Neon Noir** | `neon-noir` | `#00D4FF` (Cyan) | `#0A0A0F` | Bloomberg meets Blade Runner |
| 6 | **Electric Grid** | `electric` | `#00FF88` (Matrix) | `#050510` | HUD military, monospace heavy |
| 7 | **Ember** | `ember` | `#F59E0B` (Amber) | `#0F0D0A` | Warm, cozy, golden hour |
| 8 | **Crimson** | `crimson` | `#EF4444` (Red) | `#0F0A0A` | Bold, urgent, high-energy |
| 9 | **Carbon** | `carbon` | `#8B5CF6` (Violet) | `#0D0A12` | Creative, playful, synthetic |
| 10 | **Graphite** | `graphite` | `#14B8A6` (Teal) | `#0A0F0F` | Clean, modern, balanced |

#### Light Themes (2)

| # | Name | ID | Accent | BgPrimary | Vibe |
|---|------|----|--------|-----------|------|
| 11 | **Paper** | `paper` | `#EA580C` (Orange) | `#FAFAF9` | Clean light with warm accent |
| 12 | **Snow** | `snow` | `#2563EB` (Blue) | `#FAFBFF` | Cool light, crisp, professional |

### Default Theme: Obsidian

```
Obsidian Theme Token Values:
─────────────────────────────
bgPrimary:      #0A0A0F (near-black with subtle blue)
bgSecondary:    #12121A (slightly lighter)
bgTertiary:     #1C1C28 (elevated surface)
bgSidebar:      #08080C (darkest — sidebar recedes)

accent:         #FF6933 (hot orange)
accentSecondary:#FF8C5C (lighter orange)
accentGradient: #FF6933 → #FF8C5C (subtle)

textPrimary:    #E8ECF0 (cool white — NOT pure white)
textSecondary:  #8892A0 (muted blue-gray)
textTertiary:   #505868 (dim)
textOnAccent:   #FFFFFF (white on orange bg)

success:        #22C55E
warning:        #EAB308
error:          #EF4444
info:           #3B82F6

border:         #1E2230 (subtle)
borderSubtle:   #141820 (barely visible)
divider:        #1A1E28

entitySession:  #3B82F6 (blue)
entityProject:  #8B5CF6 (violet)
entitySkill:    #F59E0B (amber)
entityMCP:      #10B981 (emerald)
entityPlugin:   #EC4899 (pink)
entitySystem:   #06B6D4 (cyan)

glassBackground: #FFFFFF opacity 0.05
glassBorder:     #FFFFFF opacity 0.10

cornerRadius:      12
cornerRadiusSmall: 8
cornerRadiusLarge: 20

spacingXS: 4, spacingSM: 8, spacingMD: 16, spacingLG: 24, spacingXL: 32
fontCaption: 11, fontBody: 15, fontTitle3: 18, fontTitle2: 22, fontTitle1: 28
```

---

## 4. Screen Inventory

### 4.1 Sidebar

**Purpose:** Primary navigation hub. Shows connection status, session list, and quick actions.

**Data Displayed:**
- Server connection status (connected/disconnected/connecting) + server name
- Session list grouped by project directory
  - Session name
  - Time since last activity ("2h", "1d", "3d")
  - Active indicator (colored dot if streaming)
  - Project directory group header with collapse/expand
- System health indicator (compact: green/yellow/red dot + "System Healthy")
- Settings gear icon
- "+ New Session" CTA button

**iPhone Behavior:** Overlay from left edge (280pt wide). Dismiss by tap outside or swipe left. Trigger via hamburger icon in navigation bar or swipe from left screen edge.

**iPad Behavior:** Persistent left panel (320pt wide). Always visible. No overlay/dismiss behavior.

**Interactions:**
- Tap session → Navigate to chat view
- Long-press session → Context menu (Rename, Export, Delete)
- Tap "+ New Session" → New session sheet
- Tap System Health → Navigate to System Monitor
- Tap gear → Navigate to Settings
- Search bar → Filter sessions by name/project
- Pull to refresh → Reload session list

### 4.2 Home Dashboard

**Purpose:** Landing screen when no session is selected. Glanceable overview of system state and quick actions.

**Data Displayed:**
- Welcome message with server name
- Recent sessions (last 3-5, tappable to resume)
- System health summary card (CPU %, Memory %, Disk %)
- Quick actions grid:
  - New Session
  - Browse Skills (count)
  - MCP Servers (count)
  - Plugins (count)
- Connection status banner (if disconnected)

**Interactions:**
- Tap recent session → Navigate to chat
- Tap quick action → Navigate to respective view
- Tap system health card → Navigate to System Monitor

### 4.3 Chat View

**Purpose:** Core feature. Send messages to AI, see responses with tool calls, code, and thinking.

**Layout:**
```
┌─────────────────────────────┐
│ ≡  Session Name    ℹ️  ···  │  ← Navigation bar
├─────────────────────────────┤
│                             │
│  [User Message Card]        │
│                             │
│  [Assistant Response Card]  │
│   ├─ Text content           │
│   ├─ [Code Block]           │
│   ├─ [Tool Calls Accordion] │
│   └─ [Thinking Section]     │
│                             │
│  [Streaming Indicator]      │  ← When AI is responding
│                             │
├─────────────────────────────┤
│ [Input field]        [Send] │
│ [Attachments] [Commands]    │  ← Optional action row
└─────────────────────────────┘
```

**Message Content Types:**

| Type | Rendering | Component |
|------|-----------|-----------|
| Plain text | Markdown-rendered body text | `MarkdownTextView` |
| Code block | Syntax-highlighted with language label, copy button | `CodeBlockView` |
| Tool call | Collapsible accordion: tool name, status (running/done/error), params, result | `ToolCallAccordion` |
| Thinking | Collapsible section with italic text, "Thinking..." label, duration | `ThinkingSection` |
| Error | Red-tinted card with error message | `ErrorMessageView` |
| Streaming | Animated typing indicator (3 dots), status text | `StreamingIndicator` |
| System | Centered gray text (session started, forked, etc.) | `SystemMessageView` |

**Tool Call Types to Render:**

| Tool | Icon | Display |
|------|------|---------|
| Read | doc.text | File path + line range |
| Write | doc.badge.plus | File path |
| Edit | pencil.line | File path + old→new preview |
| Bash | terminal | Command + output (collapsible) |
| Grep | magnifyingglass | Pattern + match count |
| Glob | folder.badge.questionmark | Pattern + file count |
| WebSearch | globe | Query |
| WebFetch | arrow.down.doc | URL |
| Task | person.2 | Agent type + description |
| Skill | sparkles | Skill name |

**Navigation Bar:**
- Left: Hamburger icon (opens sidebar on iPhone)
- Center: Session name (tappable → rename)
- Right: Info button (session details) + overflow menu (Export, Fork, Delete)

**Input Area:**
- Text field with placeholder "Message..."
- Send button (accent colored when text present, gray when empty)
- Stop button (red, replaces send during streaming)
- Optional: attachment picker, slash command palette

### 4.4 New Session Sheet

**Purpose:** Create a new session with project and model selection.

**Presented as:** Modal sheet (`.presentationDetents([.medium])`)

**Fields:**
- Project directory picker (dropdown of known project directories)
- Session name (optional, auto-generated if empty)
- Model selection (if multiple available)
- "Create Session" CTA button

**Post-creation:** Dismiss sheet, auto-navigate to new chat view.

### 4.5 System Monitor

**Purpose:** Real-time system health monitoring.

**Data Displayed:**
- CPU usage (% + sparkline chart)
- Memory usage (used/total + sparkline)
- Disk usage (used/total + progress bar)
- Network activity (up/down rates)
- Process list (name, CPU %, memory)
- File browser (navigate server filesystem)

**Interactions:**
- Pull to refresh
- Tap process → details
- Navigate file browser

### 4.6 Settings

**Purpose:** App configuration.

**Sections:**
- **Server Connection**: URL, port, health check status, edit
- **Appearance**: Theme picker (grid of theme previews), accent color
- **Tunnel**: Cloudflare tunnel configuration (if available)
- **Notifications**: Preferences
- **About**: Version, build, backend version
- **Logs**: View app logs (debug)

### 4.7 MCP/Skills/Plugins Browser

**Purpose:** Browse and manage server extensions.

**Layout:** Segmented control (MCP | Skills | Plugins) at top, scrollable list below.

**Each item shows:**
- Name
- Description/summary
- Status (active/inactive)
- Entity-colored indicator

**Interactions:**
- Tap → Detail view
- Search/filter
- Install (plugins from marketplace)

### 4.8 Theme Picker

**Purpose:** Browse and select from 12 themes.

**Layout:** Grid of theme preview cards (2 columns). Each card shows:
- Theme name
- Mini preview (3-4 color swatches)
- Active indicator (checkmark on selected)

**Interaction:** Tap → immediate theme switch with animation.

### 4.9 Onboarding / Server Setup

**Purpose:** First-run experience to connect to backend.

**Flow:**
1. Welcome screen with ILS branding
2. Connection mode selection: Local / Remote / Tunnel
3. Server URL + port input
4. Health check with animated connection steps
5. Success → Dismiss to main app

---

## 5. Component Library

### Core Components

| Component | Purpose | Props |
|-----------|---------|-------|
| `SidebarView` | Navigation sidebar | sessions, connectionStatus, onSelect |
| `SessionRow` | Single session in list | session, isActive, projectColor |
| `ChatBubble` | Message card (user or assistant) | message, role, theme |
| `CodeBlockView` | Syntax-highlighted code | code, language, onCopy |
| `ToolCallAccordion` | Collapsible tool call | toolName, status, params, result |
| `ThinkingSection` | Collapsible thinking | text, duration, isExpanded |
| `StreamingIndicator` | Animated dots + status | statusText, isConnecting |
| `StatCard` | Metric display card | title, value, trend, sparklineData |
| `SparklineChart` | Tiny inline chart | data, color, height |
| `ConnectionBanner` | Disconnected/connecting banner | status, onAction |
| `EmptyEntityState` | Empty state illustration | entityType, message, action |
| `SkeletonRow` | Loading placeholder | — |
| `ShimmerModifier` | Loading shimmer effect | isActive |
| `GlassCard` | Glassmorphism container | content |
| `EntityBadge` | Colored entity indicator | entityType, size |
| `AccentButton` | Theme-aware CTA button | label, action, style |
| `SearchBar` | Filtered search input | text, placeholder, onSearch |

### Glass Card Spec

```swift
// GlassCard modifier
struct GlassCard: ViewModifier {
    @Environment(\.theme) var theme

    func body(content: Content) -> some View {
        content
            .background(theme.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(theme.glassBorder, lineWidth: 0.5)
            )
    }
}
```

---

## 6. iPad Layout Strategy

### Split View Architecture

```
┌──────────────────┬──────────────────────────────────┐
│                  │                                  │
│    SIDEBAR       │       CONTENT AREA               │
│    (320pt)       │       (remaining width)          │
│                  │                                  │
│  ┌────────────┐  │  ┌──────────────────────────┐    │
│  │Connection  │  │  │                          │    │
│  │Status      │  │  │   Home / Chat / System   │    │
│  ├────────────┤  │  │   / Settings / Browser   │    │
│  │Search      │  │  │                          │    │
│  ├────────────┤  │  │                          │    │
│  │Sessions    │  │  │                          │    │
│  │ ils-ios    │  │  │                          │    │
│  │  ● Review  │  │  │                          │    │
│  │  Debug     │  │  │                          │    │
│  │ backend    │  │  │                          │    │
│  │  API       │  │  │                          │    │
│  ├────────────┤  │  │                          │    │
│  │System ●    │  │  │                          │    │
│  ├────────────┤  │  └──────────────────────────┘    │
│  │[+New]   ⚙ │  │                                  │
│  └────────────┘  │                                  │
└──────────────────┴──────────────────────────────────┘
```

**Adaptive Behavior:**
- **iPhone (compact width):** Sidebar is overlay sheet, content is full-screen
- **iPad Portrait:** Sidebar 280pt, content fills remainder
- **iPad Landscape:** Sidebar 320pt, content fills remainder
- **iPad Stage Manager:** Adapts based on window width, collapses sidebar below 600pt total

**Implementation:** Use `@Environment(\.horizontalSizeClass)` to switch between overlay and persistent sidebar. `NavigationSplitView` with custom sidebar content.

---

## 7. Animation System

### Transition Specifications

| Animation | Duration | Curve | Trigger |
|-----------|----------|-------|---------|
| Sidebar open/close | 0.25s | `.spring(response: 0.3, dampingFraction: 0.85)` | Hamburger tap, edge swipe |
| Screen transition | 0.2s | `.easeOut` | Navigation push/pop |
| Card appear | 0.15s | `.easeOut` | View onAppear |
| Glass blur | 0.3s | `.easeInOut` | Modal present |
| Accent color morph | 0.4s | `.easeInOut` | Entity context change |
| Streaming dots | 1.2s loop | `.easeInOut` | During AI response |
| Skeleton shimmer | 1.5s loop | `.linear` | During loading |
| Theme switch | 0.3s | `.easeInOut` | Theme selection |
| Button press | 0.1s | `.easeOut` | Touch down |
| List item appear | 0.2s staggered | `.spring` | List population |

### Reduce Motion Support

All animations gated behind:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In animations:
withAnimation(reduceMotion ? .none : .spring(response: 0.3)) { ... }
```

When reduce motion is ON:
- All transitions become instant (`.none`)
- Shimmer effects disabled
- Streaming indicator shows static text instead of dots
- Theme switch is instant

---

## 8. Chat Content Rendering Spec

### Message Layout

```
┌─ User Message ──────────────────────────┐
│                                         │
│  Message text in SF Pro, textPrimary    │
│  color, left-aligned, full-width card   │
│                                         │
│  Time: 2:34 PM              [role icon] │
└─────────────────────────────────────────┘

┌─ Assistant Response ────────────────────┐
│                                         │
│  Response text in SF Pro, rendered      │
│  as markdown (bold, italic, lists,      │
│  links, headings)                       │
│                                         │
│  ┌─ Code Block ──────────────────────┐  │
│  │ language: swift           [Copy]  │  │
│  │ ──────────────────────────────── │  │
│  │ func hello() {                   │  │
│  │     print("world")              │  │
│  │ }                                │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ▶ Tool Calls (3)           [Expand]    │
│  ├─ 📄 Read: api/auth.ts         ✓     │
│  ├─ 🔍 Grep: "login"             ✓     │
│  └─ 💻 Bash: npm test            ✓     │
│                                         │
│  ▶ Thinking (12s)           [Expand]    │
│  "I need to analyze the auth..."        │
│                                         │
│  Time: 2:35 PM                          │
└─────────────────────────────────────────┘
```

### Code Block Spec

- Background: `bgTertiary` (darkest surface)
- Border: `borderSubtle` with `0.5px`
- Font: SF Mono, 13pt
- Language label: top-left, SF Mono 11pt, `textTertiary`
- Copy button: top-right, icon only, `textSecondary`
- Syntax highlighting: Use entity colors for keywords, strings, comments
- Corner radius: `cornerRadiusSmall` (8pt)
- Max height: 300pt with scroll, expandable

### Tool Call Accordion Spec

- Collapsed: Single row showing tool icon + name + status indicator
- Expanded: Shows parameters, output/result (code-formatted if applicable)
- Status icons: ⏳ running (animated), ✓ done (success color), ✗ error (error color)
- Group multiple tool calls under single "Tool Calls (N)" header
- Tappable to expand individual or all

---

## 9. Implementation Strategy

### Phase Order (Build & Validate Incrementally)

| Phase | Scope | Validation |
|-------|-------|------------|
| **Phase 1** | AppTheme protocol + Obsidian theme + ThemeManager | Build compiles, theme tokens accessible |
| **Phase 2** | SidebarView + SidebarRootView (replaces ContentView) | Sidebar opens/closes, sessions listed |
| **Phase 3** | ChatView rebuild with new theme | Send message, see response, tool calls render |
| **Phase 4** | Home Dashboard | Dashboard shows stats, recent sessions tappable |
| **Phase 5** | New Session Sheet | Create session, auto-navigate to chat |
| **Phase 6** | System Monitor with new theme | CPU/Memory/Disk charts render |
| **Phase 7** | Settings + Theme Picker | All 12 themes selectable, live preview |
| **Phase 8** | MCP/Skills/Plugins Browser | List renders, search works |
| **Phase 9** | iPad layout adaptation | Split view works on iPad simulator |
| **Phase 10** | Onboarding flow | First-run sheet, connection test |
| **Phase 11** | Animation polish | All transitions smooth, reduce motion works |
| **Phase 12** | Remaining themes (implement all 12) | Each theme visually correct |

### Files to Create/Modify

**NEW files (~25):**
```
Theme/AppTheme.swift              — Protocol + ThemeManager
Theme/Themes/ObsidianTheme.swift  — Default theme
Theme/Themes/SlateTheme.swift     — (and 10 more theme files)
Theme/GlassCard.swift             — Glass modifier
Views/Root/SidebarRootView.swift  — New root view
Views/Root/SidebarView.swift      — Sidebar navigation
Views/Root/SidebarSessionRow.swift — Session row in sidebar
Views/Home/HomeView.swift          — Dashboard (replaces DashboardView)
Views/Chat/ChatView.swift          — Rebuilt chat (overwrite)
Views/Chat/UserMessageCard.swift   — User message
Views/Chat/AssistantCard.swift     — Assistant response
Views/Chat/CodeBlockView.swift     — Rebuilt code block
Views/Chat/ToolCallAccordion.swift — Rebuilt tool accordion
Views/Chat/ThinkingSection.swift   — Rebuilt thinking
Views/Chat/StreamingIndicator.swift — Rebuilt streaming
Views/Chat/ErrorMessageView.swift  — Error display
Views/Settings/ThemePickerView.swift — Theme grid
Views/Onboarding/OnboardingFlow.swift — First-run
```

**MODIFY (~5):**
```
ILSAppApp.swift    — Root view → SidebarRootView, remove TabView
AppState.swift     — Navigation state for sidebar + content
ContentView.swift  — DELETE (replaced by SidebarRootView)
EntityType.swift   — Update colors to use theme tokens
```

**PRESERVE (zero changes, ~20):**
```
Services/APIClient.swift
Services/SSEClient.swift
Services/MetricsWebSocketClient.swift
Services/AppLogger.swift
ViewModels/ChatViewModel.swift
ViewModels/SessionsViewModel.swift
ViewModels/ProjectsViewModel.swift
ViewModels/DashboardViewModel.swift
ViewModels/SkillsViewModel.swift
ViewModels/MCPViewModel.swift
ViewModels/PluginsViewModel.swift
ViewModels/SystemMetricsViewModel.swift
ViewModels/BaseListViewModel.swift
Models/ChatMessage.swift
Models/SessionTemplate.swift
Utils/DateFormatters.swift
(All ILSShared/ files)
```

### Backend Endpoints Used (all /api/v1)

| Endpoint | Screen | Data |
|----------|--------|------|
| GET /sessions | Sidebar, Home | Session list with project paths |
| POST /sessions | New Session | Create session |
| GET /sessions/:id | Chat View | Session detail |
| DELETE /sessions/:id | Sidebar context menu | Delete session |
| POST /sessions/:id/chat | Chat View | Send message (SSE stream) |
| POST /sessions/:id/chat/cancel | Chat View | Cancel streaming |
| GET /projects | Home (count), Browser | Project list |
| GET /skills | Home (count), Browser | Skills list |
| GET /mcp | Home (count), Browser | MCP servers |
| GET /plugins | Home (count), Browser | Plugins list |
| GET /system/metrics | System Monitor | CPU, memory, disk, network |
| GET /health | Settings, Onboarding | Server health check |

---

## 10. Stitch Design Assets

**Stitch Project ID:** `14867200832665196748`
**Project Title:** "ILS iOS Redesign 2026"

### Generated Screen Inventory

| # | Screen | Theme | Device | Status |
|---|--------|-------|--------|--------|
| 1 | Sidebar + Home | Obsidian (Orange) | Mobile | Generated (thumbnail confirmed) |
| 2 | Chat View | Obsidian | Mobile | Submitted |
| 3 | iPad Split View | Obsidian | Tablet | Submitted |
| 4 | Settings | Obsidian | Mobile | Submitted |
| 5 | System Monitor | Obsidian | Mobile | Submitted |
| 6 | Chat View | Slate (Blue) | Mobile | Submitted |
| 7 | Chat View | Midnight (Green) | Mobile | Submitted |
| 8 | Chat View | Carbon (Violet) | Mobile | Submitted |
| 9 | New Session Sheet | Obsidian | Mobile | Submitted |
| 10 | Chat View | Ember (Amber) | Mobile | Submitted |
| 11 | Chat View | Ghost Protocol (Ice) | Mobile | Submitted |
| 12 | Theme Picker Grid | Obsidian | Mobile | Submitted |
| 13 | Onboarding | Obsidian | Mobile | Submitted |
| 14 | MCP/Skills/Plugins | Obsidian | Mobile | Submitted |
| 15 | Chat View | Crimson (Red) | Mobile | Submitted |

### Stitch Thumbnail (Confirmed Working)

The project thumbnail shows the Sidebar + Home screen with:
- Dark background (#0A0A0F range)
- Orange accent (#FF6933) for CTA button and active indicators
- SF-style typography
- Sessions grouped by project directory (ils-ios, backend-api, External Sessions)
- Connection status at top ("Nick's Server" + "CONNECTED")
- Search bar
- System health indicator at bottom
- Settings gear icon
- "+ New Session" orange CTA

**Evidence:** `mockups/stitch-thumbnail.png`

---

## 11. Competitive Positioning

### Where ILS Stands Out (No Competitor Has)

1. **System monitoring + AI chat** in one app
2. **Local-first backend** with optional tunnel exposure
3. **MCP/Plugin/Skill marketplace** as first-class browsable UI
4. **12 swappable themes** with live switching
5. **iPad-native split view** from day one
6. **Tool call transparency** at the level of individual Read/Write/Edit/Bash operations

### Key Competitive Insights Applied

| Insight | Source | How Applied |
|---------|--------|-------------|
| No separate Projects screen | All 9 competitors | Sessions grouped by project in sidebar |
| Tool calls must be transparent | GitHub Copilot Feb 2026 | ToolCallAccordion with real-time status |
| iPad needs dedicated design | Perplexity Dec 2025 | Persistent sidebar split view |
| Sessions are flat, not hierarchical | ChatGPT, Claude, Cursor | Sidebar list with project grouping |
| Progressive disclosure | 2026 trend | Tool calls collapsed by default |
| AI Assistant Cards > bubbles | 2026 trend | Card-based message layout |

---

## Appendix A: Interactive HTML Mockups

Five interactive HTML mockups were created for design direction comparison:

| File | Direction | Size |
|------|-----------|------|
| `mockups/01-ghost-protocol.html` | Ghost Protocol (selected) | 44KB |
| `mockups/02-neon-noir.html` | Neon Noir | 39KB |
| `mockups/03-electric-grid.html` | Electric Grid | 33KB |
| `mockups/04-synthwave-dreams.html` | Synthwave Dreams | 47KB |
| `mockups/05-data-storm.html` | Data Storm | 28KB |
| `mockups/index.html` | Design Picker (comparison) | 13KB |

**To view:** `python3 -m http.server 8888 --directory mockups/` then open `http://localhost:8888` in Safari.

## Appendix B: Design System Master File

Additional design system reference generated by UI/UX Pro Max skill:
`design-system/ils-ios-cyberpunk/MASTER.md`

Contains: Typography (JetBrains Mono + IBM Plex Sans reference), spacing variables, shadow depths, component CSS specs, anti-patterns, pre-delivery checklist.

**Note:** The MASTER.md uses web fonts (JetBrains Mono + IBM Plex Sans). For iOS, we use SF Mono + SF Pro instead. The spacing, shadow, and component patterns are still applicable.
