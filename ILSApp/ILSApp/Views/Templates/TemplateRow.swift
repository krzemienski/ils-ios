import SwiftUI
import ILSShared

// MARK: - TemplateRow

/// A compact list-item row that displays a single ``SessionTemplate``.
///
/// Renders the template name, a truncated description preview, a model badge
/// (e.g. "Sonnet"), a permission-mode label, and a star button for toggling
/// the favourite state.  Built-in templates receive an additional "Built-in"
/// badge to distinguish them from user-created templates.
///
/// The row is designed for use inside a SwiftUI `List` or `LazyVStack` and keeps
/// its layout tight so multiple templates are visible without scrolling.
///
/// ## Topics
/// ### Inputs
/// - ``template`` — The template model whose data drives the row
/// - ``onFavoriteToggle`` — Called when the user taps the star button
///
/// ### Display Helpers
/// - ``modelLabel`` — Capitalised, human-readable model name
/// - ``permissionModeLabel`` — Human-readable permission mode string
struct TemplateRow: View {
    /// The template model to display.
    let template: SessionTemplate
    /// Called when the user taps the favourite star; the caller is responsible
    /// for persisting the change via the API.
    let onFavoriteToggle: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: theme.spacingSM) {
            // MARK: Main Content
            VStack(alignment: .leading, spacing: 4) {
                // Row 1: name + badges
                HStack(spacing: theme.spacingXS) {
                    Text(template.name)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if template.isBuiltIn {
                        builtInBadge
                    }

                    Spacer(minLength: 0)
                }

                // Row 2: description preview
                if !template.description.isEmpty {
                    Text(template.description)
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                // Row 3: model badge + permission mode
                HStack(spacing: theme.spacingXS) {
                    modelBadge
                    permissionModeLabel
                }
            }

            // MARK: Favourite Star
            Button(action: onFavoriteToggle) {
                Image(systemName: template.isFavorite ? "star.fill" : "star")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(template.isFavorite ? theme.warning : theme.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(template.isBuiltIn)
            .opacity(template.isBuiltIn ? 0.3 : 1.0)
            .accessibilityLabel(template.isBuiltIn ? "Favourites not available for built-in templates" : (template.isFavorite ? "Remove from favourites" : "Add to favourites"))
        }
        .padding(.vertical, theme.spacingXS)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Sub-views

    /// Small pill badge marking the template as built-in.
    private var builtInBadge: some View {
        Text("Built-in")
            .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(theme.accent.opacity(0.12))
            .clipShape(Capsule())
    }

    /// Small pill badge showing the Claude model name.
    private var modelBadge: some View {
        Text(modelLabel)
            .font(.system(size: theme.fontCaption - 1, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.entitySession)
            .padding(.horizontal, theme.spacingXS + 2)
            .padding(.vertical, 2)
            .background(theme.entitySession.opacity(0.12))
            .clipShape(Capsule())
    }

    /// Permission mode displayed as plain secondary text.
    private var permissionModeLabel: some View {
        Text(permissionModeDisplayLabel)
            .font(.system(size: theme.fontCaption - 1, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
    }

    // MARK: - Helpers

    /// Human-readable, capitalised model name (e.g. "Sonnet", "Opus", "Haiku").
    private var modelLabel: String {
        template.model.prefix(1).uppercased() + template.model.dropFirst()
    }

    /// Human-readable permission mode label derived from the raw string.
    private var permissionModeDisplayLabel: String {
        switch template.permissionMode {
        case "default":         return "Default"
        case "acceptEdits":     return "Accept Edits"
        case "plan":            return "Plan"
        case "bypassPermissions": return "Bypass Permissions"
        case "delegate":        return "Delegate"
        case "dontAsk":         return "Don't Ask"
        default:
            // Capitalise unknown values gracefully
            return template.permissionMode.prefix(1).uppercased() + template.permissionMode.dropFirst()
        }
    }

    /// Combined accessibility description for VoiceOver.
    private var accessibilityDescription: String {
        var parts = [template.name]
        if template.isBuiltIn { parts.append("Built-in") }
        if !template.description.isEmpty { parts.append(template.description) }
        parts.append("Model: \(modelLabel)")
        parts.append("Permission: \(permissionModeDisplayLabel)")
        if template.isFavorite { parts.append("Favourite") }
        return parts.joined(separator: ", ")
    }
}
