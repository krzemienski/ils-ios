---
spec: rebuild-ground-up
phase: research
created: 2026-02-07T16:00:00Z
---

# Research: rebuild-ground-up

## Executive Summary

Complete front-end rebuild of ILS iOS app with dark cyberpunk theme, replacing the current 5-tab TabView navigation with a side drawer/panel pattern. The codebase has a clean MVVM architecture with well-separated backend integration (APIClient actor, SSEClient for streaming, ILSShared models) that can be fully preserved while replacing all SwiftUI views and the theme system. Five distinct cyberpunk design directions are proposed ranging from subtle/professional to bold/immersive.

## External Research

### Cyberpunk Design Best Practices

| Element | Best Practice | Source |
|---------|--------------|--------|
| Color ratio | 60-30-10 rule: dark bg (60%), mid-tones (30%), neon accents (10%) | [Metaverse Planet](https://metaverseplanet.net/blog/cyberpunk-color-palette-generator/) |
| Text color | Never use pure white (#FFFFFF); use light cyan (#E0FFFF) or light pink instead | [Metaverse Planet](https://metaverseplanet.net/blog/cyberpunk-color-palette-generator/) |
| Backgrounds | Deep blacks (#050505, #0B0B15) and midnight blues (#1A1A2E, #16213E) | [Metaverse Planet](https://metaverseplanet.net/blog/cyberpunk-color-palette-generator/) |
| Neon accents | Cyan (#00F3FF), Magenta (#FF00FF), Electric Blue (#4CC9F0), Toxic Green (#39FF14) | [Color-Hex](https://www.color-hex.com/color-palette/61235) |
| Glow effects | Use `.shadow(color:radius:)` layered 2-3x for neon glow; blur + overlay for intense glow | [Medium - Garejakirit](https://medium.com/@garejakirit/making-things-glow-and-shine-with-swiftui-a83eec917203) |
| Typography | Monospace for data/code; futuristic sans-serif for headings; minimalist sans for body | [Wendy Zhou](https://www.wendyzhou.se/blog/futuristic-ui-design-inspiration-tips/) |
| Glass effects | Translucent glass navigation bars with neon tint for cyberpunk feel | [Medium - Garejakirit](https://medium.com/@garejakirit/creating-a-translucent-glassy-navigation-bar-in-ios-with-swiftui-fffd0e33400d) |

### Cyberpunk Color Palettes (Verified Hex Codes)

**Palette A — "Neon Noir"**
- Background: `#050505`, `#0B0B15`, `#1A1A2E`
- Accent Primary: `#00F3FF` (Cyan)
- Accent Secondary: `#FF00FF` (Magenta)
- Accent Tertiary: `#39FF14` (Toxic Green)

**Palette B — "Electric City"**
- Background: `#0F0F1A`, `#16213E`, `#1B1B2A`
- Accent Primary: `#FF007A` (Hot Pink)
- Accent Secondary: `#00FFB3` (Neon Mint)
- Accent Tertiary: `#4361EE` (Electric Indigo)

**Palette C — "Synthwave"**
- Background: `#0F0418`, `#120012`, `#2D002D`
- Accent Primary: `#F72585` (Vivid Pink)
- Accent Secondary: `#4CC9F0` (Sky Cyan)
- Accent Tertiary: `#7B2CBF` (Purple)

**Palette D — "Hologram"**
- Background: `#02020A`, `#001212`, `#0B0B15`
- Accent Primary: `#00FFFF` (Pure Cyan)
- Accent Secondary: `#FF1493` (Deep Pink)
- Accent Tertiary: `#FFEE00` (Neon Yellow)

**Palette E — "Ghost Protocol"**
- Background: `#050505`, `#0F0F1A`, `#222222`
- Accent Primary: `#7DF9FF` (Ice Blue)
- Accent Secondary: `#B5179E` (Orchid)
- Accent Tertiary: `#E9C46A` (Gold)

### SwiftUI Side Navigation Approaches

| Approach | Pros | Cons | Source |
|----------|------|------|--------|
| Custom offset-based drawer | Full control, smooth animations, gesture support | Must handle safe areas, keyboard, rotation manually | [Medium - App Dev Insights](https://medium.com/@appdevinsights/creating-a-custom-drawer-menu-with-swiftui-0354afef92d8) |
| HStack with animated frame | Simple implementation, natural SwiftUI pattern | Less smooth than offset approach | [Lanars](https://lanars.com/blog/sidemenu-in-swiftui-part1) |
| SSSwiftUISideMenu library | Left/right panel support, customizable animations | External dependency | [GitHub - SSSwiftUISideMenu](https://github.com/SimformSolutionsPvtLtd/SSSwiftUISideMenu) |
| Overlay with dimmed background | Clean separation of concerns, tappable dismiss | May conflict with navigation gestures | [iOS App Templates](https://iosapptemplates.com/blog/swiftui/navigation-drawer-swiftui) |

**Recommended approach:** Custom offset-based drawer with gesture support. No external dependency needed. Implementation uses `@GestureState` for drag tracking, `offset()` for positioning, and `matchedGeometryEffect` for smooth transitions between menu items. Background dims with tappable overlay to dismiss.

### Chat UI Patterns for Dark/Cyberpunk Themes

| Pattern | Description | Source |
|---------|-------------|--------|
| AI Assistant Cards | Responses in styled cards instead of chat bubbles — better for rich content | [MultitaskAI](https://multitaskai.com/blog/chat-ui-design/) |
| Glassmorphism bubbles | Semi-transparent message bubbles with blur backdrop | [Muzli](https://muz.li/inspiration/dark-mode/) |
| Streaming typewriter | Character-by-character text reveal during AI response | [Medium - ganeshrajugalla](https://medium.com/@ganeshrajugalla/swiftui-replicating-chatgpts-typing-like-animation-in-swiftui-913ba08a323a) |
| Neon-bordered code blocks | Code blocks with neon border glow and monospace font | [Dribbble](https://dribbble.com/search/cyberpunk-ui) |

### Animation Framework Options

| Technique | Use Case | Complexity |
|-----------|----------|------------|
| `withAnimation(.spring)` | Screen transitions, menu open/close | Low |
| `PhaseAnimator` (iOS 17+) | Multi-step animations (loading states, pulse effects) | Medium |
| `matchedGeometryEffect` | Shared element transitions between views | Medium |
| Canvas + TimelineView | Particle effects, data stream visualizations, scanlines | High |
| `keyframeAnimator` (iOS 17+) | Complex multi-property animations (glitch effects) | Medium |
| Custom `ViewModifier` + Timer | Typing animation, text reveal, glow pulse | Low-Medium |

**Recommended stack:**
- SwiftUI native animations (spring, easeInOut) for all transitions
- `PhaseAnimator` for loading/streaming states
- `Canvas` + `TimelineView` for background particle effects (optional, performance-gated)
- Custom `ViewModifier` for neon glow pulse and typing reveal
- `matchedGeometryEffect` for navigation transitions

Sources: [Apple Tutorials](https://developer.apple.com/tutorials/swiftui/animating-views-and-transitions), [Open SwiftUI Animations](https://github.com/amosgyamfi/open-swiftui-animations), [Pow Library](https://github.com/EmergeTools/Pow)

### Prior Art

- **Pow library** (EmergeTools): Dissolve, ripple, and particle transitions — could be used selectively for premium effects
- **SwiftUI Effects Library** (GetStream): Built-in particle systems (fire, smoke, confetti) — smoke effect could work for cyberpunk atmosphere
- **Arcade Hub template**: Full cyberpunk SwiftUI game template with neon glow, gradient borders, particle animations — validates feasibility

## Codebase Analysis

### Current Architecture (57 Swift files in ILSApp)

```
ILSApp/
├── ILSAppApp.swift          — App entry, AppState (ObservableObject), URL handling
├── ContentView.swift         — 5-tab TabView (Dashboard/Sessions/Projects/System/Settings)
├── Theme/
│   ├── ILSTheme.swift        — Color tokens, spacing, typography, ViewModifiers
│   ├── EntityType.swift      — 6 entity types with colors/gradients/icons
│   └── Components/           — StatCard, MetricChart, SparklineChart, CodeBlockView,
│                               ToolCallAccordion, ThinkingSection, ConnectionBanner,
│                               EmptyEntityState, SkeletonRow, ShimmerModifier,
│                               ProgressRing, ConnectionSteps, ILSCodeHighlighter
├── Views/
│   ├── Chat/                 — ChatView, MessageView, MarkdownTextView, CommandPaletteView
│   ├── Sessions/             — SessionsListView, NewSessionView, SessionInfoView,
│   │                           SessionTemplatesView
│   ├── Dashboard/            — DashboardView
│   ├── Projects/             — ProjectsListView, ProjectDetailView, ProjectSessionsListView
│   ├── Settings/             — SettingsView, TunnelSettingsView, LogViewerView,
│   │                           NotificationPreferencesView
│   ├── System/               — SystemMonitorView, ProcessListView, FileBrowserView
│   ├── MCP/                  — MCPServerListView, EditMCPServerView, MCPImportExportView
│   ├── Plugins/              — PluginsListView
│   ├── Skills/               — SkillsListView
│   └── Onboarding/           — ServerSetupSheet
├── ViewModels/               — ChatViewModel, SessionsViewModel, ProjectsViewModel,
│                               DashboardViewModel, SkillsViewModel, MCPViewModel,
│                               PluginsViewModel, SystemMetricsViewModel, BaseListViewModel
├── Services/                 — APIClient (actor), SSEClient, MetricsWebSocketClient, AppLogger
├── Models/                   — ChatMessage, SessionTemplate
└── Utils/                    — DateFormatters
```

### Backend Integration Layer (PRESERVE — DO NOT REBUILD)

| Component | Role | Lines | Modification Needed |
|-----------|------|-------|-------------------|
| `APIClient.swift` | Actor-based HTTP client with caching, retry, error handling | 306 | None — perfect as-is |
| `SSEClient.swift` | SSE streaming with reconnection, timeout racing | 249 | None — working validated |
| `AppState` (in ILSAppApp.swift) | Global state, connection management, URL handling | ~220 | Minor — update URL handling for new nav |
| `ChatViewModel.swift` | Message batching, stream processing, fork/retry | 434 | None — battle-tested |
| `ILSShared/` (15 files) | All shared models, DTOs, stream protocol | ~650 | None — shared with backend |
| `AppLogger.swift` | Structured logging | ~50 | None |
| `MetricsWebSocketClient.swift` | WebSocket for system metrics | ~100 | None |

### Components to REBUILD (Pure UI)

| Component | Current | Rebuild Scope |
|-----------|---------|---------------|
| `ContentView.swift` | 5-tab TabView | Side drawer + NavigationStack |
| `ILSTheme.swift` | Orange accent (#FF6B35), system dark | Full cyberpunk theme system |
| `EntityType.swift` | 6 entity colors (Apple-style) | Cyberpunk neon entity colors |
| All views in `Views/` | Current dark theme, tab-based | Complete rebuild with cyberpunk styling |
| Theme `Components/` | StatCard, CodeBlockView, etc. | Rebuild with neon glow, glass effects |
| `DashboardViewModel.swift` | Stats fetching | Keep logic, update for new dashboard layout |
| `SessionsViewModel.swift` | Session list + search | Keep logic, update for new list design |
| Other ViewModels | Data fetching | Keep fetch logic, may add animation states |

### Dependencies & Constraints

| Constraint | Impact |
|------------|--------|
| iOS 17+ minimum | Can use `PhaseAnimator`, `keyframeAnimator`, `Observable` macro |
| Swift 5.9 / Xcode | Standard SwiftUI capabilities |
| Backend on port 9090 | No change needed |
| SSE streaming protocol | Must preserve ChatStreamRequest format |
| ILSShared models | All models shared — cannot change without backend changes |
| Simulator UDID 50523130... | Must use this specific simulator for validation |
| Bundle ID com.ils.app | No change needed |
| URL scheme `ils://` | Must preserve deep link handling |

## 5 Design Direction Concepts

### Direction 1: "NEON NOIR" — Subtle Professional Cyberpunk

**Concept:** Clean, dark interface with restrained neon accents. Think Bloomberg Terminal meets Blade Runner — information-dense but elegant. Neon only on interactive elements.

**Color Palette:**
- Background: `#0A0A0F` (near-black with blue tint), `#12121A`, `#1C1C28`
- Primary Accent: `#00D4FF` (Ice Cyan)
- Secondary Accent: `#FF3366` (Soft Neon Pink)
- Text: `#E0E8F0` (Cool White), `#8892A0` (Muted Blue-Gray)
- Borders: `#2A2A3A` with subtle cyan glow on active

**Navigation:** Minimal side panel — slim rail with icons that expands to full width on tap/swipe. Profile avatar at top, settings gear at bottom.

**Key UI Elements:**
- Thin 1px neon borders on cards
- Subtle background grid pattern (very low opacity)
- Monospace `SF Mono` for data, `.rounded` for headings
- Status indicators as small neon dots
- Code blocks with faint cyan border glow

**Animation Philosophy:** Restrained. Smooth 0.3s spring transitions. Subtle fade-ins. No particle effects. Glow pulse only on active streaming indicator.

**Mood:** Professional, focused, data-driven. Like a high-end developer tool from 2077.

---

### Direction 2: "ELECTRIC GRID" — HUD-Style Interface

**Concept:** Heads-up display aesthetic with grid overlays, scan lines, and data readouts. Information presented like a military/sci-fi command center. Strong geometric patterns.

**Color Palette:**
- Background: `#050510` (Deep Navy), `#0D1117`, `#161B22`
- Primary Accent: `#00FF88` (Matrix Green)
- Secondary Accent: `#FF6B00` (Warning Orange)
- Tertiary: `#00AAFF` (HUD Blue)
- Text: `#C9D1D9` (Cool Gray), `#7D8590` (Dim)
- Grid lines: `#1A2332` (barely visible)

**Navigation:** Full-width side drawer with user profile section, connection status HUD, and categorized menu items. Each section has a thin horizontal scan-line divider.

**Key UI Elements:**
- Visible grid pattern overlay (very subtle, 3-5% opacity)
- Corner brackets `[ ]` around section titles
- Horizontal scan-line separators
- Data readout style for stats (monospace, left-aligned labels)
- Radar/pulse animation on dashboard
- Status bars with segmented fill

**Animation Philosophy:** Technical. Scan-line sweep on view transitions. Numbers count up on load. Grid pulse on data refresh. Typing cursor blink on streaming.

**Mood:** Military command center, tactical, information warfare.

---

### Direction 3: "SYNTHWAVE DREAMS" — Retro-Futuristic Glow

**Concept:** 80s retro-futurism meets modern UI. Strong use of gradients, saturated neon, and warm-cool contrast. Most visually bold option. Chrome text effects and sunset gradients.

**Color Palette:**
- Background: `#0F0418` (Deep Purple-Black), `#1A0A2E`, `#2D1B4E`
- Primary Accent: `#F72585` (Hot Pink)
- Secondary Accent: `#4CC9F0` (Electric Cyan)
- Tertiary: `#7B2CBF` (Purple)
- Gradient: Pink-to-cyan horizontal gradients on key elements
- Text: `#F0E6FF` (Lavender White), `#9B8CB8` (Muted Lavender)

**Navigation:** Slide-out drawer with gradient header containing user avatar and connection pulse. Menu items have left-accent bars in entity colors with glow.

**Key UI Elements:**
- Gradient borders (pink-to-cyan) on primary cards
- Background gradient wash (subtle purple-to-blue)
- Neon glow halos on avatars and icons
- Chrome/metallic effect on section headers
- Message bubbles with gradient tint
- Floating action button with pulsing glow

**Animation Philosophy:** Expressive. Smooth gradient transitions. Glow pulse on interactive elements. Particle sparkle on send. Wave effect on loading. Text shimmer on streaming.

**Mood:** Vibrant, energetic, creative. Like a neon-lit arcade in Tokyo.

---

### Direction 4: "GHOST PROTOCOL" — Minimal Stealth Cyber

**Concept:** Ultra-minimal with surgical precision. Almost monochrome with single accent color that shifts between screens. Transparency and depth through layered glass. Whisper-quiet aesthetic that feels like operating a stealth system.

**Color Palette:**
- Background: `#08080C` (Almost Black), `#101018`, `#1A1A24`
- Primary Accent: `#7DF9FF` (Ice Blue) — shifts per context
- Sessions: `#7DF9FF`, Projects: `#B5179E`, System: `#00FF88`
- Text: `#D0D8E0` (Silver), `#606878` (Slate)
- Glass: White at 5-8% opacity for card backgrounds

**Navigation:** Ultra-slim side rail (60pt) with only icons. Expands to 280pt on long-press with elegant spring animation. No text labels until expanded. Profile circle at top glows with connection status color.

**Key UI Elements:**
- Glassmorphism cards (`.ultraThinMaterial` with tint)
- Single-color accent that contextually shifts
- Hairline borders (0.5px at 20% opacity)
- Negative space as primary design element
- Minimal iconography, generous padding
- Status communicated through color, not text

**Animation Philosophy:** Minimal but precise. 0.25s ease-out transitions. Glass blur animate on appear. Accent color morphs between screens. No particles, no glow — just precision motion.

**Mood:** Stealth, elegant, surgical. Like a hacker's custom OS interface.

---

### Direction 5: "DATA STORM" — Maximum Cyberpunk Immersion

**Concept:** Full cyberpunk immersion with animated backgrounds, glitch effects, and dense information display. Most aggressive option. Rain/particle effects, terminal-style text, and raw data aesthetic.

**Color Palette:**
- Background: `#000000` (Pure Black), `#0A0E1A`, `#111827`
- Primary Accent: `#00FFFF` (Pure Cyan)
- Secondary Accent: `#FF0066` (Neon Red)
- Tertiary: `#FFEE00` (Warning Yellow)
- Text: `#00FF00` at 80% (Terminal Green) for data, `#E0E0E0` for content
- Error/Alert: `#FF0000` (Pure Red)

**Navigation:** Full-screen slide-over panel with translucent background showing blurred main content underneath. Terminal-style menu with `>` prefix on items. ASCII art header. Connection status shown as terminal output.

**Key UI Elements:**
- Animated rain/data-stream background (Canvas + TimelineView)
- Glitch effect on screen transitions (keyframeAnimator)
- Terminal-style monospace throughout
- Blinking cursor on all input fields
- Scanline overlay (horizontal lines at 2% opacity)
- Raw JSON preview available for all data
- Matrix-style falling characters behind chat (very subtle)

**Animation Philosophy:** Aggressive. Glitch transitions between screens. Data rain on background. Text types character-by-character everywhere. Pulse effects on streaming. Screen flicker on errors.

**Mood:** Full immersion, raw, intense. Like jacking into the Matrix.

---

### Design Direction Comparison

| Aspect | Neon Noir | Electric Grid | Synthwave | Ghost Protocol | Data Storm |
|--------|-----------|---------------|-----------|----------------|------------|
| Visual intensity | Low | Medium | High | Very Low | Maximum |
| Professional feel | Highest | High | Medium | High | Low |
| Animation density | Minimal | Moderate | Rich | Minimal | Heavy |
| Performance risk | None | Low | Medium | None | High |
| Implementation effort | M | L | L | M | XL |
| Accessibility | Best | Good | Fair | Good | Poorest |
| Chat readability | Excellent | Good | Good | Excellent | Fair |
| Unique factor | Refined elegance | HUD aesthetic | Gradient art | Glass minimalism | Raw immersion |

## Feasibility Assessment

| Aspect | Assessment | Notes |
|--------|------------|-------|
| Technical Viability | **High** | All SwiftUI views replaceable; backend untouched |
| Effort Estimate | **L** (Large) | ~57 view files to rebuild + new theme + new nav |
| Risk Level | **Medium** | SSE streaming must remain functional; side nav is custom work |

### Risk Areas

| Risk | Severity | Mitigation |
|------|----------|------------|
| SSE streaming breaks during rebuild | High | Preserve ChatViewModel/SSEClient untouched; test streaming first |
| Side drawer conflicts with NavigationStack gestures | Medium | Test edge-swipe vs back-swipe; may need custom gesture handling |
| Particle/Canvas effects hurt scroll performance | Medium | Gate behind `UIAccessibility.isReduceMotionEnabled`; test on device |
| Deep linking breaks with new navigation | Low | Update handleURL in AppState to work with new nav structure |
| Color contrast fails accessibility | Medium | Verify WCAG AA for all text/bg combos during build |

### What Changes vs. What Stays

**STAYS (zero modification):**
- `ILSShared/` package (15 files) — all models and DTOs
- `APIClient.swift` — actor-based HTTP client
- `SSEClient.swift` — SSE streaming client
- `ChatViewModel.swift` — message processing
- `MetricsWebSocketClient.swift` — system metrics
- `AppLogger.swift` — logging
- `DateFormatters.swift` — utilities
- Backend (all controllers, services, migrations)

**STAYS with minor updates:**
- `AppState` — update navigation handling (selectedTab -> selectedScreen)
- `ILSAppApp.swift` — update root view from ContentView to new root
- Other ViewModels — keep data fetching, add animation state properties

**FULL REBUILD:**
- `ContentView.swift` -> New root with side drawer
- `ILSTheme.swift` -> CyberpunkTheme (new colors, spacing, glow modifiers)
- `EntityType.swift` -> New neon entity colors
- All 13 Theme `Components/` -> Cyberpunk-styled equivalents
- All 20+ `Views/` -> Complete visual rebuild
- New: Side drawer navigation component
- New: Animated background effects (design-dependent)
- New: Custom transition modifiers

## Quality Commands

| Type | Command | Source |
|------|---------|--------|
| Build (Backend) | `swift build` | Package.swift |
| Build (iOS) | `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build` | Xcode project |
| Run Backend | `PORT=9090 swift run ILSBackend` | docs/RUNNING_BACKEND.md |
| Lint | Not found | No SwiftLint configured |
| TypeCheck | N/A (Swift compiler handles this) | — |
| Unit Test | `swift test` | Package.swift (ILSSharedTests, ILSBackendTests) |
| Integration Test | Not found | — |
| E2E Test | Not found | — |

**Local CI**: `swift build && xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator build`

**Validation**: Build in simulator -> Launch with backend running -> Screenshot each screen -> Verify visually

## Related Specs

| Spec | Relevance | Relationship | mayNeedUpdate |
|------|-----------|-------------|---------------|
| `ils-complete-rebuild` | **High** | Attempted full spec compliance rebuild; 42 tasks planned, only 3 completed. SSH/GitHub/design token work. **Superseded by this spec** — this spec replaces the UI/design portion entirely. | true — should be marked as partially superseded for UI work |
| `ios-app-polish2` | **High** | 63/63 tasks completed. Added 5-tab nav, system monitoring, tunnel settings, chat rendering, entity colors. **All this UI work will be replaced** by this rebuild. Backend features (tunnel, metrics) preserved. | false — completed, its backend features stay |
| `ios-app-polish` | **Medium** | Added ServerSetupSheet, deterministic IDs, plugin install, cancel button, session auto-navigate. Backend features preserved; UI will be rebuilt. | false — completed |
| `app-enhancements` | **Low** | Various enhancement tasks. | false |
| `remaining-audit-fixes` | **Low** | Code quality fixes (accessibility labels, font constants, async patterns). Patterns may be re-applied in new code. | false |
| `agent-teams` | **Low** | Unrelated feature area. | false |
| `app-improvements` | **Low** | General improvements. | false |

## Recommendations for Requirements

1. **Pick one design direction first** — present all 5 to user, get selection before any implementation planning. Each direction has different implementation complexity.

2. **Preserve the entire backend integration layer** — APIClient, SSEClient, ChatViewModel, ILSShared are battle-tested. Zero modifications needed. This cuts rebuild scope by ~40%.

3. **Build chat screen FIRST** — it's the core feature and highest risk. Validate SSE streaming works with new theme before building other screens.

4. **Custom side drawer over library** — no external dependency needed. SwiftUI offset-based approach with gesture support is well-documented and gives full control over cyberpunk styling.

5. **Gate animations behind reduce-motion** — already a pattern in codebase (`UIAccessibility.isReduceMotionEnabled`). Critical for App Store compliance and accessibility.

6. **Incremental validation** — build each screen, connect to backend, take screenshot, verify. The existing simulator automation workflow (UDID 50523130...) is proven.

7. **Typography decision needed** — SF Mono for all data? Custom font? System .rounded for headings? This affects every screen and should be decided upfront.

8. **Consider Directions 1 or 4 for readability** — "Neon Noir" and "Ghost Protocol" have the best chat readability scores. Chat is the primary feature.

## Open Questions

1. Which of the 5 design directions does the user prefer? (Determines entire implementation approach)
2. Should we use any custom fonts, or stick with SF system fonts styled differently?
3. Should the side drawer show on all screens or only the main screens (not within chat)?
4. What should the side drawer profile section contain? (Avatar, connection status, server info, cost summary?)
5. Should the animated background effects (rain, particles, grid) be present always or only on specific screens (dashboard, loading)?
6. Is there a preference for the chat bubble style — traditional bubbles, AI assistant cards, or full-width messages?

## Sources

### Web Sources
- [Metaverse Planet — Cyberpunk Color Palette Generator](https://metaverseplanet.net/blog/cyberpunk-color-palette-generator/)
- [Color-Hex — Cyberpunk Neon Palette](https://www.color-hex.com/color-palette/61235)
- [Medium — Making Things Glow in SwiftUI](https://medium.com/@garejakirit/making-things-glow-and-shine-with-swiftui-a83eec917203)
- [Medium — Translucent Glassy Nav Bar](https://medium.com/@garejakirit/creating-a-translucent-glassy-navigation-bar-in-ios-with-swiftui-fffd0e33400d)
- [Medium — Custom Drawer Menu SwiftUI](https://medium.com/@appdevinsights/creating-a-custom-drawer-menu-with-swiftui-0354afef92d8)
- [iOS App Templates — Navigation Drawer](https://iosapptemplates.com/blog/swiftui/navigation-drawer-swiftui)
- [Lanars — Side Menu Part 1](https://lanars.com/blog/sidemenu-in-swiftui-part1)
- [GitHub — SSSwiftUISideMenu](https://github.com/SimformSolutionsPvtLtd/SSSwiftUISideMenu)
- [MultitaskAI — Chat UI Design Trends 2025](https://multitaskai.com/blog/chat-ui-design/)
- [Medium — ChatGPT Typing Animation](https://medium.com/@ganeshrajugalla/swiftui-replicating-chatgpts-typing-like-animation-in-swiftui-913ba08a323a)
- [Apple — Animating Views and Transitions](https://developer.apple.com/tutorials/swiftui/animating-views-and-transitions)
- [GitHub — Open SwiftUI Animations](https://github.com/amosgyamfi/open-swiftui-animations)
- [GitHub — Pow Effects](https://github.com/EmergeTools/Pow)
- [Wendy Zhou — Futuristic UI Design](https://www.wendyzhou.se/blog/futuristic-ui-design-inspiration-tips/)
- [Dribbble — Cyberpunk UI](https://dribbble.com/search/cyberpunk-ui)
- [Muzli — Dark Mode Designs](https://muz.li/inspiration/dark-mode/)

### Codebase Files (Key References)
- `<project-root>/ILSApp/ILSApp/ILSAppApp.swift` — App entry + AppState
- `<project-root>/ILSApp/ILSApp/ContentView.swift` — Current 5-tab navigation
- `<project-root>/ILSApp/ILSApp/Theme/ILSTheme.swift` — Current theme system
- `<project-root>/ILSApp/ILSApp/Theme/EntityType.swift` — Entity colors
- `<project-root>/ILSApp/ILSApp/Services/APIClient.swift` — HTTP client (preserve)
- `<project-root>/ILSApp/ILSApp/Services/SSEClient.swift` — SSE streaming (preserve)
- `<project-root>/ILSApp/ILSApp/ViewModels/ChatViewModel.swift` — Chat logic (preserve)
- `<project-root>/ILSApp/ILSApp/Views/Chat/ChatView.swift` — Current chat UI
- `<project-root>/ILSApp/ILSApp/Models/ChatMessage.swift` — Chat message model
- `<project-root>/Sources/ILSShared/Models/StreamMessage.swift` — SSE protocol
- `<project-root>/Sources/ILSShared/DTOs/Requests.swift` — All API DTOs
- `<project-root>/Sources/ILSShared/Models/Session.swift` — Session model
- `<project-root>/Package.swift` — Swift package manifest
