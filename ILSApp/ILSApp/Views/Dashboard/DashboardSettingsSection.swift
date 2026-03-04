import SwiftUI
import ILSShared

// MARK: - Dashboard Settings Section

/// Dashboard configuration section for the Settings screen.
///
/// Provides controls for:
/// - **iCloud Sync** — toggles cross-device layout sync via `DashboardLayoutStore.iCloudSyncEnabled`
/// - **Manage Layouts** — navigation link to ``DashboardLayoutPickerView``
/// - **Widget Refresh** — picker for the auto-refresh interval (15 s / 30 s / 1 min / 5 min)
/// - **Reset to Default Layout** — destructive button that calls `DashboardLayoutStore.resetToDefault()`
struct DashboardSettingsSection: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(DashboardLayoutStore.self) var layoutStore

    @State private var showResetConfirmation = false
    @State private var refreshInterval: Int = {
        let stored = UserDefaults.standard.integer(forKey: AppConstants.dashboardWidgetRefreshIntervalKey)
        return stored == 0 ? 30 : stored
    }()

    private let refreshIntervalOptions: [(label: String, seconds: Int)] = [
        ("15 sec", 15),
        ("30 sec", 30),
        ("1 min",  60),
        ("5 min",  300),
    ]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSM) {
            sectionLabel("Dashboard")

            VStack(spacing: 0) {
                iCloudSyncRow
                Divider().background(theme.borderSubtle)
                manageLayoutsRow
                Divider().background(theme.borderSubtle)
                refreshIntervalRow
                Divider().background(theme.borderSubtle)
                resetLayoutRow
            }
            .modifier(GlassCard())
        }
        .confirmationDialog(
            "Reset to Default Layout?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                layoutStore.resetToDefault()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This replaces all layouts with the built-in Developer, DevOps, and Team Lead presets.")
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private var iCloudSyncRow: some View {
        Toggle(isOn: Binding(
            get: { layoutStore.iCloudSyncEnabled },
            set: { layoutStore.iCloudSyncEnabled = $0 }
        )) {
            HStack(spacing: theme.spacingMD) {
                iconView("icloud.fill", color: theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud Sync")
                        .font(.system(size: theme.fontBody, design: theme.fontDesign))
                        .foregroundStyle(theme.textPrimary)
                    Text("Sync layouts across your devices")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .tint(theme.accent)
        .padding(theme.spacingMD)
    }

    @ViewBuilder
    private var manageLayoutsRow: some View {
        NavigationLink {
            DashboardLayoutPickerView()
        } label: {
            HStack(spacing: theme.spacingMD) {
                iconView("square.grid.2x2.fill", color: theme.accent)
                Text("Manage Layouts")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(theme.spacingMD)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var refreshIntervalRow: some View {
        HStack(spacing: theme.spacingMD) {
            iconView("arrow.clockwise", color: theme.textSecondary)
            Text("Widget Refresh")
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Picker("Widget Refresh", selection: $refreshInterval) {
                ForEach(refreshIntervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            .pickerStyle(.menu)
            .tint(theme.accent)
            .labelsHidden()
            .onChange(of: refreshInterval) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: AppConstants.dashboardWidgetRefreshIntervalKey)
            }
        }
        .padding(theme.spacingMD)
    }

    @ViewBuilder
    private var resetLayoutRow: some View {
        Button(role: .destructive) {
            showResetConfirmation = true
        } label: {
            HStack(spacing: theme.spacingMD) {
                iconView("arrow.counterclockwise", color: theme.error)
                Text("Reset to Default Layout")
                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                    .foregroundStyle(theme.error)
                Spacer()
            }
            .padding(theme.spacingMD)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func iconView(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: theme.fontBody, design: theme.fontDesign))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
            .kerning(1)
    }
}

// MARK: - Preview

#Preview {
    let store = DashboardLayoutStore()
    return NavigationStack {
        ScrollView {
            DashboardSettingsSection()
                .padding()
        }
        .environment(store)
        .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
