import SwiftUI

// MARK: - Spec 013: Push Notifications for MCP Status

/// Notification preferences screen for configuring push alert behaviour.
///
/// Manages three categories of notification settings persisted via `@AppStorage`:
///
/// - **MCP Server Alerts** — opt in to alerts when a server goes offline or comes back online.
/// - **Session Alerts** — opt in to an alert when a Claude session completes.
/// - **Quiet Hours** — define a time window during which all notifications are suppressed.
///
/// Quiet-hour start and end times are stored as integer hours and surfaced as `Date`
/// bindings for use with `DatePicker`. All toggle changes trigger a haptic selection
/// response via ``HapticManager``.
///
/// ## Topics
/// ### Persisted State
/// - ``mcpOfflineAlerts`` - Alert when an MCP server goes offline
/// - ``mcpOnlineAlerts`` - Alert when an MCP server comes back online
/// - ``sessionCompleteAlerts`` - Alert when a Claude session finishes
/// - ``quietHoursEnabled`` - Whether the quiet-hours window is active
/// - ``quietStartHour`` - Start hour (0–23) for the quiet window
/// - ``quietEndHour`` - End hour (0–23) for the quiet window
struct NotificationPreferencesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
    @Environment(AppState.self) private var appState
    @AppStorage("notif_mcpOfflineAlerts") private var mcpOfflineAlerts = true
    @AppStorage("notif_mcpOnlineAlerts") private var mcpOnlineAlerts = false
    @AppStorage("notif_sessionCompleteAlerts") private var sessionCompleteAlerts = true
    @AppStorage("notif_quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("notif_quietStartHour") private var quietStartHour: Int = 22
    @AppStorage("notif_quietEndHour") private var quietEndHour: Int = 7

    private var quietStart: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: quietStartHour)) ?? Date() },
            set: { quietStartHour = Calendar.current.component(.hour, from: $0) }
        )
    }

    private var quietEnd: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: quietEndHour)) ?? Date() },
            set: { quietEndHour = Calendar.current.component(.hour, from: $0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingMD) {
                // MCP Server Alerts
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("MCP Server Alerts")

                    VStack(spacing: 0) {
                        toggleRow("Server Goes Offline", isOn: $mcpOfflineAlerts, accessibilityLabel: "Alert when MCP server goes offline")
                        Divider().background(theme.bgTertiary)
                        toggleRow("Server Comes Online", isOn: $mcpOnlineAlerts, accessibilityLabel: "Alert when MCP server comes online")
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // Session Alerts
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("Session Alerts")

                    VStack {
                        toggleRow("Session Complete", isOn: $sessionCompleteAlerts, accessibilityLabel: "Alert when session completes")
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // System Resource Alerts
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("System Resource Alerts")

                    VStack(spacing: 0) {
                        NavigationLink(destination: AlertThresholdSettingsView()) {
                            HStack {
                                Text("Alert Thresholds")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: theme.fontCaption, weight: .semibold))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        .accessibilityLabel("Configure system resource alert thresholds")
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // Quiet Hours
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    sectionLabel("Quiet Hours")

                    VStack(spacing: theme.spacingSM) {
                        toggleRow("Enable Quiet Hours", isOn: $quietHoursEnabled, accessibilityLabel: "Enable quiet hours for notifications")

                        if quietHoursEnabled {
                            Divider().background(theme.bgTertiary)
                            HStack {
                                Text("Start")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                DatePicker("", selection: quietStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(theme.accent)
                                    .accessibilityLabel("Quiet hours start time")
                            }
                            HStack {
                                Text("End")
                                    .font(.system(size: theme.fontBody, design: theme.fontDesign))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                DatePicker("", selection: quietEnd, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(theme.accent)
                                    .accessibilityLabel("Quiet hours end time")
                            }
                        }
                    }
                    .padding(theme.spacingMD)
                    .modifier(GlassCard())
                }

                // Info
                VStack(alignment: .leading, spacing: theme.spacingSM) {
                    Text("Notifications require permission. You will be prompted when enabling alerts for the first time.")
                        .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)

                    if appState.isSyncEnabled {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: "icloud")
                                .font(.system(size: theme.fontCaption))
                                .foregroundStyle(theme.accent)
                            Text("Synced via iCloud")
                                .font(.system(size: theme.fontCaption, design: theme.fontDesign))
                                .foregroundStyle(theme.accent)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Notification preferences synced via iCloud")
                    }
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Notifications")
        #if os(iOS)
        .inlineNavigationBarTitle()
        #endif
    }

    // MARK: - Components

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
                .kerning(1)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>, accessibilityLabel: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.fontBody, design: theme.fontDesign))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(theme.accent)
        }
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: isOn.wrappedValue) {
            HapticManager.selection()
        }
    }
}

#Preview {
    NavigationStack {
        NotificationPreferencesView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
            .environment(AppState())
    }
}
