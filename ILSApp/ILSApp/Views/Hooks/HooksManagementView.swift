import SwiftUI
import ILSShared

// MARK: - Hooks Management View

/// Read-only view displaying Claude lifecycle hooks configured in ~/.claude/settings.json.
struct HooksManagementView: View {
    @Environment(AppState.self) var appState
    @Environment(\.theme) private var theme: ThemeSnapshot
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Group {
            if let config = viewModel.config?.content, let hooks = config.hooks {
                hooksList(hooks)
            } else if viewModel.isLoading {
                ProgressView("Loading hooks...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Hooks Configured",
                    systemImage: "arrow.triangle.branch",
                    description: Text("Lifecycle hooks are configured in ~/.claude/settings.json")
                )
            }
        }
        .background(theme.bgPrimary)
        .navigationTitle("Hooks")
        .task {
            viewModel.configure(client: appState.apiClient)
            await viewModel.loadAll()
        }
        .refreshable {
            await viewModel.loadAll()
        }
    }

    // MARK: - Hooks List

    @ViewBuilder
    private func hooksList(_ hooks: HooksConfig) -> some View {
        List {
            let events: [(String, String, [HookGroup]?)] = [
                ("SessionStart", "play.circle", hooks.sessionStart),
                ("SubagentStart", "person.2.circle", hooks.subagentStart),
                ("UserPromptSubmit", "bubble.left", hooks.userPromptSubmit),
                ("PreToolUse", "bolt.circle", hooks.preToolUse),
                ("PostToolUse", "checkmark.circle", hooks.postToolUse)
            ]

            ForEach(events, id: \.0) { eventName, icon, groups in
                if let groups = groups, !groups.isEmpty {
                    // SPERF-MED-6: Use indices for stable ForEach identity.
                    Section {
                        ForEach(groups.indices, id: \.self) { index in
                            hookGroupRow(groups[index])
                        }
                    } header: {
                        Label(eventName, systemImage: icon)
                            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                            .foregroundStyle(theme.entityPlugin)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Hook Group Row

    @ViewBuilder
    private func hookGroupRow(_ group: HookGroup) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if let matcher = group.matcher, !matcher.isEmpty {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                    Text("Matcher: \(matcher)")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign).italic())
                        .foregroundStyle(theme.textTertiary)
                }
            }
            if let hookDefs = group.hooks {
                ForEach(hookDefs.indices, id: \.self) { index in
                    hookDefinitionRow(hookDefs[index])
                }
            }
        }
        .padding(.vertical, theme.spacingXS)
    }

    // MARK: - Hook Definition Row

    @ViewBuilder
    private func hookDefinitionRow(_ hookDef: HookDefinition) -> some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: "terminal")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                if let type = hookDef.type {
                    Text(type.capitalized)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
                if let command = hookDef.command {
                    Text(command)
                        .font(.system(size: theme.fontCaption, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
        }
    }
}
