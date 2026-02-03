import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        Label(item.rawValue, systemImage: item.icon)
                            .foregroundColor(selectedItem == item ? ILSTheme.accent : ILSTheme.primaryText)
                    }
                    .listRowBackground(selectedItem == item ? ILSTheme.accent.opacity(0.1) : Color.clear)
                    .accessibilityIdentifier("sidebar_\(item.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))")
                    .accessibilityLabel(item.rawValue)
                    .accessibilityHint("Navigate to \(item.rawValue) section")
                    .accessibilityAddTraits(selectedItem == item ? .isSelected : [])
                }
            }

            Section("Connection") {
                HStack {
                    Circle()
                        .fill(appState.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(appState.isConnected ? "Connected" : "Disconnected")
                        .font(ILSTheme.captionFont)
                        .foregroundColor(ILSTheme.secondaryText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(appState.isConnected ? "Connected to server" : "Disconnected from server")

                if let project = appState.selectedProject {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Project")
                            .font(ILSTheme.captionFont)
                            .foregroundColor(ILSTheme.tertiaryText)
                        Text(project.name)
                            .font(ILSTheme.bodyFont)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Active project: \(project.name)")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ILS")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { appState.checkConnection() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityIdentifier("refreshConnectionButton")
                .accessibilityLabel("Refresh connection")
                .accessibilityHint("Check server connection status")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SidebarView(selectedItem: .constant(.sessions))
            .environmentObject(AppState())
    }
}
