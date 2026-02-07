# Tasks: ILS iOS Complete Front-End Rebuild

## Phase 1: Make It Work (POC) — Theme System Foundation

Focus: Prove the AppTheme protocol + ThemeManager + EnvironmentKey approach works. Build Obsidian theme, GlassCard modifier, and a placeholder screen to validate everything compiles and renders.

- [x] 1.1 Create AppTheme protocol and ObsidianTheme implementation
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/AppTheme.swift` with the `AppTheme` protocol defining all 35+ tokens: backgrounds (bgPrimary, bgSecondary, bgTertiary, bgSidebar), accents (accent, accentSecondary, accentGradient), text (textPrimary, textSecondary, textTertiary, textOnAccent), semantic (success, warning, error, info), borders (border, borderSubtle, divider), entity colors (entitySession, entityProject, entitySkill, entityMCP, entityPlugin, entitySystem), glass (glassBackground, glassBorder), geometry (cornerRadius, cornerRadiusSmall, cornerRadiusLarge), spacing (spacingXS/SM/MD/LG/XL), typography sizes (fontCaption, fontBody, fontTitle3, fontTitle2, fontTitle1)
    2. Add `ThemeManager` class as `ObservableObject` with `@Published var currentTheme: any AppTheme`, persisting theme ID to UserDefaults, with `func setTheme(_ id: String)` method
    3. Add `ThemeEnvironmentKey` conforming to `EnvironmentKey` with `ObsidianTheme` as default, plus `extension EnvironmentValues` for `\.theme`
    4. Create `ILSApp/ILSApp/Theme/Themes/ObsidianTheme.swift` implementing all tokens with exact hex values from design spec (#0A0A0F bgPrimary, #FF6933 accent, #E8ECF0 textPrimary, etc.)
  - **Files**:
    - `ILSApp/ILSApp/Theme/AppTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/ObsidianTheme.swift` (create)
  - **Done when**: Protocol has 35+ tokens, ObsidianTheme compiles with all values, ThemeManager publishes changes, `@Environment(\.theme)` available
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(theme): add AppTheme protocol, ObsidianTheme, and ThemeManager`
  - _Requirements: AC-1.1, AC-1.2, AC-1.3, AC-1.4_
  - _Design: Section 3 — Design System: AppTheme Protocol_

- [x] 1.2 Create GlassCard ViewModifier and AccentButton
  - **Do**:
    1. Create `ILSApp/ILSApp/Theme/GlassCard.swift` with `GlassCard: ViewModifier` that reads `@Environment(\.theme)` and applies `theme.glassBackground` background + `theme.glassBorder` 0.5px stroke + `theme.cornerRadius` clip shape
    2. Add `View` extension: `.glassCard()` convenience
    3. Create `AccentButton` view: themed CTA button using accent color, cornerRadiusSmall, textOnAccent for label
    4. Create `EntityBadge` view: small colored dot/icon using entity colors from theme
  - **Files**:
    - `ILSApp/ILSApp/Theme/GlassCard.swift` (create)
    - `ILSApp/ILSApp/Theme/Components/AccentButton.swift` (create)
    - `ILSApp/ILSApp/Theme/Components/EntityBadge.swift` (create)
  - **Done when**: `.glassCard()` modifier applies glass effect from current theme, AccentButton renders with accent color
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(theme): add GlassCard modifier, AccentButton, EntityBadge`
  - _Requirements: AC-1.5_
  - _Design: Section 5 — Component Library, Glass Card Spec_

- [x] 1.3 Wire ThemeManager into app root and validate in simulator
  - **Do**:
    1. Modify `ILSAppApp.swift`: add `@StateObject private var themeManager = ThemeManager()`, inject as `.environmentObject(themeManager)` and `.environment(\.theme, themeManager.currentTheme)` on root view
    2. Create a temporary `ThemeTestView.swift` that displays: bgPrimary background, a GlassCard with accent-colored text, an AccentButton, and EntityBadge for each entity type — proving all tokens work
    3. Temporarily set `ThemeTestView` as the root view content (will revert in Phase 2)
    4. Build and launch in simulator UDID 50523130-57AA-48B0-ABD0-4D59CE455F14
    5. Capture screenshot evidence
  - **Files**:
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify — add themeManager injection)
    - `ILSApp/ILSApp/Views/ThemeTestView.swift` (create — temporary)
  - **Done when**: App launches showing Obsidian theme colors, glass card visible, accent button rendered, all 6 entity badges colored correctly
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(theme): wire ThemeManager into app root, validate Obsidian theme`
  - _Requirements: AC-1.6_
  - _Design: Section 3_

- [x] V1 [VERIFY] Phase 1 checkpoint: build + simulator screenshot
  - **Do**:
    1. Build iOS app
    2. Boot simulator if needed: `xcrun simctl boot 50523130-57AA-48B0-ABD0-4D59CE455F14`
    3. Install and launch app
    4. Capture screenshot: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase1-theme.png`
    5. Verify screenshot shows dark background (#0A0A0F), orange accent (#FF6933), glass card, entity badges
  - **Verify**: `test -f specs/rebuild-ground-up/evidence/phase1-theme.png && echo "PASS: Screenshot captured"`
  - **Done when**: Screenshot exists showing Obsidian theme rendering correctly
  - **Commit**: `chore(rebuild): capture Phase 1 theme validation evidence`

---

## Phase 2: Sidebar Navigation (US-2, US-19)

Focus: Replace ContentView's TabView with SidebarRootView. Custom offset-based drawer on iPhone. Sessions grouped by project. Deep linking updated.

- [x] 2.1 Create SidebarRootView as new app root
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` — ZStack with main content area + sidebar overlay
    2. State: `@State var isSidebarOpen: Bool = false`, `@State var selectedSession: ChatSession?`, `@State var activeScreen: ActiveScreen` enum (home, chat, system, settings, browser)
    3. Main content: `NavigationStack` containing switch on `activeScreen`
    4. Sidebar: overlay from left with 280pt width, dimmed tap-to-dismiss background, left-edge swipe gesture via `DragGesture` on overlay
    5. Hamburger button in toolbar opens sidebar
    6. Delete `ThemeTestView.swift` (temporary from Phase 1)
    7. Update `ILSAppApp.swift`: replace `ContentView()` with `SidebarRootView()`, remove onboarding sheet (will be re-added in Phase 10)
  - **Files**:
    - `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (create)
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify — swap root view)
    - `ILSApp/ILSApp/Views/ThemeTestView.swift` (delete)
  - **Done when**: App launches with no tab bar, hamburger opens/closes sidebar, main content area shows placeholder
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(nav): replace TabView with SidebarRootView`
  - _Requirements: AC-2.1, AC-2.2, AC-2.13, FR-4, FR-5_
  - _Design: Section 2 — Information Architecture, Section 4.1 — Sidebar_

