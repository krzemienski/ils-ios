# Design: ILS iOS App — Complete Redesign

## Design Philosophy

**"Clarity through color, depth through glass, trust through motion."**

The redesign replaces the monochromatic dark-gray-on-black approach with a color-coded entity system where every data type has its own identity. Navigation shifts from a hidden sidebar sheet to a persistent tab bar. Glassmorphism adds depth without clutter. Every interaction has feedback.

---

## Design System

### Color Palette

#### Entity Colors (Primary Identity)

| Entity | Color | Hex | SF Symbol | Usage |
|--------|-------|-----|-----------|-------|
| Sessions | Blue | #007AFF | `bubble.left.and.bubble.right` | Session cards, chat UI, session count badges |
| Projects | Green | #34C759 | `folder.fill` | Project cards, project-related accents |
| Skills | Purple | #AF52DE | `sparkles` | Skill cards, install buttons, skill badges |
| MCP | Orange | #FF9500 | `server.rack` | MCP server cards, status indicators |
| Plugins | Yellow | #FFD60A | `puzzlepiece.extension` | Plugin cards, marketplace accents |
| System | Teal | #30B0C7 | `gauge.with.dots.needle.33percent` | Metrics charts, process list, file browser |

#### Background Scale

| Level | Hex | Name | Usage |
|-------|-----|------|-------|
| bg-0 | #000000 | Pure Black | App background, OLED true black |
| bg-1 | #0A0E1A | Midnight | Tab bar background (behind glass) |
| bg-2 | #111827 | Slate 900 | Card backgrounds, list rows |
| bg-3 | #1E293B | Slate 800 | Elevated cards, active states |
| bg-4 | #334155 | Slate 700 | Hover/pressed states, dividers |

#### Text Scale

| Level | Hex | Usage |
|-------|-----|-------|
| text-primary | #F1F5F9 | Headings, primary content (Slate 100) |
| text-secondary | #94A3B8 | Descriptions, metadata (Slate 400) |
| text-tertiary | #64748B | Placeholders, hints (Slate 500) |
| text-inverse | #0F172A | Text on colored backgrounds (Slate 900) |

#### Semantic Colors

| Role | Hex | Usage |
|------|-----|-------|
| success | #34C759 | Connected, installed, completed |
| warning | #FF9500 | Connecting, installing, in-progress |
| error | #FF453A | Disconnected, failed, error states |
| info | #007AFF | Informational banners, links |

#### Gradient Presets

```swift
// Entity gradient for card headers / stat rings
static func entityGradient(_ entity: EntityType) -> LinearGradient {
    switch entity {
    case .sessions:  // Blue
        return LinearGradient(colors: [Color(hex: "#007AFF"), Color(hex: "#5AC8FA")], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .projects:  // Green
        return LinearGradient(colors: [Color(hex: "#34C759"), Color(hex: "#30D158")], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .skills:    // Purple
        return LinearGradient(colors: [Color(hex: "#AF52DE"), Color(hex: "#BF5AF2")], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .mcp:       // Orange
        return LinearGradient(colors: [Color(hex: "#FF9500"), Color(hex: "#FF6B35")], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .plugins:   // Yellow
        return LinearGradient(colors: [Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .system:    // Teal
        return LinearGradient(colors: [Color(hex: "#30B0C7"), Color(hex: "#64D2FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
```

---

### Typography

| Role | Font | Size | Weight | Line Height |
|------|------|------|--------|-------------|
| Large Title | SF Pro Rounded | 34pt | Bold | 41pt |
| Title | SF Pro Rounded | 28pt | Bold | 34pt |
| Headline | SF Pro | 17pt | Semibold | 22pt |
| Body | SF Pro | 17pt | Regular | 22pt |
| Subheadline | SF Pro | 15pt | Regular | 20pt |
| Caption | SF Pro | 12pt | Regular | 16pt |
| Code | SF Mono | 14pt | Regular | 18pt |

