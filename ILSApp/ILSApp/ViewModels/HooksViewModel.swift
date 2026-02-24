import Foundation
import Observation
import ILSShared

/// Represents a single flattened hook for display in the hooks management UI.
struct HookDisplayItem: Identifiable, Hashable {
    let id: UUID
    let eventType: String
    let matcher: String?
    let hookType: String?
    let command: String?
    let groupIndex: Int
    let hookIndex: Int

    init(
        eventType: String,
        matcher: String?,
        hookType: String?,
        command: String?,
        groupIndex: Int,
        hookIndex: Int
    ) {
        self.id = UUID()
        self.eventType = eventType
        self.matcher = matcher
        self.hookType = hookType
        self.command = command
        self.groupIndex = groupIndex
        self.hookIndex = hookIndex
    }
}

@MainActor
@Observable
class HooksViewModel {
    var hooks: [HookDisplayItem] = []
    var isLoading = false
    var error: Error?
    var config: ConfigInfo?

    private var client: APIClient?

    init() {}

    func configure(client: APIClient) {
        self.client = client
    }

    /// Total number of hooks across all event types
    var totalHookCount: Int {
        hooks.count
    }

    /// Hooks grouped by event type for sectioned display
    var hooksByEventType: [String: [HookDisplayItem]] {
        Dictionary(grouping: hooks, by: \.eventType)
    }

    /// All distinct event types present in the hooks configuration
    var eventTypes: [String] {
        let types = Set(hooks.map(\.eventType))
        // Sort in a logical order matching Claude Code's hook lifecycle
        let order = ["SessionStart", "SubagentStart", "UserPromptSubmit", "PreToolUse", "PostToolUse"]
        return types.sorted { left, right in
            let leftIdx = order.firstIndex(of: left) ?? Int.max
            let rightIdx = order.firstIndex(of: right) ?? Int.max
            return leftIdx < rightIdx
        }
    }

    /// Count of hooks for a specific event type
    func countForEventType(_ eventType: String) -> Int {
        hooks.filter { $0.eventType == eventType }.count
    }

    /// Icon name for each hook event type
    func iconForEventType(_ eventType: String) -> String {
        switch eventType {
        case "SessionStart": return "play.circle"
        case "SubagentStart": return "person.2.circle"
        case "UserPromptSubmit": return "text.bubble"
        case "PreToolUse": return "wrench.and.screwdriver"
        case "PostToolUse": return "checkmark.circle"
        default: return "gearshape"
        }
    }

    /// Human-readable label for each hook event type
    func labelForEventType(_ eventType: String) -> String {
        switch eventType {
        case "SessionStart": return "Session Start"
        case "SubagentStart": return "Subagent Start"
        case "UserPromptSubmit": return "User Prompt Submit"
        case "PreToolUse": return "Pre Tool Use"
        case "PostToolUse": return "Post Tool Use"
        default: return eventType
        }
    }

    /// Description for each hook event type
    func descriptionForEventType(_ eventType: String) -> String {
        switch eventType {
        case "SessionStart": return "Runs when a Claude Code session begins"
        case "SubagentStart": return "Runs when a sub-agent is spawned"
        case "UserPromptSubmit": return "Runs before each user prompt is processed"
        case "PreToolUse": return "Runs before a tool is executed"
        case "PostToolUse": return "Runs after a tool finishes executing"
        default: return "Custom hook event"
        }
    }

    func loadHooks() async {
        guard let client else { return }
        isLoading = true
        error = nil

        do {
            let response: APIResponse<ConfigInfo> = try await client.get("/config?scope=user")
            if let configData = response.data {
                config = configData
                flattenHooks(from: configData.content.hooks)
            }
        } catch {
            self.error = error
            AppLogger.shared.error("Failed to load hooks config: \(error.localizedDescription)", category: "hooks")
        }

        isLoading = false
    }

    func refreshHooks() async {
        await loadHooks()
    }

    // MARK: - Private

    private func flattenHooks(from hooksConfig: HooksConfig?) {
        var items: [HookDisplayItem] = []

        guard let hooksConfig else {
            hooks = items
            return
        }

        items.append(contentsOf: flattenGroups(hooksConfig.sessionStart, eventType: "SessionStart"))
        items.append(contentsOf: flattenGroups(hooksConfig.subagentStart, eventType: "SubagentStart"))
        items.append(contentsOf: flattenGroups(hooksConfig.userPromptSubmit, eventType: "UserPromptSubmit"))
        items.append(contentsOf: flattenGroups(hooksConfig.preToolUse, eventType: "PreToolUse"))
        items.append(contentsOf: flattenGroups(hooksConfig.postToolUse, eventType: "PostToolUse"))

        hooks = items
    }

    private func flattenGroups(_ groups: [HookGroup]?, eventType: String) -> [HookDisplayItem] {
        guard let groups else { return [] }
        var items: [HookDisplayItem] = []

        for (groupIndex, group) in groups.enumerated() {
            guard let hookDefs = group.hooks else { continue }
            for (hookIndex, hookDef) in hookDefs.enumerated() {
                items.append(HookDisplayItem(
                    eventType: eventType,
                    matcher: group.matcher,
                    hookType: hookDef.type,
                    command: hookDef.command,
                    groupIndex: groupIndex,
                    hookIndex: hookIndex
                ))
            }
        }

        return items
    }
}
