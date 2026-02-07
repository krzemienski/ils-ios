import SwiftUI

// MARK: - Spec 013: Push Notifications for MCP Status

struct NotificationPreferencesView: View {
    @State private var mcpOfflineAlerts = true
    @State private var mcpOnlineAlerts = false
    @State private var sessionCompleteAlerts = true
    @State private var quietHoursEnabled = false
    @State private var quietStart = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    @State private var quietEnd = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()

    var body: some View {
        List {
            Section("MCP Server Alerts") {
                Toggle("Server Goes Offline", isOn: $mcpOfflineAlerts)
                    .accessibilityLabel("Alert when MCP server goes offline")
                Toggle("Server Comes Online", isOn: $mcpOnlineAlerts)
                    .accessibilityLabel("Alert when MCP server comes online")
            }

            Section("Session Alerts") {
                Toggle("Session Complete", isOn: $sessionCompleteAlerts)
                    .accessibilityLabel("Alert when session completes")
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)
                    .accessibilityLabel("Enable quiet hours for notifications")

                if quietHoursEnabled {
                    DatePicker("Start", selection: $quietStart, displayedComponents: .hourAndMinute)
                        .accessibilityLabel("Quiet hours start time")
                    DatePicker("End", selection: $quietEnd, displayedComponents: .hourAndMinute)
                        .accessibilityLabel("Quiet hours end time")
                }
            }

            Section {
                Text("Notifications require permission. You will be prompted when enabling alerts for the first time.")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }
        }
        .darkListStyle()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
