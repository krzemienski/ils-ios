import SwiftUI

// MARK: - Shimmer Effect

/// A view modifier that applies an animated shimmer effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let bounce: Bool

    init(duration: Double = 1.5, bounce: Bool = false) {
        self.duration = duration
        self.bounce = bounce
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(0.3), location: 0.5),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .repeatForever(autoreverses: bounce)
                ) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    /// Applies an animated shimmer effect to the view
    /// - Parameters:
    ///   - duration: Animation duration in seconds (default: 1.5)
    ///   - bounce: Whether the animation should bounce back (default: false)
    func shimmer(duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}

// MARK: - Shimmer View Component

/// A standalone shimmer view for skeleton loading states
struct ShimmerView: View {
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat

    init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = ILSTheme.cornerRadiusM
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Rectangle()
            .fill(ILSTheme.tertiaryBackground)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shimmer()
    }
}

// MARK: - Skeleton Shape Views

/// Skeleton loading view for text lines
struct SkeletonText: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 12) {
        self.width = width
        self.height = height
    }

    var body: some View {
        ShimmerView(
            width: width,
            height: height,
            cornerRadius: ILSTheme.cornerRadiusS
        )
    }
}

/// Skeleton loading view for circular avatars or icons
struct SkeletonCircle: View {
    let size: CGFloat

    init(size: CGFloat = 40) {
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(ILSTheme.tertiaryBackground)
            .frame(width: size, height: size)
            .shimmer()
    }
}

/// Skeleton loading view for rectangular content blocks
struct SkeletonRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(
        width: CGFloat? = nil,
        height: CGFloat = 100,
        cornerRadius: CGFloat = ILSTheme.cornerRadiusM
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ShimmerView(
            width: width,
            height: height,
            cornerRadius: cornerRadius
        )
    }
}

// MARK: - Skeleton Row Variants

/// Skeleton loading view matching ProjectRowView layout
struct SkeletonProjectRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SkeletonText(width: 150, height: 16)
                Spacer()
                SkeletonText(width: 60, height: 14)
            }

            SkeletonText(width: 200, height: 12)

            SkeletonText(width: 180, height: 12)

            HStack {
                SkeletonText(width: 80, height: 12)
                Spacer()
                SkeletonText(width: 60, height: 12)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Skeleton loading view matching SkillRowView layout
struct SkeletonSkillRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ILSTheme.spacingXS) {
            HStack {
                SkeletonText(width: 120, height: 16)
                Spacer()
                SkeletonCircle(size: 12)
            }

            SkeletonText(width: 220, height: 12)

            HStack(spacing: ILSTheme.spacingXS) {
                SkeletonText(width: 50, height: 18)
                SkeletonText(width: 60, height: 18)
                SkeletonText(width: 55, height: 18)
            }

            HStack(spacing: ILSTheme.spacingXS) {
                SkeletonText(width: 80, height: 10)
                SkeletonText(width: 150, height: 10)
            }
        }
        .padding(.vertical, ILSTheme.spacingXS)
    }
}

/// Skeleton loading view matching SessionRowView layout
struct SkeletonSessionRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SkeletonText(width: 140, height: 16)
                Spacer()
                SkeletonText(width: 70, height: 14)
            }

            HStack {
                SkeletonText(width: 100, height: 12)
                Spacer()
                SkeletonText(width: 60, height: 12)
            }

            HStack {
                SkeletonText(width: 90, height: 12)
                SkeletonText(width: 50, height: 12)
                Spacer()
                SkeletonText(width: 50, height: 16)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Skeleton loading view matching MCPServerRowView layout
struct SkeletonMCPServerRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SkeletonText(width: 130, height: 16)
                Spacer()
                SkeletonText(width: 60, height: 12)
            }

            SkeletonText(width: 200, height: 14)

            HStack(spacing: 8) {
                SkeletonText(width: 60, height: 18)
                SkeletonText(width: 50, height: 18)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Shimmer Components") {
    VStack(spacing: ILSTheme.spacingM) {
        // Text skeletons
        VStack(alignment: .leading, spacing: ILSTheme.spacingS) {
            SkeletonText(width: 200, height: 16)
            SkeletonText(width: 150, height: 14)
            SkeletonText(width: 180, height: 14)
        }

        Divider()

        // Circle skeleton
        HStack(spacing: ILSTheme.spacingM) {
            SkeletonCircle(size: 40)
            SkeletonCircle(size: 60)
            SkeletonCircle(size: 80)
        }

        Divider()

        // Rectangle skeleton
        SkeletonRectangle(height: 120)

        Divider()

        // Custom shimmer on any view
        Text("Custom Shimmer")
            .font(ILSTheme.headlineFont)
            .padding()
            .background(ILSTheme.tertiaryBackground)
            .cornerRadius(ILSTheme.cornerRadiusM)
            .shimmer()
    }
    .padding()
}

#Preview("Skeleton Rows") {
    List {
        Section("Project Skeleton") {
            SkeletonProjectRow()
            SkeletonProjectRow()
        }

        Section("Skill Skeleton") {
            SkeletonSkillRow()
            SkeletonSkillRow()
        }

        Section("Session Skeleton") {
            SkeletonSessionRow()
            SkeletonSessionRow()
        }

        Section("MCP Server Skeleton") {
            SkeletonMCPServerRow()
            SkeletonMCPServerRow()
        }
    }
}
