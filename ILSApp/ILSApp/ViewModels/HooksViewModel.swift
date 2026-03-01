import Foundation
import Observation
import ILSShared

// MARK: - Hook Event Type Metadata

/// Metadata for a Claude Code hook event type, used for UI display.
struct HookEventTypeInfo: Sendable {
    let name: String       // PascalCase, matches JSON key (e.g., "PreToolUse")
    let label: String      // Human-readable (e.g., "Pre Tool Use")
    let icon: String       // SF Symbol name
    let description: String
    let matcherDescription: String?  // What the matcher filters, nil = no matcher support
}

// MARK: - Hook Display Item

/// Represents a single flattened hook for display in the hooks management UI.
struct HookDisplayItem: Identifiable, Hashable {
    let id: UUID
    let eventType: String
    let matcher: String?
    let hookType: String?
    let command: String?
    let url: String?
    let prompt: String?
    let groupIndex: Int
    let hookIndex: Int
    /// Whether this hook is currently active in the Claude config.
    let isEnabled: Bool

    init(
        eventType: String,
        matcher: String?,
        hookType: String?,
        command: String?,
        url: String? = nil,
        prompt: String? = nil,
        groupIndex: Int,
        hookIndex: Int,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.eventType = eventType
        self.matcher = matcher
        self.hookType = hookType
        self.command = command
        self.url = url
        self.prompt = prompt
        self.groupIndex = groupIndex
        self.hookIndex = hookIndex
        self.isEnabled = isEnabled
    }

    /// Human-readable summary of the hook's action, regardless of handler type.
    var actionSummary: String {
        if let command, !command.isEmpty { return command }
        if let url, !url.isEmpty { return url }
        if let prompt, !prompt.isEmpty {
            let truncated = prompt.prefix(80)
            return truncated.count < prompt.count ? "\(truncated)..." : String(truncated)
        }
        return "No action configured"
    }
}

// MARK: - Hooks ViewModel

@MainActor
@Observable
class HooksViewModel {
    var hooks: [HookDisplayItem] = []
    var isLoading = false
    var isSaving = false
    var error: Error?
    var config: ConfigInfo?

    /// Keys of disabled hooks persisted across app launches.
    /// Format: "EventType:groupIndex" (e.g., "PreToolUse:0").
    private(set) var disabledHookKeys: Set<String> = []

    /// Snapshot of disabled hook groups keyed by hook key for restoration on re-enable.
    private var disabledHooksSnapshot: [String: HookGroup] = [:]

    private var client: APIClient?

    init() {
        loadDisabledState()
    }

    func configure(client: APIClient) {
        self.client = client
    }

    // MARK: - All 17 Claude Code Event Types (canonical order)

