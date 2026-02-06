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
                Toggle("Server Comes Online", isOn: $mcpOnlineAlerts)
            }

            Section("Session Alerts") {
                Toggle("Session Complete", isOn: $sessionCompleteAlerts)
            }

            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $quietHoursEnabled)

                if quietHoursEnabled {
                    DatePicker("Start", selection: $quietStart, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $quietEnd, displayedComponents: .hourAndMinute)
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
