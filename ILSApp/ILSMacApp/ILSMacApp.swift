import SwiftUI
import ILSShared
/// Focused value key for the currently selected session
struct FocusedSessionKey: FocusedValueKey {
    typealias Value = ChatSession
}

extension FocusedValues {
    var selectedSession: ChatSession? {
        get { self[FocusedSessionKey.self] }
        set { self[FocusedSessionKey.self] = newValue }
    }
}

@main
struct ILSMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @State private var layoutStore = DashboardLayoutStore()
    @State private var densityManager = DensityManager.shared
    @State private var windowManager = WindowManager.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var backendManager = BackendLifecycleManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"

    private var computedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" follows device setting
        }
    }

    /// Computed theme snapshot that combines current theme with current density.
    /// Rebuilds whenever themeManager.currentTheme or densityManager.currentDensity changes.
    private var themeSnapshot: ThemeSnapshot {
        ThemeSnapshot(themeManager.currentTheme, density: densityManager.currentDensity)
    }

    var body: some Scene {
        // Main application window
        WindowGroup {
            MacContentView()
                .environment(appState)
                .environment(themeManager)
                .environment(layoutStore)
                .environment(densityManager)
                .environment(windowManager)
                .environment(notificationManager)
                .environment(\.theme, themeSnapshot)
                .preferredColorScheme(computedColorScheme)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
                .task {
                    // Request notification permissions on first launch
                    do {
                        try await notificationManager.requestAuthorization()
                    } catch {
                        AppLogger.shared.warning(
                            "Failed to request notification permissions: \(error)",
                            category: "notifications"
                        )
                    }
                    // Start backend health monitoring if already installed
                    await backendManager.startMonitoringIfInstalled()
                    // Sync message bookmarks from CloudKit on app launch
                    Task.detached(priority: .background) {
                        await MessageBookmarksManager.shared.syncFromCloud()
                    }
                }
        }
        .defaultSize(width: 1200, height: 800)
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
        .commands {
            ILSCommands()
        }
        // .windowRestorationBehavior(.enabled) // Requires macOS 15+

        // Session windows for multi-window support
        WindowGroup("Session", for: UUID.self) { $sessionId in
            if let sessionId {
                SessionWindowView(sessionId: sessionId)
                    .environment(appState)
                    .environment(themeManager)
                    .environment(densityManager)
                    .environment(windowManager)
                    .environment(notificationManager)
                    .environment(\.theme, themeSnapshot)
                    .preferredColorScheme(computedColorScheme)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            } else {
                Text("No session selected")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .handlesExternalEvents(matching: Set(["session"]))
        // .windowRestorationBehavior(.enabled) // Requires macOS 15+
    }
}