    /// Complete list of all Claude Code hook event types with UI metadata.
    /// Order follows the lifecycle: tool events -> session events -> subagent events -> team events -> config/workspace events.
    static let allEventTypes: [HookEventTypeInfo] = [
        // Tool events
        HookEventTypeInfo(name: "PreToolUse", label: "Pre Tool Use", icon: "wrench.and.screwdriver",
            description: "Runs before a tool call executes. Can block it.",
            matcherDescription: "Tool name (e.g., Bash, Edit, Write)"),
        HookEventTypeInfo(name: "PostToolUse", label: "Post Tool Use", icon: "checkmark.circle",
            description: "Runs after a tool call succeeds.",
            matcherDescription: "Tool name"),
        HookEventTypeInfo(name: "PostToolUseFailure", label: "Post Tool Use Failure", icon: "xmark.circle",
            description: "Runs after a tool call fails.",
            matcherDescription: "Tool name"),
        HookEventTypeInfo(name: "PermissionRequest", label: "Permission Request", icon: "lock.shield",
            description: "Runs when a permission dialog appears.",
            matcherDescription: "Tool name"),

        // Notification
        HookEventTypeInfo(name: "Notification", label: "Notification", icon: "bell",
            description: "Runs when Claude Code sends a notification.",
            matcherDescription: "Notification type"),

        // Session lifecycle events
        HookEventTypeInfo(name: "UserPromptSubmit", label: "User Prompt Submit", icon: "arrow.up.circle",
            description: "Runs when you submit a prompt, before Claude processes it.",
            matcherDescription: nil),
        HookEventTypeInfo(name: "Stop", label: "Stop", icon: "hand.raised",
            description: "Runs when Claude finishes responding.",
            matcherDescription: nil),
        HookEventTypeInfo(name: "SessionStart", label: "Session Start", icon: "play.circle",
            description: "Runs when a session begins or resumes.",
            matcherDescription: "How session started (startup, resume, clear, compact)"),
        HookEventTypeInfo(name: "SessionEnd", label: "Session End", icon: "stop.circle",
            description: "Runs when a session terminates.",
            matcherDescription: "Why session ended"),

        // Subagent events
        HookEventTypeInfo(name: "SubagentStart", label: "Subagent Start", icon: "person.fill.badge.plus",
            description: "Runs when a subagent is spawned.",
            matcherDescription: "Agent type"),
        HookEventTypeInfo(name: "SubagentStop", label: "Subagent Stop", icon: "person.fill.xmark",
            description: "Runs when a subagent finishes.",
            matcherDescription: "Agent type"),

        // Team events
        HookEventTypeInfo(name: "TeammateIdle", label: "Teammate Idle", icon: "person.crop.circle.badge.clock",
            description: "Runs when a team teammate is about to go idle.",
            matcherDescription: nil),
        HookEventTypeInfo(name: "TaskCompleted", label: "Task Completed", icon: "checkmark.seal",
            description: "Runs when a task is being marked as completed.",
            matcherDescription: nil),

        // Config & workspace events
        HookEventTypeInfo(name: "ConfigChange", label: "Config Change", icon: "gearshape.2",
            description: "Runs when a configuration file changes during a session.",
            matcherDescription: "Config source"),
        HookEventTypeInfo(name: "WorktreeCreate", label: "Worktree Create", icon: "plus.rectangle.on.folder",
            description: "Runs when a worktree is being created.",
            matcherDescription: nil),
        HookEventTypeInfo(name: "WorktreeRemove", label: "Worktree Remove", icon: "minus.rectangle",
            description: "Runs when a worktree is being removed.",
            matcherDescription: nil),
        HookEventTypeInfo(name: "PreCompact", label: "Pre Compact", icon: "arrow.down.right.and.arrow.up.left",
            description: "Runs before context compaction.",
            matcherDescription: "Trigger type (manual, auto)"),
    ]

    /// Lookup from event type name to metadata for O(1) access.
    private static let eventTypeLookup: [String: HookEventTypeInfo] = {
        Dictionary(uniqueKeysWithValues: allEventTypes.map { ($0.name, $0) })
    }()

    /// Canonical event type ordering for sorting.
    private static let eventTypeOrder: [String: Int] = {
        Dictionary(uniqueKeysWithValues: allEventTypes.enumerated().map { ($1.name, $0) })
    }()

    // MARK: - Computed Properties

    /// Total number of hooks across all event types.
    var totalHookCount: Int {
        hooks.count
    }

    /// Hooks grouped by event type for sectioned display.
    var hooksByEventType: [String: [HookDisplayItem]] {
        Dictionary(grouping: hooks, by: \.eventType)
    }

    /// All distinct event types present in the hooks configuration, sorted by lifecycle order.
    var eventTypes: [String] {
        let types = Set(hooks.map(\.eventType))
        return types.sorted { left, right in
            let leftIdx = Self.eventTypeOrder[left] ?? Int.max
            let rightIdx = Self.eventTypeOrder[right] ?? Int.max
            return leftIdx < rightIdx
        }
    }

    /// Count of hooks for a specific event type.
    func countForEventType(_ eventType: String) -> Int {
        hooks.filter { $0.eventType == eventType }.count
    }

    /// Icon name for each hook event type.
    func iconForEventType(_ eventType: String) -> String {
        Self.eventTypeLookup[eventType]?.icon ?? "bolt"
    }

