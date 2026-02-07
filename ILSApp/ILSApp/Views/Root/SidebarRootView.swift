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
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        NavigationStack {
            Group {
                switch activeScreen {
                case .home:
                    homePlaceholder
                case .chat(let session):
                    chatPlaceholder(session: session)
                case .system:
                    systemPlaceholder
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
            // Sidebar content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("ILS")
                        .font(.system(size: theme.fontTitle1, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.accent)

                    HStack(spacing: theme.spacingXS) {
                        Circle()
                            .fill(appState.isConnected ? theme.success : theme.error)
                            .frame(width: 8, height: 8)
                        Text(appState.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.top, theme.spacingLG)
                .padding(.bottom, theme.spacingMD)

                Divider()
                    .overlay(theme.divider)

                // Navigation items
                ScrollView {
                    VStack(spacing: theme.spacingXS) {
                        sidebarNavItem(
                            icon: "house.fill",
                            label: "Home",
                            screen: .home
                        )
                        sidebarNavItem(
                            icon: "gauge.with.dots.needle.33percent",
                            label: "System Monitor",
                            screen: .system
                        )
                        sidebarNavItem(
                            icon: "square.grid.2x2.fill",
                            label: "Browse",
                            screen: .browser
                        )
                        sidebarNavItem(
                            icon: "gearshape.fill",
                            label: "Settings",
                            screen: .settings
                        )
                    }
                    .padding(.horizontal, theme.spacingSM)
                    .padding(.top, theme.spacingMD)

                    // Sessions section header
                    HStack {
                        Text("SESSIONS")
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.top, theme.spacingLG)
                    .padding(.bottom, theme.spacingXS)

                    // Placeholder for session list (built in task 2.2)
                    VStack(spacing: theme.spacingXS) {
                        Text("Sessions will appear here")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingLG)
                    }
                    .padding(.horizontal, theme.spacingSM)
                }

                Spacer()

                Divider()
                    .overlay(theme.divider)

                // Bottom: New Session button
                Button {
                    // New session action — wired in task 5.1
                    closeSidebar()
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Session")
                            .font(.system(size: theme.fontBody, weight: .semibold))
                    }
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingSM + 2)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.vertical, theme.spacingMD)
            }
            .frame(width: sidebarWidth)
            .background(theme.bgSidebar)

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

    // MARK: - Sidebar Navigation Item

    private func sidebarNavItem(icon: String, label: String, screen: ActiveScreen) -> some View {
        let isActive = isScreenActive(screen)

        return Button {
            activeScreen = screen
            closeSidebar()
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: theme.fontBody))
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: theme.fontBody))
                Spacer()
            }
            .foregroundStyle(isActive ? theme.accent : theme.textSecondary)
            .padding(.horizontal, theme.spacingSM + 4)
            .padding(.vertical, theme.spacingSM + 2)
            .background(
                isActive
                    ? theme.accent.opacity(0.1)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Placeholder Views

    @ViewBuilder
    private var homePlaceholder: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "house.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)
            Text("Home Dashboard")
                .font(.system(size: theme.fontTitle2, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Built in Phase 4")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
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
    private var systemPlaceholder: some View {
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 48))
                .foregroundStyle(theme.entitySystem)
            Text("System Monitor")
                .font(.system(size: theme.fontTitle2, weight: .bold))
                .foregroundStyle(theme.textPrimary)
            Text("Built in Phase 6")
                .font(.system(size: theme.fontBody))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
        .navigationTitle("System")
        .navigationBarTitleDisplayMode(.inline)
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

    private func isScreenActive(_ screen: ActiveScreen) -> Bool {
        switch (activeScreen, screen) {
        case (.home, .home), (.system, .system), (.settings, .settings), (.browser, .browser):
            return true
        case (.chat, .chat):
            return true
        default:
            return false
        }
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
