import SwiftUI
import ILSShared

// MARK: - Active Screen
// NAV-MED-1/2: ActiveScreen enum routing is the intentional navigation architecture.
// iOS uses a sheet-based sidebar (not NavigationSplitView) which requires manual
// screen routing via @State. NavigationStack+navigationDestination is used for
// within-screen drill-downs (e.g., session detail). This split is intentional:
// sidebar manages top-level screens, NavigationStack manages hierarchical navigation.

enum ActiveScreen: Hashable {
    case home
    case chat(ChatSession)
    case system
    case settings
    case browser
    case teams
    case hostProfiles
    case themes
    case hooks
    case activityFeed

    /// Backward-compatible alias: `.fleet` maps to `.hostProfiles`.
    static var fleet: ActiveScreen { .hostProfiles }

    /// String key for @SceneStorage persistence (excludes associated values).
    var storageKey: String {
        switch self {
        case .home: return "home"
        case .chat: return "chat"
        case .system: return "system"
        case .settings: return "settings"
        case .browser: return "browser"
        case .teams: return "teams"
        case .hostProfiles: return "hostProfiles"
        case .themes: return "themes"
        case .hooks: return "hooks"
        case .activityFeed: return "activityFeed"
        }
    }

    /// Restore from a storage key. Chat requires a session, so returns nil if unavailable.
    static func fromStorageKey(_ key: String) -> ActiveScreen? {
        switch key {
        case "home": return .home
        case "system": return .system
        case "settings": return .settings
        case "browser": return .browser
        case "teams": return .teams
        case "fleet", "hostProfiles": return .hostProfiles  // "fleet" kept for backward compat
        case "themes": return .themes
        case "hooks": return .hooks
        case "activityFeed": return .activityFeed
        default: return nil  // "chat" requires session — handled separately
        }
    }
}

// MARK: - Sidebar Root View

/// Root container view providing adaptive navigation for the ILS iOS/macOS app.
///
/// Renders a ``NavigationSplitView`` with a persistent sidebar column on iPad (regular-width
/// size class) and a ZStack overlay sidebar on iPhone (compact-width size class). Routing
/// between app screens is driven by the ``ActiveScreen`` enum; the active destination is
/// persisted across launches via `@SceneStorage` and restored on first appearance.
/// App-wide navigation requests are consumed from ``AppState/navigationIntent`` and forwarded
/// to ``activeScreen``. On iPhone an edge-swipe gesture from the leading edge opens or closes
/// the sidebar panel.
///
/// ## Topics
/// ### Layout
/// - ``iPadLayout`` - NavigationSplitView with a persistent sidebar column (regular width)
/// - ``iPhoneLayout`` - ZStack overlay sidebar with a backdrop dimmer (compact width)
///
/// ### Navigation
/// - ``activeScreen`` - Currently displayed screen, driven by ``ActiveScreen`` routing
/// - ``navigationPath`` - NavigationStack path for push-navigation within the active screen
///
/// ### State
/// - ``activeScreenKey`` - SceneStorage key persisting the active screen identifier across launches
/// - ``lastChatSessionId`` - SceneStorage UUID string for restoring the last open chat session
/// - ``sessionsVM`` - Shared sessions view model passed down to the sidebar and home screen
///
/// ### Gestures
/// - ``edgeSwipeGesture`` - DragGesture that opens the sidebar from the leading edge on iPhone
/// - ``sidebarDragOffset`` - Live horizontal translation applied to the sidebar while dragging
/// - ``isSidebarOpen`` - Whether the sidebar overlay panel is currently visible
struct SidebarRootView: View {
    @Environment(AppState.self) var appState
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Persisted string key identifying the active screen, used to restore navigation state
    /// across app launches. Excludes `.chat` (which requires an async session fetch).
    @SceneStorage("activeScreenKey") private var activeScreenKey: String = "home"
    /// UUID string of the last open chat session. When `activeScreenKey` is `"chat"` on launch,
    /// this value is used to look up and restore the corresponding ``ChatSession``.
    @SceneStorage("lastChatSessionId") private var lastChatSessionId: String = ""
    /// Whether the sidebar overlay panel is currently visible. Only meaningful on iPhone;
    /// on iPad the sidebar is always present inside the NavigationSplitView.
    @State private var isSidebarOpen: Bool = false
    /// The currently displayed app screen, switched by selecting items in the sidebar or via
    /// ``AppState/navigationIntent``.
    @State private var activeScreen: ActiveScreen = .home
    /// The screen the user was on before navigating to chat, used for the back button.
    /// `nil` when chat was opened via @SceneStorage restoration (no meaningful "back").
    @State private var previousScreen: ActiveScreen? = nil
    @State private var sidebarDragOffset: CGFloat = 0
    /// Controls NavigationSplitView column visibility on iPad, allowing the sidebar column
    /// to be shown or hidden programmatically. Defaults to `.all` so the sidebar is always
    /// visible on launch; the system auto-collapses it to `.detailOnly` when the Split View
    /// window is too narrow (e.g., 1/3 split on iPad mini landscape).
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// Initial segment selection forwarded to ``BrowserView`` when navigation is triggered
    /// via `onNavigateToBrowser` from the home screen.
    @State private var browserSegment: BrowserSegment = .mcp
    /// Shared sessions view model owned by this root view and passed to ``SidebarView`` and
    /// ``HomeView``, ensuring sessions are fetched once and reused across both consumers.
    @State private var sessionsVM = SessionsViewModel()
    /// Current connection event shown in the toast banner. `nil` when no toast is visible.
    @State private var connectionEvent: ConnectionEvent? = nil
    /// Shared network reachability monitor used to detect connection loss and restore events.
    private let networkMonitor = NetworkMonitor.shared
    /// Activity feed view model, instantiated once and reused by ``ActivityFeedView``.
    @State private var activityFeedVM = ActivityFeedViewModel()

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var sidebarWidth: CGFloat { 280 }

