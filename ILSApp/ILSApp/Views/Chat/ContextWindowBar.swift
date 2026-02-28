import SwiftUI

/// Compact progress bar showing context window usage in the chat view.
///
/// Displays the percentage of the context window consumed by the current session,
/// color-coded by usage level. Tapping opens the detail sheet for a full breakdown.
///
/// ## Color Thresholds
/// - < 80%: Accent color (normal)
/// - 80–90%: Warning (yellow)
/// - 90–95%: Orange
/// - ≥ 95%: Error (red)
///
/// ## Topics
/// ### Input Properties
/// - ``usedTokens`` - Number of tokens consumed in the context window
/// - ``contextWindowSize`` - Maximum context window capacity
/// - ``onTap`` - Closure invoked when the user taps the bar to view details
struct ContextWindowBar: View {
    /// Number of tokens consumed so far.
    let usedTokens: Int
    /// Maximum capacity of the context window.
    let contextWindowSize: Int
    /// Called when the user taps the bar to open the detail sheet.
    let onTap: () -> Void

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Computed

    private var percent: Double {
        guard contextWindowSize > 0 else { return 0 }
        return min(Double(usedTokens) / Double(contextWindowSize), 1.0)
    }

    private var barColor: Color {
        switch percent {
        case ..<0.80: return theme.accent
        case 0.80..<0.90: return theme.warning
        case 0.90..<0.95: return .orange
        default: return theme.error
        }
    }

    private var percentText: String {
        "\(Int(percent * 100))%"
    }

    private var tokenCountText: String {
        "\(formatTokens(usedTokens)) / \(formatTokens(contextWindowSize)) tokens"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacingSM) {
                // Icon: warning indicator when approaching limit, cpu icon otherwise
                Image(systemName: percent >= 0.80 ? "exclamationmark.triangle.fill" : "cpu")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(barColor)
                    .frame(width: 14)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.easeInOut(duration: 0.3), value: percent >= 0.80)

                // Progress bar track + fill via GeometryReader for accurate width calculation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.bgTertiary)
                            .frame(height: 4)

                        Capsule()
                            .fill(barColor)
                            .frame(width: geometry.size.width * percent, height: 4)
                            .animation(.easeInOut(duration: 0.4), value: percent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 4)

                // Percentage + token count summary
                Text("\(percentText) \u{00B7} \(tokenCountText)")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign).leading(.tight))
                    .foregroundStyle(percent >= 0.80 ? barColor : theme.textTertiary)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .animation(.easeInOut(duration: 0.3), value: percent >= 0.80)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, theme.spacingXS)
            .background(theme.bgSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context window \(Int(percent * 100))% used")
        .accessibilityHint("Tap for details")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Normal usage (< 80%)
        ContextWindowBar(usedTokens: 50_000, contextWindowSize: 200_000) {}
        Divider()
        // Warning level (80–90%)
        ContextWindowBar(usedTokens: 168_000, contextWindowSize: 200_000) {}
        Divider()
        // Orange level (90–95%)
        ContextWindowBar(usedTokens: 184_000, contextWindowSize: 200_000) {}
        Divider()
        // Critical level (≥ 95%)
        ContextWindowBar(usedTokens: 195_000, contextWindowSize: 200_000) {}
    }
}
