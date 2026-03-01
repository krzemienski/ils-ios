import SwiftUI
import ILSShared

/// Modal form sheet for creating or editing a Claude Code hook.
/// Shows event type picker, matcher field, handler type selector, and handler-specific fields.
/// Includes a live JSON preview panel and access to the built-in template library.
struct HookEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    /// Non-nil when editing an existing hook. Nil when creating a new one.
    let existingHook: (eventType: String, groupIndex: Int, group: HookGroup)?

    /// Called when user taps Save. Returns error message or nil on success.
    let onSave: (String, HookGroup, Int?) async -> String?

    // MARK: - Form State

    @State private var selectedEventType: String = "PreToolUse"
    @State private var matcher: String = ""
    @State private var handlerType: String = "command"  // command, http, prompt, agent

    // Command handler fields
    @State private var command: String = ""
    @State private var isAsync: Bool = false

    // HTTP handler fields
    @State private var url: String = ""

    // Prompt/Agent handler fields
    @State private var promptText: String = ""

    // Common fields
    @State private var timeoutText: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    // MARK: - Preview & Template State

    @State private var showPreview = false
    @State private var showTemplateLibrary = false

    var isEditing: Bool { existingHook != nil }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    eventTypeSection
                    matcherSection
                    handlerTypeSection
                    handlerFieldsSection
                    optionalFieldsSection

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(theme.error)
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        }
                    }
                }

                if showPreview {
                    HookPreviewPanel(
                        eventType: selectedEventType,
                        matcher: matcher,
                        handlerType: handlerType,
                        command: command,
                        url: url,
                        promptText: promptText,
                        isAsync: isAsync,
                        timeout: timeoutText
                    )
                    .frame(height: 220)
                    .padding(Edge.Set.horizontal)
                    .padding(Edge.Set.bottom)
                }
            }
            .navigationTitle(isEditing ? "Edit Hook" : "New Hook")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                // Templates button — only shown when creating a new hook
                if !isEditing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showTemplateLibrary = true
                        } label: {
                            Image(systemName: "square.stack")
                        }
                        .accessibilityLabel("Hook Templates")
                    }
                }

                // Preview toggle button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPreview.toggle()
                        }
                    } label: {
                        Image(systemName: showPreview ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(showPreview ? "Hide Preview" : "Show JSON Preview")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                    .bold()
                }
            }
            .onAppear { populateFromExisting() }
            .sheet(isPresented: $showTemplateLibrary) {
                HookTemplateLibraryView { template in
                    applyTemplate(template)
                }
            }
        }
    }

    // MARK: - Sections

    private var eventTypeSection: some View {
        Section {
            Picker("Event Type", selection: $selectedEventType) {
                ForEach(HooksViewModel.allEventTypes, id: \.name) { eventInfo in
                    Label(eventInfo.label, systemImage: eventInfo.icon)
                        .tag(eventInfo.name)
                }
            }
            .disabled(isEditing)

            if let eventInfo = HooksViewModel.allEventTypes.first(where: { $0.name == selectedEventType }) {
                Text(eventInfo.description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        } header: {
            Text("Event")
        }
    }

    private var matcherSection: some View {
        Section {
            TextField("Pattern (regex, optional)", text: $matcher)
                .font(.system(size: theme.fontBody, design: .monospaced))
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if let hint = matcherHint {
                Text("Filters on: \(hint)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        } header: {
            Text("Matcher")
        } footer: {
            Text("Leave empty to match all events of this type.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    private var handlerTypeSection: some View {
        Section {
            Picker("Handler Type", selection: $handlerType) {
                Text("Command").tag("command")
                Text("HTTP").tag("http")
                Text("Prompt").tag("prompt")
                Text("Agent").tag("agent")
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Handler")
        }
    }

    @ViewBuilder
    private var handlerFieldsSection: some View {
        Section {
            switch handlerType {
            case "command":
                TextField("Shell command", text: $command)
                    .font(.system(size: theme.fontBody, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                Toggle("Run asynchronously", isOn: $isAsync)

            case "http":
                TextField("Webhook URL", text: $url)
                    .font(.system(size: theme.fontBody, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif

            case "prompt", "agent":
                ZStack(alignment: .topLeading) {
                    if promptText.isEmpty {
                        Text("Enter prompt for LLM evaluation...")
                            .foregroundStyle(theme.textTertiary)
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $promptText)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
                if handlerType == "agent" {
                    Text("Agent handlers have tool access and can make changes.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)
                }

            default:
                EmptyView()
            }
        } header: {
            Text(handlerTypeLabel)
        }
    }

    private var optionalFieldsSection: some View {
        Section {
            TextField("Timeout (seconds)", text: $timeoutText)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        } header: {
            Text("Options")
        } footer: {
            Text("Leave empty for default timeout.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
        }
    }

    // MARK: - Helpers

    private var matcherHint: String? {
        HooksViewModel.allEventTypes.first(where: { $0.name == selectedEventType })?.matcherDescription
    }

    private var handlerTypeLabel: String {
        switch handlerType {
        case "command": return "Command Configuration"
        case "http": return "HTTP Configuration"
        case "prompt": return "Prompt Configuration"
        case "agent": return "Agent Configuration"
        default: return "Configuration"
        }
    }

    /// Whether the form has enough data to save.
    private var isValid: Bool {
        switch handlerType {
        case "command": return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "http": return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "prompt", "agent": return !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return false
        }
    }

    // MARK: - Populate from existing hook

    private func populateFromExisting() {
        guard let existing = existingHook else { return }
        selectedEventType = existing.eventType

        if let existingMatcher = existing.group.matcher {
            matcher = existingMatcher
        }

        if let hookDef = existing.group.hooks?.first {
            handlerType = hookDef.type ?? "command"
            command = hookDef.command ?? ""
            isAsync = hookDef.isAsync ?? false
            url = hookDef.url ?? ""
            promptText = hookDef.prompt ?? ""
            if let t = hookDef.timeout {
                timeoutText = "\(t)"
            }
        }
    }

    // MARK: - Apply Template

    private func applyTemplate(_ template: HookTemplate) {
        selectedEventType = template.eventType
        matcher = template.matcher ?? ""

        let hookDef = template.hookDefinition
        handlerType = hookDef.type ?? "command"
        command = hookDef.command ?? ""
        isAsync = hookDef.isAsync ?? false
        url = hookDef.url ?? ""
        promptText = hookDef.prompt ?? ""
        if let t = hookDef.timeout {
            timeoutText = "\(t)"
        } else {
            timeoutText = ""
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Build HookDefinition from form fields
        var hookDef = HookDefinition()
        hookDef.type = handlerType

        switch handlerType {
        case "command":
            hookDef.command = command.trimmingCharacters(in: .whitespacesAndNewlines)
            if isAsync { hookDef.isAsync = true }
        case "http":
            hookDef.url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        case "prompt", "agent":
            hookDef.prompt = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            break
        }

        if let timeout = Int(timeoutText), timeout > 0 {
            hookDef.timeout = timeout
        }

        // Build HookGroup
        let trimmedMatcher = matcher.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = HookGroup(
            matcher: trimmedMatcher.isEmpty ? nil : trimmedMatcher,
            hooks: [hookDef]
        )

        let editIndex = existingHook?.groupIndex
        if let error = await onSave(selectedEventType, group, editIndex) {
            errorMessage = error
        } else {
            dismiss()
        }
    }
}
