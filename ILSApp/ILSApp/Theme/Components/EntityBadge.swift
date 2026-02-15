import SwiftUI

struct EntityBadge: View {
    @Environment(\.theme) private var theme
    let entityType: EntityType
    let showLabel: Bool

    init(_ entityType: EntityType, showLabel: Bool = false) {
        self.entityType = entityType
        self.showLabel = showLabel
    }

    private var entityColor: Color {
        switch entityType {
        case .sessions: return theme.entitySession
        case .projects: return theme.entityProject
        case .skills: return theme.entitySkill
        case .mcp: return theme.entityMCP
        case .plugins: return theme.entityPlugin
        case .system: return theme.entitySystem
        }
    }

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: entityType.icon)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundColor(entityColor)

            if showLabel {
                Text(entityType.displayName)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundColor(entityColor)
            }
        }
        .accessibilityLabel("\(entityType.displayName) entity")
    }
}