    /// Human-readable label for each hook event type.
    func labelForEventType(_ eventType: String) -> String {
        Self.eventTypeLookup[eventType]?.label ?? eventType
    }

    /// Description for each hook event type.
    func descriptionForEventType(_ eventType: String) -> String {
        Self.eventTypeLookup[eventType]?.description ?? "Custom hook event"
    }

    /// Matcher description for a given event type. Nil means no matcher support.
    func matcherDescriptionForEventType(_ eventType: String) -> String? {
        Self.eventTypeLookup[eventType]?.matcherDescription
    }

    // MARK: - Load

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

    // MARK: - CRUD Operations

    /// Save a hook (create new or update existing).
    /// - Parameters:
    ///   - eventType: PascalCase event type name (e.g., "PreToolUse")
    ///   - group: The HookGroup to save (contains matcher + hooks array)
    ///   - editIndex: If non-nil, replaces the group at this index. If nil, appends as new.
    /// - Returns: Error message string, or nil on success.
    func saveHook(eventType: String, group: HookGroup, editIndex: Int?) async -> String? {
        guard client != nil else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        let settingsVM = SettingsViewModel()
        settingsVM.configure(client: client!)
        let result = await settingsVM.saveWithPatch { config in
            if config.hooks == nil {
                config.hooks = HooksConfig(events: [:])
            }
            var groups = config.hooks?.events[eventType] ?? []
            if let index = editIndex, index < groups.count {
                groups[index] = group
            } else {
                groups.append(group)
            }
            config.hooks?.events[eventType] = groups
        }

        if result == nil {
            // Reload hooks to reflect saved changes
            await loadHooks()
        }

        return result
    }

    /// Delete a hook group at a specific index for an event type.
    /// - Parameters:
    ///   - eventType: PascalCase event type name
    ///   - groupIndex: Index of the group to delete within that event type's array
    /// - Returns: Error message string, or nil on success.
    func deleteHook(eventType: String, groupIndex: Int) async -> String? {
        guard client != nil else { return "Client not configured" }
        isSaving = true
        defer { isSaving = false }

        let settingsVM = SettingsViewModel()
        settingsVM.configure(client: client!)
        let result = await settingsVM.saveWithPatch { config in
            config.hooks?.events[eventType]?.remove(at: groupIndex)
            // Clean up empty arrays -- don't leave empty [] in the JSON
            if config.hooks?.events[eventType]?.isEmpty == true {
                config.hooks?.events.removeValue(forKey: eventType)
            }
            // Clean up if no hooks remain at all
            if config.hooks?.events.isEmpty == true {
                config.hooks = nil
            }
        }

        if result == nil {
            await loadHooks()
        }

        return result
    }

    // MARK: - Import / Export