- [x] 2.2 Build SidebarView with session list grouped by project
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Root/SidebarView.swift` — full sidebar content
    2. Top: connection status (green/red dot + server name from AppState)
    3. SearchBar component for filtering sessions
    4. Session list: use `SessionsViewModel` to load sessions, group by `session.projectPath` or `session.projectName`, render collapsible `DisclosureGroup` per project
    5. Create `ILSApp/ILSApp/Views/Root/SidebarSessionRow.swift` — shows session name, relative time (use DateFormatters), active dot (colored if streaming), entity color for sessions
    6. Bottom: system health indicator (compact dot + label), settings gear icon button, "+ New Session" AccentButton
    7. Pull-to-refresh on session list via `.refreshable`
    8. Long-press context menu on session rows: Rename, Export, Delete
    9. Tap session -> set `selectedSession` in parent, close sidebar
  - **Files**:
    - `ILSApp/ILSApp/Views/Root/SidebarView.swift` (create)
    - `ILSApp/ILSApp/Views/Root/SidebarSessionRow.swift` (create)
  - **Done when**: Sidebar shows real sessions from backend grouped by project, tapping a session closes sidebar
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(nav): build SidebarView with grouped sessions and search`
  - _Requirements: AC-2.3, AC-2.4, AC-2.5, AC-2.6, AC-2.7, AC-2.8, AC-2.9, AC-2.10, AC-2.11, AC-2.12, FR-6_
  - _Design: Section 4.1 — Sidebar_

- [x] 2.3 Update deep linking for sidebar navigation
  - **Do**:
    1. Update `AppState.handleURL` to set `activeScreen` enum values instead of `selectedTab` strings
    2. Add `@Published var activeScreen: ActiveScreen = .home` to AppState (or keep navigation in SidebarRootView and have AppState publish navigation intents)
    3. Support `ils://sessions`, `ils://settings`, `ils://system` routing to correct screen
    4. Add connection banner logic: show "Configure" for first-run, "Retry" for returning users (reuse ConnectionBanner component, adapt for new theme)
  - **Files**:
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify AppState.handleURL)
    - `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (modify — wire deep links)
  - **Done when**: Deep links navigate correctly within sidebar-based navigation
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(nav): update deep linking for sidebar navigation`
  - _Requirements: AC-19.1, AC-19.2, AC-19.3, FR-23, FR-24_
  - _Design: Section 2 — Navigation Flows_