**Note:** Use SF Pro Rounded for large titles and section headers to add warmth. SF Mono for code blocks and technical data. Standard SF Pro for everything else.

---

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| space-2xs | 2pt | Icon-to-text micro gap |
| space-xs | 4pt | Badge padding, tight spacing |
| space-s | 8pt | Intra-component spacing |
| space-m | 12pt | Inter-element spacing |
| space-l | 16pt | Section padding, card internal |
| space-xl | 20pt | Section gaps |
| space-2xl | 24pt | Major section breaks |
| space-3xl | 32pt | Screen-level padding |

---

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| radius-xs | 6pt | Badges, tags, small pills |
| radius-s | 10pt | Buttons, input fields |
| radius-m | 14pt | Cards, list rows |
| radius-l | 20pt | Sheets, modals |
| radius-xl | 28pt | Large cards, hero sections |

---

### Effects

#### Glassmorphism
```swift
// Tab bar, sheets, overlays
.background(.ultraThinMaterial)
.background(Color(hex: "#0A0E1A").opacity(0.7))

// Elevated glass cards
.background(.thinMaterial)
.overlay(
    RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.08), lineWidth: 1)
)
```

#### Shadows (subtle, for elevation only)
```swift
// Card shadow
.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

// Floating elements (FAB, tab bar)
.shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
```

#### Glow (entity accent, very subtle)
```swift
// Entity glow behind stat cards
.shadow(color: entityColor.opacity(0.2), radius: 20, x: 0, y: 0)
```

---

## Navigation Architecture

### Tab Bar (5 Tabs)

```
┌─────────────────────────────────────────────┐
│                                             │
│            [Current View Content]           │
│                                             │
├─────────────────────────────────────────────┤
│  ●         ●         ●         ●        ●  │
│ Home    Sessions  Projects  System  Settings│
│ 🏠        💬        📁       📊       ⚙️   │
└─────────────────────────────────────────────┘
```

| Tab | SF Symbol | Active Color | Content |
|-----|-----------|-------------|---------|
| Home | `house.fill` | White | Dashboard with stat cards + quick actions |
| Sessions | `bubble.left.and.bubble.right.fill` | #007AFF (Blue) | Sessions list + chat |
| Projects | `folder.fill` | #34C759 (Green) | Projects list + detail |
| System | `gauge.with.dots.needle.33percent` | #30B0C7 (Teal) | Metrics + processes + files |
| Settings | `gearshape.fill` | #94A3B8 (Slate) | Config + Remote Access + Skills/MCP/Plugins |

#### Tab Bar Styling
```swift
TabView(selection: $selectedTab) { ... }
    .tint(.white)
    // Tab bar uses glass material
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
```

#### Nested Under Settings
Skills, MCP Servers, and Plugins move to Settings sub-sections to keep tab count at 5:
```
Settings
├── Connection (server URL, test, tunnel)
├── Remote Access (Cloudflare tunnel)
├── Skills Management
├── MCP Servers
├── Plugins & Marketplace
├── Appearance (theme, color scheme)
├── Advanced (permissions, hooks, cache)
└── About
```

---

## Screen Designs

### 1. Dashboard (Home Tab)

