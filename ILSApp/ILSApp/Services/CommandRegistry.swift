import Foundation
import Observation

// MARK: - CommandCategory

/// Groups commands into logical sections shown in the command palette.
enum CommandCategory: String, CaseIterable {
    case navigation
    case sessions
    case system
    case settings
    case mcp
    case teams
    case voiceCommands

    /// Human-readable section title shown in the palette.
    var displayName: String {
        switch self {
        case .navigation: return "Navigation"
        case .sessions: return "Sessions"
        case .system: return "System"
        case .settings: return "Settings"
        case .mcp: return "MCP"
        case .teams: return "Teams"
        case .voiceCommands: return "Voice Commands"
        }
    }

    /// SF Symbol name representing this category.
    var icon: String {
        switch self {
        case .navigation: return "arrow.up.right.square"
        case .sessions: return "bubble.left.fill"
        case .system: return "gauge.with.dots.needle.33percent"
        case .settings: return "gearshape.fill"
        case .mcp: return "server.rack"
        case .teams: return "person.3.fill"
        case .voiceCommands: return "waveform.badge.mic"
        }
    }
}

// MARK: - CommandAction

/// The effect produced when a command is executed.
enum CommandAction {
    /// Navigate the app to the specified top-level screen.
    case navigate(ActiveScreen)
    /// Post a notification to `NotificationCenter.default`.
    case postNotification(Notification.Name)
    /// A custom string-based action; handled by the caller.
    case custom(String)
}

// MARK: - GlobalCommand

/// A single executable command entry in the global command palette.
struct GlobalCommand: Identifiable {
    /// Stable identifier used for recent-command tracking and shortcut customization.
    let id: String
    /// Primary display label shown in the palette row.
    let title: String
    /// Secondary description shown below the title.
    let subtitle: String
    /// Which category bucket this command belongs to.
    let category: CommandCategory
    /// SF Symbol name for the row icon.
    let icon: String
    /// Default keyboard shortcut hint to display (e.g. "⌘K"), if any.
    let defaultShortcutDisplay: String?
    /// The effect produced when this command is selected.
    let action: CommandAction
}

// MARK: - CommandRegistry

/// Observable service that owns the master list of global commands,
/// tracks recent usage, and provides fuzzy-search results.
///
/// Usage counts and recent-command IDs are persisted to `UserDefaults`
/// so the "recently used" section survives app restarts.
@MainActor
@Observable
class CommandRegistry {
    /// All registered commands in insertion order.
    private(set) var allCommands: [GlobalCommand] = []

    /// IDs of recently used commands, most-recent first. Capped at 10 entries.
    private(set) var recentCommandIds: [String] = []

    /// Number of times each command ID has been executed this app lifetime.
    private(set) var usageCount: [String: Int] = [:]

    init() {
        loadPersistedData()
        registerBuiltInCommands()
    }

    // MARK: - Public API

    /// Records a command execution, updating usage count and recent-commands list.
    func recordUsage(commandId: String) {
        usageCount[commandId, default: 0] += 1

        recentCommandIds.removeAll { $0 == commandId }
        recentCommandIds.insert(commandId, at: 0)
        if recentCommandIds.count > 10 {
            recentCommandIds = Array(recentCommandIds.prefix(10))
        }

        persistData()
    }

    /// Returns recently used commands sorted by usage frequency descending.
    func recentCommands() -> [GlobalCommand] {
        recentCommandIds
            .compactMap { id in allCommands.first { $0.id == id } }
            .sorted { (usageCount[$0.id] ?? 0) > (usageCount[$1.id] ?? 0) }
    }

    /// Returns commands matching `query` via fuzzy search, sorted by relevance.
    /// When `query` is empty, returns all commands in their original order.
    func search(query: String) -> [GlobalCommand] {
        guard !query.isEmpty else { return allCommands }
        return allCommands
            .filter {
                FuzzyMatcher.matches(query: query, in: $0.title)
                || FuzzyMatcher.matches(query: query, in: $0.subtitle)
            }
            .sorted {
                let scoreA = max(
                    FuzzyMatcher.score(query: query, in: $0.title),
                    FuzzyMatcher.score(query: query, in: $0.subtitle)
                )
                let scoreB = max(
                    FuzzyMatcher.score(query: query, in: $1.title),
                    FuzzyMatcher.score(query: query, in: $1.subtitle)
                )
                return scoreA > scoreB
            }
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        recentCommandIds = UserDefaults.standard
            .stringArray(forKey: AppConstants.commandPaletteRecentCommandsKey) ?? []

        if let data = UserDefaults.standard.data(forKey: AppConstants.commandPaletteUsageCountKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            usageCount = decoded
        }
    }

