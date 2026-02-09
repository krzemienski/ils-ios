import SwiftUI
import ILSShared

/// Local UI model for advanced chat options, converted to ChatOptions for API calls
struct ChatOptionsConfig {
    var systemPrompt: String = ""
    var appendSystemPrompt: String = ""
    var model: String = "sonnet"
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
        model != "sonnet" || permissionMode != .default ||
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

struct AdvancedOptionsSheet: View {
    @Environment(\.theme) private var theme: any AppTheme
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
            .navigationBarTitleDisplayMode(.inline)
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
                .font(.system(.body, design: .monospaced))
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
                .font(.system(.body, design: .monospaced))
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
                            .font(.system(size: theme.fontCaption, weight: config.model == model ? .semibold : .regular))
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
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 100)
                    .accessibilityLabel("Max budget USD text field")
            }
        }
        .listRowBackground(theme.bgSecondary)
    }

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

    private var advancedSection: some View {
        Section("Advanced") {
            Toggle("Continue Previous Session", isOn: $config.continueConversation)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Continue previous session toggle")

            Toggle("Disable Session Persistence", isOn: $config.noSessionPersistence)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Disable session persistence toggle")

            Toggle("Stream Partial Messages", isOn: $config.includePartialMessages)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Stream partial messages toggle")

            Toggle("Debug Mode", isOn: $config.debug)
                .foregroundColor(theme.textPrimary)
                .accessibilityLabel("Debug mode toggle")

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
