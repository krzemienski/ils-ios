# Phase 52: Hooks & Status Management - Research

**Researched:** 2026-02-28
**Domain:** SwiftUI hooks CRUD management, Claude Code hook event types, skill/plugin status toggle UI
**Confidence:** HIGH

## Summary

Phase 52 expands the existing read-only hooks display into a full CRUD management screen, expands the event type support from 5 to all 17 Claude Code lifecycle events, and adds visible active/inactive toggle indicators to the skills and plugins browser rows.

The current codebase has a functional foundation. `HooksManagementView.swift` renders hooks grouped by 5 event types (PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SubagentStart) in a read-only list. `HooksViewModel.swift` flattens `HookGroup` arrays into `HookDisplayItem` structs for display. The `HooksConfig` model in ILSShared only declares 5 event types via explicit properties with `CodingKeys` -- this must be expanded to handle all 17 event types. The `SettingsViewModel.saveWithPatch()` pattern from Phase 51 provides the proven read-modify-write mechanism for persisting hook changes to `~/.claude/settings.json` without clobbering other config fields.

For skills/plugins status, the infrastructure is already complete: `SkillsViewModel.toggleSkillActive()` calls enable/disable endpoints, `PluginsViewModel.enablePlugin()/disablePlugin()` do the same, and `BrowserView` already has context menu items for enable/disable. The gap is that there is no visible status indicator on the row itself -- users must long-press to discover the context menu. SKILL-07 requires a visible toggle indicator on each row.

**Primary recommendation:** Restructure `HooksConfig` to use a dictionary-based approach (`[String: [HookGroup]]`) or add all 17 event type properties. Extend `HooksManagementView` with create/edit/delete sheets using `saveWithPatch`. Add a visible toggle button (small circle indicator + swipe action) to skill and plugin rows in `BrowserView`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SKILL-05 | Hooks management screen supports all 16 Claude Code event types (expanded from 5) | Official docs confirm 17 event types (note: requirement says 16 but docs show 17). Current `HooksConfig` has 5 explicit properties. Must expand model to handle all event types. See "Architecture Patterns > Pattern 1" for `additionalEvents` dictionary approach. |
| SKILL-06 | User can create, edit, and delete hooks with 4 handler types (command, prompt, agent, http) | `saveWithPatch` from Phase 51 provides read-modify-write. Create/edit need a form sheet with event type picker, handler type picker, and handler-specific fields. Delete via swipe action. See "Architecture Patterns > Pattern 2" for hook editor sheet design. |
| SKILL-07 | Skills and plugins display active/inactive status indicators with toggle capability | `BrowserView` already shows "Active"/"Inactive" text status via `browserRow()` and has context menu toggles. Gap: no visible inline toggle. `SkillsViewModel.toggleSkillActive()` and `PluginsViewModel.enablePlugin()/disablePlugin()` already work. See "Architecture Patterns > Pattern 3" for toggle indicator design. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | Hook management UI, forms, sheets, toggles | Already used by all views |
| ILSShared | local | `HooksConfig`, `HookGroup`, `HookDefinition`, `ClaudeConfig` models | Must be extended for 17 event types |
| Observation | Swift 5.10+ | `@Observable` for HooksViewModel | Already used by HooksViewModel |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SettingsViewModel | local | `saveWithPatch()` for read-modify-write config updates | All hook CRUD operations |
| APIClient | local | HTTP GET/PUT for config, POST for skill/plugin enable/disable | All network operations |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend `HooksConfig` with 17 explicit properties | Use `[String: [HookGroup]]` dictionary | Dictionary is more flexible but loses type safety. Hybrid approach recommended (keep 5 explicit + `additionalEvents` dictionary for remaining 12). |
| Raw JSON editor for hook creation | Structured form with pickers | Structured form is much better UX -- users don't need to know JSON. Raw editor already exists in `ConfigEditorView` as fallback. |
| Separate HooksEditorViewModel | Extend existing HooksViewModel + use SettingsViewModel.saveWithPatch | Reusing SettingsViewModel's saveWithPatch avoids duplicating the read-modify-write logic. |

**Installation:** No new dependencies. All changes are to existing ILSShared models, ViewModels, and Views.

