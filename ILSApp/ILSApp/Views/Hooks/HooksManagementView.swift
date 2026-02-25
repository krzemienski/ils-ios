import SwiftUI
import ILSShared

struct HooksManagementView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoadingConfig {
                loadingState
            } else if let hooks = viewModel.config?.content.hooks, hasAnyHooks(hooks) {
                hooksList(hooks)
            } else {
                emptyState
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Hooks")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
        .refreshable {
            await viewModel.loadConfig()
        }
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadConfig()
        }
        .onChange(of: appState.serverURL) { _, _ in
            viewModel.configure(client: appState.apiClient)
            Task { await viewModel.loadConfig() }
        }
    }

    // MARK: - Helpers

    private func hasAnyHooks(_ hooks: HooksConfig) -> Bool {
        countTotalHooks(hooks) > 0
    }

    private func eventSections(_ hooks: HooksConfig) -> [(String, [HookGroup])] {
        [
            ("PreToolUse", hooks.preToolUse ?? []),
            ("PostToolUse", hooks.postToolUse ?? []),
            ("UserPromptSubmit", hooks.userPromptSubmit ?? []),
            ("SessionStart", hooks.sessionStart ?? []),
            ("SubagentStart", hooks.subagentStart ?? [])
        ].filter { !$0.1.isEmpty }
    }

    // MARK: - Hooks List

    private func hooksList(_ hooks: HooksConfig) -> some View {
        ScrollView {
            LazyVStack(spacing: theme.spacingMD) {
                summaryHeader(hooks)

                ForEach(eventSections(hooks), id: \.0) { eventType, groups in
                    hookEventSection(eventType: eventType, groups: groups)
                }

                configActionButtons
                    .padding(.top, theme.spacingSM)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.bottom, theme.spacingLG)
        }
    }

    // MARK: - Summary Header

    private func countTotalHooks(_ hooks: HooksConfig) -> Int {
        var count = 0
        count += hooks.sessionStart?.count ?? 0
        count += hooks.subagentStart?.count ?? 0
        count += hooks.userPromptSubmit?.count ?? 0
        count += hooks.preToolUse?.count ?? 0
        count += hooks.postToolUse?.count ?? 0
        return count
    }

    @ViewBuilder
    private func summaryHeader(_ hooks: HooksConfig) -> some View {
        let totalHooks = countTotalHooks(hooks)
        let eventCount = eventSections(hooks).count

        HStack(spacing: theme.spacingMD) {
            VStack(spacing: 2) {
                Text("\(totalHooks)")
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
                Text("\(eventCount)")
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

    private func countGroupHooks(_ groups: [HookGroup]) -> Int {
        groups.reduce(0) { $0 + ($1.hooks?.count ?? 0) }
    }

    private func hookEventSection(eventType: String, groups: [HookGroup]) -> some View {
        let hookCount = countGroupHooks(groups)
        return VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: iconForEventType(eventType))
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(eventType)
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

            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                ForEach(group.hooks ?? [], id: \.command) { hookDef in
                    hookRow(hookDef: hookDef, matcher: group.matcher, eventType: eventType)
                }
            }
        }
    }

    // MARK: - Hook Row

    private func hookRow(hookDef: HookDefinition, matcher: String?, eventType: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Command line
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "terminal")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(hookDef.command ?? "No command")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Spacer()
            }

            // Metadata row
            HStack(spacing: theme.spacingSM) {
                // Hook type badge
                if let hookType = hookDef.type {
                    Text(hookType)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Matcher badge
                if let matcher, !matcher.isEmpty {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(eventType) hook, \(hookDef.command ?? "no command")")
    }

    private func iconForEventType(_ eventType: String) -> String {
        switch eventType {
        case "PreToolUse": return "wrench.and.screwdriver"
        case "PostToolUse": return "checkmark.circle"
        case "UserPromptSubmit": return "arrow.up.circle"
        case "SessionStart": return "play.circle"
        case "SubagentStart": return "person.fill.badge.plus"
        default: return "bolt"
        }
    }

    // MARK: - Config Action Buttons (shared between hooksList and emptyState)

    @State private var showCopiedConfirmation = false

    @ViewBuilder
    private var configActionButtons: some View {
        HStack(spacing: theme.spacingSM) {
            NavigationLink {
                ConfigEditorView(scope: "user")
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
        VStack(spacing: theme.spacingMD) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 40, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)
            Text("No Hooks Configured")
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Text("Hooks let you run custom commands at key points in Claude Code's lifecycle, such as before/after tool use or when a session ends.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingLG)

            // Actionable guidance card
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                Text("To add hooks, edit your settings file:")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)

                Text("~/.claude/settings.json")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.accent)
                    .padding(theme.spacingSM)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bgTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                configActionButtons

                Text("Supported event types: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, SubagentStart")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
            .padding(.horizontal, theme.spacingMD)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, theme.spacingXL)
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

#Preview {
    NavigationStack {
        HooksManagementView()
            .environment(AppState())
    }
}

