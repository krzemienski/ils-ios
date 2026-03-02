import AppIntents

/// Provides App Shortcuts for Siri and the Shortcuts app.
///
/// These shortcuts appear in Spotlight search and can be invoked via voice commands.
@available(iOS 16.0, *)
struct ILSShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateSessionIntent(),
            phrases: [
                "Create a new \(.applicationName) session",
                "Start a new session in \(.applicationName)",
                "New \(.applicationName) session"
            ],
            shortTitle: "New Session",
            systemImageName: "plus.message"
        )
        AppShortcut(
            intent: SendMessageIntent(),
            phrases: [
                "Send a message in \(.applicationName)",
                "Message \(.applicationName)",
                "Ask \(.applicationName)"
            ],
            shortTitle: "Send Message",
            systemImageName: "paperplane"
        )
        AppShortcut(
            intent: GetSessionInfoIntent(),
            phrases: [
                "Get session info from \(.applicationName)",
                "Show \(.applicationName) session details",
                "Check session status in \(.applicationName)"
            ],
            shortTitle: "Session Info",
            systemImageName: "info.circle"
        )
        AppShortcut(
            intent: ListSessionsIntent(),
            phrases: [
                "List my \(.applicationName) sessions",
                "Show \(.applicationName) sessions",
                "What sessions are open in \(.applicationName)"
            ],
            shortTitle: "List Sessions",
            systemImageName: "list.bullet"
        )
        AppShortcut(
            intent: ListProjectsIntent(),
            phrases: [
                "List my \(.applicationName) projects",
                "Show \(.applicationName) projects",
                "What projects are in \(.applicationName)"
            ],
            shortTitle: "List Projects",
            systemImageName: "folder"
        )
    }
}
