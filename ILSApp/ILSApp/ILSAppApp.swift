import SwiftUI
import Observation
import ILSShared
import TipKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@main
struct ILSAppApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @State private var permissionNotifDelegate = PermissionNotificationDelegate()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"
    @State private var showLaunchScreen = true

    private var computedColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // "system" follows device setting
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                SidebarRootView()
                    .environment(appState)
                    .environment(themeManager)
                    .environment(\.theme, themeManager.currentSnapshot)
                    .preferredColorScheme(computedColorScheme)
                    .dynamicTypeSize(DynamicTypeSize.xSmall ... DynamicTypeSize.accessibility3)
                    .onOpenURL { url in
                        appState.handleURL(url)
                    }
                    .task {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showLaunchScreen = false
                        }
                        ICloudSyncManager.shared.syncPreferencesToCloud()
                        Task.detached(priority: .background) {
                            try? Tips.configure([
                                .displayFrequency(.daily),
                                .datastoreLocation(.applicationDefault)
                            ])
                            // Donate app open count for TipKit sequential unlock
                            let currentCount = UserDefaults.standard.integer(forKey: "appOpenCount") + 1
                            UserDefaults.standard.set(currentCount, forKey: "appOpenCount")
                            ThemeTip.appOpenCount = currentCount
                            MCPBrowserTip.appOpenCount = currentCount
                            SkippedTourTip.appOpenCount = currentCount

                            // Compute onboarding window: progressive tips only show within
                            // the first 7 days after onboarding completion.
                            let isWithinOnboardingWindow: Bool
                            if let completionDate = UserDefaults.standard.object(
                                forKey: "onboardingCompletionDate"
                            ) as? Date {
                                let daysSince = Calendar.current.dateComponents(
                                    [.day],
                                    from: completionDate,
                                    to: Date()
                                ).day ?? Int.max
                                isWithinOnboardingWindow = daysSince < 7
                            } else {
                                isWithinOnboardingWindow = false
                            }
                            CommandPaletteTip.isWithinOnboardingWindow = isWithinOnboardingWindow
                            ThemeTip.isWithinOnboardingWindow = isWithinOnboardingWindow
                            MCPBrowserTip.isWithinOnboardingWindow = isWithinOnboardingWindow
                            TeamsTip.isWithinOnboardingWindow = isWithinOnboardingWindow

                            // Surface the skipped-tour tip for users who skipped onboarding
                            // but have not yet completed the feature tour.
                            let tourSkipped = UserDefaults.standard.bool(forKey: "onboardingSkipped")
                            let tourDone = UserDefaults.standard.bool(forKey: "featureTourCompleted")
                            SkippedTourTip.tourWasSkipped = tourSkipped && !tourDone

                            await CacheService.shared.initialize()
                        }
                        #if os(iOS)
                        // MEM-01 + H-M1: Proactive cache eviction under memory pressure.
                        // Observer targets a singleton (CacheService.shared) so no retain cycle,
                        // but NotificationCenter holds the token forever. Acceptable for app-lifetime
                        // observer registered once in the root @main struct.
                        NotificationCenter.default.addObserver(
                            forName: UIApplication.didReceiveMemoryWarningNotification,
                            object: nil,
                            queue: .main
                        ) { _ in
                            Task {
                                await CacheService.shared.cleanupExpired()
                                AppLogger.shared.warning("Memory pressure: caches evicted", category: "memory")
                            }
                        }
                        PerformanceMonitor.shared.start()

                        // Register permission notification category and request authorization.
                        // Delegate is set before requestAuthorization so action taps received
                        // during launch are handled correctly.
                        UNUserNotificationCenter.current().delegate = permissionNotifDelegate
                        PermissionService.registerNotificationCategory()
                        try? await UNUserNotificationCenter.current().requestAuthorization(
                            options: [.alert, .sound, .badge]
                        )
                        permissionNotifDelegate.onAction = { requestId, decision in
                            Task {
                                try? await appState.permissionService.submitDecision(
                                    requestId: requestId,
                                    decision: decision,
                                    apiClient: appState.apiClient
                                )
                            }
                        }
                        #endif
                    }

                if showLaunchScreen {
                    LaunchScreenView()
                        .environment(\.theme, themeManager.currentSnapshot)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhase(newPhase)
            if newPhase == .active {
                ICloudSyncManager.shared.syncPreferencesToCloud()
            }
        }
    }
}

// MARK: - Permission Notification Delegate

/// Routes UNUserNotificationCenter action callbacks (Allow / Deny) to ``PermissionService``.
///
/// Registered as the `UNUserNotificationCenter` delegate at launch by ``ILSAppApp``.
/// The ``onAction`` closure is set after the delegate is registered so it has a live
/// reference to `AppState` without retaining the SwiftUI view hierarchy.
final class PermissionNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Called by `ILSAppApp` to forward notification actions to the live `PermissionService`.
    var onAction: ((String, String) -> Void)?

    /// Shows permission notifications as banners when the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handles Allow / Deny taps on permission notification action buttons.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard let requestId = userInfo["requestId"] as? String else { return }

        switch response.actionIdentifier {
        case "ALLOW_PERMISSION":
            onAction?(requestId, "allow")
        case "DENY_PERMISSION":
            onAction?(requestId, "deny")
        default:
            break
        }
    }
}
