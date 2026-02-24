import SwiftUI
import ILSShared

/// Local UI model representing the full set of advanced chat options configurable before sending a message.
///
/// Holds mutable String/Bool/Double fields that map 1:1 to ``ChatOptions`` API parameters.
/// Comma-separated string fields (e.g. ``allowedTools``, ``betas``) are split into arrays
/// by ``toChatOptions()`` when constructing the API payload. All properties default to their
/// "no-op" values so that ``toChatOptions()`` returns `nil` unless the user has changed at
/// least one setting.
///
/// ## Topics
/// ### System Prompt
/// - ``systemPrompt``
/// - ``appendSystemPrompt``
///
/// ### Model & Execution
/// - ``model``
/// - ``permissionMode``
/// - ``maxTurns``
/// - ``maxBudgetUSD``
///
/// ### Tool Control
/// - ``allowedTools``
/// - ``disallowedTools``
///
/// ### Session Behaviour
/// - ``continueConversation``
/// - ``noSessionPersistence``
/// - ``includePartialMessages``
///
/// ### Miscellaneous
/// - ``inputFormat``
/// - ``agent``
/// - ``betas``
/// - ``debug``
///
/// ### Conversion
/// - ``hasCustomOptions``
/// - ``toChatOptions()``
struct ChatOptionsConfig {
    /// Full system prompt text that completely replaces the default system prompt for this request.
    /// Empty string means no override — the server uses its built-in default.
    var systemPrompt: String = ""

    /// Additional text appended to the existing system prompt rather than replacing it.
    /// Useful for injecting context or constraints without discarding the default prompt.
    var appendSystemPrompt: String = ""

    /// The Claude model identifier to use for this request (e.g. `"sonnet"`, `"opus"`, `"haiku"`).
    /// Defaults to `"sonnet"`. Omitted from the API payload when equal to `"sonnet"`.
    var model: String = "sonnet"

    /// How Claude handles tool-use permission prompts during execution.
    /// Defaults to `.default`, which prompts the user for each potentially destructive action.
    var permissionMode: PermissionMode = .default

    /// Maximum number of agentic turns Claude may take before stopping and returning.
    /// Each turn corresponds to one round of tool calls and responses. Defaults to `1`.
    var maxTurns: Int = 1

    /// Optional spending cap in US dollars for this request.
    /// `nil` means no limit is enforced. When set, Claude stops execution if the estimated
    /// cost would exceed this value.
    var maxBudgetUSD: Double? = nil

    /// Comma-separated list of tool names Claude is explicitly permitted to use.
    /// Empty string means all tools are allowed (subject to ``permissionMode``).
    /// Example: `"Read,Write,Bash"`.
    var allowedTools: String = ""

    /// Comma-separated list of tool names Claude is forbidden from using.
    /// Empty string means no tools are blocked beyond the default policy.
    /// Example: `"Edit,Write"`.
    var disallowedTools: String = ""

    /// When `true`, Claude resumes the most recent conversation in the session rather
    /// than starting a fresh turn. Maps to the `continueConversation` API flag.
    var continueConversation: Bool = false

    /// When `true`, the session and its messages are not persisted to the backend store.
    /// Useful for ephemeral or privacy-sensitive interactions.
    var noSessionPersistence: Bool = false

    /// When `true` (the default), Claude streams partial in-progress tool results and
    /// assistant text as they arrive. Set to `false` to receive only fully-completed messages.
    var includePartialMessages: Bool = true

    /// Specifies the wire format for the input payload (e.g. `"stream-json"`).
    /// Empty string means the default format is used. Rarely needed in normal usage.
    var inputFormat: String = ""

    /// Identifier of a specific sub-agent or persona for Claude to adopt.
    /// Empty string means the default top-level agent is used.
    var agent: String = ""

    /// Comma-separated list of Anthropic beta feature flags to enable for this request.
    /// Empty string means no beta features are activated.
    /// Example: `"interleaved-thinking-2025-05-14"`.
    var betas: String = ""

    /// When `true`, enables verbose debug output from the Claude Code SDK during execution.
    /// Intended for development and troubleshooting; not recommended in production.
    var debug: Bool = false