- [x] V2 [VERIFY] Phase 2 checkpoint: sidebar + navigation validation
  - **Do**:
    1. Build and install app on simulator
    2. Start backend: `PORT=9090 swift run ILSBackend` (if not running)
    3. Launch app, capture screenshot of home with sidebar closed
    4. Open sidebar (hamburger tap), capture screenshot showing session list grouped by project
    5. Tap a session, verify navigation to chat area
    6. Verify no bottom tab bar in any screenshot
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase2-sidebar.png && echo "PASS"`
  - **Done when**: Screenshots show sidebar with sessions grouped by project, no tab bar, navigation works
  - **Commit**: `chore(rebuild): capture Phase 2 sidebar validation evidence`

---

## Phase 3: Chat View (US-4, US-5, US-6, US-7, US-8, US-18)

Focus: Highest-risk phase. Rebuild entire ChatView with AI Assistant Card layout, themed components. Must preserve ChatViewModel/SSEClient integration exactly. Split into 5 sub-tasks.

- [ ] 3.1 Create UserMessageCard and AssistantCard components
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Chat/UserMessageCard.swift` — full-width card with bgSecondary background, textPrimary text, left-aligned, themed cornerRadius. Show timestamp. Context menu: Copy, Delete
    2. Create `ILSApp/ILSApp/Views/Chat/AssistantCard.swift` — AI Assistant Card (NOT bubble): full-width themed card with glassCard modifier, renders child content slots for markdown text, code blocks, tool calls, thinking. Show timestamp + cost if available
    3. Both cards read `@Environment(\.theme)` for all colors/spacing
    4. Cards are NOT aligned left/right like bubbles — both are full-width cards with role indicators
  - **Files**:
    - `ILSApp/ILSApp/Views/Chat/UserMessageCard.swift` (create)
    - `ILSApp/ILSApp/Views/Chat/AssistantCard.swift` (create)
  - **Done when**: Both card types compile, use theme tokens, render text with timestamps
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): create UserMessageCard and AssistantCard components`
  - _Requirements: AC-4.1, AC-4.2, AC-4.8, FR-8_
  - _Design: Section 8 — Chat Content Rendering Spec, Message Layout_

- [x] 3.2 Rebuild CodeBlockView and MarkdownTextView with theme
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` — bgTertiary background, borderSubtle 0.5px border, cornerRadiusSmall (8pt), SF Mono 13pt, language label top-left (SF Mono 11pt, textTertiary), copy button top-right with clipboard + visual feedback, max height 300pt with ScrollView, tap to expand
    2. Update `ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift` — use theme tokens for colors (textPrimary, accent for links), detect and render code blocks via CodeBlockView, handle bold, italic, lists, links, headings with SF Pro
    3. All colors from `@Environment(\.theme)`, not hardcoded ILSTheme statics
  - **Files**:
    - `ILSApp/ILSApp/Theme/Components/CodeBlockView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Chat/MarkdownTextView.swift` (rewrite)
  - **Done when**: Code blocks show language label, copy button, syntax highlighting with entity colors; markdown renders headings, bold, italic, lists, links
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): rebuild CodeBlockView and MarkdownTextView with theme tokens`
  - _Requirements: AC-6.1, AC-6.2, AC-6.3, AC-6.4, AC-6.5, AC-6.6, FR-9_
  - _Design: Section 8 — Code Block Spec_

- [x] 3.3 Rebuild ToolCallAccordion with all 10 tool types
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` — collapsible accordion with SF Symbol icon per tool type, tool name, status indicator (spinner running, checkmark success, X error)
    2. Map all 10 tool types to correct icons: Read→doc.text, Write→doc.badge.plus, Edit→pencil.line, Bash→terminal, Grep→magnifyingglass, Glob→folder.badge.questionmark, WebSearch→globe, WebFetch→arrow.down.doc, Task→person.2, Skill→sparkles
    3. Collapsed: single row (icon + name + status). Expanded: shows parameters and result content
    4. Group header: "Tool Calls (N)" that expands/collapses all
    5. Use theme tokens for all colors, spacing, corner radii
  - **Files**:
    - `ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` (rewrite)
  - **Done when**: Each of 10 tool types renders with correct icon; expand/collapse works; group header toggles all
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): rebuild ToolCallAccordion with 10 tool types and theme tokens`
  - _Requirements: AC-7.1, AC-7.2, AC-7.3, AC-7.4, AC-7.5, AC-7.6, FR-10_
  - _Design: Section 8 — Tool Call Accordion Spec, Tool Call Types table_

- [x] V3 [VERIFY] Quality checkpoint: build compiles with chat components
  - **Do**: Build iOS target to verify all new/rewritten chat components compile together
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds with zero errors
  - **Commit**: `chore(rebuild): pass quality checkpoint` (only if fixes needed)

- [x] 3.4 Rebuild StreamingIndicator, ThinkingSection, and error/system views
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift` — animated 3-dot typing indicator (1.2s easeInOut loop), status text below, reduce-motion: static "Responding..." text. Use theme colors
    2. Rewrite `ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` — collapsible "Thinking..." label with duration, collapsed by default, italic textSecondary content when expanded
    3. Create `ILSApp/ILSApp/Views/Chat/ErrorMessageView.swift` — red-tinted card using theme error color at low opacity
    4. Create `ILSApp/ILSApp/Views/Chat/SystemMessageView.swift` — centered textTertiary text for system events
  - **Files**:
    - `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift` (create)
    - `ILSApp/ILSApp/Theme/Components/ThinkingSection.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Chat/ErrorMessageView.swift` (create)
    - `ILSApp/ILSApp/Views/Chat/SystemMessageView.swift` (create)
  - **Done when**: Streaming dots animate, thinking section collapses/expands with duration, errors show red card, system messages centered
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): add StreamingIndicator, ThinkingSection, error/system views`
  - _Requirements: AC-5.1, AC-5.2, AC-5.6, AC-8.1, AC-8.2, AC-8.3, AC-8.4, AC-8.5, FR-11_
  - _Design: Section 8 — Message Content Types table_

- [x] 3.5 Rebuild ChatView with new components and ChatViewModel integration
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Views/Chat/ChatView.swift` — use new card components instead of MessageView/bubbles
    2. Navigation bar: hamburger icon (opens sidebar via callback/binding), session name (tappable to rename inline), info button, overflow menu (Export, Fork, Delete)
    3. Message list: `LazyVStack` in ScrollView with auto-scroll to bottom on new messages
    4. Input area: text field with "Message..." placeholder, accent-colored send button (gray when empty), red stop button during streaming
    5. Wire existing `ChatViewModel` with ZERO modification: `.task { viewModel.configure(client: appState.apiClient, sseClient: appState.sseClient) }` etc.
    6. Preserve all existing functionality: fork, session info sheet, error alerts, command palette, external session read-only banner
    7. Keep existing `ChatInputView` logic (haptics, reduce-motion) but restyle with theme tokens
    8. Delete old `MessageView.swift` — replaced by UserMessageCard + AssistantCard pattern in ChatView's message rendering
  - **Files**:
    - `ILSApp/ILSApp/Views/Chat/ChatView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Chat/MessageView.swift` (delete — functionality moved to cards)
  - **Done when**: Chat sends messages via existing ChatViewModel, SSE streaming works, tool calls render in accordion, code blocks highlight, stop button cancels
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): rebuild ChatView with AI Assistant Cards and theme`
  - _Requirements: AC-4.3, AC-4.4, AC-4.5, AC-4.6, AC-4.7, AC-5.3, AC-5.4, AC-5.5, FR-7_
  - _Design: Section 4.3 — Chat View_

- [x] 3.6 Session management: rename, export, fork, delete
  - **Do**:
    1. Implement inline rename: tapping session name in nav bar shows TextField overlay for editing, calls PATCH /sessions/:id
    2. Overflow menu items: Export (generate transcript text, share sheet), Fork (existing viewModel.forkSession), Delete (confirmation alert, DELETE /sessions/:id)
    3. Wire these into the rebuilt ChatView toolbar
  - **Files**:
    - `ILSApp/ILSApp/Views/Chat/ChatView.swift` (modify — add rename + export)
  - **Done when**: Rename, export, fork, delete all functional from ChatView toolbar menu
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(chat): add session rename, export, fork, delete`
  - _Requirements: AC-18.1, AC-18.2, AC-18.3, AC-18.4, AC-18.5_
  - _Design: Section 4.3 — Navigation Bar_