## Architecture Patterns

### Recommended File Changes

```
Sources/ILSShared/Models/
└── ClaudeConfig.swift           # MODIFY: expand HooksConfig, HookDefinition for all 17 event types + 4 handler types

ILSApp/ILSApp/
├── ViewModels/
│   └── HooksViewModel.swift     # MODIFY: support all 17 event types, add CRUD methods using saveWithPatch
├── Views/
│   ├── Hooks/
│   │   └── HooksManagementView.swift  # MODIFY: full CRUD UI, create/edit sheets, delete actions
│   │   └── HookEditorSheet.swift      # NEW: form sheet for creating/editing a hook
│   └── Browser/
│       └── BrowserView.swift          # MODIFY: add visible toggle indicators to skill/plugin rows

ILSApp/ILSMacApp/Views/
└── (HooksManagementView is shared)    # macOS already uses the same HooksManagementView
```

### Pattern 1: Expanding HooksConfig for All 17 Event Types

**What:** The current `HooksConfig` has 5 explicit properties with `CodingKeys`. Claude Code has 17 event types. Rather than adding 12 more explicit properties, use a hybrid approach.

**Why hybrid:** Adding 12 more explicit properties (SessionEnd, Stop, Notification, PermissionRequest, PostToolUseFailure, SubagentStop, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove, PreCompact) creates a large struct with 17 optionals. A dictionary `additionalEvents: [String: [HookGroup]]` catches all event types not explicitly modeled, and custom Codable logic merges them.

**Complete list of all 17 Claude Code hook event types (from official docs):**

| Event | When It Fires | Matcher Filters |
|-------|---------------|-----------------|
| `PreToolUse` | Before a tool call executes, can block it | tool name |
| `PostToolUse` | After a tool call succeeds | tool name |
| `PostToolUseFailure` | After a tool call fails | tool name |
| `PermissionRequest` | When a permission dialog appears | tool name |
| `UserPromptSubmit` | When user submits a prompt, before processing | no matcher |
| `Stop` | When Claude finishes responding | no matcher |
| `SessionStart` | When a session begins or resumes | how session started |
| `SessionEnd` | When a session terminates | why session ended |
| `SubagentStart` | When a subagent is spawned | agent type |
| `SubagentStop` | When a subagent finishes | agent type |
| `Notification` | When Claude Code sends a notification | notification type |
| `TeammateIdle` | When a team teammate is about to go idle | no matcher |
| `TaskCompleted` | When a task is marked completed | no matcher |
| `ConfigChange` | When a config file changes during session | config source |
| `WorktreeCreate` | When a worktree is created | no matcher |
| `WorktreeRemove` | When a worktree is removed | no matcher |
| `PreCompact` | Before context compaction | trigger type |

**Recommended approach -- dictionary-based `HooksConfig`:**

```swift
// Replace explicit properties with a single dictionary
public struct HooksConfig: Codable, Hashable, Sendable {
    /// All hooks keyed by event type name (e.g., "PreToolUse", "Stop", etc.)
    public var events: [String: [HookGroup]]

    public init(events: [String: [HookGroup]] = [:]) {
        self.events = events
    }

    // Custom Codable: encode/decode directly as {"PreToolUse": [...], "PostToolUse": [...]}
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        events = try container.decode([String: [HookGroup]].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(events)
    }

    // Backward-compatible computed accessors
    public var preToolUse: [HookGroup]? { events["PreToolUse"] }
    public var postToolUse: [HookGroup]? { events["PostToolUse"] }
    public var sessionStart: [HookGroup]? { events["SessionStart"] }
    public var subagentStart: [HookGroup]? { events["SubagentStart"] }
    public var userPromptSubmit: [HookGroup]? { events["UserPromptSubmit"] }
}
```

**Why this works:** Claude Code's hooks JSON structure IS a dictionary of event type names to arrays of hook groups. The current explicit-property approach with `CodingKeys` artificially limits it to 5 types and silently drops any others during decoding. A dictionary naturally handles all current and future event types.

