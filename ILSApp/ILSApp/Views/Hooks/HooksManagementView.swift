import SwiftUI
import ILSShared

struct HooksManagementView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = HooksViewModel()
    @State private var showCreateSheet = false
    @State private var editingHook: (eventType: String, groupIndex: Int, group: HookGroup)?
    @State private var showDeleteError: String?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.hooks.isEmpty {
                loadingState
            } else if viewModel.hooks.isEmpty {
                emptyState
            } else {
                hooksList
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Hooks")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new hook")
            }
        }
        .refreshable {
            await viewModel.loadHooks()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadHooks()
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadHooks() }
        }
        .sheet(isPresented: $showCreateSheet) {
            HookEditorSheet(
                existingHook: nil,
                onSave: { eventType, group, editIndex in
                    await viewModel.saveHook(eventType: eventType, group: group, editIndex: editIndex)
                }
            )
        }
        .sheet(item: Binding(
            get: { editingHook.map { EditingHookWrapper(eventType: $0.eventType, groupIndex: $0.groupIndex, group: $0.group) } },
            set: { wrapper in editingHook = wrapper.map { ($0.eventType, $0.groupIndex, $0.group) } }
        )) { wrapper in
            HookEditorSheet(
                existingHook: (wrapper.eventType, wrapper.groupIndex, wrapper.group),
                onSave: { eventType, group, editIndex in
                    await viewModel.saveHook(eventType: eventType, group: group, editIndex: editIndex)
                }
            )
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { showDeleteError != nil },
            set: { if !$0 { showDeleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = showDeleteError {
                Text(error)
            }
        }
    }

    // MARK: - Hooks List

    private var hooksList: some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                summaryHeader

                ForEach(viewModel.eventTypes, id: \.self) { eventType in
                    hookEventSection(eventType: eventType)
                }

                configActionButtons
                    .padding(.top, theme.spacingSM)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(viewModel.totalHookCount)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Text("Total Hooks")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            VStack(spacing: 2) {
                Text("\(viewModel.eventTypes.count)")
                    .font(.system(size: theme.fontTitle3, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.info)
                Text("Event Types")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .background(theme.info.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }

    // MARK: - Hook Event Section

    private func hookEventSection(eventType: String) -> some View {
        let items = viewModel.hooksByEventType[eventType] ?? []
        let hookCount = items.count

        return VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: viewModel.iconForEventType(eventType))
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(viewModel.labelForEventType(eventType))
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Text("\(hookCount)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.bgTertiary)
                    .clipShape(Capsule())
            }
            .padding(.top, theme.spacingSM)

            ForEach(items) { item in
                hookRow(item: item, eventType: eventType)
            }
        }
    }

    // MARK: - Hook Row

    private func hookRow(item: HookDisplayItem, eventType: String) -> some View {
        Button {
            // Open edit sheet -- build the HookGroup from the display item
            if let hooksConfig = viewModel.config?.content.hooks,
               let groups = hooksConfig.events[eventType],
               item.groupIndex < groups.count {
                editingHook = (eventType: eventType, groupIndex: item.groupIndex, group: groups[item.groupIndex])
            }
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Action summary line
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: iconForHandlerType(item.hookType))
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .accessibilityHidden(true)

                    Text(item.actionSummary)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    // Chevron to indicate tappable
                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }

                // Metadata row
                HStack(spacing: theme.spacingSM) {
                    // Hook type badge
                    if let hookType = item.hookType {
                        Text(hookType)
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(colorForHandlerType(hookType))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(colorForHandlerType(hookType).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    // Matcher badge
                    if let matcher = item.matcher, !matcher.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .accessibilityHidden(true)
                            Text(matcher)
                                .lineLimit(1)
                        }
                        .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.warning.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Spacer()
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                if let hooksConfig = viewModel.config?.content.hooks,
                   let groups = hooksConfig.events[eventType],
                   item.groupIndex < groups.count {
                    editingHook = (eventType: eventType, groupIndex: item.groupIndex, group: groups[item.groupIndex])
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                Task {
                    if let error = await viewModel.deleteHook(eventType: eventType, groupIndex: item.groupIndex) {
                        showDeleteError = error
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eventType) hook, \(item.actionSummary)")
        .accessibilityHint("Tap to edit, long press for options")
    }

    // MARK: - Handler Type Helpers

    private func iconForHandlerType(_ type: String?) -> String {
        switch type {
        case "command": return "terminal"
        case "http": return "network"
        case "prompt": return "text.bubble"
        case "agent": return "person.crop.circle"
        default: return "terminal"
        }
    }

    private func colorForHandlerType(_ type: String) -> Color {
        switch type {
        case "command": return theme.accent
        case "http": return theme.info
        case "prompt": return theme.success
        case "agent": return theme.warning
        default: return theme.accent
        }
    }

    // MARK: - Config Action Buttons

    @State private var showCopiedConfirmation = false

    @ViewBuilder
    private var configActionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            NavigationLink {
                ConfigEditorView(scope: .user)
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: "doc.text")
                        .accessibilityHidden(true)
                    Text("Edit Config")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background(theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }

            Button {
                #if os(iOS)
                UIPasteboard.general.string = "~/.claude/settings.json"
                #elseif os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("~/.claude/settings.json", forType: .string)
                #endif
                if reduceMotion {
                    showCopiedConfirmation = true
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopiedConfirmation = true
                    }
                }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    Image(systemName: showCopiedConfirmation ? "checkmark" : "doc.on.doc")
                        .accessibilityHidden(true)
                    Text(showCopiedConfirmation ? "Copied" : "Copy Path")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                }
                .foregroundStyle(showCopiedConfirmation ? theme.success : theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, theme.spacingSM)
                .background((showCopiedConfirmation ? theme.success : theme.accent).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
            .buttonStyle(.plain)
            .onChange(of: showCopiedConfirmation) { _, copied in
                if copied {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        if reduceMotion {
                            showCopiedConfirmation = false
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showCopiedConfirmation = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 40, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .accessibilityHidden(true)
                Text("No Hooks Configured")
                    .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("Hooks let you run custom commands at key points in Claude Code's lifecycle, such as before/after tool use, when a session starts, or when config changes.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingLG)

                // Create hook button
                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: theme.spacingSM) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Hook")
                            .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, theme.spacingMD)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingMD)

                // Supported event types card
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Supported Event Types")
                        .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingSM) {
                        ForEach(HooksViewModel.allEventTypes, id: \.name) { eventInfo in
                            HStack(spacing: 4) {
                                Image(systemName: eventInfo.icon)
                                    .font(.system(size: theme.fontCaption))
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 16)
                                Text(eventInfo.label)
                                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }

                    configActionButtons
                        .padding(.top, theme.spacingSM)
                }
                .padding(theme.spacingMD)
                .modifier(GlassCard())
                .padding(.horizontal, theme.spacingMD)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingXL)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: theme.spacingMD) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading hooks...")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Identifiable Wrapper for Edit Sheet

/// Wrapper to make the editing hook tuple Identifiable for sheet(item:) binding.
private struct EditingHookWrapper: Identifiable {
    let id = UUID()
    let eventType: String
    let groupIndex: Int
    let group: HookGroup
}

#Preview {
    NavigationStack {
        HooksManagementView()
            .environment(AppState())
    }
}
