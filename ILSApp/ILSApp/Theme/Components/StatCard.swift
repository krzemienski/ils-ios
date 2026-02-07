import SwiftUI

/// A stat card with entity-colored accents, count, title, and optional sparkline.
/// Uses theme tokens for all colors and spacing.
struct StatCard: View {
    let title: String
    let count: Int
    let entityType: EntityType
    let sparklineData: [Double]

    @Environment(\.theme) private var theme: any AppTheme
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

    private var entityColor: Color {
        entityType.themeColor(from: theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            HStack {
                Image(systemName: entityType.icon)
                    .font(.system(size: theme.fontTitle3))
                    .foregroundStyle(entityColor)

                Spacer()

                Text("\(count)")
                    .font(.system(size: theme.fontTitle2, weight: .bold, design: .monospaced))
                    .foregroundStyle(entityColor)
            }

            Text(title)
                .font(.system(size: theme.fontCaption, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            SparklineChart(data: sparklineData, color: entityColor)
        }
        .padding(theme.spacingMD)
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(entityColor.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: entityColor.opacity(0.10), radius: 8, x: 0, y: 4)
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