- [x] V4 [VERIFY] Phase 3 critical: SSE streaming end-to-end in simulator
  - **Do**:
    1. Ensure backend running: `PORT=9090 swift run ILSBackend`
    2. Build, install, launch app
    3. Open sidebar, tap a session (or create one)
    4. Send a message (e.g. "What is 2+2?")
    5. Capture screenshot showing streaming indicator (animated dots)
    6. Wait for response, capture screenshot showing AI Assistant Card with rendered markdown
    7. Verify tool calls render if any were triggered
    8. Verify stop button appears during streaming
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase3-chat.png && echo "PASS"`
  - **Done when**: Message sent, streaming indicator shown, response rendered as AI Assistant Card with code/tool calls, no regressions from pre-rebuild SSE behavior
  - **Commit**: `chore(rebuild): capture Phase 3 chat validation evidence`

---

## Phase 4: Home Dashboard (US-9)

- [x] 4.1 Build HomeView dashboard
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Home/HomeView.swift` — default content when no session selected
    2. Welcome message with server name (from AppState)
    3. Recent sessions section (last 5 from SessionsViewModel), each tappable to navigate to chat
    4. System health summary card (CPU %, Memory %, Disk %) using DashboardViewModel — tappable to navigate to System Monitor
    5. Quick actions grid (2x2): New Session, Browse Skills (count), MCP Servers (count), Plugins (count) — taps navigate to respective views
    6. Connection status banner when disconnected
    7. All styled with theme tokens and GlassCard modifiers
    8. Rewrite `ILSApp/ILSApp/Theme/Components/StatCard.swift` with theme tokens
    9. Rewrite `ILSApp/ILSApp/Theme/Components/SparklineChart.swift` with theme tokens
  - **Files**:
    - `ILSApp/ILSApp/Views/Home/HomeView.swift` (create — replaces DashboardView)
    - `ILSApp/ILSApp/Theme/Components/StatCard.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/SparklineChart.swift` (rewrite)
  - **Done when**: Dashboard shows real backend data, taps navigate, health card shows metrics
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(home): build HomeView dashboard with health stats and quick actions`
  - _Requirements: AC-9.1, AC-9.2, AC-9.3, AC-9.4, AC-9.5, AC-9.6, AC-9.7, AC-9.8, FR-12_
  - _Design: Section 4.2 — Home Dashboard_

- [x] V5 [VERIFY] Phase 4 checkpoint: dashboard with backend data
  - **Do**:
    1. Build, install, launch with backend running
    2. Verify home screen shows with welcome message, recent sessions, health stats
    3. Tap a recent session, verify navigation to chat
    4. Capture screenshot
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase4-home.png && echo "PASS"`
  - **Done when**: Dashboard renders real data from backend
  - **Commit**: `chore(rebuild): capture Phase 4 dashboard validation evidence`

---

## Phase 5: New Session Creation (US-10)

- [x] 5.1 Build NewSessionSheet
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift` — modal sheet with `.presentationDetents([.medium])`
    2. Project directory picker: dropdown populated from `ProjectsViewModel` (GET /projects)
    3. Optional session name field (auto-generated if empty)
    4. Model selection picker
    5. "Create Session" AccentButton CTA
    6. On creation: POST /sessions, dismiss sheet, callback to parent to navigate to new chat
    7. Theme all elements with `@Environment(\.theme)` tokens
  - **Files**:
    - `ILSApp/ILSApp/Views/Sessions/NewSessionView.swift` (rewrite)
  - **Done when**: Sheet opens, project picker populated from backend, session created via API, auto-navigates to chat
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(sessions): rebuild NewSessionSheet with theme and project picker`
  - _Requirements: AC-10.1, AC-10.2, AC-10.3, AC-10.4, AC-10.5, AC-10.6, AC-10.7, FR-13_
  - _Design: Section 4.4 — New Session Sheet_

- [x] V6 [VERIFY] Quality checkpoint: build + new session flow
  - **Do**: Build app, verify new session creation compiles and all views integrate
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Build succeeds
  - **Commit**: `chore(rebuild): pass quality checkpoint` (only if fixes needed)

---

## Phase 6: System Monitor (US-11)

- [x] 6.1 Rebuild SystemMonitorView with theme
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` — CPU sparkline, memory sparkline, disk progress bar, network up/down rates, all styled with theme tokens and GlassCard
    2. Rewrite `ILSApp/ILSApp/Theme/Components/MetricChart.swift` with theme colors
    3. Rewrite `ILSApp/ILSApp/Views/System/ProcessListView.swift` — themed process list
    4. Rewrite `ILSApp/ILSApp/Views/System/FileBrowserView.swift` — themed file browser
    5. Pull-to-refresh with `.refreshable`
    6. Data from existing `SystemMetricsViewModel` (GET /system/metrics)
  - **Files**:
    - `ILSApp/ILSApp/Views/System/SystemMonitorView.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/MetricChart.swift` (rewrite)
    - `ILSApp/ILSApp/Views/System/ProcessListView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/System/FileBrowserView.swift` (rewrite)
  - **Done when**: System monitor shows real CPU/memory/disk/network data with themed sparklines
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(system): rebuild SystemMonitorView with theme and charts`
  - _Requirements: AC-11.1, AC-11.2, AC-11.3, AC-11.4, AC-11.5, AC-11.6, AC-11.7, AC-11.8, FR-14_
  - _Design: Section 4.5 — System Monitor_