**Risk:** This changes the Codable representation. The backend `ConfigFileService` reads `ClaudeConfig` which embeds `HooksConfig`. Since the JSON on disk already uses PascalCase event type keys ("PreToolUse"), and the dictionary approach decodes them as-is, this is backward compatible. The old `CodingKeys` mapping (`preToolUse = "PreToolUse"`) is replaced by the dictionary key being "PreToolUse" directly.

### Pattern 2: Hook Editor Sheet (Create/Edit)

**What:** A modal sheet for creating or editing a single hook, with structured form fields instead of raw JSON.

**Form fields:**
1. **Event Type** picker -- all 17 event types, with descriptions
2. **Matcher** text field (optional, regex) -- with hint text showing what the matcher filters for the selected event type
3. **Handler Type** segmented picker -- command / prompt / agent / http
4. **Handler Configuration** (varies by type):
   - `command`: command text field, optional timeout, optional async toggle
   - `prompt`: prompt text area, optional model picker
   - `agent`: prompt text area, optional model picker
   - `http`: URL text field, optional headers key-value editor, optional allowedEnvVars list

**Save flow using `saveWithPatch`:**

```swift
func saveHook(eventType: String, group: HookGroup, isNew: Bool, editIndex: Int?) async -> String? {
    let settingsVM = SettingsViewModel()
    settingsVM.configure(client: client)
    return await settingsVM.saveWithPatch { config in
        if config.hooks == nil {
            config.hooks = HooksConfig(events: [:])
        }
        var groups = config.hooks?.events[eventType] ?? []
        if isNew {
            groups.append(group)
        } else if let index = editIndex, index < groups.count {
            groups[index] = group
        }
        config.hooks?.events[eventType] = groups
    }
}

func deleteHook(eventType: String, groupIndex: Int) async -> String? {
    let settingsVM = SettingsViewModel()
    settingsVM.configure(client: client)
    return await settingsVM.saveWithPatch { config in
        config.hooks?.events[eventType]?.remove(at: groupIndex)
        // Clean up empty arrays
        if config.hooks?.events[eventType]?.isEmpty == true {
            config.hooks?.events.removeValue(forKey: eventType)
        }
    }
}
```

**Critical detail:** `saveWithPatch` reads fresh config from server, applies the delta closure, then PUTs the full config back. This ensures hooks changes don't clobber other settings (model, permissions, env, etc.). This is exactly how Phase 51's settings toggles work.

### Pattern 3: Visible Status Toggle on Skill/Plugin Rows

**What:** Add a visible active/inactive indicator and tap-to-toggle to skill and plugin rows in `BrowserView`.

**Current state:**
- `browserRow()` already renders status text ("Active"/"Inactive") and a colored dot
- Context menu has Enable/Disable actions (long-press only)
- `SkillsViewModel.toggleSkillActive()` and `PluginsViewModel.enablePlugin()/disablePlugin()` work

**Gap:** No inline toggle button -- users must discover the context menu.

**Recommended approach -- add a trailing toggle circle:**

```swift
// In the skill row area of BrowserView's skillsContent
HStack {
    browserRow(name: ..., subtitle: ..., status: ..., statusColor: ..., entityColor: ..., badge: ...)

    Button {
        Task { await skillsVM.toggleSkillActive(skill) }
    } label: {
        Image(systemName: skill.isActive ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(skill.isActive ? theme.success : theme.textTertiary)
            .font(.system(size: 20))
    }
    .buttonStyle(.plain)
}
```

**Alternative -- swipe action (also good):**

```swift
.swipeActions(edge: .trailing) {
    Button {
        Task { await skillsVM.toggleSkillActive(skill) }
    } label: {
        Label(skill.isActive ? "Disable" : "Enable",
              systemImage: skill.isActive ? "pause.circle" : "play.circle")
    }
    .tint(skill.isActive ? theme.warning : theme.success)
}
```

**Recommendation:** Use BOTH -- visible trailing toggle circle for discoverability + swipe action for power users. Keep the existing context menu as well.

### Anti-Patterns to Avoid

