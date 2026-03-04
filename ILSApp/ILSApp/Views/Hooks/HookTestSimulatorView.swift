import SwiftUI
import ILSShared

/// Simulates a Claude Code hook event and shows which enabled hooks would fire.
///
/// Allows the user to pick an event type, enter optional tool name / extra context,
/// and tap "Simulate" to see which hooks currently match.  Results are derived from
/// ``HooksViewModel/simulateEvent(eventType:toolName:extraContext:)`` and displayed
/// inline without modifying any configuration.
struct HookTestSimulatorView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    let viewModel: HooksViewModel

    // MARK: - State

    @State private var selectedEventType: String = "PreToolUse"
    @State private var toolName: String = ""
    @State private var extraContext: String = ""
    @State private var matchedHooks: [HookDisplayItem] = []
    @State private var hasSimulated = false

    // MARK: - Derived

    private var selectedEventInfo: HookEventTypeInfo? {
        HooksViewModel.allEventTypes.first { $0.name == selectedEventType }
    }

    private var supportsMatcherInput: Bool {
        selectedEventInfo?.matcherDescription != nil
    }

    private var matcherPlaceholder: String {
        selectedEventInfo?.matcherDescription ?? "Context string"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                infoCard
                eventTypeSection
                inputSection
                simulateButton

                if hasSimulated {
                    resultsSection
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.top, theme.spacingSM)
            .padding(.bottom, theme.spacingLG)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Test Simulator")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            Image(systemName: "info.circle")
                .foregroundStyle(theme.info)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .accessibilityHidden(true)

            Text("Select an event type, provide optional inputs, then tap Simulate to see which of your enabled hooks would fire.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Event Type Section

    private var eventTypeSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Label("Event Type", systemImage: "bolt.circle")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            Menu {
                ForEach(HooksViewModel.allEventTypes, id: \.name) { info in
                    Button {
                        selectedEventType = info.name
                        toolName = ""
                        extraContext = ""
                        hasSimulated = false
                    } label: {
                        Label(info.label, systemImage: info.icon)
                    }
                }
            } label: {
                HStack(spacing: theme.spacingSM) {
                    if let info = selectedEventInfo {
                        Image(systemName: info.icon)
                            .foregroundStyle(theme.accent)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        Text(info.label)
                            .foregroundStyle(theme.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(theme.textTertiary)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                }
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .padding(theme.spacingMD)
                .modifier(GlassCard())
            }
            .accessibilityLabel("Event type: \(selectedEventInfo?.label ?? selectedEventType)")

            if let description = selectedEventInfo?.description {
                Text(description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingXS)
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Label("Simulation Inputs", systemImage: "slider.horizontal.3")
                .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 0) {
                if supportsMatcherInput {
                    inputRow(
                        label: matcherPlaceholder,
                        systemImage: "line.3.horizontal.decrease",
                        placeholder: "e.g. Bash, Edit, Write",
                        text: $toolName
                    )
                    Divider()
                        .padding(.leading, theme.spacingMD)
                }

                inputRow(
                    label: "Extra Context",
                    systemImage: "text.alignleft",
                    placeholder: "Additional matcher context",
                    text: $extraContext
                )
            }
            .modifier(GlassCard())
        }
    }

    private func inputRow(
        label: String,
        systemImage: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                TextField(placeholder, text: text)
                    .font(.system(size: theme.fontBody, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: text.wrappedValue) { _, _ in
                        hasSimulated = false
                    }
            }
        }
        .padding(theme.spacingMD)
    }

    // MARK: - Simulate Button

    private var simulateButton: some View {
        Button {
            runSimulation()
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text("Simulate Event")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMD)
            .background(viewModel.hooks.isEmpty ? theme.accent.opacity(0.4) : theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.hooks.isEmpty)
        .accessibilityLabel("Simulate \(selectedEventInfo?.label ?? selectedEventType) event")
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Label("Matched Hooks", systemImage: "bolt.badge.checkmark")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                Text("\(matchedHooks.count)")
                    .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(matchedHooks.isEmpty ? theme.textTertiary : theme.success)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((matchedHooks.isEmpty ? theme.textTertiary : theme.success).opacity(0.12))
                    .clipShape(Capsule())
            }

            if matchedHooks.isEmpty {
                noMatchState
            } else {
                ForEach(matchedHooks) { hook in
                    matchedHookRow(hook)
                }
            }
        }
    }

    // MARK: - No Match State

    private var noMatchState: some View {
        HStack(spacing: theme.spacingMD) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 28, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("No hooks would fire")
                    .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Text("No enabled hooks match the \(selectedEventInfo?.label ?? selectedEventType) event with the provided inputs.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(GlassCard())
    }

    // MARK: - Matched Hook Row

    private func matchedHookRow(_ hook: HookDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: iconForHandlerType(hook.hookType))
                    .foregroundStyle(theme.success)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .accessibilityHidden(true)

                Text(hook.actionSummary)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.success)
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .accessibilityHidden(true)
            }

            HStack(spacing: theme.spacingSM) {
                if let hookType = hook.hookType {
                    Text(hookType)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(colorForHandlerType(hookType))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForHandlerType(hookType).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                if let matcher = hook.matcher, !matcher.isEmpty {
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
                } else {
                    Text("always fires")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.info)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.info.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hook would fire: \(hook.actionSummary)")
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

    // MARK: - Simulation

    private func runSimulation() {
        matchedHooks = viewModel.simulateEvent(
            eventType: selectedEventType,
            toolName: toolName.isEmpty ? nil : toolName,
            extraContext: extraContext.isEmpty ? nil : extraContext
        )
        hasSimulated = true
    }
}

#Preview {
    NavigationStack {
        HookTestSimulatorView(viewModel: HooksViewModel())
    }
}