- [x] V7 [VERIFY] Phase 6 checkpoint: system monitor with real data
  - **Do**: Build, launch with backend, navigate to System Monitor from sidebar, capture screenshot
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase6-system.png && echo "PASS"`
  - **Done when**: System monitor renders real metrics from backend
  - **Commit**: `chore(rebuild): capture Phase 6 system monitor validation evidence`

---

## Phase 7: Settings + Theme Picker (US-12, US-13)

- [x] 7.1 Rebuild SettingsView with theme
  - **Do**:
    1. Rewrite `ILSApp/ILSApp/Views/Settings/SettingsView.swift` — List with sections:
       - Server Connection: URL, port, health check status dot, edit capability
       - Appearance: link to Theme Picker
       - Tunnel: Cloudflare tunnel config (rewrite TunnelSettingsView with theme)
       - Notifications: preferences (rewrite NotificationPreferencesView)
       - About: app version, build, backend version
       - Logs: link to log viewer (rewrite LogViewerView)
    2. All styled with theme tokens, GlassCard backgrounds for sections
    3. Rewrite `TunnelSettingsView.swift`, `NotificationPreferencesView.swift`, `LogViewerView.swift` with theme
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/SettingsView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Settings/TunnelSettingsView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Settings/NotificationPreferencesView.swift` (rewrite)
    - `ILSApp/ILSApp/Views/Settings/LogViewerView.swift` (rewrite)
  - **Done when**: Settings shows all sections with themed styling, health check works
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(settings): rebuild SettingsView with all sections and theme`
  - _Requirements: AC-12.1, AC-12.2, AC-12.3, AC-12.4, AC-12.5, AC-12.6, FR-15_
  - _Design: Section 4.6 — Settings_

- [x] 7.2 Build ThemePickerView with live preview
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` — 2-column LazyVGrid of theme preview cards
    2. Each card: theme name, 4 color swatches (bgPrimary, accent, textPrimary, bgSecondary), checkmark on active theme
    3. Tap: immediately switch theme via `themeManager.setTheme(id)` with 0.3s easeInOut animation
    4. For now, only Obsidian is fully implemented — other cards show placeholder swatches but are tappable (themes added in Phase 12)
    5. Navigate from Settings > Appearance
  - **Files**:
    - `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` (create)
  - **Done when**: Grid renders all 12 theme cards, tapping Obsidian shows checkmark, other themes register tap (even if colors identical for now)
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(settings): add ThemePickerView with grid and live switching`
  - _Requirements: AC-13.1, AC-13.2, AC-13.3, AC-13.4, AC-13.5, FR-16_
  - _Design: Section 4.8 — Theme Picker_

- [x] V8 [VERIFY] Phase 7 checkpoint: settings + theme picker
  - **Do**: Build, navigate to Settings, then Theme Picker. Capture screenshots
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase7-settings.png && echo "PASS"`
  - **Done when**: Settings and theme picker render correctly
  - **Commit**: `chore(rebuild): capture Phase 7 settings validation evidence`

---

## Phase 8: MCP/Skills/Plugins Browser (US-15)

- [x] 8.1 Build BrowserView with segmented control
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Browser/BrowserView.swift` — segmented control (MCP | Skills | Plugins) at top
    2. Each segment: scrollable list with search/filter bar, items showing name, description, status, entity-colored indicator (entityMCP, entitySkill, entityPlugin)
    3. Tap item: NavigationLink to detail view
    4. Rewrite `MCPServerListView.swift`, `SkillsListView.swift`, `PluginsListView.swift` as themed sub-views or inline in BrowserView
    5. Plugin install from marketplace via existing git clone logic
    6. Use existing ViewModels: MCPViewModel, SkillsViewModel, PluginsViewModel
    7. Delete unused views: `EditMCPServerView.swift`, `MCPImportExportView.swift`, `ProjectDetailView.swift`, `ProjectSessionsListView.swift`, `ProjectsListView.swift`, `SessionsListView.swift`, `SessionInfoView.swift`, `SessionTemplatesView.swift`, `CommandPaletteView.swift`
  - **Files**:
    - `ILSApp/ILSApp/Views/Browser/BrowserView.swift` (create)
    - `ILSApp/ILSApp/Views/MCP/MCPServerListView.swift` (rewrite or delete — inline in BrowserView)
    - `ILSApp/ILSApp/Views/Skills/SkillsListView.swift` (rewrite or delete — inline)
    - `ILSApp/ILSApp/Views/Plugins/PluginsListView.swift` (rewrite or delete — inline)
    - Old views to delete: `EditMCPServerView.swift`, `MCPImportExportView.swift`, `ProjectDetailView.swift`, `ProjectSessionsListView.swift`, `ProjectsListView.swift`, `SessionsListView.swift`, `SessionInfoView.swift`, `SessionTemplatesView.swift`, `CommandPaletteView.swift`
  - **Done when**: Browser shows MCP/Skills/Plugins with segmented switching, search works, data from backend
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(browser): build MCP/Skills/Plugins browser with segmented control`
  - _Requirements: AC-15.1, AC-15.2, AC-15.3, AC-15.4, AC-15.5, AC-15.6, FR-17_
  - _Design: Section 4.7 — MCP/Skills/Plugins Browser_

