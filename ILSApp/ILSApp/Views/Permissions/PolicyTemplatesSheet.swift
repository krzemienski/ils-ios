import SwiftUI
import ILSShared

// MARK: - PolicyTemplatesSheet

/// Modal sheet displaying built-in policy templates (Strict, Balanced, Permissive)
/// with descriptions of what each does, a preview of the rules that would be
/// created, and a one-tap Apply button.
///
/// When backend-provided templates are available they are used directly;
/// otherwise the view falls back to three hardcoded built-in definitions so
/// the user always sees meaningful content.
struct PolicyTemplatesSheet: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.dismiss) private var dismiss

    /// Templates loaded from the backend (may be empty).
    let templates: [PolicyTemplateResponse]
    /// Callback invoked when the user taps Apply.  Returns `true` on success.
    let onApply: (String) async -> Bool

    @State private var applyingTemplateId: String?
    @State private var expandedTemplateId: String?

    /// Resolved list — backend templates if available, otherwise built-in fallbacks.
    private var displayTemplates: [PolicyTemplateResponse] {
        templates.isEmpty ? Self.builtInTemplates : templates
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacingMD) {
                    headerInfo

                    ForEach(displayTemplates) { template in
                        templateCard(template: template)
                    }
                }
                .padding(.horizontal, theme.spacingMD)
                .padding(.bottom, theme.spacingLG)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Policy Templates")
            #if os(iOS)
            .inlineNavigationBarTitle()
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .environment(\.theme, theme)
    }

    // MARK: - Header Info

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text("Choose a template to quickly configure approval rules for your workflow.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
    }

    // MARK: - Template Card

    private func templateCard(template: PolicyTemplateResponse) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            // Header row: icon + name + Apply button
            HStack(spacing: theme.spacingSM) {
                Image(systemName: templateIcon(for: template.template))
                    .font(.system(size: 20, design: theme.fontDesign))
                    .foregroundStyle(templateColor(for: template.template))
                    .frame(width: 32, height: 32)
                    .background(templateColor(for: template.template).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text(template.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                applyButton(for: template)
            }

            // Default action badge
            HStack(spacing: theme.spacingSM) {
                Text("Default:")
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)

                actionBadge(for: template.defaultAction)

                if !template.confirmationRequiredRiskLevels.isEmpty {
                    Text("Confirm:")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    ForEach(template.confirmationRequiredRiskLevels, id: \.self) { level in
                        riskBadge(for: level)
                    }
                }
            }

            // Expandable rule preview
            if !template.toolRules.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedTemplateId == template.id {
                            expandedTemplateId = nil
                        } else {
                            expandedTemplateId = template.id
                        }
                    }
                } label: {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: expandedTemplateId == template.id
                              ? "chevron.down" : "chevron.right")
                            .font(.system(size: theme.fontCaption))
                            .foregroundStyle(theme.accent)
                            .accessibilityHidden(true)

                        Text("\(template.toolRules.count) tool rule\(template.toolRules.count == 1 ? "" : "s")")
                            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                            .foregroundStyle(theme.accent)
                    }
                }
                .buttonStyle(.plain)

                if expandedTemplateId == template.id {
                    rulePreviewList(rules: template.toolRules)
                }
            }
        }
        .padding(theme.spacingMD)
        .modifier(GlassCard())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: template))
    }

    // MARK: - Apply Button

    private func applyButton(for template: PolicyTemplateResponse) -> some View {
        Button {
            Task {
                applyingTemplateId = template.id
                let success = await onApply(template.id)
                applyingTemplateId = nil
                if success {
                    HapticManager.selection()
                    dismiss()
                }
            }
        } label: {
            if applyingTemplateId == template.id {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
            } else {
                Text("Apply")
                    .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .buttonStyle(.plain)
        .disabled(applyingTemplateId != nil)
        .accessibilityLabel("Apply \(template.name) template")
    }

    // MARK: - Action Badge

    private func actionBadge(for action: PolicyAction) -> some View {
        HStack(spacing: 2) {
            Image(systemName: actionIcon(for: action))
                .accessibilityHidden(true)
            Text(actionLabel(for: action))
        }
        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
        .foregroundStyle(actionColor(for: action))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(actionColor(for: action).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Risk Badge

    private func riskBadge(for level: PermissionRiskLevel) -> some View {
        Text(riskLabel(for: level))
            .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(riskColor(for: level))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskColor(for: level).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Rule Preview List

    private func rulePreviewList(rules: [PolicyToolRule]) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ForEach(rules, id: \.toolPattern) { rule in
                HStack(spacing: theme.spacingSM) {
                    Text(rule.toolPattern)
                        .font(.system(size: theme.fontCaption, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: actionIcon(for: rule.action))
                            .accessibilityHidden(true)
                        Text(actionLabel(for: rule.action))
                    }
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(actionColor(for: rule.action))
                }
                .padding(.horizontal, theme.spacingSM)
                .padding(.vertical, 4)
                .background(theme.bgTertiary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Display Helpers

    private func templateIcon(for template: PolicyTemplate) -> String {
        switch template {
        case .strict: return "lock.shield.fill"
        case .balanced: return "scale.3d"
        case .permissive: return "bolt.shield.fill"
        case .custom: return "gearshape"
        }
    }

    private func templateColor(for template: PolicyTemplate) -> Color {
        switch template {
        case .strict: return theme.error
        case .balanced: return theme.warning
        case .permissive: return theme.success
        case .custom: return theme.accent
        }
    }

    private func actionLabel(for action: PolicyAction) -> String {
        switch action {
        case .autoApprove: return "Auto-Approve"
        case .alwaysAsk: return "Always Ask"
        case .autoDeny: return "Auto-Deny"
        case .requireConfirmation: return "Confirm"
        }
    }

    private func actionIcon(for action: PolicyAction) -> String {
        switch action {
        case .autoApprove: return "checkmark.circle.fill"
        case .alwaysAsk: return "questionmark.circle.fill"
        case .autoDeny: return "xmark.circle.fill"
        case .requireConfirmation: return "exclamationmark.circle.fill"
        }
    }

    private func actionColor(for action: PolicyAction) -> Color {
        switch action {
        case .autoApprove: return theme.success
        case .alwaysAsk: return theme.warning
        case .autoDeny: return theme.error
        case .requireConfirmation: return theme.accent
        }
    }

    private func riskLabel(for level: PermissionRiskLevel) -> String {
        switch level {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    private func riskColor(for level: PermissionRiskLevel) -> Color {
        switch level {
        case .low: return theme.accent
        case .medium: return theme.warning
        case .high, .critical: return theme.error
        }
    }

    private func accessibilityLabel(for template: PolicyTemplateResponse) -> String {
        let ruleCount = template.toolRules.count
        let rules = ruleCount == 1 ? "1 tool rule" : "\(ruleCount) tool rules"
        return "\(template.name) template. \(template.description). \(rules)."
    }

    // MARK: - Built-in Fallback Templates

    /// Hardcoded templates shown when the backend hasn't provided any.
    static let builtInTemplates: [PolicyTemplateResponse] = [
        PolicyTemplateResponse(
            id: "strict",
            name: "Strict",
            description: "Maximum safety: all actions require explicit user approval. Best for sensitive codebases or when first onboarding an agent.",
            template: .strict,
            defaultAction: .alwaysAsk,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Glob", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Grep", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Bash", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Write", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Edit", action: .alwaysAsk),
            ],
            confirmationRequiredRiskLevels: [.low, .medium, .high, .critical]
        ),
        PolicyTemplateResponse(
            id: "balanced",
            name: "Balanced",
            description: "Moderate safety: read-only operations (Read, Glob, Grep) are auto-approved. Write operations and Bash commands require explicit approval.",
            template: .balanced,
            defaultAction: .alwaysAsk,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .autoApprove),
                PolicyToolRule(toolPattern: "Glob", action: .autoApprove),
                PolicyToolRule(toolPattern: "Grep", action: .autoApprove),
                PolicyToolRule(toolPattern: "Write", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Edit", action: .alwaysAsk),
                PolicyToolRule(toolPattern: "Bash", action: .alwaysAsk),
            ],
            confirmationRequiredRiskLevels: [.high, .critical]
        ),
        PolicyTemplateResponse(
            id: "permissive",
            name: "Permissive",
            description: "Minimum friction: most tools auto-approved for fast iteration. Only destructive or high-risk actions require confirmation.",
            template: .permissive,
            defaultAction: .autoApprove,
            toolRules: [
                PolicyToolRule(toolPattern: "Read", action: .autoApprove),
                PolicyToolRule(toolPattern: "Glob", action: .autoApprove),
                PolicyToolRule(toolPattern: "Grep", action: .autoApprove),
                PolicyToolRule(toolPattern: "Write", action: .autoApprove),
                PolicyToolRule(toolPattern: "Edit", action: .autoApprove),
                PolicyToolRule(toolPattern: "Bash", action: .requireConfirmation),
            ],
            confirmationRequiredRiskLevels: [.critical]
        ),
    ]
}

#Preview {
    PolicyTemplatesSheet(
        templates: [],
        onApply: { _ in true }
    )
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
