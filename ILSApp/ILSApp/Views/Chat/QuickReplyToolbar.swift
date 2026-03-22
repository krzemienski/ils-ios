import SwiftUI

/// A compact horizontal scrolling chip bar that surfaces pinned and frequently-used
/// quick reply templates above the keyboard in the chat input area.
///
/// Chips are ordered with pinned (favourite) templates first, followed by the top-5
/// most-used templates. A trailing "+" chip opens the full template sheet via
/// ``onShowAll``. Tapping any template chip invokes ``onSelect`` with the chosen
/// template so the caller can insert its content into the text field.
///
/// ## Topics
/// ### Input Properties
/// - ``templates`` - Ordered list of templates to display as chips (pinned first, then most-used)
///
/// ### Callbacks
/// - ``onSelect`` - Invoked when the user taps a template chip
/// - ``onShowAll`` - Invoked when the user taps the trailing "+" chip to open the full sheet
struct QuickReplyToolbar: View {
    /// Ordered list of templates to display. Should be pinned templates first,
    /// followed by most-used (top-5). Prepared by the caller.
    let templates: [QuickReplyTemplate]
    /// Called when the user selects a template chip.
    let onSelect: (QuickReplyTemplate) -> Void
    /// Called when the user taps the trailing "+" chip to open the full template browser.
    let onShowAll: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: theme.spacingSM) {
                ForEach(templates) { template in
                    TemplateChip(template: template, theme: theme) {
                        onSelect(template)
                    }
                }
                ShowAllChip(theme: theme, action: onShowAll)
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
        }
        .frame(height: 44)
        .accessibilityIdentifier("quick-reply-toolbar")
        .accessibilityLabel("Quick reply templates")
    }
}

// MARK: - Template Chip

private struct TemplateChip: View {
    let template: QuickReplyTemplate
    let theme: ThemeSnapshot
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    // UXF-008: Shorter chip labels on compact devices to fit more chips on screen
    private var maxTitleLength: Int {
        sizeClass == .compact ? 14 : 20
    }

    private var displayTitle: String {
        let title = template.name
        guard title.count > maxTitleLength else { return title }
        return String(title.prefix(maxTitleLength - 1)) + "\u{2026}"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if template.isFavorite {
                    Image(systemName: "pin.fill")
                        // ACC-007: Use theme caption size for Dynamic Type compliance
                        .font(.system(size: theme.fontCaption, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
                Text(displayTitle)
                    .font(.system(size: theme.fontBody, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
            }
            // UXF-008: Tighter padding on compact devices
            .padding(.horizontal, sizeClass == .compact ? 8 : 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.bgTertiary)
                    .overlay(
                        Capsule()
                            .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(template.name)
        .accessibilityHint("Insert template: \(template.name)")
        .accessibilityIdentifier("quick-reply-chip-\(template.id.uuidString.lowercased())")
    }
}

// MARK: - Show All Chip

private struct ShowAllChip: View {
    let theme: ThemeSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: theme.fontBody, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(theme.bgTertiary)
                        .overlay(
                            Circle()
                                .strokeBorder(theme.borderSubtle, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Browse all templates")
        .accessibilityHint("Opens the full quick reply template library")
        .accessibilityIdentifier("quick-reply-show-all")
    }
}
