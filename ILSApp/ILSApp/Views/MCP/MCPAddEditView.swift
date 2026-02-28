import SwiftUI
import ILSShared

// MARK: - Environment Variable Entry

private struct EnvEntry: Identifiable {
    var id = UUID()
    var key: String
    var value: String
}

// MARK: - MCP Add/Edit View

/// Full-featured form for creating or editing an MCP server configuration.
/// Pass `server: nil` to create a new server, or a non-nil `MCPServer` to edit an existing one.
struct MCPAddEditView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    var viewModel: MCPViewModel
    /// nil = create mode, non-nil = edit mode
    var server: MCPServer?
    /// Called with the created/updated server when the save succeeds.
    var onSaved: ((MCPServer) -> Void)?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var args: [String] = []
    @State private var envEntries: [EnvEntry] = []
    @State private var scope: MCPScope = .user

    // MARK: - UI State

    @State private var isSaving = false
    @State private var validationResult: MCPValidationResult?
    @State private var validationTask: Task<Void, Never>?
    @State private var saveError: String?
    @State private var showPresetsSheet = false

    private var isEditMode: Bool { server != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingMD) {
                    // Choose Preset (create mode only)
                    if !isEditMode {
                        presetButton
                    }

                    nameSection
                    commandSection
                    argumentsSection
                    environmentSection
                    scopeSection

                    if let result = validationResult {
                        validationSection(result: result)
                    }

                    if let error = saveError {
                        errorBanner(error)
                    }
                }
                .padding(theme.spacingMD)
            }
            .background(theme.bgPrimary)
            .navigationTitle(isEditMode ? "Edit Server" : "Add MCP Server")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(theme.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSaving {
                        ProgressView().tint(theme.accent)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? theme.accent : theme.textTertiary)
                        .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $showPresetsSheet) {
                MCPPresetsView(viewModel: viewModel) { preset in
                    applyPreset(preset)
                    showPresetsSheet = false
                }
            }
        }
        .onAppear {
            loadExistingServer()
        }
    }

    // MARK: - Presets Button

    @ViewBuilder
    private var presetButton: some View {
        Button {
            Task { await viewModel.loadPresets() }
            showPresetsSheet = true
        } label: {
            HStack {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(theme.accent)
                Text("Choose Preset")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose from preset MCP server configurations")
    }

    // MARK: - Name Section

    @ViewBuilder
    private var nameSection: some View {
        formSection(title: "Server Name") {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                TextField("e.g. filesystem", text: $name)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: name) { _, _ in scheduleValidation() }

                if isEditMode {
                    Text("Server name is read-only in edit mode")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .opacity(isEditMode ? 0.6 : 1)
        .allowsHitTesting(!isEditMode)
    }

    // MARK: - Command Section

    @ViewBuilder
    private var commandSection: some View {
        formSection(title: "Command") {
            TextField("e.g. npx", text: $command)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onChange(of: command) { _, _ in scheduleValidation() }
        }
    }

    // MARK: - Arguments Section

    @ViewBuilder
    private var argumentsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("ARGUMENTS")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(1)
                Spacer()
                Button {
                    args.append("")
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.fontBody))
                }
                .accessibilityLabel("Add argument")
            }

            if args.isEmpty {
                Text("No arguments configured")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
            } else {
                VStack(spacing: theme.spacingSM) {
                    ForEach(args.indices, id: \.self) { index in
                        HStack(spacing: theme.spacingSM) {
                            TextField("argument \(index + 1)", text: Binding(
                                get: { args[index] },
                                set: {
                                    args[index] = $0
                                    scheduleValidation()
                                }
                            ))
                            .font(.system(size: theme.fontBody, design: theme.fontDesign))
                            .foregroundStyle(theme.textPrimary)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                            Button {
                                args.remove(at: index)
                                scheduleValidation()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(theme.error)
                                    .font(.system(size: theme.fontBody))
                            }
                            .accessibilityLabel("Remove argument \(index + 1)")
                        }
                        .padding(theme.spacingMD)
                        .modifier(GlassCard())
                    }
                }
            }
        }
    }

    // MARK: - Environment Variables Section

    @ViewBuilder
    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Text("ENVIRONMENT VARIABLES")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(1)
                Spacer()
                Button {
                    envEntries.append(EnvEntry(key: "", value: ""))
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.fontBody))
                }
                .accessibilityLabel("Add environment variable")
            }

            if envEntries.isEmpty {
                Text("No environment variables")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
            } else {
                VStack(spacing: theme.spacingSM) {
                    ForEach($envEntries) { $entry in
                        envEntryRow(entry: $entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func envEntryRow(entry: Binding<EnvEntry>) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            VStack(alignment: .leading, spacing: 6) {
                TextField("KEY_NAME", text: entry.key)
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)

                if isSensitiveKey(entry.key.wrappedValue) {
                    SecureField("value (sensitive)", text: entry.value)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    TextField("value", text: entry.value)
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }

            Spacer()

            Button {
                envEntries.removeAll { $0.id == entry.id }
                scheduleValidation()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(theme.error)
                    .font(.system(size: theme.fontBody))
            }
            .accessibilityLabel("Remove \(entry.key.wrappedValue.isEmpty ? "variable" : entry.key.wrappedValue)")
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Scope Section

    @ViewBuilder
    private var scopeSection: some View {
        formSection(title: "Scope") {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Picker("Scope", selection: $scope) {
                    Text("User (~/.claude/)").tag(MCPScope.user)
                    Text("Project").tag(MCPScope.project)
                    Text("Local").tag(MCPScope.local)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Configuration scope")

                Text(scopeDescription)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private func validationSection(result: MCPValidationResult) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Label("Configuration Errors", systemImage: "xmark.circle.fill")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.error)

                    ForEach(result.errors, id: \.self) { message in
                        HStack(alignment: .top, spacing: theme.spacingSM) {
                            Circle()
                                .fill(theme.error)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(message)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.error)
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }

            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.warning)

                    ForEach(result.warnings, id: \.self) { message in
                        HStack(alignment: .top, spacing: theme.spacingSM) {
                            Circle()
                                .fill(theme.warning)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            Text(message)
                                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                .foregroundStyle(theme.warning)
                        }
                    }
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(theme.error)
            Text(message)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.error)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Helpers

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text(title.uppercased())
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .tracking(1)

            content()
                .padding(theme.spacingMD)
                .modifier(GlassCard())
        }
    }

    private var scopeDescription: String {
        switch scope {
        case .user: return "Available across all your projects (~/.claude/)"
        case .project: return "Scoped to the current project's configuration file"
        case .local: return "Scoped to the current working directory only"
        case .managed: return "Enterprise/system-wide managed configuration"
        }
    }

    private func isSensitiveKey(_ key: String) -> Bool {
        let patterns = ["key", "token", "secret", "password", "auth", "credential", "bearer"]
        let lower = key.lowercased()
        return patterns.contains { lower.contains($0) }
    }

    private func loadExistingServer() {
        guard let server = server else { return }
        name = server.name
        command = server.command
        args = server.args
        scope = server.scope
        if let env = server.env {
            envEntries = env.map { EnvEntry(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key }
        }
    }

    private func scheduleValidation() {
        validationTask?.cancel()
        validationTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty, !trimmedCommand.isEmpty else {
                validationResult = nil
                return
            }
            let env = buildEnvDictionary()
            validationResult = await viewModel.validateConfig(
                name: trimmedName,
                command: trimmedCommand,
                args: args.filter { !$0.isEmpty },
                env: env.isEmpty ? nil : env,
                scope: scope.rawValue
            )
        }
    }

    private func buildEnvDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        for entry in envEntries where !entry.key.isEmpty {
            dict[entry.key] = entry.value
        }
        return dict
    }

    private func applyPreset(_ preset: MCPPreset) {
        name = preset.name.lowercased().replacingOccurrences(of: " ", with: "-")
        command = preset.command
        args = preset.args
        scope = preset.scope
        if let env = preset.env {
            envEntries = env.map { EnvEntry(key: $0.key, value: $0.value) }
                .sorted { $0.key < $1.key }
        } else {
            envEntries = []
        }
        scheduleValidation()
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        let filteredArgs = args.filter { !$0.isEmpty }
        let envDict = buildEnvDictionary()
        let envToSave: [String: String]? = envDict.isEmpty ? nil : envDict

        if isEditMode {
            let updated = await viewModel.updateServer(
                name: trimmedName,
                command: trimmedCommand,
                args: filteredArgs,
                env: envToSave,
                scope: scope.rawValue
            )
            if let updated = updated {
                onSaved?(updated)
                dismiss()
            } else {
                saveError = "Failed to update server. Please try again."
            }
        } else {
            let created = await viewModel.addServer(
                name: trimmedName,
                command: trimmedCommand,
                args: filteredArgs,
                env: envToSave,
                scope: scope.rawValue
            )
            if let created = created {
                onSaved?(created)
                dismiss()
            } else {
                saveError = "Failed to create server. Please try again."
            }
        }

        isSaving = false
    }
}
