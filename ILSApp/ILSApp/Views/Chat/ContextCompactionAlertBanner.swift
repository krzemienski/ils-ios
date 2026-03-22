import SwiftUI

/// Dismissible in-app banner warning that context compaction is imminent.
///
/// Shown when context window usage crosses the 85%, 90%, or 95% threshold.
/// Displays a severity-colored warning with the current usage percentage and
/// action buttons to fork the session, save a snapshot, or dismiss the alert.
///
/// The parent view is responsible for deciding when to present this banner.
/// Severity is determined automatically from `usedTokens` / `contextWindowSize`.
///
/// ## Severity Levels
/// - **warning** (85–90%): Yellow — "Approaching compaction threshold"
/// - **serious** (90–95%): Orange — "Compaction imminent"
/// - **critical** (≥ 95%): Red — "Compaction imminent — action required"
///
/// ## Topics
/// ### Input Properties
/// - ``usedTokens`` - Number of tokens consumed in the context window
/// - ``contextWindowSize`` - Maximum context window capacity
/// - ``onForkSession`` - Closure invoked when the user taps Fork Session
/// - ``onSaveSnapshot`` - Closure invoked when the user taps Save Snapshot
/// - ``onDismiss`` - Closure invoked when the user dismisses the banner
struct ContextCompactionAlertBanner: View {
    /// Number of tokens consumed so far.
    let usedTokens: Int
    /// Maximum capacity of the context window.
    let contextWindowSize: Int
    /// Called when the user taps "Fork Session" to continue in a fresh context.
    let onForkSession: () -> Void
    /// Called when the user taps "Save Snapshot" to preserve current context.
    let onSaveSnapshot: () -> Void
    /// Called when the user dismisses the banner.
    let onDismiss: () -> Void
    /// Optional: Called when the user taps "Auto-Fork Settings" to open context preservation settings.
    var onAutoForkSettings: (() -> Void)? = nil

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Computed Properties

    /// Usage ratio clamped to [0, 1].
    private var percent: Double {
        guard contextWindowSize > 0 else { return 0 }
        return min(Double(usedTokens) / Double(contextWindowSize), 1.0)
    }

    /// Threshold-based severity level derived from current usage.
    private var severity: CompactionAlertSeverity {
        switch percent {
        case ..<0.85: return .warning
        case 0.85..<0.90: return .warning
        case 0.90..<0.95: return .serious
        default: return .critical
        }
    }

    /// Severity-mapped accent color for icons, text, and borders.
    private var severityColor: Color {
        switch severity {
        case .warning: return theme.warning
        case .serious: return .orange
        case .critical: return theme.error
        }
    }

    /// Short contextual message describing the urgency of the alert.
    private var severityMessage: String {
        switch severity {
        case .warning: return "Approaching compaction threshold"
        case .serious: return "Compaction imminent"
        case .critical: return "Compaction imminent — action required"
        }
    }

    private var percentText: String {
        "\(Int(percent * 100))%"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            actionButtonRow
        }
        .background(severityColor.opacity(0.10))
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(severityColor)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Context compaction alert: \(percentText) full. \(severityMessage).")
    }

    // MARK: - Header Row

    /// Top row: icon, severity message, percentage, and dismiss button.
    private var headerRow: some View {
        HStack(spacing: theme.spacingSM) {
            Image(systemName: severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: theme.fontBody, weight: .semibold))
                .foregroundStyle(severityColor)
                .contentTransition(.symbolEffect(.replace))
                .animation(.easeInOut(duration: 0.3), value: severity == .critical)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(severityMessage)
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(severityColor)

                    Text("\u{00B7}")
                        .foregroundStyle(theme.textTertiary)

                    Text(percentText)
                        .font(
                            .system(size: theme.fontBody, weight: .bold, design: theme.fontDesign)
                            .monospacedDigit()
                        )
                        .foregroundStyle(severityColor)
                        .contentTransition(.numericText())
                }

                Text("Context window \(percentText) full — earlier messages may be truncated")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: theme.fontCaption, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingXS)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss context compaction alert")
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.top, theme.spacingMD)
        .padding(.bottom, theme.spacingSM)
    }

    // MARK: - Action Button Row

    /// Bottom row: Fork Session and Save Snapshot action buttons, with optional settings link.
    private var actionButtonRow: some View {
        VStack(spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingSM) {
                Button(action: onForkSession) {
                    Label("Fork Session", systemImage: "arrow.branch")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(severityColor)
                        .foregroundStyle(theme.textOnAccent)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fork session to continue with a fresh context window")

                Button(action: onSaveSnapshot) {
                    Label("Save Snapshot", systemImage: "camera")
                        .font(.system(size: theme.fontBody, weight: .semibold, design: theme.fontDesign))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, theme.spacingSM)
                        .background(severityColor.opacity(0.15))
                        .foregroundStyle(severityColor)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save a snapshot of the current context before compaction")
            }

            if let onAutoForkSettings {
                Button(action: onAutoForkSettings) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: theme.fontCaption, weight: .medium))
                        Text("Auto-Fork Settings")
                            .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    }
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open auto-fork settings")
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.bottom, theme.spacingMD)
    }
}

// MARK: - Supporting Types

/// Severity level for a context compaction alert banner.
private enum CompactionAlertSeverity {
    /// 85–90%: Yellow warning — context approaching compaction threshold.
    case warning
    /// 90–95%: Orange — compaction is imminent.
    case serious
    /// ≥ 95%: Red critical — compaction will occur imminently, action required.
    case critical
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Warning level (85–90%)
        ContextCompactionAlertBanner(
            usedTokens: 172_000,
            contextWindowSize: 200_000,
            onForkSession: {},
            onSaveSnapshot: {},
            onDismiss: {}
        )
        Divider()
        // Serious level (90–95%)
        ContextCompactionAlertBanner(
            usedTokens: 184_000,
            contextWindowSize: 200_000,
            onForkSession: {},
            onSaveSnapshot: {},
            onDismiss: {}
        )
        Divider()
        // Critical level (≥ 95%)
        ContextCompactionAlertBanner(
            usedTokens: 195_000,
            contextWindowSize: 200_000,
            onForkSession: {},
            onSaveSnapshot: {},
            onDismiss: {}
        )
    }
}