- **Separate SettingsViewModel instance per CRUD op:** Don't create a new SettingsViewModel for every save. Instead, let HooksViewModel hold a reference to one shared SettingsViewModel (or just use `saveWithPatch` directly via the existing pattern).
- **Direct JSON manipulation in the UI:** Don't let users type raw JSON for hook configuration. The `ConfigEditorView` already exists as an escape hatch for power users.
- **Hardcoded event type list in the View:** Define the canonical event type list in the ViewModel or a constant, not scattered across view code.
- **Forgetting to handle empty arrays:** When deleting the last hook from an event type, remove the event type key from the dictionary entirely (not leave an empty array). Claude Code may behave differently with an empty array vs absent key.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Config read-modify-write | Custom HTTP PATCH or diff-based approach | `SettingsViewModel.saveWithPatch()` | Already handles fresh read, delta application, full PUT, and effective config refresh |
| JSON validation for hook config | Custom JSON parser | `ClaudeConfig` Codable + `ConfigEditorView` for raw editing | Codable handles structure, raw editor is the escape hatch |
| Event type metadata (icons, labels, descriptions) | Inline switch statements in views | Centralized enum or dictionary in HooksViewModel | Keeps view code clean, easy to update when new events are added |

**Key insight:** The `saveWithPatch` pattern is the critical foundation. It solves the hard problem of modifying hooks without clobbering other config fields. Building a custom PATCH mechanism would be error-prone and duplicative.

## Common Pitfalls

### Pitfall 1: HooksConfig CodingKeys Silently Drop Unknown Event Types

**What goes wrong:** The current `HooksConfig` uses explicit `CodingKeys` mapping `preToolUse` to `"PreToolUse"`, etc. When the backend returns hooks for event types not in the CodingKeys (e.g., `Stop`, `Notification`, `SessionEnd`), JSONDecoder silently ignores them. A subsequent `saveWithPatch` that re-encodes `HooksConfig` would DROP those hooks from the config file.

**Why it happens:** Swift's Codable with explicit CodingKeys only decodes/encodes keys listed in the enum.

**How to avoid:** Switch to the dictionary-based `HooksConfig` approach (Pattern 1) which naturally preserves all event types.

**Warning signs:** User reports hooks disappearing after using the iOS app settings.

### Pitfall 2: Event Type String Case Sensitivity

**What goes wrong:** Claude Code uses PascalCase for event type names ("PreToolUse", not "preToolUse" or "pre_tool_use"). If the UI or model uses a different case, hooks won't fire.

**Why it happens:** Different naming conventions between Swift (camelCase) and Claude Code (PascalCase).

**How to avoid:** Store and transmit event type names as their exact PascalCase strings. The dictionary-based approach naturally preserves the original casing.

**Warning signs:** Hooks created via the iOS app don't fire in Claude Code.

### Pitfall 3: saveWithPatch Race Condition on Concurrent Edits

**What goes wrong:** If two quick hook edits overlap (user taps save twice quickly), the second `saveWithPatch` reads stale config and overwrites the first edit.

**Why it happens:** `saveWithPatch` does GET-mutate-PUT which is not atomic.

**How to avoid:** Disable the save button while `isSaving` is true (already the pattern used by settings). Use `defer { isSaving = false }` in the save function.

**Warning signs:** Second of two rapid edits silently reverts the first.

### Pitfall 4: Handler Type Fields Vary Per Type

**What goes wrong:** Showing all handler fields (command, url, prompt, headers) simultaneously confuses users and risks sending empty/invalid fields.

**Why it happens:** The 4 handler types have different required and optional fields.

**How to avoid:** Use a segmented control for handler type and conditionally show only the relevant fields. The `HookDefinition` model must be extended to include fields for all 4 types (currently only has `type` and `command`).

**Warning signs:** User creates an HTTP hook but fills in the command field, or vice versa.

### Pitfall 5: Stale Hooks After External Edits

**What goes wrong:** User edits `~/.claude/settings.json` manually (or via CLI `/hooks` command) while the iOS app is open. The app shows stale hook data.

**Why it happens:** HooksManagementView loads hooks once on appear and only refreshes on pull-to-refresh.

**How to avoid:** Add `.refreshable` (already present) and refresh when the view appears from background (`onAppear` / `scenePhase`). Consider polling or a timestamp check.

**Warning signs:** Hooks list doesn't match what `cat ~/.claude/settings.json` shows.

