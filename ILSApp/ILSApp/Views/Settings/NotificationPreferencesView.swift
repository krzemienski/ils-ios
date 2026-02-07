import SwiftUI

// MARK: - Spec 013: Push Notifications for MCP Status

struct NotificationPreferencesView: View {
    @Environment(\.theme) private var theme: any AppTheme
    @State private var mcpOfflineAlerts = true
    @State private var mcpOnlineAlerts = false
    @State private var sessionCompleteAlerts = true
    @State private var quietHoursEnabled = false
    @State private var quietStart = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    @State private var quietEnd = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()

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
                                    .font(.system(size: theme.fontBody))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                DatePicker("", selection: $quietStart, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(theme.accent)
                                    .accessibilityLabel("Quiet hours start time")
                            }
                            HStack {
                                Text("End")
                                    .font(.system(size: theme.fontBody))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                DatePicker("", selection: $quietEnd, displayedComponents: .hourAndMinute)
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
                        .font(.system(size: theme.fontCaption))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
        }
        .background(theme.bgPrimary)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: theme.fontCaption, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, isOn: Binding<Bool>, accessibilityLabel: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: theme.fontBody))
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
            .environment(\.theme, ObsidianTheme())
    }
}