```
┌─────────────────────────────────┐
│ Good evening, Nick         [●]  │  ← Greeting + connection dot
├─────────────────────────────────┤
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │ ◐ 12     │ │ ◐ 371    │      │  ← Stat cards with progress rings
│ │ Sessions │ │ Projects  │      │     Entity gradient ring + count
│ │  ● ● ●   │ │  ● ● ●   │      │     Sparkline mini-chart below
│ └──────────┘ └──────────┘      │
│ ┌──────────┐ ┌──────────┐      │
│ │ ◐ 1527   │ │ ◐ 20     │      │
│ │ Skills   │ │ MCP      │      │
│ │  ● ● ●   │ │  ● ● ●   │      │
│ └──────────┘ └──────────┘      │
│                                 │
│ ── Quick Actions ──────────     │
│ [+ New Session] [⏱ Cost: $X]   │
│                                 │
│ ── Recent Sessions ────────     │
│ ┌─────────────────────────┐     │
│ │ 🔵 Auth refactor    2m  │     │  ← Blue dot = sessions entity color
│ │    claude-3.5-sonnet     │     │
│ ├─────────────────────────┤     │
│ │ 🔵 Debug websocket  15m │     │
│ │    claude-3.5-sonnet     │     │
│ └─────────────────────────┘     │
│                                 │
│ ── System Health ──────────     │
│ CPU ████░░░░░ 45%  Mem 62% │     │  ← Compact inline metrics
└─────────────────────────────────┘
```

#### Stat Card Component
```swift
struct StatCard: View {
    let title: String
    let count: Int
    let entity: EntityType
    let sparklineData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Progress ring with entity gradient stroke
                ProgressRing(progress: 0.7, gradient: ILSTheme.entityGradient(entity))
                    .frame(width: 36, height: 36)
                Spacer()
                Text("\(count)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(ILSTheme.entityColor(entity))
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Sparkline
            SparklineChart(data: sparklineData, color: ILSTheme.entityColor(entity))
                .frame(height: 24)
        }
        .padding(16)
        .background(Color(hex: "#111827"))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ILSTheme.entityColor(entity).opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(14)
        .shadow(color: ILSTheme.entityColor(entity).opacity(0.1), radius: 12)
    }
}
```

---

### 2. Sessions List (Sessions Tab)

```
┌─────────────────────────────────┐
│ Sessions                   [+]  │  ← Title + FAB for new session
│ ┌─────────────────────────────┐ │
│ │ 🔍 Search sessions...       │ │
│ └─────────────────────────────┘ │
│                                 │
│ ── Active ─────────────────     │
│ ┌─────────────────────────┐     │
│ │ ● Auth refactor          │     │  ← Blue dot = active
│ │   sonnet · 24 msgs · 2m  │     │
│ │   $0.42         ▸        │     │
│ └─────────────────────────┘     │
│                                 │
│ ── Recent ─────────────────     │
│ ┌─────────────────────────┐     │
│ │ ○ Debug websocket        │     │  ← Hollow dot = inactive
│ │   sonnet · 8 msgs · 1h   │     │
│ │   $0.18         ▸        │     │
│ ├─────────────────────────┤     │
│ │ ○ Fix streaming          │     │
│ │   sonnet · 12 msgs · 3h  │     │
│ │   $0.31         ▸        │     │
│ └─────────────────────────┘     │
│                                 │
│ ── External (read-only) ──      │
│ ┌─────────────────────────┐     │
│ │ 👁 Project X session     │     │  ← Eye icon = external read-only
│ │   claude-code · 45 msgs  │     │
│ └─────────────────────────┘     │
└─────────────────────────────────┘
```

#### Session Row
- Blue accent for session entity
- Status dot: filled blue = active, hollow = inactive, eye = external
- Swipe actions: Rename (left), Delete (right)
- Tap navigates to ChatView

---

### 3. Chat View