## Code Examples

### Extending HookDefinition for All 4 Handler Types

```swift
/// Individual hook definition supporting all 4 handler types.
public struct HookDefinition: Codable, Hashable, Sendable {
    /// Handler type: "command", "http", "prompt", or "agent"
    public var type: String?

    // Command handler fields
    /// Shell command to execute
    public var command: String?
    /// If true, runs in background without blocking
    public var async: Bool?

    // HTTP handler fields
    /// URL to send POST request to
    public var url: String?
    /// Additional HTTP headers
    public var headers: [String: String]?
    /// Environment variables allowed in header interpolation
    public var allowedEnvVars: [String]?

    // Prompt/Agent handler fields
    /// Prompt text for LLM evaluation
    public var prompt: String?
    /// Model to use for evaluation
    public var model: String?

    // Common optional fields
    /// Seconds before canceling
    public var timeout: Int?
    /// Custom spinner message
    public var statusMessage: String?
    /// If true, runs only once per session (skills only)
    public var once: Bool?

    // Coding keys: preserve JSON field names exactly as Claude Code expects
    enum CodingKeys: String, CodingKey {
        case type, command, url, headers, allowedEnvVars, prompt, model
        case timeout, statusMessage, once
        case async = "async"  // "async" is a Swift keyword but valid JSON key
    }
}
```

### Event Type Metadata for UI Display

```swift
/// Canonical list of all Claude Code hook event types with UI metadata.
struct HookEventTypeInfo {
    let name: String       // PascalCase, matches JSON key
    let label: String      // Human-readable
    let icon: String       // SF Symbol
    let description: String
    let matcherDescription: String?  // What the matcher filters, nil = no matcher support
}

static let allEventTypes: [HookEventTypeInfo] = [
    // Agentic loop events
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
    HookEventTypeInfo(name: "Notification", label: "Notification", icon: "bell",
        description: "Runs when Claude Code sends a notification.",
        matcherDescription: "Notification type (permission_prompt, idle_prompt, etc.)"),

    // Session lifecycle events
    HookEventTypeInfo(name: "SessionStart", label: "Session Start", icon: "play.circle",
        description: "Runs when a session begins or resumes.",
        matcherDescription: "How session started (startup, resume, clear, compact)"),
    HookEventTypeInfo(name: "SessionEnd", label: "Session End", icon: "stop.circle",
        description: "Runs when a session terminates.",
        matcherDescription: "Why session ended (clear, logout, etc.)"),
    HookEventTypeInfo(name: "UserPromptSubmit", label: "User Prompt Submit", icon: "arrow.up.circle",
        description: "Runs when you submit a prompt, before Claude processes it.",
        matcherDescription: nil),
    HookEventTypeInfo(name: "Stop", label: "Stop", icon: "hand.raised",
        description: "Runs when Claude finishes responding.",
        matcherDescription: nil),

    // Subagent events
    HookEventTypeInfo(name: "SubagentStart", label: "Subagent Start", icon: "person.fill.badge.plus",
        description: "Runs when a subagent is spawned.",
        matcherDescription: "Agent type (Bash, Explore, Plan, etc.)"),
    HookEventTypeInfo(name: "SubagentStop", label: "Subagent Stop", icon: "person.fill.xmark",
        description: "Runs when a subagent finishes.",
        matcherDescription: "Agent type"),

    // Team events
    HookEventTypeInfo(name: "TeammateIdle", label: "Teammate Idle", icon: "person.crop.circle.badge.clock",
        description: "Runs when an agent team teammate is about to go idle.",
        matcherDescription: nil),
    HookEventTypeInfo(name: "TaskCompleted", label: "Task Completed", icon: "checkmark.seal",
        description: "Runs when a task is being marked as completed.",
        matcherDescription: nil),

    // Config & workspace events
    HookEventTypeInfo(name: "ConfigChange", label: "Config Change", icon: "gearshape.2",
        description: "Runs when a configuration file changes during a session.",
        matcherDescription: "Config source (user_settings, project_settings, etc.)"),
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
```

### Hook Editor Sheet Pattern

