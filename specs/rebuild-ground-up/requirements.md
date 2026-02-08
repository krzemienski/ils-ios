---
spec: rebuild-ground-up
phase: requirements
created: 2026-02-07T17:10:00Z
---

# Requirements: ILS iOS Complete Front-End Rebuild

## Goal

Rebuild the entire ILS iOS front-end from scratch with a Ghost Protocol design system (12 swappable themes), sidebar-first navigation, AI Assistant Card chat with tool call transparency, and iPad-native split-view layout — delivering App Store distribution quality with zero compromise on aesthetics, functionality, or chat experience.

## User Decisions

| Question | Decision |
|----------|----------|
| Primary users | End users via App Store |
| Priority tradeoffs | Feature completeness — all screens and themes must work before shipping |
| Success criteria | No compromises: premium look + full functionality + great chat experience |
| Design direction | Ghost Protocol — ultra-minimal stealth with professional polish |
| Typography | SF Mono (data/code) + SF Pro (body/headings) — system fonts only |
| Chat style | AI Assistant Cards (not bubbles) |
| Animation density | Subtle everywhere, 0.25s ease-out, reduce-motion gated |
| Navigation | Sidebar-first (overlay iPhone, persistent iPad) |
| Projects screen | None — sessions grouped by project directory in sidebar |

---

## User Stories

### US-1: Theme System Foundation

**As a** developer building subsequent screens
**I want** an AppTheme protocol with ThemeManager and Obsidian default theme
**So that** every view can pull consistent design tokens and themes are hot-swappable