- [x] V9 [VERIFY] Phase 8 checkpoint: browser with backend data
  - **Do**: Build, navigate to Browser from home quick actions, verify all 3 segments load data
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase8-browser.png && echo "PASS"`
  - **Done when**: MCP (20), Skills (1527), Plugins (78) load and display
  - **Commit**: `chore(rebuild): capture Phase 8 browser validation evidence`

---

## Phase 2 (Refactoring): Clean Up and Modularize

- [ ] 2R.1 Clean up dead files and old references
  - **Do**:
    1. Delete `ContentView.swift` (replaced by SidebarRootView)
    2. Delete `DashboardView.swift` (replaced by HomeView)
    3. Delete remaining old view files that were not already removed: any views in Projects/, Sessions/ (except NewSessionView), MCP/, Plugins/, Skills/ that are now unused
    4. Remove all hardcoded `ILSTheme.accent`, `ILSTheme.background` etc. references from any remaining files — replace with `@Environment(\.theme)` pattern
    5. Update `EntityType.swift` to provide colors from current theme's entity tokens instead of hardcoded colors
    6. Delete `ILSTheme.swift` old static color tokens (keep only typography and spacing if still referenced, or migrate those to AppTheme protocol too)
  - **Files**:
    - `ILSApp/ILSApp/ContentView.swift` (delete)
    - `ILSApp/ILSApp/Views/Dashboard/DashboardView.swift` (delete)
    - Various old view files (delete)
    - `ILSApp/ILSApp/Theme/EntityType.swift` (modify — use theme tokens)
    - `ILSApp/ILSApp/Theme/ILSTheme.swift` (modify — strip old statics)
  - **Done when**: Zero references to old TabView navigation, zero hardcoded ILSTheme color calls, all views use `@Environment(\.theme)`
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `refactor(rebuild): remove dead files and migrate to theme environment`
  - _Design: Section 9 — Files to Create/Modify, PRESERVE list_

- [ ] 2R.2 Rebuild remaining shared components with theme
  - **Do**:
    1. Rewrite `ConnectionBanner.swift` — use theme tokens, show "Configure" for first-run, "Retry" for returning
    2. Rewrite `ConnectionSteps.swift` — themed connection step indicators
    3. Rewrite `EmptyEntityState.swift` — themed empty state with entity colors
    4. Rewrite `SkeletonRow.swift` — themed loading placeholder
    5. Rewrite `ShimmerModifier.swift` — themed shimmer (1.5s linear loop), disabled when reduce-motion
    6. Rewrite `ProgressRing.swift` — themed progress indicator
    7. Rewrite `ILSCodeHighlighter.swift` — use entity-derived colors from theme
    8. Move reusable modifiers from old ILSTheme.swift (CardStyle, ErrorStateView, LoadingOverlay, StatusBadge, HapticManager, Toast) into theme-aware versions
  - **Files**:
    - `ILSApp/ILSApp/Theme/Components/ConnectionBanner.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/ConnectionSteps.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/EmptyEntityState.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/SkeletonRow.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/ProgressRing.swift` (rewrite)
    - `ILSApp/ILSApp/Theme/Components/ILSCodeHighlighter.swift` (rewrite)
  - **Done when**: All shared components use `@Environment(\.theme)`, zero hardcoded ILSTheme references in components
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `refactor(theme): rebuild all shared components with theme environment`
  - _Design: Section 5 — Component Library_

- [ ] V10 [VERIFY] Refactoring checkpoint: full app builds and renders
  - **Do**: Build, launch, verify all screens still render correctly after cleanup
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Clean build, all screens accessible, no dead code references
  - **Commit**: `chore(rebuild): pass refactoring quality checkpoint`

---

## Phase 9: iPad Layout (US-3)

- [ ] 9.1 Add iPad persistent sidebar via size class detection
  - **Do**:
    1. In `SidebarRootView.swift`: detect `@Environment(\.horizontalSizeClass)` — if `.regular`, show sidebar persistently (320pt wide) alongside content; if `.compact`, keep overlay behavior
    2. iPad portrait: 280pt sidebar. iPad landscape: 320pt sidebar
    3. Content area fills remaining width
    4. Stage Manager: if window width < 600pt, collapse to overlay
    5. All sidebar interactions work identically on iPad
  - **Files**:
    - `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (modify — add iPad layout)
  - **Done when**: iPad simulator shows persistent sidebar + content side by side, iPhone stays overlay
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(ipad): add persistent sidebar for regular size class`
  - _Requirements: AC-3.1, AC-3.2, AC-3.3, AC-3.4, AC-3.5, AC-3.6, FR-18_
  - _Design: Section 6 — iPad Layout Strategy_

- [ ] V11 [VERIFY] Phase 9 checkpoint: iPad layout (build only)
  - **Do**: Build for iPad simulator target to verify compilation. iPad screenshot is nice-to-have if iPad simulator available
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Builds successfully with iPad size class logic
  - **Commit**: `chore(rebuild): capture Phase 9 iPad validation evidence`

---

## Phase 10: Onboarding (US-16)

- [ ] 10.1 Build OnboardingFlow for first-run experience
  - **Do**:
    1. Create `ILSApp/ILSApp/Views/Onboarding/OnboardingFlow.swift` — multi-step sheet:
       - Step 1: Welcome screen with ILS branding, themed with bgPrimary + accent
       - Step 2: Connection mode selection: Local / Remote / Tunnel (3 tappable cards)
       - Step 3: Server URL + port input fields (pre-filled for Local: localhost:9090)
       - Step 4: Health check with ConnectionSteps animation (reduce-motion: static steps)
       - Step 5: Success state -> dismiss to main app
    2. Connection settings saved to UserDefaults via `AppState.connectToServer(url:)`
    3. Only shown when no saved server config exists (`hasConnectedBefore == false`)
    4. Rewrite existing `ServerSetupSheet.swift` or replace with OnboardingFlow
    5. Wire back into `ILSAppApp.swift`: `.sheet(isPresented: $appState.showOnboarding)`
  - **Files**:
    - `ILSApp/ILSApp/Views/Onboarding/OnboardingFlow.swift` (create)
    - `ILSApp/ILSApp/Views/Onboarding/ServerSetupSheet.swift` (delete — replaced)
    - `ILSApp/ILSApp/ILSAppApp.swift` (modify — wire onboarding sheet)
  - **Done when**: First-run shows onboarding, connection test works, subsequent launches skip it
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(onboarding): build multi-step OnboardingFlow with connection test`
  - _Requirements: AC-16.1, AC-16.2, AC-16.3, AC-16.4, AC-16.5, AC-16.6, AC-16.7, FR-19_
  - _Design: Section 4.9 — Onboarding / Server Setup_

- [ ] V12 [VERIFY] Phase 10 checkpoint: onboarding flow
  - **Do**: Clear UserDefaults `hasConnectedBefore`, launch app, verify onboarding appears
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Onboarding shows on first launch, skipped after connection saved
  - **Commit**: `chore(rebuild): capture Phase 10 onboarding validation evidence`

---

## Phase 11: Animation Polish (US-17)

