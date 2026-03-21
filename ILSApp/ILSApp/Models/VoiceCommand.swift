import Foundation

// MARK: - VoiceCommandCategory

/// Groups voice commands into logical sections for display and filtering.
enum VoiceCommandCategory: String, CaseIterable, Codable, Sendable {
    case session
    case navigation
    case permission
    case workflow
    case status

    /// Human-readable section title.
    var displayName: String {
        switch self {
        case .session: return "Sessions"
        case .navigation: return "Navigation"
        case .permission: return "Permissions"
        case .workflow: return "Workflows"
        case .status: return "Status"
        }
    }

    /// SF Symbol name representing this category.
    var icon: String {
        switch self {
        case .session: return "bubble.left.fill"
        case .navigation: return "arrow.up.right.square"
        case .permission: return "shield.checkered"
        case .workflow: return "play.circle.fill"
        case .status: return "chart.bar.doc.horizontal"
        }
    }
}

// MARK: - VoiceCommandAction

/// The effect produced when a voice command is executed.
enum VoiceCommandAction: Sendable {
    /// Approve the current pending permission request.
    case approve
    /// Deny the current pending permission request.
    case deny
    /// Approve all pending permission requests.
    case approveAll
    /// Deny all pending permission requests.
    case denyAll
    /// Open a specific session by context.
    case openSession
    /// Create a new session.
    case newSession
    /// Delete the current session (destructive).
    case deleteSession
    /// Summarize the current status of sessions.
    case summarizeStatus
    /// Trigger a workflow by name.
    case triggerWorkflow
    /// Navigate the app to a top-level screen.
    case navigate(ActiveScreen)
    /// A custom string-based action; handled by the caller.
    case custom(String)
}

// MARK: - VoiceCommand

/// A single voice command that can be recognized from speech and executed.
struct VoiceCommand: Identifiable, Sendable {
    /// Stable identifier used for tracking and persistence.
    let id: String
    /// Which category bucket this command belongs to.
    let category: VoiceCommandCategory
    /// Natural language phrases that trigger this command.
    let phrases: [String]
    /// The effect produced when this command is executed.
    let action: VoiceCommandAction
    /// Whether this command performs a destructive or irreversible operation.
    let isDestructive: Bool
    /// Whether the user must confirm before execution (always true for destructive).
    let requiresConfirmation: Bool
    /// Whether this command can be queued for offline execution.
    let offlineCapable: Bool
    /// SF Symbol name for display.
    let icon: String
    /// Primary display label.
    let displayName: String
    /// Secondary description shown below the display name.
    let description: String
}

// MARK: - VoiceCommandMatch

/// The result of attempting to match transcribed speech to a voice command.
enum VoiceCommandMatch: Sendable {
    /// An exact phrase match with high confidence.
    case exact(VoiceCommand, confidence: Double)
    /// A fuzzy match with moderate confidence.
    case fuzzy(VoiceCommand, confidence: Double)
    /// Multiple commands matched with similar confidence; user must disambiguate.
    case ambiguous([VoiceCommand])
    /// No match found; includes suggestions of closest commands.
    case noMatch(suggestions: [VoiceCommand])
}

// MARK: - VoiceCommandCatalog

/// The predefined catalog of all available voice commands.
struct VoiceCommandCatalog {