```
┌─────────────────────────────────┐
│ ← Auth refactor      [ℹ] [⋯]  │  ← Nav bar with info + menu
├─────────────────────────────────┤
│                                 │
│          ┌─────────────────┐    │
│          │ Refactor the    │ →  │  ← User bubble: right-aligned
│          │ auth module to  │    │     Blue gradient background
│          │ use JWT tokens  │    │
│          └─────────────────┘    │
│                                 │
│ ┌─────────────────────┐        │
│ │ I'll refactor the    │ ←     │  ← Assistant bubble: left-aligned
│ │ authentication...    │        │     Dark glass background
│ │                      │        │
│ │ ```swift             │        │  ← Code block with syntax highlighting
│ │ struct JWTAuth {     │        │     Language label "swift" at top
│ │   let token: String  │        │
│ │ }                    │        │
│ │ ```                  │        │
│ │                      │        │
│ │ ▶ Tool: read_file   │        │  ← Collapsible tool call accordion
│ │ ▶ Thinking...        │        │  ← Collapsible thinking section
│ └─────────────────────┘        │
│                                 │
│ ┌───────────────────┐           │
│ │ ●●● Claude is     │           │  ← Streaming indicator
│ │   responding...    │           │     Animated dots + status text
│ │         [■ Stop]   │           │     Red stop button
│ └───────────────────┘           │
│                                 │
├─────────────────────────────────┤
│ ┌────────────────────┐ [/] [➤] │  ← Input bar
│ │ Message Claude...   │         │     [/] = command palette
│ └────────────────────┘         │     [➤] = send button (blue)
└─────────────────────────────────┘
```

#### Chat Bubble Styling
```swift
// User message bubble
.padding(12)
.background(
    LinearGradient(
        colors: [Color(hex: "#007AFF"), Color(hex: "#0056B3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
)
.cornerRadius(16)
.cornerRadius(4, corners: .bottomTrailing) // Chat tail

// Assistant message bubble
.padding(12)
.background(.thinMaterial)
.background(Color(hex: "#111827"))
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.06), lineWidth: 1)
)
.cornerRadius(16)
.cornerRadius(4, corners: .bottomLeading) // Chat tail
```

#### Code Block Rendering
```swift
struct CodeBlockView: View {
    let language: String
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language header
            HStack {
                Text(language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") { ... }
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#1E293B"))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(Color(hex: "#F1F5F9"))
                    .padding(12)
            }
            .background(Color(hex: "#0F172A"))
        }
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
```

---

### 4. System Monitoring (System Tab)

```
┌─────────────────────────────────┐
│ System Monitor          [Live●] │  ← Live indicator pulsing
├─────────────────────────────────┤
│                                 │
│ ┌───────────────────────────┐   │
│ │ CPU                  45%  │   │  ← Teal gradient area chart
│ │ ╱╲    ╱╲╱╲               │   │     Last 2 minutes of data
│ │╱  ╲╱╲╱    ╲───           │   │     Y-axis: 0-100%
│ └───────────────────────────┘   │
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │ Memory   │ │ Disk     │      │
│ │ ◐ 62%   │ │ ◐ 45%   │      │  ← Circular progress with gradient
│ │ 10/16 GB │ │ 450/1TB  │      │
│ └──────────┘ └──────────┘      │
│                                 │
│ ┌───────────────────────────┐   │
│ │ Network    ↑ 2.3 MB/s     │   │  ← Dual-line chart (in/out)
│ │            ↓ 15.1 MB/s    │   │
│ │ ╱╲╱╲ (upload in teal)    │   │
│ │ ╱╲╱╲╱╲ (download in blue)│   │
│ └───────────────────────────┘   │
│                                 │
│ ── Processes ──────── [CPU▼]    │
│ ┌─────────────────────────┐     │
│ │ claude  PID:4521  34% 2G│     │
│ │ ILSBack PID:4488  12% 1G│     │
│ │ node    PID:4302   8% 500│     │
│ │ cloudfl PID:4600   2% 50M│     │
│ └─────────────────────────┘     │
│                                 │
│ ── Files ─────── ~/            │
│ ┌─────────────────────────┐     │
│ │ 📁 .claude/              │     │
│ │ 📁 Desktop/              │     │
│ │ 📁 Projects/             │     │
│ │ 📄 .zshrc          4KB  │     │
│ └─────────────────────────┘     │
└─────────────────────────────────┘
```

#### Metric Chart Component (Swift Charts)
```swift
struct MetricChart: View {
    let title: String
    let data: [MetricDataPoint]  // timestamp + value
    let color: Color
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(data.last?.value ?? 0, specifier: "%.0f")\(unit)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
            }

            Chart(data) { point in
                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYAxis { AxisMarks(position: .trailing) }
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .padding(16)
        .background(Color(hex: "#111827"))
        .cornerRadius(14)
    }
}
```