- [ ] 11.1 Apply animation system across all views
  - **Do**:
    1. Sidebar open/close: `.spring(response: 0.3, dampingFraction: 0.85)` — already in SidebarRootView, verify duration matches 0.25s
    2. Screen transitions: `.easeOut` 0.2s on NavigationStack push/pop
    3. Card appear: `.easeOut` 0.15s on `onAppear` for GlassCard content
    4. Glass blur: `.easeInOut` 0.3s on modal present
    5. Accent color morph: `.easeInOut` 0.4s when entity context changes (e.g. switching from session to system)
    6. Streaming dots: verify 1.2s easeInOut loop
    7. Skeleton shimmer: verify 1.5s linear loop
    8. Theme switch: `.easeInOut` 0.3s wrapper on `ThemeManager.setTheme`
    9. Button press: `.easeOut` 0.1s scale effect on touch-down (already in ChatInputView)
    10. List items: `.spring` 0.2s staggered appear on list population
    11. Gate ALL animations behind `@Environment(\.accessibilityReduceMotion)`: `reduceMotion ? .none : animation`
    12. StreamingIndicator reduce-motion: static "Responding..." text instead of dots
  - **Files**:
    - `ILSApp/ILSApp/Views/Root/SidebarRootView.swift` (modify — verify animations)
    - `ILSApp/ILSApp/Theme/GlassCard.swift` (modify — add appear animation)
    - `ILSApp/ILSApp/Views/Chat/StreamingIndicatorView.swift` (modify — verify reduce-motion)
    - `ILSApp/ILSApp/Theme/Components/ShimmerModifier.swift` (modify — verify reduce-motion)
    - `ILSApp/ILSApp/Views/Settings/ThemePickerView.swift` (modify — animate theme switch)
    - Various views (modify — add staggered list animations)
  - **Done when**: All 10 animation types match design spec durations/curves, all disabled with reduce-motion
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(animation): apply full animation system with reduce-motion gating`
  - _Requirements: AC-17.1 through AC-17.11, FR-20, FR-22_
  - _Design: Section 7 — Animation System_

- [ ] V13 [VERIFY] Phase 11 checkpoint: animations + reduce-motion
  - **Do**: Build, launch, verify sidebar animation is smooth, streaming dots animate, reduce-motion setting disables all
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Done when**: Animations match spec, reduce-motion compliance verified
  - **Commit**: `chore(rebuild): capture Phase 11 animation validation evidence`

---

## Phase 12: All 12 Themes (US-14)

- [ ] 12.1 Implement remaining 11 themes
  - **Do**:
    1. Create one file per theme in `ILSApp/ILSApp/Theme/Themes/`:
       - `SlateTheme.swift` — #3B82F6 blue accent, #0F1117 bg
       - `MidnightTheme.swift` — #10B981 emerald accent, #0A0F0D bg
       - `GhostProtocolTheme.swift` — #7DF9FF ice blue accent, #08080C bg
       - `NeonNoirTheme.swift` — #00D4FF cyan accent, #0A0A0F bg
       - `ElectricGridTheme.swift` — #00FF88 matrix accent, #050510 bg
       - `EmberTheme.swift` — #F59E0B amber accent, #0F0D0A bg
       - `CrimsonTheme.swift` — #EF4444 red accent, #0F0A0A bg
       - `CarbonTheme.swift` — #8B5CF6 violet accent, #0D0A12 bg
       - `GraphiteTheme.swift` — #14B8A6 teal accent, #0A0F0F bg
       - `PaperTheme.swift` — #EA580C orange accent, #FAFAF9 light bg, black glass opacity instead of white
       - `SnowTheme.swift` — #2563EB blue accent, #FAFBFF light bg, black glass opacity
    2. Each implements `AppTheme` protocol with all tokens. Dark themes: white glass opacity. Light themes: black glass opacity
    3. Entity colors consistent across all themes
    4. Register all themes in `ThemeManager` so theme picker can list and switch to any
    5. Ensure text meets WCAG AA contrast (4.5:1 body, 3:1 large) against each theme's bg
  - **Files**:
    - `ILSApp/ILSApp/Theme/Themes/SlateTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/MidnightTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/GhostProtocolTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/NeonNoirTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/ElectricGridTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/EmberTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/CrimsonTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/CarbonTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/GraphiteTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/PaperTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/Themes/SnowTheme.swift` (create)
    - `ILSApp/ILSApp/Theme/AppTheme.swift` (modify ThemeManager — register all themes)
  - **Done when**: All 12 themes selectable in picker, each renders with correct colors, light themes invert glass
  - **Verify**: `xcodebuild -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14' build 2>&1 | tail -5`
  - **Commit**: `feat(theme): implement all 12 themes with correct color values`
  - _Requirements: AC-14.1, AC-14.2, AC-14.3, AC-14.4, AC-14.5, AC-14.6, FR-21_
  - _Design: Section 3 — 12 Theme Definitions_

- [ ] V14 [VERIFY] Phase 12 checkpoint: all 12 themes render
  - **Do**:
    1. Build and launch
    2. Navigate to Theme Picker
    3. Switch between at least 4 themes (Obsidian, Slate, Ghost Protocol, Paper) and capture screenshots of each
    4. Verify light theme (Paper) inverts glass effects
  - **Verify**: `xcrun simctl io 50523130-57AA-48B0-ABD0-4D59CE455F14 screenshot specs/rebuild-ground-up/evidence/phase12-themes.png && echo "PASS"`
  - **Done when**: All 12 themes render correctly, light themes have inverted glass
  - **Commit**: `chore(rebuild): capture Phase 12 all-themes validation evidence`

---

## Phase 3 (Testing): Functional Validation

No unit tests per FUNCTIONAL VALIDATION MANDATE. All validation is simulator-based with real backend data.

- [ ] 3T.1 Full chat E2E validation with screenshot evidence
  - **Do**:
    1. Start backend: `PORT=9090 swift run ILSBackend`
    2. Build and install app
    3. Create new session via sidebar "+ New Session"
    4. Send message "What is 2+2?" — capture streaming screenshot
    5. Wait for response — capture rendered AI Assistant Card screenshot
    6. Send message triggering tool calls (e.g. "Read the contents of Package.swift") — capture tool call accordion screenshot
    7. Verify code blocks render with language label and copy button
    8. Test stop button during streaming
    9. Test session rename from nav bar
    10. Export a session transcript
  - **Verify**: `ls specs/rebuild-ground-up/evidence/phase3-*.png | wc -l` (expect 3+ screenshots)
  - **Done when**: Chat streaming, tool calls, code blocks, rename, export all work with screenshot evidence
  - **Commit**: `chore(rebuild): comprehensive chat E2E validation with evidence`
  - _Requirements: All AC-4.*, AC-5.*, AC-6.*, AC-7.*, AC-8.*, AC-18.*_