    private func persistData() {
        UserDefaults.standard.set(
            recentCommandIds,
            forKey: AppConstants.commandPaletteRecentCommandsKey
        )
        if let encoded = try? JSONEncoder().encode(usageCount) {
            UserDefaults.standard.set(encoded, forKey: AppConstants.commandPaletteUsageCountKey)
        }
    }

    // MARK: - Built-in Commands

    private func registerBuiltInCommands() {
        allCommands = [
            // Navigation
            GlobalCommand(
                id: "goto-home",
                title: "Home",
                subtitle: "Navigate to home screen",
                category: .navigation,
                icon: "house.fill",
                defaultShortcutDisplay: "⌘1",
                action: .navigate(.home)
            ),
            GlobalCommand(
                id: "goto-sessions",
                title: "Sessions",
                subtitle: "Navigate to sessions list",
                category: .navigation,
                icon: "bubble.left.fill",
                defaultShortcutDisplay: "⌘2",
                action: .navigate(.home)
            ),
            GlobalCommand(
                id: "goto-browse",
                title: "Browse",
                subtitle: "Navigate to project browser",
                category: .navigation,
                icon: "square.grid.2x2.fill",
                defaultShortcutDisplay: "⌘3",
                action: .navigate(.browser)
            ),
            GlobalCommand(
                id: "goto-system",
                title: "System",
                subtitle: "Navigate to system screen",
                category: .navigation,
                icon: "gauge.with.dots.needle.33percent",
                defaultShortcutDisplay: "⌘4",
                action: .navigate(.system)
            ),
            // Settings
            GlobalCommand(
                id: "goto-settings",
                title: "Settings",
                subtitle: "Open app settings",
                category: .settings,
                icon: "gearshape.fill",
                defaultShortcutDisplay: "⌘,",
                action: .navigate(.settings)
            ),
            // Sessions
            GlobalCommand(
                id: "new-session",
                title: "New Session",
                subtitle: "Create a new chat session",
                category: .sessions,
                icon: "plus.bubble.fill",
                defaultShortcutDisplay: "⌘N",
                action: .postNotification(Notification.Name("ILSCreateNewSession"))
            ),
            GlobalCommand(
                id: "rename-session",
                title: "Rename Session",
                subtitle: "Rename the current session",
                category: .sessions,
                icon: "pencil",
                defaultShortcutDisplay: "⌘⇧R",
                action: .postNotification(Notification.Name("ILSRenameSession"))
            ),
            GlobalCommand(
                id: "fork-session",
                title: "Fork Session",
                subtitle: "Fork the current session",
                category: .sessions,
                icon: "arrow.branch",
                defaultShortcutDisplay: "⌘⇧F",
                action: .postNotification(Notification.Name("ILSForkSession"))
            ),
            GlobalCommand(
                id: "export-session",
                title: "Export Session",
                subtitle: "Export the current session",
                category: .sessions,
                icon: "square.and.arrow.up",
                defaultShortcutDisplay: "⌘⇧E",
                action: .postNotification(Notification.Name("ILSExportSession"))
            ),
            GlobalCommand(
                id: "delete-session",
                title: "Delete Session",
                subtitle: "Delete the current session",
                category: .sessions,
                icon: "trash",
                defaultShortcutDisplay: "⌘⌫",
                action: .postNotification(Notification.Name("ILSDeleteSession"))
            ),
            // Voice Commands
            GlobalCommand(
                id: "approve-permission",
                title: "Approve Permission",
                subtitle: "Approve the pending permission request",
                category: .voiceCommands,
                icon: "shield.lefthalf.filled.badge.checkmark",
                defaultShortcutDisplay: nil,
                action: .postNotification(Notification.Name("ILSApprovePermission"))
            ),
            GlobalCommand(
                id: "deny-permission",
                title: "Deny Permission",
                subtitle: "Deny the pending permission request",
                category: .voiceCommands,
                icon: "shield.slash",
                defaultShortcutDisplay: nil,
                action: .postNotification(Notification.Name("ILSDenyPermission"))
            ),
            GlobalCommand(
                id: "summarize-status",
                title: "Summarize Status",
                subtitle: "Get a summary of active sessions and system status",
                category: .voiceCommands,
                icon: "chart.bar.doc.horizontal",
                defaultShortcutDisplay: nil,
                action: .custom("summarize-status")
            ),
            GlobalCommand(
                id: "voice-command-mode",
                title: "Voice Command Mode",
                subtitle: "Toggle voice command recognition mode",
                category: .voiceCommands,
                icon: "waveform.badge.mic",
                defaultShortcutDisplay: nil,
                action: .custom("voice-command-mode")
            ),
        ]
    }
}
