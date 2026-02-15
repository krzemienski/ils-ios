import SwiftUI

/// Custom empty state view themed to each entity type.
/// Shows a large entity-colored SF Symbol, title, description, and optional action button.
struct EmptyEntityState: View {
    let entityType: EntityType
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?
    @Environment(\.theme) private var theme: any AppTheme

    init(
        entityType: EntityType,
        title: String,
        description: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.entityType = entityType
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: theme.spacingLG) {
            let entityColor = entityType.themeColor(from: theme)

            Image(systemName: entityType.icon)
                .font(.system(size: theme.fontTitle1, design: theme.fontDesign))
                .foregroundStyle(
                    LinearGradient(
                        colors: [entityColor, entityColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, theme.spacingSM)

            Text(title)
                .font(.system(size: theme.fontTitle3, weight: .semibold, design: theme.fontDesign))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundColor(theme.textOnAccent)
                        .padding(.horizontal, theme.spacingLG)
                        .padding(.vertical, theme.spacingSM)
                        .background(entityColor)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingXL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}
