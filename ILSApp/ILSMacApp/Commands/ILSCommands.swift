import SwiftUI
import ILSShared

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the user requests a new session via the menu bar.
    static let ilsCreateNewSession = Notification.Name("ILSCreateNewSession")

    /// Posted when the user requests navigation to a specific screen.
    /// The notification `object` is the target screen name as a `String`.
    static let ilsNavigateTo = Notification.Name("ILSNavigateTo")

    /// Posted when the user wants to rename the current session.
    static let ilsRenameSession = Notification.Name("ILSRenameSession")

    /// Posted when the user wants to fork the current session.
    static let ilsForkSession = Notification.Name("ILSForkSession")

    /// Posted when the user wants to export the current session.
    static let ilsExportSession = Notification.Name("ILSExportSession")

    /// Posted when the user wants to delete the current session.
    static let ilsDeleteSession = Notification.Name("ILSDeleteSession")
}

// MARK: - ILS Commands

/// SwiftUI `Commands` providing keyboard shortcuts and menu items for the ILS macOS app.
///
/// Communication with views uses `NotificationCenter` since `Commands` do not have
/// direct access to view state. Views observe these notifications to perform actions.
struct ILSCommands: Commands {
    var body: some Commands {
        // Replace the default New Window command group
        CommandGroup(replacing: .newItem) {
            Button("New Session") {
                NotificationCenter.default.post(name: .ilsCreateNewSession, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Navigation menu
        CommandMenu("Navigate") {
            Button("Home") {
                NotificationCenter.default.post(name: .ilsNavigateTo, object: "home")
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Sessions") {
                NotificationCenter.default.post(name: .ilsNavigateTo, object: "sessions")
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Browse") {
                NotificationCenter.default.post(name: .ilsNavigateTo, object: "browser")
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("System Monitor") {
                NotificationCenter.default.post(name: .ilsNavigateTo, object: "system")
            }
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Button("Settings") {
                NotificationCenter.default.post(name: .ilsNavigateTo, object: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // Session menu
        CommandMenu("Session") {
            Button("Rename Session...") {
                NotificationCenter.default.post(name: .ilsRenameSession, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Fork Session") {
                NotificationCenter.default.post(name: .ilsForkSession, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Export Session...") {
                NotificationCenter.default.post(name: .ilsExportSession, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Delete Session") {
                NotificationCenter.default.post(name: .ilsDeleteSession, object: nil)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}
