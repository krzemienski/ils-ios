import SwiftUI

/// Placeholder skeleton row with rounded rectangles for loading states.
/// Shows shimmering animation while data loads.
struct SkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 160, height: 16)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 60, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(ILSTheme.bg3)
                .frame(width: 220, height: 12)

            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 100, height: 12)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(ILSTheme.bg3)
                    .frame(width: 50, height: 12)
            }
        }
        .padding(.vertical, 8)
        .shimmer()
    }
}

/// Shows 5 skeleton rows during loading state
struct SkeletonListView: View {
    var body: some View {
        ForEach(0..<5, id: \.self) { _ in
            SkeletonRow()
        }
    }
}