```swift
struct HookEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    // Input: nil for create, non-nil for edit
    let existingHook: (eventType: String, groupIndex: Int, group: HookGroup)?
    let onSave: (String, HookGroup) async -> String?  // (eventType, group) -> error?

    @State private var selectedEventType: String = "PreToolUse"
    @State private var matcher: String = ""
    @State private var handlerType: String = "command"  // command, http, prompt, agent
    @State private var command: String = ""
    @State private var url: String = ""
    @State private var prompt: String = ""
    @State private var timeout: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // Event type picker (disabled during edit)
                // Matcher field (with contextual hint)
                // Handler type segmented control
                // Handler-specific fields
                // Timeout field
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Save") { save() }.disabled(isSaving) }
            }
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 5 explicit hook event types | 17 event types (official docs) | Claude Code 2025+ | Must expand HooksConfig model |
| `command` only handler type | 4 handler types (command, http, prompt, agent) | Claude Code 2025+ | Must expand HookDefinition model |
| `HooksConfig` with CodingKeys | Dictionary-based `[String: [HookGroup]]` | This phase | Prevents silent data loss, future-proof |
| Context menu only for toggles | Visible inline status indicator + toggle | This phase | Better discoverability per SKILL-07 |

**Deprecated/outdated:**
- The 5-event-type `HooksConfig` with explicit `CodingKeys` is outdated -- it silently drops hooks for the 12 event types it doesn't model. This is a data loss risk whenever `saveWithPatch` re-encodes the config.

## Open Questions

1. **Event type count: 16 vs 17**
   - What we know: The requirement says "16 Claude Code event types" but official docs list 17 (including `SessionEnd`). The 17th (`SessionEnd`) may have been added after the requirement was written.
   - What's unclear: Whether to show exactly 16 or all 17.
   - Recommendation: Show all 17. Having more is strictly better -- the UI should reflect the actual Claude Code capabilities.

2. **Scope handling for hook CRUD**
   - What we know: `saveWithPatch` writes to user scope (`~/.claude/settings.json`). Hooks can exist in project (`.claude/settings.json`) and local (`.claude/settings.local.json`) scopes too.
   - What's unclear: Should the create/edit UI support writing to project/local scope? The backend's `writeConfig` only supports `.user` scope.
   - Recommendation: Create/edit writes to user scope only (consistent with settings). Display hooks from all scopes (read-only) with scope badges like the existing config UI.

3. **`async` field naming**
   - What we know: Claude Code hooks support an `async` field on command handlers. `async` is a reserved keyword in Swift.
   - What's unclear: Whether Swift's Codable will handle this gracefully.
   - Recommendation: Use `CodingKeys` to map a Swift property name like `isAsync` to the JSON key `"async"`. Verified: this works with explicit CodingKeys.

## Sources

### Primary (HIGH confidence)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) - Official documentation listing all 17 event types, handler types, matcher patterns, and configuration schema. Fetched 2026-02-28.
- ILSShared source: `Sources/ILSShared/Models/ClaudeConfig.swift` - Current HooksConfig, HookGroup, HookDefinition models
- ILSApp source: `ILSApp/ILSApp/Views/Hooks/HooksManagementView.swift` - Current read-only hooks UI
- ILSApp source: `ILSApp/ILSApp/ViewModels/SettingsViewModel.swift` - `saveWithPatch()` pattern from Phase 51
- ILSApp source: `ILSApp/ILSApp/Views/Browser/BrowserView.swift` - Existing skill/plugin toggle via context menu

### Secondary (MEDIUM confidence)
- [Claude Code Hooks Guide (DataCamp)](https://www.datacamp.com/tutorial/claude-code-hooks) - Community tutorial confirming event types and handler patterns
- [Claude Code Hooks Guide (Pixelmojo)](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns) - Lists 12 lifecycle events (slightly outdated count)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, no new dependencies
- Architecture: HIGH - `saveWithPatch` pattern proven in Phase 51, dictionary-based HooksConfig is straightforward Codable change
- Pitfalls: HIGH - CodingKeys data loss risk is verified by reading the actual model code; all other pitfalls are from direct codebase analysis

**Research date:** 2026-02-28
**Valid until:** 2026-03-28 (stable -- Claude Code hook event types change infrequently)
