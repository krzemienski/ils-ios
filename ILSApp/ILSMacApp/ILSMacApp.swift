import SwiftUI
import ILSShared
import Combine

@main
struct ILSMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
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
        WindowGroup {
            SidebarRootView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environment(\.theme, themeManager.currentTheme)
                .preferredColorScheme(computedColorScheme)
                .onOpenURL { url in
                    appState.handleURL(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
        }
    }
}

/// AppDelegate for macOS-specific app lifecycle and menu bar customization
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar customization will be added in Phase 4
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running when last window closes (standard macOS behavior)
        return false
    }
}
