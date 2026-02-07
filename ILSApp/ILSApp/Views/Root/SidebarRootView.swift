import SwiftUI
import ILSShared

// MARK: - Active Screen

enum ActiveScreen: Hashable {
    case home
    case chat(ChatSession)
    case system
    case settings
    case browser
}

// MARK: - Sidebar Root View

struct SidebarRootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.theme) private var theme: any AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isSidebarOpen: Bool = false
    @State private var activeScreen: ActiveScreen = .home
    @State private var sidebarDragOffset: CGFloat = 0

    private let sidebarWidth: CGFloat = 280

    var body: some View {
        ZStack(alignment: .leading) {
            // Main content area
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Dimmed overlay (tap to dismiss)
            if isSidebarOpen {
                theme.bgPrimary
                    .opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSidebar()
                    }
                    .transition(.opacity)
            }

            // Sidebar panel
            sidebarPanel
        }
        .gesture(edgeSwipeGesture)
        .onChange(of: appState.navigationIntent) { _, intent in
            guard let screen = intent else { return }
            activeScreen = screen
            appState.navigationIntent = nil
            closeSidebar()
        }
        .sheet(isPresented: $appState.showOnboarding) {
            ServerSetupSheet()
                .environmentObject(appState)
                .environment(\.theme, theme)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            Group {
                switch activeScreen {
                case .home:
                    homeScreen
                case .chat(let session):
                    chatPlaceholder(session: session)
                case .system:
                    systemScreen
                case .settings:
                    settingsPlaceholder
                case .browser:
                    browserPlaceholder
                }
            }
            .toolbar {
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
        .tint(theme.accent)
    }

    // MARK: - Sidebar Panel

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

    // MARK: - Placeholder Views

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
    private func chatPlaceholder(session: ChatSession) -> some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.entitySession)
            Text(session.name ?? "Chat")
                .font(.system(size: theme.fontTitle2, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Chat rebuilt in Phase 3")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle(session.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var systemScreen: some View {
        SystemMonitorView()
    }

    @ViewBuilder
    private var settingsPlaceholder: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.textSecondary)
            Text("Settings")
                .font(.system(size: theme.fontTitle2, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Built in Phase 7")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var browserPlaceholder: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.entitySkill)
            Text("MCP / Skills / Plugins")
                .font(.system(size: theme.fontTitle2, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Built in Phase 8")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sidebar Logic

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

    // MARK: - Edge Swipe Gesture

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let startX = value.startLocation.x

                if isSidebarOpen {
                    // Swipe left to close
                    if value.translation.width < 0 {
                        sidebarDragOffset = value.translation.width
                    }
                } else {
                    // Swipe from left edge to open (within 30pt of left edge)
                    if startX < 30 && value.translation.width > 0 {
                        sidebarDragOffset = min(value.translation.width, sidebarWidth)
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = sidebarWidth * 0.3

                if isSidebarOpen {
                    // Close if dragged far enough left
                    if value.translation.width < -threshold {
                        closeSidebar()
                    } else {
                        sidebarDragOffset = 0
                    }
                } else {
                    // Open if dragged far enough right from left edge
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
