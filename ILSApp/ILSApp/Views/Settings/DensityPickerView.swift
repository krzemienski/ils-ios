import SwiftUI
import ILSShared

// MARK: - Density Picker View

/// Density selection screen for choosing the information density level.
///
/// Presents all available density modes in a single-column list. Each card shows a
/// visual preview demonstrating the spacing and sizing characteristics of that density level.
/// Tapping a card applies the density immediately via ``DensityManager/setDensity(_:)`` with
/// an optional animation that respects the system's reduce-motion accessibility setting.
///
/// Three density levels are available:
/// - **Compact**: Minimal padding, smaller fonts, maximum information per screen
/// - **Standard**: Balanced spacing and readability (default)
/// - **Comfortable**: Generous spacing, larger fonts, enhanced readability
///
/// ## Topics
/// ### View Components
/// - ``densityCard(_:)`` - Card for each density level with visual preview
/// - ``densityPreview(_:)`` - Visual demonstration of spacing for a density level
struct DensityPickerView: View {
    @Environment(DensityManager.self) var densityManager
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingMD) {
                Text("Choose how much information is shown on screen. Density affects spacing, font sizes, and element sizes throughout the app.")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)

                VStack(spacing: theme.spacingSM) {
                    densityCard(.compact)
                    densityCard(.standard)
                    densityCard(.comfortable)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Information Density")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }

    // MARK: - Density Card

    @ViewBuilder
    private func densityCard(_ density: InformationDensity) -> some View {
        let isActive = densityManager.currentDensity == density

        Button {
            if reduceMotion {
                densityManager.setDensity(density)
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    densityManager.setDensity(density)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: theme.spacingSM) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: theme.spacingXS) {
                            Text(density.displayName)
                                .font(.system(size: theme.fontBody, weight: isActive ? .semibold : .medium, design: theme.fontDesign))
                                .foregroundStyle(isActive ? theme.accent : theme.textPrimary)

                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.accent)
                            }
                        }

                        Text(density.description)
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Spacer()
                }

                // Visual preview of the density level
                densityPreview(density)
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .stroke(isActive ? theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(density.displayName) density\(isActive ? ", active" : "")")
        .accessibilityHint(density.description)
    }

    // MARK: - Density Preview

    @ViewBuilder
    private func densityPreview(_ density: InformationDensity) -> some View {
        // Visual demonstration of spacing based on density level
        let itemSpacing: CGFloat = {
            switch density {
            case .compact: return 4
            case .standard: return 8
            case .comfortable: return 12
            }
        }()

        let itemHeight: CGFloat = {
            switch density {
            case .compact: return 32
            case .standard: return 44
            case .comfortable: return 56
            }
        }()

        let fontSize: CGFloat = {
            switch density {
            case .compact: return 13
            case .standard: return 15
            case .comfortable: return 17
            }
        }()

        VStack(spacing: itemSpacing) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.accent.opacity(0.7))
                        .frame(width: fontSize + 2, height: fontSize + 2)

                    VStack(alignment: .leading, spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.textPrimary.opacity(0.6))
                            .frame(width: 120, height: fontSize * 0.6)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.textSecondary.opacity(0.4))
                            .frame(width: 80, height: fontSize * 0.5)
                    }

                    Spacer()
                }
                .frame(height: itemHeight)
                .padding(.horizontal, theme.spacingSM)
                .background(theme.bgSecondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
            }
        }
        .padding(theme.spacingSM)
        .background(theme.bgPrimary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }
}

#Preview {
    NavigationStack {
        DensityPickerView()
            .environment(DensityManager.shared)
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
