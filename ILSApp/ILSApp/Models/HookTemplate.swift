import Foundation
import ILSShared

struct HookTemplate: Codable, Identifiable {
    let id: UUID
    var name: String
    var description: String
    var category: String
    var eventType: String
    var matcher: String?
    var hookDefinition: HookDefinition

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        category: String = "General",
        eventType: String = "PreToolUse",
        matcher: String? = nil,
        hookDefinition: HookDefinition
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.eventType = eventType
        self.matcher = matcher
        self.hookDefinition = hookDefinition
    }

    /// Pre-built hook templates for common automation patterns.
    static let defaults: [HookTemplate] = [
        // MARK: Notifications
        HookTemplate(
            name: "Session Start Notification",
            description: "Show a system notification when a Claude Code session begins",
            category: "Notifications",
            eventType: "SessionStart",
            hookDefinition: HookDefinition(
                type: "command",
                command: "osascript -e 'display notification \"Session started\" with title \"Claude Code\"'"
            )
        ),
        HookTemplate(
            name: "Notify on File Delete",
            description: "Alert when Claude runs a shell command that could delete files",
            category: "Notifications",
            eventType: "PreToolUse",
            matcher: "Bash",
            hookDefinition: HookDefinition(
                type: "command",
                command: #"echo "$CLAUDE_TOOL_INPUT" | grep -qE '\brm\b|\brmdir\b' && osascript -e 'display notification "Claude wants to delete files" with title "Claude Code"' || true"#
            )
        ),

        // MARK: Monitoring
        HookTemplate(
            name: "Log Bash Commands",
            description: "Append every bash command Claude runs to ~/claude_commands.log",
            category: "Monitoring",
            eventType: "PreToolUse",
            matcher: "Bash",
            hookDefinition: HookDefinition(
                type: "command",
                command: #"echo "[$(date '+%Y-%m-%d %H:%M:%S')] $CLAUDE_TOOL_INPUT" >> ~/claude_commands.log"#,
                isAsync: true
            )
        ),
        HookTemplate(
            name: "Log Tool Usage Statistics",
            description: "Track which tools Claude uses to ~/claude_tool_stats.jsonl for analysis",
            category: "Monitoring",
            eventType: "PostToolUse",
            hookDefinition: HookDefinition(
                type: "command",
                command: #"echo "{\"tool\": \"$CLAUDE_TOOL_NAME\", \"time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> ~/claude_tool_stats.jsonl"#,
                isAsync: true
            )
        ),

        // MARK: Automation
        HookTemplate(
            name: "Auto-approve Reads in /src",
            description: "Silently allow all file reads within the /src directory without prompting",
            category: "Automation",
            eventType: "PreToolUse",
            matcher: "Read",
            hookDefinition: HookDefinition(
                type: "command",
                command: #"echo "$CLAUDE_TOOL_INPUT_FILE_PATH" | grep -q '/src/' && exit 0 || exit 1"#
            )
        ),

        // MARK: Safety
        HookTemplate(
            name: "Block Writes Outside Project",
            description: "Prevent Claude from writing files outside the current project directory",
            category: "Safety",
            eventType: "PreToolUse",
            matcher: "Write",
            hookDefinition: HookDefinition(
                type: "command",
                command: #"echo "$CLAUDE_TOOL_INPUT_FILE_PATH" | grep -q "$PWD" || { echo 'Blocked: file is outside project directory' >&2; exit 2; }"#
            )
        ),
    ]
}
