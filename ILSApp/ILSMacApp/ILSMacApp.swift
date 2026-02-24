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
    @State private var windowManager = WindowManager.shared
    @State private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"

    private var computedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" follows device setting
        }
    }

    var body: some Scene {
        // Main application window
        WindowGroup {
            MacContentView()
                .environment(appState)
                .environment(themeManager)
                .environment(windowManager)
                .environment(notificationManager)
                .environment(\.theme, themeManager.currentSnapshot)
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
                        print("Failed to request notification permissions: \(error)")
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
                    .environment(windowManager)
                    .environment(notificationManager)
                    .environment(\.theme, themeManager.currentSnapshot)
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
