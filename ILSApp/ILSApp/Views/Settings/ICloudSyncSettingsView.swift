import SwiftUI

// MARK: - Spec 169: iCloud Cross-Device Sync

/// iCloud sync settings screen for configuring and monitoring cross-device synchronisation.
///
/// Surfaces three controls backed by ``ICloudSyncManager``:
///
/// - **Sync Enabled** — per-device toggle that writes to `UserDefaults` via
///   `ICloudSyncManager.setSyncEnabled(_:)`.
/// - **Sync Status** — live readout of the current ``ICloudSyncStatus`` plus the
///   time of the most recent successful synchronisation.
/// - **Sync Now** — manually triggers `syncPreferencesToCloud()` to push the latest
///   local preferences up to iCloud immediately.
///
/// The view observes `ICloudSyncManager.shared` via `@Observable` so all status
/// and date changes are reflected without any manual refresh logic.
///
/// ## Topics
/// ### Observed State
/// - ``syncManager`` - Shared singleton driving sync operations
struct ICloudSyncSettingsView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot

    // ICloudSyncManager is @Observable — SwiftUI tracks property access automatically.
    private let syncManager = ICloudSyncManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                syncToggleSection

                syncStatusSection

                infoSection
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("iCloud Sync")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }

    // MARK: - Sections

    @ViewBuilder
    private var syncToggleSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Sync Settings")

            VStack(spacing: 0) {
                HStack {
                    Text("Enable iCloud Sync")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { syncManager.isSyncEnabled },
                        set: { enabled in
                            syncManager.setSyncEnabled(enabled)
                            HapticManager.selection()
                        }
                    ))
                    .labelsHidden()
                    .tint(theme.accent)
                }
                .accessibilityLabel("Enable iCloud sync for this device")
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    @ViewBuilder
    private var syncStatusSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Status")

            VStack(spacing: 0) {
                statusRow

                Divider().background(theme.bgTertiary)

                lastSyncRow

                if syncManager.isSyncEnabled {
                    Divider().background(theme.bgTertiary)
                    syncNowButton
                }
            }
            .padding(theme.spacingMD)
            .modifier(GlassCard())
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack {
            Text("Status")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: theme.spacingXS) {
                statusIndicator
                Text(statusLabel)
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(statusColor)
            }
        }
        .accessibilityLabel("Sync status: \(statusLabel)")
    }

    @ViewBuilder
    private var lastSyncRow: some View {
        HStack {
            Text("Last Synced")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(lastSyncText)
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityLabel("Last synced: \(lastSyncText)")
        .padding(.top, theme.spacingSM)
    }

    @ViewBuilder
    private var syncNowButton: some View {
        Button {
            HapticManager.impact(.light)
            syncManager.syncPreferencesToCloud()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                    .foregroundStyle(theme.accent)
                Text("Sync Now")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.accent)
                Spacer()
            }
        }
        .disabled(syncManager.syncStatus == .syncing)
        .padding(.top, theme.spacingSM)
        .accessibilityLabel("Manually trigger iCloud sync now")
    }

    @ViewBuilder
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            Text("iCloud sync keeps your preferences, notification settings, and server configuration in sync across all your devices. Disabling sync on this device will not affect other devices.")
                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                .foregroundStyle(theme.textTertiary)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusLabel: String {
        switch syncManager.syncStatus {
        case .idle:       return syncManager.isSyncEnabled ? "Up to Date" : "Disabled"
        case .syncing:    return "Syncing…"
        case .error:      return "Error"
        case .disabled:   return "Disabled"
        }
    }

    private var statusColor: Color {
        switch syncManager.syncStatus {
        case .idle:       return syncManager.isSyncEnabled ? theme.success : theme.textTertiary
        case .syncing:    return theme.accent
        case .error:      return theme.error
        case .disabled:   return theme.textTertiary
        }
    }

    private var lastSyncText: String {
        guard let date = syncManager.lastSyncDate else {
            return "Never"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        ICloudSyncSettingsView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
