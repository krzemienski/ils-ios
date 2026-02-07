import SwiftUI

/// A stat card with entity-colored accents, count, title, and optional sparkline.
/// Background: bg2 (#111827), entity-colored border stroke at 15% opacity, shadow at 10%.
struct StatCard: View {
    let title: String
    let count: Int
    let entityType: EntityType
    let sparklineData: [Double]
    @State private var isPressed = false

    init(
        title: String,
        count: Int,
        entityType: EntityType,
        sparklineData: [Double] = []
    ) {
        self.title = title
        self.count = count
        self.entityType = entityType
        self.sparklineData = sparklineData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spaceS) {
            HStack {
                Image(systemName: entityType.icon)
                    .font(.title3)
                    .foregroundStyle(entityType.gradient)

                Spacer()

                Text("\(count)")
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(entityType.color)
            }

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(ILSTheme.textSecondary)

            SparklineChart(data: sparklineData, color: entityType.color)
        }
        .padding(ILSTheme.spaceM)
        .background(ILSTheme.bg2)
        .clipShape(RoundedRectangle(cornerRadius: ILSTheme.radiusS))
        .overlay(
            RoundedRectangle(cornerRadius: ILSTheme.radiusS)
                .stroke(entityType.color.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: entityType.color.opacity(0.10), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count)")
    }
}