- [ ] 3T.2 Full navigation E2E validation
  - **Do**:
    1. Sidebar: open/close via hamburger and swipe gesture
    2. Session switching: tap different sessions in sidebar
    3. Home dashboard: verify all quick actions navigate correctly
    4. System monitor: verify metrics load
    5. Settings: verify all sections render
    6. Theme picker: switch between 3 themes, verify app-wide re-render
    7. Onboarding: clear defaults, verify flow appears
    8. Capture screenshots of each screen
  - **Verify**: `ls specs/rebuild-ground-up/evidence/ | wc -l` (expect 10+ evidence files)
  - **Done when**: All screens navigable, all render with real data, 10+ screenshots captured
  - **Commit**: `chore(rebuild): comprehensive navigation E2E validation`
  - _Requirements: All AC-2.*, AC-9.*, AC-12.*, AC-13.*_

- [ ] V15 [VERIFY] Full functional validation checkpoint
  - **Do**: Verify all evidence screenshots exist and cover all 10 screens
  - **Verify**: `ls specs/rebuild-ground-up/evidence/*.png | wc -l` (expect 10+)
  - **Done when**: Complete evidence portfolio covering all screens and flows
  - **Commit**: None

---

## Phase 4: Quality Gates

- [ ] 4.1 [VERIFY] Full local CI: build iOS app
  - **Do**:
    1. Clean build: `xcodebuild clean build -project ILSApp/ILSApp.xcodeproj -scheme ILSApp -sdk iphonesimulator -destination 'id=50523130-57AA-48B0-ABD0-4D59CE455F14'`
    2. Build backend: `swift build`
    3. Fix any warnings or errors
  - **Verify**: Both commands exit 0
  - **Done when**: Clean build with zero errors
  - **Commit**: `fix(rebuild): resolve build warnings` (if fixes needed)

- [ ] 4.2 Create PR and verify CI
  - **Do**:
    1. Verify current branch: `git branch --show-current` (should be feature branch, NOT main)
    2. Stage all changes: `git add -A`
    3. Final commit: `feat(rebuild): complete ILS iOS front-end rebuild with Ghost Protocol theme`
    4. Push: `git push -u origin <branch>`
    5. Create PR: `gh pr create --title "Complete iOS Front-End Rebuild — Ghost Protocol Theme" --body "..."`
    6. Check CI: `gh pr checks --watch`
  - **Verify**: `gh pr checks` shows all green
  - **Done when**: PR created, CI green
  - **Commit**: As described above

---

## Phase 5: PR Lifecycle

- [ ] 5.1 Monitor CI and fix failures
  - **Do**:
    1. `gh pr checks --watch` — wait for CI completion
    2. If failures: read error details, fix locally, push
    3. Repeat until green
  - **Verify**: `gh pr checks` all passing
  - **Done when**: CI fully green

- [ ] 5.2 Address review comments
  - **Do**:
    1. `gh pr view --comments` — read any review feedback
    2. Address each comment with code changes
    3. Push fixes, re-verify CI
  - **Verify**: `gh pr checks` still green after fixes
  - **Done when**: All review comments resolved

- [ ] V16 [VERIFY] Final AC checklist
  - **Do**: Programmatically verify each acceptance criterion is satisfied:
    1. AC-1.*: `grep -r "protocol AppTheme" ILSApp/` confirms protocol exists
    2. AC-2.*: `grep -r "SidebarRootView" ILSApp/` confirms no TabView
    3. AC-4.*: `grep -r "AssistantCard\|UserMessageCard" ILSApp/Views/Chat/` confirms card layout
    4. AC-7.*: `grep -r "doc.text\|doc.badge.plus\|pencil.line\|terminal\|magnifyingglass\|folder.badge.questionmark\|globe\|arrow.down.doc\|person.2\|sparkles" ILSApp/ILSApp/Theme/Components/ToolCallAccordion.swift` confirms all 10 tool icons
    5. AC-13.*: `find ILSApp/ILSApp/Theme/Themes -name "*Theme.swift" | wc -l` confirms 12 theme files
    6. AC-17.11: `grep -r "reduceMotion\|accessibilityReduceMotion" ILSApp/ | wc -l` confirms reduce-motion gates
    7. Evidence screenshots exist: `ls specs/rebuild-ground-up/evidence/*.png | wc -l`
  - **Verify**: All grep/find commands return expected results
  - **Done when**: All acceptance criteria confirmed met via automated checks
  - **Commit**: None

---

## Notes

### POC shortcuts taken (Phase 1)
- Only Obsidian theme implemented; other 11 themes deferred to Phase 12
- ThemeTestView used as temporary validation screen (deleted in Phase 2)
- No iPad layout — iPhone only until Phase 9
- No onboarding — direct launch until Phase 10
- No animation polish — functional first until Phase 11

### Production TODOs (cleaned up in refactoring)
- Remove all hardcoded ILSTheme static references
- Delete ContentView.swift and old tab-based views
- Migrate EntityType colors to use theme tokens
- Ensure all components use `@Environment(\.theme)` consistently

### Risk areas identified
- SSE streaming regression: ChatView rewrite must use ChatViewModel identically to current code
- Sidebar edge-swipe vs NavigationStack back-swipe: test `.simultaneousGesture` approach early
- Light theme glass inversion: easy to miss, test Paper/Snow themes explicitly
- 100+ message scroll performance: use `LazyVStack`, limit expanded tool calls
- WCAG contrast: verify every theme's text colors against backgrounds

### Files preserved (ZERO modification)
- `Services/APIClient.swift`
- `Services/SSEClient.swift`
- `Services/MetricsWebSocketClient.swift`
- `Services/AppLogger.swift`
- `ViewModels/ChatViewModel.swift`
- `ViewModels/SessionsViewModel.swift`
- `ViewModels/ProjectsViewModel.swift`
- `ViewModels/DashboardViewModel.swift`
- `ViewModels/SkillsViewModel.swift`
- `ViewModels/MCPViewModel.swift`
- `ViewModels/PluginsViewModel.swift`
- `ViewModels/SystemMetricsViewModel.swift`
- `ViewModels/BaseListViewModel.swift`
- `Models/ChatMessage.swift`
- `Models/SessionTemplate.swift`
- `Utils/DateFormatters.swift`
- All `ILSShared/` files
