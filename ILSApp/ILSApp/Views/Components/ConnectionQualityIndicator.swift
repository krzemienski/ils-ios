import SwiftUI

/// Compact connection quality indicator showing a colored status dot and optional latency.
///
/// Supports two display modes:
/// - **compact**: dot only — suitable for navigation bars or tight spaces
/// - **expanded**: dot + latency text — suitable for status areas where detail is welcome
///
/// Colors map directly to connection quality tiers:
/// - Excellent (< 50ms) → green
/// - Good (< 150ms) → yellow
/// - Fair (< 500ms) → orange
/// - Poor (≥ 500ms) → red
/// - Offline → gray
struct ConnectionQualityIndicator: View {

    // MARK: - Display Mode

    enum DisplayMode {
        /// Dot only — minimal footprint for navigation bars.
        case compact
        /// Dot and latency/status text — more detail for status areas.
        case expanded
    }

    // MARK: - Input

    let quality: ConnectionQuality
    let latencyMs: Double?
    var mode: DisplayMode = .compact

    // MARK: - Environment

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        HStack(spacing: theme.spacingXS) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            if mode == .expanded {
                Text(statusText)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private Helpers

    /// Color representing the current connection quality tier.
    private var dotColor: Color {
        switch quality {
        case .excellent: return theme.success
        case .good:      return theme.warning
        case .fair:      return theme.warning.opacity(0.8)
        case .poor:      return theme.error
        case .offline:   return theme.textTertiary
        }
    }

    /// Short status string for the expanded label (e.g. "42ms", "Offline").
    private var statusText: String {
        switch quality {
        case .offline:
            return "Offline"
        default:
            if let ms = latencyMs {
                return "\(Int(ms))ms"
            }
            return quality.label
        }
    }

    /// Full VoiceOver description of connection state.
    private var accessibilityLabel: String {
        switch quality {
        case .offline:
            return "Connection offline"
        default:
            if let ms = latencyMs {
                return "Connection \(quality.label), \(Int(ms)) milliseconds latency"
            }
            return "Connection \(quality.label)"
        }
    }
}

// MARK: - Previews

#Preview("Compact mode") {
    HStack(spacing: 16) {
        ConnectionQualityIndicator(quality: .excellent, latencyMs: 30)
        ConnectionQualityIndicator(quality: .good, latencyMs: 120)
        ConnectionQualityIndicator(quality: .fair, latencyMs: 350)
        ConnectionQualityIndicator(quality: .poor, latencyMs: 800)
        ConnectionQualityIndicator(quality: .offline, latencyMs: nil)
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}

#Preview("Expanded mode") {
    VStack(alignment: .leading, spacing: 12) {
        ConnectionQualityIndicator(quality: .excellent, latencyMs: 30, mode: .expanded)
        ConnectionQualityIndicator(quality: .good, latencyMs: 120, mode: .expanded)
        ConnectionQualityIndicator(quality: .fair, latencyMs: 350, mode: .expanded)
        ConnectionQualityIndicator(quality: .poor, latencyMs: 800, mode: .expanded)
        ConnectionQualityIndicator(quality: .offline, latencyMs: nil, mode: .expanded)
    }
    .padding()
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