    /// Exports the current hooks configuration as a pretty-printed JSON string.
    ///
    /// The JSON format matches the Claude Code `hooks` config block exactly, e.g.:
    /// ```json
    /// {
    ///   "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": "echo hi" }] }]
    /// }
    /// ```
    /// - Returns: Pretty-printed JSON string, or nil if there are no hooks or serialization fails.
    func exportHooksAsJSON() -> String? {
        guard let hooksConfig = config?.content.hooks, !hooksConfig.events.isEmpty else {
            return nil
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(hooksConfig) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Imports hooks from a JSON string, replacing the current hooks configuration.
    ///
    /// Expects the same format as `exportHooksAsJSON()` — a top-level object whose keys are
    /// PascalCase event type names and values are arrays of `HookGroup` objects.
    /// - Parameter jsonString: JSON string in Claude Code hooks format.
    /// - Returns: Error message string, or nil on success.
    func importHooksFromJSON(_ jsonString: String) async -> String? {
        guard let data = jsonString.data(using: .utf8) else {
            return "Invalid JSON string encoding"
        }
        guard client != nil else { return "Client not configured" }

        let importedEvents: [String: [HookGroup]]
        do {
            importedEvents = try JSONDecoder().decode([String: [HookGroup]].self, from: data)
        } catch {
            return "Failed to parse JSON: \(error.localizedDescription)"
        }

        guard !importedEvents.isEmpty else { return "No hooks found in JSON" }

        isSaving = true
        defer { isSaving = false }

        let settingsVM = SettingsViewModel()
        settingsVM.configure(client: client!)
        let result = await settingsVM.saveWithPatch { config in
            config.hooks = HooksConfig(events: importedEvents)
        }

        if result == nil {
            await loadHooks()
        }

        return result
    }

    // MARK: - Test Simulator

    /// Simulates a Claude Code event and returns the enabled hooks that would fire.
    ///
    /// Matching rules:
    /// - Only enabled hooks are considered (disabled hooks are excluded).
    /// - A hook matches when its `eventType` equals the given `eventType`.
    /// - If the hook has no matcher (nil or empty), it matches all events of that type.
    /// - If the hook has a matcher, it is treated as a regex pattern and tested against
    ///   `toolName` first; if `toolName` is nil or doesn't match, it is tested against
    ///   `extraContext`.
    ///
    /// - Parameters:
    ///   - eventType: PascalCase event type to simulate (e.g., "PreToolUse").
    ///   - toolName: Optional tool name input (e.g., "Bash", "Edit").
    ///   - extraContext: Optional free-form context string for matcher testing.
    /// - Returns: Array of `HookDisplayItem` that would fire for this event.
    func simulateEvent(eventType: String, toolName: String?, extraContext: String?) -> [HookDisplayItem] {
        hooks.filter { hook in
            guard hook.isEnabled, hook.eventType == eventType else { return false }

            // No matcher means the hook fires for every event of this type.
            guard let matcher = hook.matcher, !matcher.isEmpty else { return true }

            return matchesPattern(matcher, input: toolName) ||
                   matchesPattern(matcher, input: extraContext)
        }
    }

    /// Tests whether `pattern` (a regex string) matches `input`.
    /// Returns false when `input` is nil or the pattern is invalid.
    private func matchesPattern(_ pattern: String, input: String?) -> Bool {
        guard let input, !input.isEmpty else { return false }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(input.startIndex..., in: input)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }

    // MARK: - Enable / Disable

    /// Returns true when the hook at the given position is currently disabled.
    func isHookDisabled(eventType: String, groupIndex: Int) -> Bool {
        disabledHookKeys.contains(hookKey(eventType: eventType, groupIndex: groupIndex))
    }

    /// Toggle the enabled state of a hook.
    ///
    /// - For an **enabled** hook: saves its `HookGroup` to a local snapshot, removes it from
    ///   the Claude config, and marks it disabled in UserDefaults.
    /// - For a **disabled** hook: restores its `HookGroup` from the snapshot back into the
    ///   Claude config and removes the disabled record.
    /// - Returns: An error string on failure, or `nil` on success.
    func toggleHookEnabled(eventType: String, groupIndex: Int) async -> String? {
        let key = hookKey(eventType: eventType, groupIndex: groupIndex)
        if disabledHookKeys.contains(key) {
            return await enableHook(key: key, eventType: eventType)
        } else {
            return await disableHook(key: key, eventType: eventType, groupIndex: groupIndex)
        }
    }

    // MARK: - Private Enable/Disable Helpers

    private func hookKey(eventType: String, groupIndex: Int) -> String {
        "\(eventType):\(groupIndex)"
    }

    private func disableHook(key: String, eventType: String, groupIndex: Int) async -> String? {
        guard let groups = config?.content.hooks?.events[eventType],
              groupIndex >= 0, groupIndex < groups.count else {
            return "Hook not found in configuration"
        }
        let group = groups[groupIndex]

        // Persist snapshot and disabled key before touching the config
        disabledHooksSnapshot[key] = group
        disabledHookKeys.insert(key)
        persistDisabledState()

        let result = await deleteHook(eventType: eventType, groupIndex: groupIndex)
        if result != nil {
            // Rollback local state on failure
            disabledHooksSnapshot.removeValue(forKey: key)
            disabledHookKeys.remove(key)
            persistDisabledState()
        }
        return result
    }

    private func enableHook(key: String, eventType: String) async -> String? {
        guard let group = disabledHooksSnapshot[key] else {
            return "Disabled hook not found in snapshot; cannot re-enable"
        }

        // Append the group back to the end of the event type's list
        let result = await saveHook(eventType: eventType, group: group, editIndex: nil)
        if result == nil {
            disabledHookKeys.remove(key)
            disabledHooksSnapshot.removeValue(forKey: key)
            persistDisabledState()
        }
        return result
    }

    // MARK: - UserDefaults Persistence for Disabled State

    private func loadDisabledState() {
        if let data = UserDefaults.standard.data(forKey: AppConstants.disabledHooksKey),
           let keys = try? JSONDecoder().decode([String].self, from: data) {
            disabledHookKeys = Set(keys)
        }

        let snapshotKey = AppConstants.disabledHooksKey + "_snapshot"
        if let data = UserDefaults.standard.data(forKey: snapshotKey),
           let snapshot = try? JSONDecoder().decode([String: HookGroup].self, from: data) {
            disabledHooksSnapshot = snapshot
        }
    }

    private func persistDisabledState() {
        if let data = try? JSONEncoder().encode(Array(disabledHookKeys)) {
            UserDefaults.standard.set(data, forKey: AppConstants.disabledHooksKey)
        }

        let snapshotKey = AppConstants.disabledHooksKey + "_snapshot"
        if let data = try? JSONEncoder().encode(disabledHooksSnapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    // MARK: - Private

    private func flattenHooks(from hooksConfig: HooksConfig?) {
        var items: [HookDisplayItem] = []

        if let hooksConfig {
            // Iterate over all event types in the dictionary, sorted by canonical lifecycle order
            let sortedEvents = hooksConfig.events.sorted { left, right in
                let leftIdx = Self.eventTypeOrder[left.key] ?? Int.max
                let rightIdx = Self.eventTypeOrder[right.key] ?? Int.max
                return leftIdx < rightIdx
            }

            for (eventType, groups) in sortedEvents {
                items.append(contentsOf: flattenGroups(groups, eventType: eventType, isEnabled: true))
            }
        }

        // Append disabled hooks from the local snapshot, sorted by lifecycle order
        let sortedDisabled = disabledHooksSnapshot.sorted { left, right in
            let leftEvent = left.key.components(separatedBy: ":").first ?? ""
            let rightEvent = right.key.components(separatedBy: ":").first ?? ""
            let leftIdx = Self.eventTypeOrder[leftEvent] ?? Int.max
            let rightIdx = Self.eventTypeOrder[rightEvent] ?? Int.max
            return leftIdx < rightIdx
        }

        for (key, group) in sortedDisabled {
            let parts = key.split(separator: ":", maxSplits: 1)
            guard parts.count == 2,
                  let originalGroupIndex = Int(parts[1]) else { continue }
            let eventType = String(parts[0])
            items.append(contentsOf: flattenGroups(
                [group],
                eventType: eventType,
                startGroupIndex: originalGroupIndex,
                isEnabled: false
            ))
        }

        hooks = items
    }

    private func flattenGroups(
        _ groups: [HookGroup],
        eventType: String,
        startGroupIndex: Int = 0,
        isEnabled: Bool
    ) -> [HookDisplayItem] {
        var items: [HookDisplayItem] = []

        for (offset, group) in groups.enumerated() {
            let groupIndex = startGroupIndex + offset
            guard let hookDefs = group.hooks else { continue }
            for (hookIndex, hookDef) in hookDefs.enumerated() {
                items.append(HookDisplayItem(
                    eventType: eventType,
                    matcher: group.matcher,
                    hookType: hookDef.type,
                    command: hookDef.command,
                    url: hookDef.url,
                    prompt: hookDef.prompt,
                    groupIndex: groupIndex,
                    hookIndex: hookIndex,
                    isEnabled: isEnabled
                ))
            }
        }

        return items
    }
}
