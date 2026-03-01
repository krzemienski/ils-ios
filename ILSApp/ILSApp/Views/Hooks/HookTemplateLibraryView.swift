import SwiftUI
import ILSShared

/// Browse and apply pre-built hook templates.
///
/// Presented as a sheet from ``HookEditorSheet``. When the user taps a template
/// the ``onApply`` callback fires and the sheet dismisses automatically.
struct HookTemplateLibraryView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Called when the user selects a template to apply.
    let onApply: (HookTemplate) -> Void

    // MARK: - Derived Data

    /// Ordered list of unique category names preserving insertion order.
    private var categories: [String] {
        var seen = Set<String>()
        return HookTemplate.defaults.compactMap { template in
            if seen.insert(template.category).inserted {
                return template.category
            }
            return nil
        }
    }

    private func templates(for category: String) -> [HookTemplate] {
        HookTemplate.defaults.filter { $0.category == category }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacingMD) {
                    ForEach(categories, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingLG)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Hook Templates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            categoryHeader(category)
            ForEach(templates(for: category)) { template in
                templateRow(template)
            }
        }
        .padding(.top, theme.spacingSM)
    }

    // MARK: - Category Header

    private func categoryHeader(_ category: String) -> some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: iconForCategory(category))
                .foregroundStyle(colorForCategory(category))
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .accessibilityHidden(true)

            Text(category)
                .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Text("\(templates(for: category).count)")
                .font(.system(size: theme.fontCaption, weight: .bold, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgTertiary)
                .clipShape(Capsule())
        }
    }

    // MARK: - Template Row

    private func templateRow(_ template: HookTemplate) -> some View {
        Button {
            onApply(template)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                // Name row
                HStack(spacing: theme.spacingSM) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }

                // Description
                Text(template.description)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Badges
                HStack(spacing: theme.spacingSM) {
                    // Event type badge
                    Text(labelForEventType(template.eventType))
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Matcher badge (if present)
                    if let matcher = template.matcher, !matcher.isEmpty {
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

                    // Handler type badge
                    Text(template.hookDefinition.type ?? "command")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(template.description)")
        .accessibilityHint("Tap to apply this template")
    }

    // MARK: - Helpers

    private func labelForEventType(_ eventType: String) -> String {
        switch eventType {
        case "PreToolUse": return "Pre-Tool Use"
        case "PostToolUse": return "Post-Tool Use"
        case "Notification": return "Notification"
        case "SessionStart": return "Session Start"
        case "Stop": return "Stop"
        case "SubagentStop": return "Subagent Stop"
        default: return eventType
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Notifications": return "bell.fill"
        case "Monitoring": return "chart.bar.fill"
        case "Automation": return "gearshape.2.fill"
        case "Safety": return "shield.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Notifications": return theme.info
        case "Monitoring": return theme.accent
        case "Automation": return theme.success
        case "Safety": return theme.warning
        default: return theme.textSecondary
        }
    }
}

#Preview {
    HookTemplateLibraryView { template in
        _ = template
    }
    .environment(AppState())
}