    /// All registered voice commands.
    static let allCommands: [VoiceCommand] = {
        var commands: [VoiceCommand] = []

        // MARK: Permission Commands

        commands.append(VoiceCommand(
            id: "voice-approve",
            category: .permission,
            phrases: ["approve", "allow", "accept", "yes", "go ahead", "permit", "approve it"],
            action: .approve,
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: false,
            icon: "shield.checkered",
            displayName: "Approve",
            description: "Approve the current pending permission request"
        ))

        commands.append(VoiceCommand(
            id: "voice-deny",
            category: .permission,
            phrases: ["deny", "reject", "block", "no", "refuse", "deny it"],
            action: .deny,
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: false,
            icon: "shield.slash",
            displayName: "Deny",
            description: "Deny the current pending permission request"
        ))

        commands.append(VoiceCommand(
            id: "voice-approve-all",
            category: .permission,
            phrases: ["approve all", "allow all", "accept all", "approve everything"],
            action: .approveAll,
            isDestructive: false,
            requiresConfirmation: true,
            offlineCapable: false,
            icon: "shield.checkered",
            displayName: "Approve All",
            description: "Approve all pending permission requests"
        ))

        commands.append(VoiceCommand(
            id: "voice-deny-all",
            category: .permission,
            phrases: ["deny all", "reject all", "block all"],
            action: .denyAll,
            isDestructive: true,
            requiresConfirmation: true,
            offlineCapable: false,
            icon: "shield.slash",
            displayName: "Deny All",
            description: "Deny all pending permission requests"
        ))

        // MARK: Session Commands

        commands.append(VoiceCommand(
            id: "voice-new-session",
            category: .session,
            phrases: ["new session", "create session", "start session", "start new session"],
            action: .newSession,
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: false,
            icon: "plus.bubble.fill",
            displayName: "New Session",
            description: "Create a new chat session"
        ))

        commands.append(VoiceCommand(
            id: "voice-delete-session",
            category: .session,
            phrases: ["delete session", "remove session", "close session"],
            action: .deleteSession,
            isDestructive: true,
            requiresConfirmation: true,
            offlineCapable: false,
            icon: "trash.fill",
            displayName: "Delete Session",
            description: "Delete the current session"
        ))

        // MARK: Navigation Commands

        commands.append(VoiceCommand(
            id: "voice-go-home",
            category: .navigation,
            phrases: ["go to home", "go home", "open home", "show home"],
            action: .navigate(.home),
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: true,
            icon: "house.fill",
            displayName: "Go to Home",
            description: "Navigate to the home screen"
        ))

        commands.append(VoiceCommand(
            id: "voice-open-sessions",
            category: .navigation,
            phrases: ["open sessions", "show sessions", "go to sessions"],
            action: .navigate(.home),
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: true,
            icon: "bubble.left.fill",
            displayName: "Open Sessions",
            description: "Navigate to the sessions list"
        ))

        commands.append(VoiceCommand(
            id: "voice-show-settings",
            category: .navigation,
            phrases: ["show settings", "open settings", "go to settings"],
            action: .navigate(.settings),
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: true,
            icon: "gearshape.fill",
            displayName: "Show Settings",
            description: "Navigate to the settings screen"
        ))

        commands.append(VoiceCommand(
            id: "voice-go-system",
            category: .navigation,
            phrases: ["go to system", "open system", "show system"],
            action: .navigate(.system),
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: true,
            icon: "gauge.with.dots.needle.33percent",
            displayName: "Go to System",
            description: "Navigate to the system screen"
        ))

        commands.append(VoiceCommand(
            id: "voice-show-workflows",
            category: .navigation,
            phrases: ["show workflows", "open workflows", "go to workflows"],
            action: .navigate(.agentQueue),
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: true,
            icon: "play.circle.fill",
            displayName: "Show Workflows",
            description: "Navigate to the workflows screen"
        ))

        // MARK: Status Commands

        commands.append(VoiceCommand(
            id: "voice-summarize-status",
            category: .status,
            phrases: ["status", "summarize", "what is happening", "show status", "session status"],
            action: .summarizeStatus,
            isDestructive: false,
            requiresConfirmation: false,
            offlineCapable: false,
            icon: "chart.bar.doc.horizontal",
            displayName: "Summarize Status",
            description: "Get a summary of current session activity"
        ))

        // MARK: Workflow Commands

        commands.append(VoiceCommand(
            id: "voice-trigger-workflow",
            category: .workflow,
            phrases: ["run workflow", "trigger workflow", "execute workflow", "start workflow"],
            action: .triggerWorkflow,
            isDestructive: false,
            requiresConfirmation: true,
            offlineCapable: false,
            icon: "play.circle.fill",
            displayName: "Trigger Workflow",
            description: "Start a workflow execution"
        ))

        return commands
    }()

    /// Returns commands filtered by category.
    static func commands(for category: VoiceCommandCategory) -> [VoiceCommand] {
        allCommands.filter { $0.category == category }
    }

    /// Looks up a command by its stable identifier.
    static func command(withId id: String) -> VoiceCommand? {
        allCommands.first { $0.id == id }
    }
}