    /// Whether any non-default options have been set.
    /// Returns `true` if any property differs from its default, indicating that ``toChatOptions()``
    /// will produce a non-nil ``ChatOptions`` payload to attach to the outgoing request.
    var hasCustomOptions: Bool {
        !systemPrompt.isEmpty || !appendSystemPrompt.isEmpty ||
        model != "sonnet" || permissionMode != .default ||
        maxTurns != 1 || maxBudgetUSD != nil ||
        !allowedTools.isEmpty || !disallowedTools.isEmpty ||
        continueConversation || noSessionPersistence ||
        !includePartialMessages || !inputFormat.isEmpty ||
        !agent.isEmpty || !betas.isEmpty || debug
    }

    /// Converts this UI model to a ``ChatOptions`` value for inclusion in an API request.
    /// Returns `nil` when ``hasCustomOptions`` is `false` so callers can omit the field entirely.
    /// Comma-separated string fields are split on `","` and nil-coalesced to omit empty values.
    func toChatOptions() -> ChatOptions? {
        guard hasCustomOptions else { return nil }
        return ChatOptions(
            model: model != "sonnet" ? model : nil,
            permissionMode: permissionMode != .default ? permissionMode : nil,
            maxTurns: maxTurns != 1 ? maxTurns : nil,
            maxBudgetUSD: maxBudgetUSD,
            allowedTools: allowedTools.isEmpty ? nil : allowedTools.split(separator: ",").map(String.init),
            disallowedTools: disallowedTools.isEmpty ? nil : disallowedTools.split(separator: ",").map(String.init),
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            appendSystemPrompt: appendSystemPrompt.isEmpty ? nil : appendSystemPrompt,
            continueConversation: continueConversation ? true : nil,
            includePartialMessages: !includePartialMessages ? false : nil,
            noSessionPersistence: noSessionPersistence ? true : nil,
            inputFormat: inputFormat.isEmpty ? nil : inputFormat,
            agent: agent.isEmpty ? nil : agent,
            betas: betas.isEmpty ? nil : betas.split(separator: ",").map(String.init),
            debug: debug ? true : nil
        )
    }
}