**Acceptance Criteria:**
- [ ] AC-1.1: AppTheme protocol defines all tokens (backgrounds, accents, text, semantic, borders, entity colors, glass, geometry, spacing, typography) — minimum 30 tokens
- [ ] AC-1.2: ObsidianTheme implements all tokens matching hex values from design spec (#0A0A0F bgPrimary, #FF6933 accent, etc.)
- [ ] AC-1.3: ThemeManager as ObservableObject publishes `currentTheme` and persists selection to UserDefaults
- [ ] AC-1.4: `@Environment(\.theme)` custom EnvironmentKey injects theme into any view
- [ ] AC-1.5: GlassCard ViewModifier applies `glassBackground` + `glassBorder` + `cornerRadius` from current theme
- [ ] AC-1.6: App builds and launches in simulator with Obsidian theme visible on a placeholder screen

**Phase:** 1 | **Priority:** P0

---

### US-2: Sidebar Navigation

**As a** user on iPhone
**I want** a left-edge overlay sidebar showing my sessions grouped by project
**So that** I can quickly find and switch between conversations without a tab bar

**Acceptance Criteria:**
- [ ] AC-2.1: Sidebar opens from left edge via hamburger icon tap or left-edge swipe gesture
- [ ] AC-2.2: Sidebar is 280pt wide on iPhone, dismisses on tap-outside or swipe-left
- [ ] AC-2.3: Sessions listed grouped by project directory with collapsible group headers
- [ ] AC-2.4: Each session row shows name, relative time ("2h ago"), active indicator (colored dot if streaming)
- [ ] AC-2.5: Server connection status displayed at top (connected/disconnected/connecting + server name)
- [ ] AC-2.6: Search bar filters sessions by name or project
- [ ] AC-2.7: System health indicator (colored dot + label) visible near bottom
- [ ] AC-2.8: "+ New Session" CTA button with accent color at bottom
- [ ] AC-2.9: Settings gear icon navigates to Settings
- [ ] AC-2.10: Pull-to-refresh reloads session list from backend
- [ ] AC-2.11: Long-press session shows context menu (Rename, Export, Delete)
- [ ] AC-2.12: Tap session navigates to ChatView in main content area
- [ ] AC-2.13: Sidebar replaces the 5-tab TabView — no bottom tab bar exists

**Phase:** 2 | **Priority:** P0

---

### US-3: iPad Sidebar

**As a** user on iPad
**I want** a persistent sidebar alongside my content area
**So that** I can see sessions and content simultaneously without toggling

**Acceptance Criteria:**
- [ ] AC-3.1: Sidebar is persistent (always visible) on iPad in landscape (320pt wide)
- [ ] AC-3.2: Sidebar is persistent in iPad portrait (280pt wide)
- [ ] AC-3.3: Content area fills remaining width
- [ ] AC-3.4: `@Environment(\.horizontalSizeClass)` switches between overlay (compact) and persistent (regular)
- [ ] AC-3.5: iPad Stage Manager adapts — collapses sidebar below 600pt window width
- [ ] AC-3.6: All sidebar interactions from US-2 work identically on iPad

**Phase:** 9 | **Priority:** P1

---

### US-4: Chat View — Core Messaging

**As a** user chatting with AI
**I want** to send messages and see responses rendered as styled cards with markdown
**So that** I can have a productive conversation with clear, readable content

**Acceptance Criteria:**
- [ ] AC-4.1: User messages render as themed cards (bgSecondary background, textPrimary text, left-aligned)
- [ ] AC-4.2: Assistant messages render as AI Assistant Cards (not bubbles) with full markdown support (bold, italic, lists, links, headings)
- [ ] AC-4.3: Input field at bottom with placeholder "Message...", accent-colored send button when text present, gray when empty
- [ ] AC-4.4: Send message via send button or keyboard return — message appears immediately, SSE streaming begins
- [ ] AC-4.5: Navigation bar shows hamburger (opens sidebar), session name (tappable to rename), info button, overflow menu
- [ ] AC-4.6: Existing ChatViewModel, SSEClient, APIClient used with zero modification
- [ ] AC-4.7: Message list auto-scrolls to bottom on new messages
- [ ] AC-4.8: Timestamps shown on messages (e.g. "2:34 PM")

**Phase:** 3 | **Priority:** P0

---

### US-5: Chat View — Streaming & Stop

**As a** user waiting for an AI response
**I want** a streaming indicator and the ability to stop generation
**So that** I know the AI is working and can cancel if needed

**Acceptance Criteria:**
- [ ] AC-5.1: StreamingIndicator shows animated 3-dot typing animation during AI response
- [ ] AC-5.2: Status text displayed below dots (e.g. "Taking longer than expected..." after 30s)
- [ ] AC-5.3: Red stop button replaces send button during streaming
- [ ] AC-5.4: Tap stop calls `/sessions/:id/chat/cancel` endpoint and stops streaming
- [ ] AC-5.5: After stop/completion, input field and send button restore
- [ ] AC-5.6: Reduce motion: static text "Responding..." replaces animated dots

**Phase:** 3 | **Priority:** P0

---

### US-6: Chat View — Code Blocks

**As a** user viewing code in AI responses
**I want** syntax-highlighted code blocks with language labels and copy buttons
**So that** I can read and reuse code easily

**Acceptance Criteria:**
- [ ] AC-6.1: Code blocks render with bgTertiary background, borderSubtle 0.5px border, cornerRadiusSmall (8pt)
- [ ] AC-6.2: Language label top-left in SF Mono 11pt, textTertiary color
- [ ] AC-6.3: Copy button top-right, copies to clipboard on tap with visual feedback
- [ ] AC-6.4: SF Mono 13pt font for code content
- [ ] AC-6.5: Max height 300pt with scroll; tappable to expand
- [ ] AC-6.6: Syntax highlighting uses entity-derived colors for keywords, strings, comments

**Phase:** 3 | **Priority:** P0

---

### US-7: Chat View — Tool Call Transparency

**As a** user watching AI work
**I want** to see each tool call (Read, Write, Edit, Bash, Grep, etc.) with status and expandable details
**So that** I understand exactly what the AI is doing

**Acceptance Criteria:**
- [ ] AC-7.1: Tool calls grouped under "Tool Calls (N)" collapsible header
- [ ] AC-7.2: Each tool call shows: SF Symbol icon, tool name, status indicator
- [ ] AC-7.3: Status icons: spinner (running), checkmark in success color (done), X in error color (error)
- [ ] AC-7.4: All 10 tool types rendered with correct icon and display: Read (doc.text + file path), Write (doc.badge.plus + file path), Edit (pencil.line + file path + old/new preview), Bash (terminal + command + output), Grep (magnifyingglass + pattern + match count), Glob (folder.badge.questionmark + pattern + file count), WebSearch (globe + query), WebFetch (arrow.down.doc + URL), Task (person.2 + agent type), Skill (sparkles + skill name)
- [ ] AC-7.5: Tap individual tool call expands to show parameters and result
- [ ] AC-7.6: Tap group header expands/collapses all tool calls

**Phase:** 3 | **Priority:** P0

---

### US-8: Chat View — Thinking Sections

**As a** user curious about AI reasoning
**I want** to see collapsible thinking sections with duration
**So that** I can optionally peek into the AI's thought process

**Acceptance Criteria:**
- [ ] AC-8.1: Thinking section renders as collapsible block with "Thinking..." label and duration (e.g. "12s")
- [ ] AC-8.2: Collapsed by default, tappable to expand
- [ ] AC-8.3: Expanded content in italic text, textSecondary color
- [ ] AC-8.4: Error messages render as red-tinted cards with error color background
- [ ] AC-8.5: System messages render as centered textTertiary text (session started, forked, etc.)

**Phase:** 3 | **Priority:** P1

---

### US-9: Home Dashboard

**As a** user opening the app with no session selected
**I want** a dashboard with recent sessions, system health, and quick actions
**So that** I can orient myself and quickly get to work

**Acceptance Criteria:**
- [ ] AC-9.1: Dashboard shown as default content when no session is selected
- [ ] AC-9.2: Welcome message includes server name
- [ ] AC-9.3: Recent sessions section (last 3-5), each tappable to navigate to chat
- [ ] AC-9.4: System health summary card showing CPU %, Memory %, Disk %
- [ ] AC-9.5: Quick actions grid: New Session, Browse Skills (with count), MCP Servers (with count), Plugins (with count)
- [ ] AC-9.6: Tap quick action navigates to respective view
- [ ] AC-9.7: Connection status banner visible when disconnected
- [ ] AC-9.8: Tap system health card navigates to System Monitor

**Phase:** 4 | **Priority:** P1

---

### US-10: New Session Creation

**As a** user starting a new conversation
**I want** a modal sheet to pick project directory and create a session
**So that** I can start chatting with the right context

**Acceptance Criteria:**
- [ ] AC-10.1: Sheet presented as `.presentationDetents([.medium])` modal
- [ ] AC-10.2: Project directory picker dropdown populated from backend `/projects`
- [ ] AC-10.3: Optional session name field (auto-generated if empty)
- [ ] AC-10.4: Model selection if multiple available
- [ ] AC-10.5: "Create Session" CTA button with accent color
- [ ] AC-10.6: On creation: sheet dismisses, auto-navigates to new chat view
- [ ] AC-10.7: POST /sessions called with correct payload

**Phase:** 5 | **Priority:** P1

---

### US-11: System Monitor

**As a** user monitoring my server
**I want** real-time system metrics with charts
**So that** I can spot issues before they affect my work

**Acceptance Criteria:**
- [ ] AC-11.1: CPU usage shown as percentage + sparkline chart
- [ ] AC-11.2: Memory usage shown as used/total + sparkline
- [ ] AC-11.3: Disk usage shown as used/total + progress bar
- [ ] AC-11.4: Network activity shown as up/down rates
- [ ] AC-11.5: Process list showing name, CPU %, memory
- [ ] AC-11.6: File browser to navigate server filesystem
- [ ] AC-11.7: Pull-to-refresh updates all metrics
- [ ] AC-11.8: All data from GET /system/metrics endpoint

**Phase:** 6 | **Priority:** P2

---

### US-12: Settings

**As a** user customizing my app
**I want** a settings screen with server config, theme selection, and app info
**So that** I can personalize my experience and manage my connection

**Acceptance Criteria:**
- [ ] AC-12.1: Server Connection section: URL, port, health check status, edit capability
- [ ] AC-12.2: Appearance section links to Theme Picker
- [ ] AC-12.3: Tunnel section for Cloudflare tunnel config (if available)
- [ ] AC-12.4: Notifications preferences
- [ ] AC-12.5: About section: app version, build number, backend version
- [ ] AC-12.6: Logs section: view app logs (debug)

**Phase:** 7 | **Priority:** P1

---

### US-13: Theme Picker

**As a** user who wants to personalize the app
**I want** a grid of 12 theme previews I can tap to instantly switch
**So that** I can choose the aesthetic that suits me

**Acceptance Criteria:**
- [ ] AC-13.1: 2-column grid of theme preview cards
- [ ] AC-13.2: Each card shows: theme name, 3-4 color swatches (bgPrimary, accent, textPrimary, bgSecondary)
- [ ] AC-13.3: Active theme shows checkmark indicator
- [ ] AC-13.4: Tap card immediately switches theme app-wide with 0.3s easeInOut animation
- [ ] AC-13.5: Selection persists across app launches (UserDefaults)
- [ ] AC-13.6: All 12 themes selectable: Obsidian, Slate, Midnight, Ghost Protocol, Neon Noir, Electric Grid, Ember, Crimson, Carbon, Graphite, Paper, Snow

**Phase:** 7 | **Priority:** P1

---

### US-14: All 12 Themes Implemented

**As a** user browsing themes
**I want** all 12 themes to render correctly with their specified colors
**So that** every theme option delivers a distinct, polished experience

**Acceptance Criteria:**
- [ ] AC-14.1: Each of 10 dark themes uses correct bgPrimary, accent, and vibe per design spec
- [ ] AC-14.2: Both light themes (Paper, Snow) use light bgPrimary with correct accent colors
- [ ] AC-14.3: Entity colors consistent across all themes (entitySession blue, entityProject violet, etc.)
- [ ] AC-14.4: Glass effects adapt per theme (white opacity for dark themes, black opacity for light themes)
- [ ] AC-14.5: All text meets WCAG AA contrast ratio (4.5:1 for body text, 3:1 for large text) against their theme backgrounds
- [ ] AC-14.6: Semantic colors (success, warning, error, info) readable in all 12 themes

**Phase:** 12 | **Priority:** P1

---

### US-15: MCP/Skills/Plugins Browser

**As a** user exploring server extensions
**I want** a browsable list with segmented control for MCP, Skills, and Plugins
**So that** I can discover and manage what's available on my server

**Acceptance Criteria:**
- [ ] AC-15.1: Segmented control at top (MCP | Skills | Plugins)
- [ ] AC-15.2: Each item shows: name, description/summary, status (active/inactive), entity-colored indicator
- [ ] AC-15.3: Tap item navigates to detail view
- [ ] AC-15.4: Search/filter bar within each segment
- [ ] AC-15.5: Plugin install from marketplace via real git clone
- [ ] AC-15.6: Data from GET /mcp, GET /skills, GET /plugins endpoints

**Phase:** 8 | **Priority:** P2

---

### US-16: Onboarding / Server Setup

**As a** first-time user
**I want** a guided onboarding flow to connect to my backend
**So that** I can get started without reading documentation

**Acceptance Criteria:**
- [ ] AC-16.1: Welcome screen with ILS branding shown on first launch
- [ ] AC-16.2: Connection mode selection: Local / Remote / Tunnel
- [ ] AC-16.3: Server URL + port input fields
- [ ] AC-16.4: Health check with animated connection steps (reduce-motion: static steps)
- [ ] AC-16.5: Success state dismisses to main app
- [ ] AC-16.6: Connection settings saved for subsequent launches
- [ ] AC-16.7: Onboarding only shown when no saved server configuration exists

**Phase:** 10 | **Priority:** P1

---

### US-17: Animation Polish

**As a** user interacting with the app
**I want** subtle, consistent animations throughout
**So that** the app feels premium and responsive

**Acceptance Criteria:**
- [ ] AC-17.1: Sidebar open/close: 0.25s spring (response: 0.3, dampingFraction: 0.85)
- [ ] AC-17.2: Screen transitions: 0.2s easeOut
- [ ] AC-17.3: Card appear: 0.15s easeOut on onAppear
- [ ] AC-17.4: Glass blur: 0.3s easeInOut on modal present
- [ ] AC-17.5: Accent color morph: 0.4s easeInOut on entity context change
- [ ] AC-17.6: Streaming dots: 1.2s loop easeInOut
- [ ] AC-17.7: Skeleton shimmer: 1.5s loop linear during loading
- [ ] AC-17.8: Theme switch: 0.3s easeInOut
- [ ] AC-17.9: Button press: 0.1s easeOut on touch down
- [ ] AC-17.10: List items: 0.2s staggered spring on population
- [ ] AC-17.11: ALL animations disabled when `accessibilityReduceMotion` is true (transitions become `.none`)

**Phase:** 11 | **Priority:** P1

---

### US-18: Session Management

**As a** user organizing my conversations
**I want** to rename, export, fork, and delete sessions
**So that** I can manage my conversation history

**Acceptance Criteria:**
- [ ] AC-18.1: Tap session name in ChatView nav bar triggers inline rename
- [ ] AC-18.2: Overflow menu in ChatView offers: Export, Fork, Delete
- [ ] AC-18.3: Delete shows confirmation alert before calling DELETE /sessions/:id
- [ ] AC-18.4: Fork creates new session from current point
- [ ] AC-18.5: Export generates shareable session transcript

**Phase:** 3 | **Priority:** P2

---

### US-19: Deep Linking

**As a** user tapping an `ils://` URL
**I want** the app to navigate to the correct screen
**So that** external integrations can open specific sessions or views

**Acceptance Criteria:**
- [ ] AC-19.1: `ils://` URL scheme preserved and functional
- [ ] AC-19.2: Deep links navigate correctly within sidebar-based navigation (not tab-based)
- [ ] AC-19.3: AppState.handleURL updated for new navigation structure

**Phase:** 2 | **Priority:** P2

---

## Functional Requirements

| ID | Requirement | Priority | Phase | Acceptance Criteria |
|----|-------------|----------|-------|---------------------|
| FR-1 | AppTheme protocol with 30+ design tokens covering backgrounds, accents, text, semantic, borders, entity colors, glass, geometry, spacing, typography | P0 | 1 | Build compiles; all tokens accessible via `@Environment(\.theme)` |
| FR-2 | ThemeManager persists theme selection to UserDefaults and publishes changes | P0 | 1 | Theme survives app restart; switching theme updates all views |
| FR-3 | GlassCard ViewModifier renders translucent card with themed blur and border | P0 | 1 | Visual inspection: card shows glass effect on dark background |
| FR-4 | SidebarRootView replaces ContentView as app root — no TabView | P0 | 2 | No bottom tab bar visible; sidebar is only navigation |
| FR-5 | Custom sidebar with offset-based drawer, edge-swipe gesture, overlay dismiss | P0 | 2 | Swipe from left edge opens; tap outside closes; no external dependencies |
| FR-6 | Sessions grouped by project directory in sidebar with collapsible headers | P0 | 2 | Groups match session.projectPath; collapse/expand works |
| FR-7 | ChatView sends messages via existing ChatViewModel/SSEClient with zero modification | P0 | 3 | Send message → receive streamed response → tool calls render |
| FR-8 | AI Assistant Card layout for messages (not bubbles) | P0 | 3 | Messages render as full-width themed cards, not aligned bubbles |
| FR-9 | CodeBlockView with syntax highlighting, language label, copy button | P0 | 3 | Code block visually matches spec; copy works |
| FR-10 | ToolCallAccordion renders all 10 tool types with correct icons and expandable details | P0 | 3 | Each tool type identifiable; expand shows params + result |
| FR-11 | StreamingIndicator with animated dots and stop button | P0 | 3 | Dots animate; stop button cancels stream |
| FR-12 | Home Dashboard with recent sessions, health summary, quick actions | P1 | 4 | All data loads from backend; taps navigate correctly |
| FR-13 | New Session Sheet with project picker, name, model selection, auto-navigate | P1 | 5 | Session created via API; chat opens automatically |
| FR-14 | System Monitor with CPU/Memory/Disk/Network charts and process list | P2 | 6 | Charts render with real data from /system/metrics |
| FR-15 | Settings with server config, theme picker link, tunnel, about, logs | P1 | 7 | All sections accessible; server health check works |
| FR-16 | Theme Picker grid (2 columns) with live preview and instant switch | P1 | 7 | All 12 themes shown; tap switches immediately |
| FR-17 | MCP/Skills/Plugins browser with segmented control, search, detail views | P2 | 8 | Data loads; search filters; navigation to detail works |
| FR-18 | iPad persistent sidebar via NavigationSplitView with adaptive width | P1 | 9 | Sidebar visible at all times on iPad; content fills remainder |
| FR-19 | Onboarding flow: welcome, connection mode, URL input, health check, dismiss | P1 | 10 | First-run shows onboarding; subsequent launches skip it |
| FR-20 | Animation system matching all 10 transition specs from design.md | P1 | 11 | Each animation matches specified duration and curve |
| FR-21 | All 12 themes fully implemented with correct color values per design spec | P1 | 12 | Visual inspection of each theme against spec hex values |
| FR-22 | Reduce motion: all animations gated behind `accessibilityReduceMotion` | P0 | 11 | Enable reduce motion → zero animations, static indicators |
| FR-23 | Deep linking preserved with `ils://` scheme adapted for sidebar navigation | P2 | 2 | Deep link opens correct screen |
| FR-24 | Connection banner shown when backend disconnected; "Configure" for first-run, "Retry" for returning | P1 | 2 | Banner appears on disconnect; correct action shown |

---

## Non-Functional Requirements

| ID | Requirement | Metric | Target |
|----|-------------|--------|--------|
| NFR-1 | App launch to interactive | Time | < 2 seconds cold start on iPhone 15 |
| NFR-2 | Chat scroll performance | Frame rate | 60fps while scrolling message list with 100+ messages |
| NFR-3 | Theme switch latency | Time | < 0.5 seconds for full app re-render |
| NFR-4 | Memory footprint | Peak RAM | < 150MB during normal chat usage |
| NFR-5 | Sidebar gesture responsiveness | Latency | < 16ms response to touch (1 frame) |
| NFR-6 | Text contrast (WCAG AA) | Contrast ratio | 4.5:1 body text, 3:1 large text — all 12 themes |
| NFR-7 | Dynamic Type support | Font scaling | All text respects system Dynamic Type settings |
| NFR-8 | VoiceOver accessibility | Screen reader | All interactive elements have accessibility labels |
| NFR-9 | Reduce motion compliance | Animation | Zero animations when system setting enabled |
| NFR-10 | Offline resilience | Behavior | App launches and shows cached data when backend unreachable |
| NFR-11 | SSE streaming reliability | Uptime | Zero regressions from current validated streaming behavior |
| NFR-12 | Bundle size | App size | < 25MB (no custom fonts, no external dependencies) |
| NFR-13 | Minimum OS | iOS version | iOS 17.0+ |
| NFR-14 | iPad support | Layout | Dedicated split-view layout, not scaled iPhone UI |
| NFR-15 | Orientation | Support | Portrait + landscape on iPad; portrait on iPhone |

---

## Glossary

- **Ghost Protocol**: Selected design direction — ultra-minimal stealth aesthetic with single accent color, glassmorphism depth, and surgical precision
- **AppTheme**: Swift protocol defining all visual design tokens (colors, spacing, typography, geometry) for a theme
- **ThemeManager**: ObservableObject that manages the current theme and persists selection
- **GlassCard**: Translucent card effect using background opacity (5-8%) and border opacity (10-15%) for spatial hierarchy
- **AI Assistant Card**: Full-width styled card for AI responses (vs. aligned chat bubbles), better for rich content like code blocks and tool calls
- **ToolCallAccordion**: Collapsible component showing individual tool operations (Read, Write, Bash, etc.) with status, params, and results
- **SSE**: Server-Sent Events — the streaming protocol used for real-time AI responses
- **Entity Colors**: Consistent color system for 6 entity types (session=blue, project=violet, skill=amber, MCP=emerald, plugin=pink, system=cyan)
- **SidebarRootView**: New app root view replacing ContentView; manages sidebar + content area
- **Design Tokens**: Named values (colors, spacing, radii) that define the visual language of a theme
- **ILSShared**: Swift package containing models and DTOs shared between iOS app and backend — must not be modified

---

## Out of Scope

- Backend code changes (controllers, services, migrations, ILSShared models)
- New backend API endpoints
- Custom font loading (SF system fonts only)
- External SwiftUI dependencies or libraries (no Pow, no SSSwiftUISideMenu)
- Push notification implementation
- Authentication / login system
- App Store submission process (TestFlight, certificates, provisioning)
- Localization / internationalization
- watchOS or macOS companion apps
- Particle effects, data rain, glitch transitions (per Ghost Protocol direction)
- Desktop Claude integration (MCP bridging)
- Offline-first data sync (cache is read-only fallback)

---

## Dependencies

| Dependency | Type | Risk |
|------------|------|------|
| Backend running on port 9090 | Runtime | Must be running for any data-dependent validation |
| SSEClient / ChatViewModel unchanged | Code | Any modification risks breaking validated streaming |
| ILSShared package | Code | Shared models define data contracts — cannot change |
| iOS 17+ SDK features | Platform | PhaseAnimator, keyframeAnimator, Observable macro required |
| Xcode (current version) | Tooling | Build system for simulator validation |
| Simulator UDID 50523130-57AA-48B0-ABD0-4D59CE455F14 | Validation | All screenshots must use this simulator |
| AppState ObservableObject pattern | Code | New views must use @Published/@ObservedObject — not @Observable |

---

## Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| SSE streaming breaks during UI rebuild | Critical | Low | Preserve ChatViewModel/SSEClient untouched; validate streaming in Phase 3 before building other screens |
| Sidebar edge-swipe conflicts with NavigationStack back-swipe | High | Medium | Custom gesture handling with `.simultaneousGesture`; test on device early in Phase 2 |
| Chat scroll jank with complex tool call content | High | Medium | Lazy rendering, limit expanded tool calls, profile with Instruments in Phase 3 |
| Theme switch causes flash/layout jump | Medium | Medium | Use `withAnimation` wrapper on theme change; test all 12 themes in Phase 12 |
| Light themes (Paper, Snow) break glass effects | Medium | Medium | Glass modifier must detect theme lightness and swap white opacity for black opacity |
| iPad layout broken on Stage Manager | Medium | Low | Test with multiple window sizes in Phase 9 |
| 100+ message lists cause memory pressure | Medium | Medium | Use `LazyVStack` with message recycling; profile memory in Phase 3 |
| Deep link routing fails with new navigation | Low | Medium | Update AppState.handleURL in Phase 2; test all URL schemes |
| Accessibility contrast fails on some themes | High | Medium | Validate every theme against WCAG AA in Phase 12; adjust colors if needed |
| Reduce motion check missed on new animations | Medium | High | Code review checklist: every `withAnimation` wrapped in reduce-motion gate |

---

## Success Criteria

| Criterion | Measurement | Target |
|-----------|-------------|--------|
| All 10 screens functional | Screenshot evidence in simulator | 10/10 screens render with real backend data |
| All 12 themes render correctly | Visual inspection per theme | 12/12 themes match design spec hex values |
| Chat streaming works end-to-end | Send message, receive streamed response | SSE streaming identical to pre-rebuild behavior |
| Tool call transparency | Send message triggering tools, verify accordion | All 10 tool types render with correct icons and expandable details |
| iPad split-view works | iPad simulator screenshots | Persistent sidebar + content area, no overlap |
| No bottom tab bar | Screenshot of any screen | Zero tab bar visible |
| Sidebar navigation works | Open/close sidebar, navigate between sessions | Gesture + button both work; session switching is seamless |
| Animations respect reduce motion | Toggle setting, verify | Zero animations with reduce motion on |
| App Store quality | Holistic assessment | Premium look, zero visual glitches, smooth performance |
| Zero streaming regressions | Same test flow as 2026-02-05 SSE validation | Streaming indicator, stop button, timeout handling all work |

---

## Unresolved Questions

1. Should the sidebar show session message count or last message preview?
2. What happens when user has 50+ sessions across many projects — is there pagination or infinite scroll?
3. Should theme selection sync across devices (iCloud) or be device-local only?
4. Should the onboarding flow include a theme picker step?
5. What's the maximum number of tool calls to render before showing "Show N more..."?
6. Should the file browser in System Monitor support file operations (create, delete) or read-only?

---

## Next Steps

1. Approve requirements (user review)
2. Generate implementation tasks from user stories, one task per phase
3. Begin Phase 1: AppTheme protocol + Obsidian theme + ThemeManager
4. Validate each phase in simulator before proceeding to next