#### Circular Progress Ring
```swift
struct ProgressRing: View {
    let progress: Double  // 0.0 - 1.0
    let gradient: LinearGradient
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}
```

---

### 5. Settings (Settings Tab)

```
┌─────────────────────────────────┐
│ Settings                        │
├─────────────────────────────────┤
│                                 │
│ ── Connection ─────────────     │
│ ┌─────────────────────────┐     │
│ │ Server    localhost:9090 │     │
│ │ Status    ● Connected    │     │
│ │ Claude    v1.2.3         │     │
│ │ [Test Connection]        │     │
│ └─────────────────────────┘     │
│                                 │
│ ── Remote Access ──────────     │
│ ┌─────────────────────────┐     │
│ │ Cloudflare Tunnel   [◯] │     │  ← Toggle to start/stop
│ │ URL: (none active)       │     │
│ │ ▸ Custom Domain          │     │  ← Collapsed section
│ └─────────────────────────┘     │
│                                 │
│ ── Manage ─────────────────     │
│ ┌─────────────────────────┐     │
│ │ 🟣 Skills         1527 ▸│     │  ← Entity colored icons
│ │ 🟠 MCP Servers      20 ▸│     │
│ │ 🟡 Plugins          78 ▸│     │
│ └─────────────────────────┘     │
│                                 │
│ ── Appearance ─────────────     │
│ ┌─────────────────────────┐     │
│ │ Color Scheme  [Sys|L|D]  │     │  ← Segmented picker
│ │ AI Model     [picker]    │     │
│ └─────────────────────────┘     │
│                                 │
│ ── Advanced ───────────────     │
│ ┌─────────────────────────┐     │
│ │ Permissions         ▸   │     │
│ │ Hooks               ▸   │     │
│ │ API Key             ▸   │     │
│ │ Clear Cache         ▸   │     │
│ └─────────────────────────┘     │
│                                 │
│ ── About ──────────────────     │
│ ┌─────────────────────────┐     │
│ │ ILS v2.0                 │     │
│ │ Backend: Vapor + Claude  │     │
│ └─────────────────────────┘     │
└─────────────────────────────────┘
```

---

### 6. Enhanced Onboarding (ServerSetupSheet)

```
┌─────────────────────────────────┐
│                                 │
│        ┌──────────────┐         │
│        │  ILS Logo     │         │  ← App icon / brand mark
│        │  ✦            │         │
│        └──────────────┘         │
│                                 │
│   Welcome to ILS                │
│   Connect to your backend       │
│                                 │
│ ┌─────┬──────────┬─────────┐    │
│ │Local│  Remote  │ Tunnel  │    │  ← Segmented tabs
│ └─────┴──────────┴─────────┘    │
│                                 │
│ ┌─────────────────────────┐     │
│ │ http://192.168.1.100    │     │  ← URL input field
│ │ :9090                    │     │
│ └─────────────────────────┘     │
│                                 │
│ ── Connection Progress ────     │
│ ✅ DNS Resolved                 │
│ ✅ TCP Connected                │
│ ⏳ Health Check...              │  ← Step-by-step progress
│                                 │
│ ── Recent ─────────────────     │
│ localhost:9090           2m ago  │
│ 192.168.1.50:9090       1d ago  │
│                                 │
│       [ Connect ]               │  ← Primary action button
│                                 │
└─────────────────────────────────┘
```

---

### 7. Cloudflare Tunnel (Remote Access in Settings)

