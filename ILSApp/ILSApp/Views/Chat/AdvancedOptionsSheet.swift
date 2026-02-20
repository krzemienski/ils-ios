import SwiftUI
import ILSShared

/// Local UI model for advanced chat options, converted to ChatOptions for API calls
struct ChatOptionsConfig {
    var systemPrompt: String = ""
    var appendSystemPrompt: String = ""
    var model: String = AppConstants.defaultModel
    var permissionMode: PermissionMode = .default
    var maxTurns: Int = 1
    var maxBudgetUSD: Double? = nil
    var allowedTools: String = ""
    var disallowedTools: String = ""
    var continueConversation: Bool = false
    var noSessionPersistence: Bool = false
    var includePartialMessages: Bool = true
    var inputFormat: String = ""
    var agent: String = ""
    var betas: String = ""
    var debug: Bool = false

    /// Whether any non-default options have been set
    var hasCustomOptions: Bool {
        !systemPrompt.isEmpty || !appendSystemPrompt.isEmpty ||
        model != AppConstants.defaultModel || permissionMode != .default ||
        maxTurns != 1 || maxBudgetUSD != nil ||
        !allowedTools.isEmpty || !disallowedTools.isEmpty ||
        continueConversation || noSessionPersistence ||
        !includePartialMessages || !inputFormat.isEmpty ||
        !agent.isEmpty || !betas.isEmpty || debug
    }

    /// Convert to ChatOptions for API request
    func toChatOptions() -> ChatOptions? {
        guard hasCustomOptions else { return nil }
        return ChatOptions(
            model: model != AppConstants.defaultModel ? model : nil,
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

struct AdvancedOptionsSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss
    @Binding var config: ChatOptionsConfig

    var body: some View {
        NavigationStack {
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
    }

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

    private var toolControlSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Allowed Tools")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                    InfoTooltipButton(text: "Comma-separated list of tools Claude can use. Supports glob patterns like 'Bash(npm:*)' or 'Read'. Leave empty for default behavior.")
                }
                TextField("e.g. Read,Write,Bash", text: $config.allowedTools)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityLabel("Allowed tools text field")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Disallowed Tools")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                    InfoTooltipButton(text: "Comma-separated list of tools Claude cannot use. Overrides allowed tools. Leave empty for default behavior.")
                }
                TextField("e.g. Edit,Write", text: $config.disallowedTools)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityLabel("Disallowed tools text field")
            }
        } header: {
            Text("Tool Control")
        }
        .listRowBackground(theme.bgSecondary)
    }

    private var advancedSection: some View {
        Section("Advanced") {
            Toggle(isOn: $config.continueConversation) {
                HStack {
                    Text("Continue Previous Session")
                    InfoTooltipButton(text: "Resume the most recent session instead of starting fresh. Preserves conversation context and tool state from the previous interaction.")
                }
            }
            .foregroundColor(theme.textPrimary)
            .accessibilityLabel("Continue previous session toggle")

            Toggle(isOn: $config.noSessionPersistence) {
                HStack {
                    Text("Disable Session Persistence")
                    InfoTooltipButton(text: "Session data won't be saved to disk. Useful for ephemeral tasks or sensitive conversations that shouldn't persist.")
                }
            }
            .foregroundColor(theme.textPrimary)
            .accessibilityLabel("Disable session persistence toggle")

            Toggle(isOn: $config.includePartialMessages) {
                HStack {
                    Text("Stream Partial Messages")
                    InfoTooltipButton(text: "Receive incremental message updates as Claude generates them. Disable for complete messages only (reduces network traffic).")
                }
            }
            .foregroundColor(theme.textPrimary)
            .accessibilityLabel("Stream partial messages toggle")

            Toggle(isOn: $config.debug) {
                HStack {
                    Text("Debug Mode")
                    InfoTooltipButton(text: "Enables verbose logging of API calls, tool executions, and internal state. Useful for troubleshooting but produces significant output.")
                }
            }
            .foregroundColor(theme.textPrimary)
            .accessibilityLabel("Debug mode toggle")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Agent")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                    InfoTooltipButton(text: "Specify a custom agent identifier to route the session to a specialized agent configuration. Leave empty for the default Claude agent.")
                }
                TextField("Agent identifier", text: $config.agent)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityLabel("Agent identifier text field")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Beta Flags")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                    InfoTooltipButton(text: "Comma-separated list of experimental feature flags to enable. These control access to beta capabilities that may change without notice.")
                }
                TextField("e.g. interleaved-thinking", text: $config.betas)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityLabel("Beta flags text field")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Input Format")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundColor(theme.textSecondary)
                    InfoTooltipButton(text: "Controls the format of input passed to Claude. Options include 'stream-json' for structured streaming or leave empty for default text input.")
                }
                TextField("e.g. stream-json", text: $config.inputFormat)
                    .foregroundColor(theme.textPrimary)
                    .accessibilityLabel("Input format text field")
            }
        }
        .listRowBackground(theme.bgSecondary)
    }

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
