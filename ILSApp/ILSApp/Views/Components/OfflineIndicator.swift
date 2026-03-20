import SwiftUI

/// Banner displayed when the device is offline or to indicate online connection type.
///
/// Slides in from the top with animation and shows a message
/// indicating cached data is being displayed. When offline and
/// messages are queued, shows a count of pending messages awaiting sync.
/// When online with a `connectionType` label provided, shows a slim
/// connection-type indicator instead.
struct OfflineIndicator: View {
    let isOffline: Bool
    /// Optional connection type label shown when online (e.g. "WiFi", "5G").
    var connectionType: String? = nil

    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pendingCount: Int = 0
    @State private var pendingSyncCount: Int = 0
    @State private var conflictCount: Int = 0

    private var queueLabel: String? {
        guard pendingCount > 0 else { return nil }
        return pendingCount == 1 ? "1 message queued" : "\(pendingCount) messages queued"
    }

    private var syncStatusLabel: String? {
        var parts: [String] = []
        if pendingSyncCount > 0 {
            parts.append("\(pendingSyncCount) pending")
        }
        if conflictCount > 0 {
            parts.append("\(conflictCount) \(conflictCount == 1 ? "conflict" : "conflicts")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    var body: some View {
        if isOffline {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: theme.fontCaption, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Offline \u{2014} showing cached data")
                        .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))

                    if let label = queueLabel {
                        Text(label)
                            .font(.system(size: theme.fontCaption - 1, weight: .regular, design: theme.fontDesign))
                            .opacity(0.85)
                    }

                    if let syncLabel = syncStatusLabel {
                        Text(syncLabel)
                            .font(.system(size: theme.fontCaption - 1, weight: .regular, design: theme.fontDesign))
                            .opacity(0.85)
                    }
                }
            }
            .foregroundStyle(theme.warning)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.warning.opacity(0.15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(theme.warning.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
            )
            .accessibilityLabel({
                var label = "Offline mode. Showing cached data."
                if let queue = queueLabel { label += " \(queue)." }
                if let sync = syncStatusLabel { label += " \(sync)." }
                return label
            }())
            .task {
                while !Task.isCancelled {
                    pendingCount = await SyncCoordinator.shared.pendingCount
                    let statusMap = await SyncCoordinator.shared.syncStatusMap
                    pendingSyncCount = statusMap.values.filter { $0 == .pending }.count
                    conflictCount = statusMap.values.filter { $0 == .conflict }.count
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        } else if let connType = connectionType {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: "wifi")
                    .font(.system(size: theme.fontCaption, weight: .semibold))

                Text(connType)
                    .font(.system(size: theme.fontCaption, weight: .medium, design: theme.fontDesign))
            }
            .foregroundStyle(theme.success)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.success.opacity(0.12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(theme.success.opacity(0.25), lineWidth: 0.5)
                    )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
            )
            .accessibilityLabel("Connected via \(connType).")
        }
    }
}

#Preview("Offline — no queue") {
    VStack {
        OfflineIndicator(isOffline: true)
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}

#Preview("Online — connection type") {
    VStack {
        OfflineIndicator(isOffline: false, connectionType: "WiFi")
        Spacer()
    }
    .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
}