    // SP-MED-5: ARC overhead in SwiftUI closures — `.task`, `.onChange`, and `.onAppear` closures
    // capture `self` implicitly. Using `[weak self]` here would require optional-chaining every
    // property access, adding branching overhead that exceeds the ARC retain/release cost (~25ns).
    // These closures are short-lived (tied to view lifetime) so retain cycles are impossible.
    // `[weak self]` is reserved for long-lived closures (NotificationCenter, Timer, escaping).

    var body: some View {
        // LAYOUT-01: Size-class branch is intentional — iPad uses NavigationSplitView, iPhone uses
        // custom sheet-based sidebar. These are structurally incompatible views. Identity loss on
        // rotation is accepted: iPhone rarely rotates in this app, and iPad stays in regular width.
        // @SceneStorage persists activeScreen across rebuilds for state restoration.
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let screen = intent else { return }

            // Consume browser segment intent BEFORE setting activeScreen so that
            // BrowserView receives the correct initialSegment and a fresh .id().
            if screen == .browser, let segmentIntent = appState.browserSegmentIntent {
                browserSegment = segmentIntent
                appState.browserSegmentIntent = nil
            }

            // Handle chat deep links through navigateToChat for back button support
            if case .chat(let session) = screen {
                navigateToChat(session)
            } else {
                previousScreen = nil  // Non-chat deep links clear back history
                activeScreen = screen
            }

            appState.navigationIntent = nil
            if !isRegularWidth {
                closeSidebar()
            }
        }
        .onChange(of: activeScreen) { _, newScreen in
            activeScreenKey = newScreen.storageKey
            // Persist the chat session ID for state restoration
            if case .chat(let session) = newScreen {
                lastChatSessionId = session.id.uuidString
            } else {
                // Sidebar navigation to a non-chat screen clears stale back history
                previousScreen = nil
            }
        }
        .onAppear {
            if let restored = ActiveScreen.fromStorageKey(activeScreenKey) {
                activeScreen = restored
            }
            // Non-chat screens are restored above; chat requires async session fetch
        }
        .task {
            sessionsVM.configure(client: appState.apiClient)
            activityFeedVM.configure(client: appState.apiClient)
            await sessionsVM.loadSessions(refresh: true)
            // Load custom themes from backend and register with ThemeManager
            // This allows custom themes to appear in ThemePickerView alongside built-ins
            await themeManager.loadAndRegisterCustomThemes(client: appState.apiClient)

            // Restore chat session if app was backgrounded while viewing chat
            if activeScreenKey == "chat", !lastChatSessionId.isEmpty,
               let uuid = UUID(uuidString: lastChatSessionId) {
                if let session = sessionsVM.session(byID: uuid) {
                    activeScreen = .chat(session)
                } else {
                    // Fallback: create minimal session for restoration
                    let session = ChatSession(id: uuid, name: "Session")
                    activeScreen = .chat(session)
                }
            }
        }
        .onChange(of: appState.serverURL) { _, _ in
            sessionsVM.configure(client: appState.apiClient)
            activityFeedVM.configure(client: appState.apiClient)
            Task {
                await sessionsVM.loadSessions(refresh: true)
                await themeManager.loadAndRegisterCustomThemes(client: appState.apiClient)
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                connectionEvent = isConnected ? .restored : .lost
            }
        }
        .sheet(isPresented: Bindable(appState).showOnboarding) {
            ServerSetupSheet()
                .environment(appState)
                .environment(\.theme, theme)
        }
        // DEBUG: Auto-navigate for screenshot capture (revert after)
        // .task { ... } — REVERTED after validation
    }

    // MARK: - iPad Layout (Persistent Sidebar)

    private var iPadLayout: some View {
        // IPAD-SPLIT-1: NavigationSplitView column widths are chosen to remain functional
        // across all Split View configurations:
        //   • 1/3 split (≈398pt on iPad 11" landscape): sidebar min 200 leaves ≈198pt for content.
        //     On narrower devices (iPad mini landscape 1/3 ≈248pt) the system auto-collapses
        //     the sidebar to .detailOnly; the restore button below lets the user bring it back.
        //   • 1/2 split (≈512pt): sidebar fits comfortably at ideal 280pt.
        //   • 2/3 split / full screen: extra room uses up to max 360pt.
        // columnVisibility defaults to .all so the sidebar is immediately visible on launch.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                sessionsViewModel: sessionsVM,
                activeScreen: $activeScreen,
                isSidebarOpen: .constant(true),
                onSessionSelected: { session in
                    navigateToChat(session)
                },
                activityFeedUnreadCount: activityFeedVM.unreadCount
            )
            .background(theme.bgSidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 280, max: 360)
        } detail: {
            mainContent(showHamburger: false, ipadSidebarCollapsed: columnVisibility == .detailOnly) {
                columnVisibility = .all
            }
        }
        #if os(iOS)
        // IPAD-KB-1: Zero-size overlay that provides global Cmd+N / Cmd+, shortcuts for
        // external keyboard users. Positioned on iPadLayout (regular width only) since
        // iPhone users don't typically pair physical keyboards.
        .overlay {
            iPadKeyboardShortcutOverlay()
        }
        #endif
    }

    // MARK: - iPhone Layout (Overlay Sidebar)

    private var iPhoneLayout: some View {
        ZStack(alignment: .leading) {
            mainContent(showHamburger: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isSidebarOpen {
                theme.bgPrimary
                    .opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSidebar()
                    }
                    .transition(.opacity)
            }

            sidebarPanel
        }
        .gesture(edgeSwipeGesture)
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(
        showHamburger: Bool,
        ipadSidebarCollapsed: Bool = false,
        onShowIPadSidebar: (() -> Void)? = nil
    ) -> some View {
        NavigationStack {
            Group {
                switch activeScreen {
                case .home:
                    homeScreen
                case .chat(let session):
                    ChatView(session: session, onBack: previousScreen != nil ? {
                        if let prev = previousScreen {
                            activeScreen = prev
                            previousScreen = nil
                        }
                    } : nil)
                case .system:
                    systemScreen
                case .settings:
                    settingsScreen
                case .browser:
                    browserScreen
                case .teams:
                    teamsScreen
                case .hostProfiles:
                    hostProfilesScreen
                case .themes:
                    themesScreen
                case .hooks:
                    hooksScreen
                case .activityFeed:
                    activityFeedScreen
                }
            }
            .id(activeScreen.storageKey)
            .transition(.opacity)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: activeScreen)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    OfflineIndicator(isOffline: appState.isOffline)
                        .animation(
                            reduceMotion ? .none : .easeInOut(duration: 0.3),
                            value: appState.isOffline
                        )
                    ConnectionEventToast(event: $connectionEvent)
                        .animation(
                            reduceMotion ? .none : .easeInOut(duration: 0.3),
                            value: connectionEvent
                        )
                }
            }
            #if os(iOS)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(theme.bgPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                if showHamburger {
                    // iPhone: overlay sidebar toggle
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            openSidebar()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: theme.fontTitle3, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .accessibilityLabel("Open sidebar")
                        .accessibilityHint("Opens navigation sidebar")
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        Button {
                            openSidebar()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: theme.fontTitle3, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .accessibilityLabel("Open sidebar")
                        .accessibilityHint("Opens navigation sidebar")
                    }
                    #endif
                } else if ipadSidebarCollapsed, let showSidebar = onShowIPadSidebar {
                    // IPAD-SPLIT-2: iPad Split View — sidebar was auto-collapsed by the system
                    // (e.g., at 1/3 screen width). Show a restore button so the user can expand
                    // it again without needing to know to drag from the edge.
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: showSidebar) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: theme.fontTitle3, weight: .medium, design: theme.fontDesign))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .accessibilityLabel("Show sidebar")
                        .accessibilityHint("Shows navigation sidebar")
                    }
                    #endif
                }
            }
        }
        .tint(theme.accent)
    }

    // MARK: - Sidebar Panel (iPhone overlay)

    private var sidebarPanel: some View {
        HStack(spacing: 0) {
            SidebarView(
                sessionsViewModel: sessionsVM,
                activeScreen: $activeScreen,
                isSidebarOpen: $isSidebarOpen,
                onSessionSelected: { session in
                    navigateToChat(session)
                },
                activityFeedUnreadCount: activityFeedVM.unreadCount
            )
            .frame(width: sidebarWidth)

            Spacer(minLength: 0)
        }
        .offset(x: sidebarXOffset)
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.85),
            value: isSidebarOpen
        )
        .animation(
            reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.85),
            value: sidebarDragOffset
        )
    }

    // MARK: - Screen Views

    @ViewBuilder
    private var homeScreen: some View {
        HomeView(
            sessionsVM: sessionsVM,
            onSessionSelected: { session in
                navigateToChat(session)
            },
            onNavigate: { screen in
                activeScreen = screen
            },
            onNavigateToBrowser: { segment in
                browserSegment = segment
                activeScreen = .browser
            }
        )
    }

    @ViewBuilder
    private var systemScreen: some View {
        SystemMonitorView()
    }

    @ViewBuilder
    private var settingsScreen: some View {
        SettingsView()
    }

    @ViewBuilder
    private var browserScreen: some View {
        BrowserView(initialSegment: browserSegment)
            .id(browserSegment)
    }

    @ViewBuilder
    private var teamsScreen: some View {
        AgentTeamsListView(apiClient: appState.apiClient)
    }

    @ViewBuilder
    private var hostProfilesScreen: some View {
        HostProfilesView()
    }

    @ViewBuilder
    private var themesScreen: some View {
        ThemePickerView()
    }

    @ViewBuilder
    private var hooksScreen: some View {
        HooksManagementView()
    }

    @ViewBuilder
    private var activityFeedScreen: some View {
        ActivityFeedView(viewModel: activityFeedVM) { sessionId in
            if let uuid = UUID(uuidString: sessionId),
               let session = sessionsVM.session(byID: uuid) {
                navigateToChat(session)
            }
        }
    }

    // MARK: - Chat Navigation

    /// Navigate to a chat session, recording the current screen for back-button support.
    /// When already viewing a chat, switches session without updating `previousScreen`.
    private func navigateToChat(_ session: ChatSession) {
        if case .chat = activeScreen {
            // Already in chat — just switch session, don't update previousScreen
            activeScreen = .chat(session)
        } else {
            previousScreen = activeScreen
            activeScreen = .chat(session)
        }
    }

    // MARK: - Sidebar Logic (iPhone)

    private var sidebarXOffset: CGFloat {
        if isSidebarOpen {
            return max(sidebarDragOffset, -sidebarWidth)
        } else {
            return -sidebarWidth + max(sidebarDragOffset, 0)
        }
    }

    private func openSidebar() {
        HapticManager.impact(.light)
        isSidebarOpen = true
        sidebarDragOffset = 0
    }

    private func closeSidebar() {
        HapticManager.impact(.light)
        isSidebarOpen = false
        sidebarDragOffset = 0
    }

    // MARK: - Edge Swipe Gesture (iPhone)

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let startX = value.startLocation.x

                if isSidebarOpen {
                    if value.translation.width < 0 {
                        sidebarDragOffset = value.translation.width
                    }
                } else {
                    if startX < 30 && value.translation.width > 0 {
                        sidebarDragOffset = min(value.translation.width, sidebarWidth)
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = sidebarWidth * 0.3

                if isSidebarOpen {
                    if value.translation.width < -threshold {
                        closeSidebar()
                    } else {
                        sidebarDragOffset = 0
                    }
                } else {
                    if value.startLocation.x < 30 && value.translation.width > threshold {
                        openSidebar()
                    } else {
                        sidebarDragOffset = 0
                    }
                }
            }
    }
}

#Preview {
    SidebarRootView()
        .environment(AppState())
        .environment(ThemeManager())
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
