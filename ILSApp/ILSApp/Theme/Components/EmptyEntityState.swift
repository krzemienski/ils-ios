import SwiftUI

/// Custom empty state view themed to each entity type.
/// Shows a large entity-colored SF Symbol, title, description, and optional action button.
struct EmptyEntityState: View {
    let entityType: EntityType
    let title: String
    let description: String
    let actionTitle: String?
    let action: (() -> Void)?

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
        VStack(spacing: ILSTheme.spaceL) {
            Image(systemName: entityType.icon)
                .font(.system(.largeTitle)) // Decorative icon, Dynamic Type compatible
                .foregroundStyle(entityType.gradient)
                .padding(.bottom, ILSTheme.spaceS)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(ILSTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.subheadline)
                .foregroundColor(ILSTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, ILSTheme.spaceXL)
                        .padding(.vertical, ILSTheme.spaceS)
                        .background(entityType.color)
                        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(ILSTheme.space2XL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}