```
┌─────────────────────────────────┐
│ Remote Access                   │
├─────────────────────────────────┤
│                                 │
│ ── Quick Tunnel ───────────     │
│ ┌─────────────────────────┐     │
│ │ Cloudflare Tunnel        │     │
│ │                    [●ON] │     │  ← Toggle switch
│ │                          │     │
│ │ ┌─────────────────────┐  │     │
│ │ │ https://abc-xyz.try │  │     │  ← Tunnel URL
│ │ │ cloudflare.com      │  │     │
│ │ └─────────────────────┘  │     │
│ │ [Copy URL] [QR Code]    │     │
│ │                          │     │
│ │ Uptime: 2h 34m           │     │
│ │ Status: ● Healthy        │     │
│ └─────────────────────────┘     │
│                                 │
│ ── Custom Domain (Optional) ─   │
│ ┌─────────────────────────┐     │
│ │ ▸ Use your own domain    │     │  ← Expandable section
│ │                          │     │
│ │ Cloudflare API Token:    │     │
│ │ ┌────────────────────┐   │     │
│ │ │ ••••••••••••••••   │   │     │
│ │ └────────────────────┘   │     │
│ │                          │     │
│ │ Tunnel Name:             │     │
│ │ ┌────────────────────┐   │     │
│ │ │ ils-production     │   │     │
│ │ └────────────────────┘   │     │
│ │                          │     │
│ │ Domain:                  │     │
│ │ ┌────────────────────┐   │     │
│ │ │ ils.yourdomain.com │   │     │
│ │ └────────────────────┘   │     │
│ └─────────────────────────┘     │
│                                 │
│ ── How it Works ───────────     │
│ Cloudflare Tunnel creates a     │
│ secure connection from your     │
│ backend to the internet.        │
│ Quick tunnels are free and      │
│ require no account.             │
│                                 │
│ [Install cloudflared →]         │  ← Link if not installed
└─────────────────────────────────┘
```

---

### 8. Empty States (Custom)

Each entity type gets a personalized empty state:

```
Sessions Empty:
┌─────────────────────────────────┐
│                                 │
│        💬                       │
│   (blue tinted SF Symbol)       │
│                                 │
│   No sessions yet               │
│   Start a conversation with     │
│   Claude to begin               │
│                                 │
│      [+ New Session]            │  ← Entity-colored button
│                                 │
└─────────────────────────────────┘

System Disconnected:
┌─────────────────────────────────┐
│                                 │
│        📊                       │
│   (teal tinted SF Symbol)       │
│                                 │
│   No system data                │
│   Connect to a backend to       │
│   see live metrics              │
│                                 │
│      [Configure]                │
│                                 │
└─────────────────────────────────┘
```

---

### 9. Connection Banner (Slim)

```
Disconnected state:
┌─────────────────────────────────┐
│ ● Reconnecting...          [×]  │  ← Slim red/orange bar
└─────────────────────────────────┘

Connected state (auto-dismiss after 2s):
┌─────────────────────────────────┐
│ ● Connected                     │  ← Slim green bar, fades out
└─────────────────────────────────┘
```

Styling: 36pt height, `.ultraThinMaterial` background, slides down from top with spring animation. Auto-retries every 5 seconds when disconnected.

---

### 10. Skeleton Loading

```
┌─────────────────────────────────┐
│ ┌─────────────────────────┐     │
│ │ ████████░░░░░░░         │     │  ← Shimmer animation
│ │ ██████████████░░░       │     │     Left-to-right gradient sweep
│ │ ████████░░░░░░░         │     │     at 1.5s duration, repeating
│ └─────────────────────────┘     │
│ ┌─────────────────────────┐     │
│ │ ████████░░░░░░░         │     │
│ │ ██████████████░░░       │     │
│ └─────────────────────────┘     │
│ ┌─────────────────────────┐     │
│ │ ████████░░░░░░░         │     │
│ │ ██████████████░░░       │     │
│ └─────────────────────────┘     │
└─────────────────────────────────┘
```

```swift
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}
```

---

## Component Library

### New Components Required

