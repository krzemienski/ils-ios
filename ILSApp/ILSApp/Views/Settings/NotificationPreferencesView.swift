import SwiftUI

// MARK: - Spec 013: Push Notifications for MCP Status

struct NotificationPreferencesView: View {
    @Environment(\.theme) private var theme: ThemeSnapshot
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
    }
}

#Preview {
    NavigationStack {
        NotificationPreferencesView()
            .environment(\.theme, ThemeSnapshot(ObsidianTheme()))
    }
}
