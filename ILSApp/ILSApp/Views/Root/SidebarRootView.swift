import SwiftUI
import ILSShared

// MARK: - Active Screen

enum ActiveScreen: Hashable {
    case home
    case chat(ChatSession)
    case system
    case settings
    case browser
    case teams
    case fleet
}

// MARK: - Sidebar Root View

struct SidebarRootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var isSidebarOpen: Bool = false
    @State private var activeScreen: ActiveScreen = .home
    @State private var sidebarDragOffset: CGFloat = 0

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var sidebarWidth: CGFloat {
        isRegularWidth ? 320 : 280
    }

    var body: some View {
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let screen = intent else { return }
            activeScreen = screen
            appState.navigationIntent = nil
            if !isRegularWidth {
                closeSidebar()
            }
        }
        .sheet(isPresented: $appState.showOnboarding) {
            ServerSetupSheet()
                .environmentObject(appState)
                .environment(\.theme, theme)
        }
        // DEBUG: Auto-navigate for screenshot capture (revert after)
        // .task { ... } — REVERTED after validation
    }

    // MARK: - iPad Layout (Persistent Sidebar)

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            SidebarView(
                activeScreen: $activeScreen,
                isSidebarOpen: .constant(true),
                onSessionSelected: { session in
                    activeScreen = .chat(session)
                }
            )
            .frame(width: sidebarWidth)
            .background(theme.bgSidebar)

            Divider()
                .background(theme.divider)

            mainContent(showHamburger: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
    private func mainContent(showHamburger: Bool) -> some View {
        NavigationStack {
            Group {
                switch activeScreen {
                case .home:
                    homeScreen
                case .chat(let session):
                    ChatView(session: session)
                case .system:
                    systemScreen
                case .settings:
                    settingsScreen
                case .browser:
                    browserScreen
                case .teams:
                    teamsScreen
                case .fleet:
                    fleetScreen
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(theme.bgPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if showHamburger {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            openSidebar()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: theme.fontTitle3, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .accessibilityLabel("Open sidebar")
                    }
                }
            }
        }
        .tint(theme.accent)
    }

    // MARK: - Sidebar Panel (iPhone overlay)

    private var sidebarPanel: some View {
        HStack(spacing: 0) {
            SidebarView(
                activeScreen: $activeScreen,
                isSidebarOpen: $isSidebarOpen,
                onSessionSelected: { session in
                    activeScreen = .chat(session)
                }
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
            onSessionSelected: { session in
                activeScreen = .chat(session)
            },
            onNavigate: { screen in
                activeScreen = screen
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
        BrowserView()
    }

    @ViewBuilder
    private var teamsScreen: some View {
        AgentTeamsListView(apiClient: appState.apiClient)
    }

    @ViewBuilder
    private var fleetScreen: some View {
        FleetManagementView()
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
        isSidebarOpen = true
        sidebarDragOffset = 0
    }

    private func closeSidebar() {
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
        .environmentObject(AppState())
        .environmentObject(ThemeManager())
        .environment(\.theme, ObsidianTheme())
}