| Component | Purpose | Entity |
|-----------|---------|--------|
| `StatCard` | Dashboard metric card with ring + sparkline | All |
| `ProgressRing` | Circular progress with gradient stroke | All |
| `SparklineChart` | Miniature trend line | All |
| `MetricChart` | Full-width area/line chart | System |
| `CodeBlockView` | Syntax-highlighted code display | Chat |
| `ToolCallAccordion` | Expandable tool call details | Chat |
| `ThinkingSection` | Collapsible thinking block | Chat |
| `ChatBubble` | Gradient user / glass assistant bubble | Chat |
| `ProcessRow` | Process list item with CPU/mem bars | System |
| `FileBrowserRow` | File/directory entry with icon | System |
| `ConnectionBanner` | Slim top reconnection bar | Global |
| `SkeletonRow` | Shimmer loading placeholder | All |
| `EmptyEntityState` | Typed empty state with entity icon | All |
| `TunnelStatusCard` | Tunnel URL display with copy/QR | Settings |
| `ConnectionSteps` | Multi-step connection progress | Onboarding |

### Modified Components

| Component | Changes |
|-----------|---------|
| `ILSTheme` | Add entity colors, gradients, new bg scale, rounded fonts |
| `CardStyle` | Use bg-2 (#111827), add border stroke, entity shadow |
| `PrimaryButtonStyle` | Accept entity color parameter, gradient background |
| `ErrorStateView` | Use entity-typed icons, better error messages |
| `EmptyStateView` | Replace with `EmptyEntityState` |
| `ToastModifier` | Add success/error/warning variants with colors |
| `StatusBadge` | Use entity colors instead of generic |

---

## Animation Specifications

| Animation | Duration | Curve | Trigger |
|-----------|----------|-------|---------|
| Tab switch | 200ms | easeInOut | Tab tap |
| Card appear | 300ms | spring(0.6) | View load, staggered 50ms |
| Chart data update | 500ms | easeInOut | New data point |
| Connection banner slide | 300ms | spring(0.7) | Connection state change |
| Toast appear/dismiss | 200ms | easeInOut | Action result |
| Skeleton shimmer | 1500ms | linear, repeating | Loading state |
| Progress ring fill | 500ms | easeInOut | Value change |
| Chat bubble appear | 250ms | spring(0.8) | New message |
| Accordion expand | 200ms | easeInOut | Tap toggle |
| Tunnel URL copy | haptic + 100ms scale | spring | Copy tap |

**Reduced Motion:** All animations respect `@Environment(\.accessibilityReduceMotion)`. When enabled: instant transitions, no shimmer, no spring bounces.

---

## Accessibility Checklist

- [ ] All colors meet WCAG AA contrast (4.5:1 for text, 3:1 for large text)
- [ ] Entity colors tested for colorblind accessibility (text labels always present, never color-only)
- [ ] Dynamic Type supported at all sizes (M through XXXL)
- [ ] VoiceOver reads logical order on every screen
- [ ] All interactive elements have accessibility labels
- [ ] Charts have `accessibilityLabel` describing the trend ("CPU usage is 45%, trending up")
- [ ] Skeleton loading announces "Loading" to VoiceOver
- [ ] Tab bar items have descriptive labels
- [ ] Code blocks readable at Dynamic Type XXXL (horizontal scroll)
- [ ] Reduced motion honored for all animations

---

## Implementation Notes

### Theme Migration Strategy

1. Add new colors/gradients to `ILSTheme.swift` alongside existing ones
2. Create `EntityType` enum with associated colors/gradients/icons
3. Update `CardStyle` to accept entity parameter
4. Migrate views one tab at a time (Dashboard → Sessions → Projects → System → Settings)
5. Remove old color constants after all views migrated
6. Remove deprecated corner radius aliases

### Swift Charts Integration

- Import `Charts` framework (iOS 16+ native)
- `MetricChart` for full-width system metrics
- `SparklineChart` for dashboard stat cards
- Data model: `struct MetricDataPoint: Identifiable { let id = UUID(); let timestamp: Date; let value: Double }`
- Sliding window: keep last 60 data points (2 minutes at 2s interval)

### Markdown Rendering

Options evaluated:
1. **swift-markdown-ui** (third-party) — Full markdown rendering, code highlighting, customizable themes. ~2MB size.
2. **Custom AttributedString** — Native, no dependency, but limited (no code highlighting).
3. **WKWebView** — Full rendering but heavy, non-native feel.

**Recommendation:** Use `swift-markdown-ui` for chat messages. It handles code blocks, lists, headings, links, and supports custom themes. The dependency is worth the rendering quality.

### WebSocket for Metrics

- Extend existing `WebSocketService` or create `MetricsWebSocketClient`
- Connect on System tab appear, disconnect on tab disappear
- Protocol: JSON messages `{ "cpu": 45.2, "memory": { "used": 10737418240, "total": 17179869184 }, "disk": {...}, "network": {...} }`
- Reconnect on disconnect with exponential backoff (1s, 2s, 4s, max 30s)

---

## File Structure (New/Modified)

```
ILSApp/ILSApp/
├── Theme/
│   ├── ILSTheme.swift           ← MODIFY: entity colors, gradients, new bg scale
│   ├── EntityType.swift         ← NEW: enum with colors/icons/gradients per entity
│   └── Components/
│       ├── StatCard.swift       ← NEW
│       ├── ProgressRing.swift   ← NEW
│       ├── SparklineChart.swift ← NEW
│       ├── MetricChart.swift    ← NEW
│       ├── CodeBlockView.swift  ← NEW
│       ├── ChatBubble.swift     ← NEW
│       ├── ToolCallAccordion.swift ← NEW
│       ├── SkeletonRow.swift    ← NEW
│       ├── EmptyEntityState.swift ← NEW
│       ├── ConnectionBanner.swift ← NEW
│       └── ShimmerModifier.swift ← NEW
├── Views/
│   ├── Dashboard/
│   │   └── DashboardView.swift  ← MODIFY: stat cards, quick actions, system health
│   ├── Sessions/
│   │   ├── SessionsListView.swift ← MODIFY: entity styling, swipe rename
│   │   └── NewSessionView.swift   ← MODIFY: send advanced options
│   ├── Chat/
│   │   ├── ChatView.swift         ← MODIFY: bubble styling, input bar
│   │   └── MessageView.swift      ← MODIFY: markdown rendering, code blocks, accordions
│   ├── Projects/
│   │   └── ProjectsListView.swift ← MODIFY: entity styling
│   ├── System/                    ← NEW DIRECTORY
│   │   ├── SystemMonitorView.swift ← NEW: metrics dashboard
│   │   ├── ProcessListView.swift   ← NEW: process list
│   │   └── FileBrowserView.swift   ← NEW: file browser
│   ├── Settings/
│   │   ├── SettingsView.swift     ← MODIFY: restructure, add Remote Access
│   │   └── TunnelSettingsView.swift ← NEW: Cloudflare tunnel UI
│   ├── Onboarding/
│   │   └── ServerSetupSheet.swift ← MODIFY: 3 tabs, connection history
│   └── CommandPalette/
│       └── CommandPaletteView.swift ← MODIFY: dynamic commands
├── ViewModels/
│   ├── SystemMetricsViewModel.swift ← NEW
│   └── ChatViewModel.swift          ← MODIFY: markdown processing
├── Services/
│   └── MetricsWebSocketClient.swift ← NEW
└── ILSAppApp.swift                  ← MODIFY: TabView, remove hardcoded dark mode
```

Backend (`Sources/ILSBackend/`):
```
Controllers/
├── TunnelController.swift       ← NEW
├── SystemController.swift       ← NEW
└── SessionsController.swift     ← MODIFY: add PUT rename

Services/
├── TunnelService.swift          ← NEW
└── SystemMetricsService.swift   ← NEW
```