/// Modal sheet presenting a five-section form for configuring advanced chat options before sending a message.
///
/// Binds to a ``ChatOptionsConfig`` value and allows the user to tweak every Claude Code
/// SDK parameter exposed by the app. Changes take effect immediately in the binding; the
/// caller decides when to read ``ChatOptionsConfig/toChatOptions()`` and attach the result
/// to an outgoing message.
///
/// ## Form Sections
/// 1. **System Prompt** — ``systemPromptSection``: full system-prompt override and append fields.
/// 2. **Model & Execution** — ``modelExecutionSection``: model picker, permission mode, max turns, and budget cap.
/// 3. **Tool Control** — ``toolControlSection``: comma-separated allowed and disallowed tool lists.
/// 4. **Advanced** — ``advancedSection``: session behaviour toggles, agent, beta flags, input format, and debug mode.
/// 5. **Reset** — ``resetSection``: destructive button that restores all fields to their defaults.
struct AdvancedOptionsSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    /// The mutable configuration model bound to the presenting view.
    @Binding var config: ChatOptionsConfig

    var body: some View {
        Form {
            systemPromptSection
            modelExecutionSection
            toolControlSection
            advancedSection
            resetSection
        }
        .scrollContentBackground(.hidden)
        .background(theme.bgPrimary)
        .tint(theme.accent)
        .navigationTitle("Chat Options")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundColor(theme.accent)
                    .accessibilityLabel("Done configuring chat options")
            }
        }
    }

    /// Form section for overriding or appending to the system prompt.
    /// Contains a tall `TextEditor` for a full replacement prompt and a shorter one for an append-only suffix.
    private var systemPromptSection: some View {
        Section("System Prompt") {
            TextEditor(text: $config.systemPrompt)
                .frame(minHeight: 80)
                .font(.system(.body, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(theme.bgSecondary)
                .cornerRadius(6)
                .accessibilityLabel("System prompt text editor")

            Text("Append to System Prompt")
                .font(.caption)
                .foregroundColor(theme.textSecondary)

            TextEditor(text: $config.appendSystemPrompt)
                .frame(minHeight: 48)
                .font(.system(.body, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(theme.bgSecondary)
                .cornerRadius(6)
                .accessibilityLabel("Append system prompt text editor")
        }
        .listRowBackground(theme.bgSecondary)
    }

    /// Form section for model selection and execution constraints.
    /// Provides a segmented-style model picker (sonnet/opus/haiku), a permission-mode menu,
    /// a max-turns stepper, and an optional dollar budget cap text field.
    private var modelExecutionSection: some View {
        Section("Model & Execution") {
            HStack(spacing: 0) {
                ForEach(["sonnet", "opus", "haiku"], id: \.self) { model in
                    Button {
                        config.model = model
                    } label: {
                        Text(model.capitalized)
                            .font(.system(size: theme.fontCaption, weight: config.model == model ? .semibold : .regular, design: theme.fontDesign))
                            .foregroundStyle(config.model == model ? theme.textPrimary : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacingSM)
                            .background(config.model == model ? theme.accent.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(theme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
            .accessibilityLabel("Model selection picker")

            Picker("Permission Mode", selection: $config.permissionMode) {
                ForEach([PermissionMode.default, .plan, .acceptEdits, .delegate, .dontAsk, .bypassPermissions], id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Permission mode picker")

            Stepper("Max Turns: \(config.maxTurns)", value: $config.maxTurns, in: 1...100)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Max turns stepper, current value \(config.maxTurns)")

            HStack {
                Text("Max Budget USD")
                    .foregroundColor(theme.textPrimary)
                Spacer()
                TextField("No limit", value: $config.maxBudgetUSD, format: .number)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .accessibilityLabel("Max budget USD text field")
            }
        }
        .listRowBackground(theme.bgSecondary)
    }

    /// Form section for restricting which Claude Code tools may be used during execution.
    /// Both fields accept comma-separated tool names (e.g. `"Read,Write,Bash"`).
    private var toolControlSection: some View {
        Section("Tool Control") {
            TextField("Allowed Tools", text: $config.allowedTools)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Allowed tools text field")
                .accessibilityHint("e.g. Read,Write,Bash")

            TextField("Disallowed Tools", text: $config.disallowedTools)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Disallowed tools text field")
                .accessibilityHint("e.g. Edit,Write")
        }
        .listRowBackground(theme.bgSecondary)
    }

    /// Form section for less-common session behaviour flags and SDK internals.
    /// Contains toggles for session continuity, persistence, partial-message streaming,
    /// and debug mode, plus text fields for agent identifier, beta feature flags, and input format.
    private var advancedSection: some View {
        Section("Advanced") {
            Toggle("Continue Previous Session", isOn: $config.continueConversation)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Continue previous session toggle")
                .onChange(of: config.continueConversation) { _, _ in
                    HapticManager.selection()
                }

            Toggle("Disable Session Persistence", isOn: $config.noSessionPersistence)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Disable session persistence toggle")
                .onChange(of: config.noSessionPersistence) { _, _ in
                    HapticManager.selection()
                }

            Toggle("Stream Partial Messages", isOn: $config.includePartialMessages)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Stream partial messages toggle")
                .onChange(of: config.includePartialMessages) { _, _ in
                    HapticManager.selection()
                }

            Toggle("Debug Mode", isOn: $config.debug)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Debug mode toggle")
                .onChange(of: config.debug) { _, _ in
                    HapticManager.selection()
                }

            TextField("Agent", text: $config.agent)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Agent identifier text field")

            TextField("Beta Flags", text: $config.betas)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Beta flags text field")
                .accessibilityHint("Comma-separated")

            TextField("Input Format", text: $config.inputFormat)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Input format text field")
                .accessibilityHint("e.g. stream-json")
        }
        .listRowBackground(theme.bgSecondary)
    }

    /// Form section containing a single destructive button that resets all fields to their default values.
    /// Replaces the entire ``config`` binding with a freshly initialised ``ChatOptionsConfig``.
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                config = ChatOptionsConfig()
            } label: {
                Text("Reset to Defaults")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Reset to defaults button")
        }
        .listRowBackground(theme.bgSecondary)
    }
}
