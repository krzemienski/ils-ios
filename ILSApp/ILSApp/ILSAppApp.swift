import SwiftUI
import Observation
import ILSShared
import TipKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import BackgroundTasks
#endif

@main
struct ILSAppApp: App {
    @State private var appState = AppState()
    @State private var themeManager = ThemeManager()
    @State private var layoutStore = DashboardLayoutStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("colorScheme") private var colorSchemePreference: String = "dark"
    @State private var showLaunchScreen = true

    init() {
        #if os(iOS)
        // Register default values for notification preferences. These are only used when
        // the user has never explicitly set the preference (i.e., on fresh install before
        // visiting Settings). UserDefaults.register does NOT overwrite existing user values.
        UserDefaults.standard.register(defaults: [
            "notif_sessionCompleteAlerts": true,
            "notif_sessionErrorAlerts": true,
            "notif_mcpOfflineAlerts": true,
            "notif_mcpOnlineAlerts": false,
            "notif_quietHoursEnabled": false,
            "notif_quietStartHour": 22,
            "notif_quietEndHour": 7
        ])

        // BGTaskScheduler.shared.register must be called before the app finishes launching.
        // Registering here in init() satisfies that requirement.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: SessionMonitorService.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                SessionMonitorService.shared.handleBackgroundTask(refreshTask)
            }
        }
        #endif
    }

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
                    .environment(layoutStore)
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
                            try? await SessionMemoryService.shared.initialize()
                        }
                        #if os(iOS)
                        // Request notification permissions on first launch.
                        // Errors are non-fatal — user can enable permissions later in Settings.
                        do {
                            try await NotificationService.shared.requestAuthorization()
                        } catch {
                            AppLogger.shared.warning(
                                "Failed to request notification permissions: \(error)",
                                category: "notifications"
                            )
                        }

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
                        Task {
                            try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        }
                        _ = AlertThresholdManager.shared
                        #endif
                    }
                    #if os(iOS)
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("OpenSessionFromNotification")
                        )
                    ) { notification in
                        guard let sessionId = notification.object as? UUID else { return }
                        // UUIDs in deep links must be lowercase (per CLAUDE.md)
                        let path = "ils://sessions/\(sessionId.uuidString.lowercased())"
                        if let url = URL(string: path) {
                            appState.handleURL(url)
                        }
                    }
                    #endif

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
