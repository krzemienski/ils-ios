import SwiftUI

// MARK: - Spec 021: Configuration Sharing via Cloud Sync

struct CloudSyncView: View {
    @State private var iCloudEnabled = false
    @State private var syncSettings = true
    @State private var syncMCPConfigs = true
    @State private var syncSkills = false
    @State private var lastSyncDate: Date?

    var body: some View {
        List {
            Section("iCloud Sync") {
                Toggle("Enable iCloud Sync", isOn: $iCloudEnabled)

                if iCloudEnabled {
                    Toggle("Sync Settings", isOn: $syncSettings)
                    Toggle("Sync MCP Configurations", isOn: $syncMCPConfigs)
                    Toggle("Sync Skills", isOn: $syncSkills)
                }
            }

            if iCloudEnabled {
                Section("Status") {
                    LabeledContent("Last Sync") {
                        if let lastSyncDate {
                            Text(lastSyncDate, style: .relative)
                                .foregroundColor(ILSTheme.secondaryText)
                        } else {
                            Text("Never")
                                .foregroundColor(ILSTheme.tertiaryText)
                        }
                    }

                    Button {
                        HapticManager.impact(.medium)
                        lastSyncDate = Date()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync Now")
                        }
                    }
                }
            }

            Section {
                Text("Cloud sync allows sharing configurations across devices signed into the same iCloud account.")
                    .font(ILSTheme.captionFont)
                    .foregroundColor(ILSTheme.secondaryText)
            }
        }
        .darkListStyle()
        .navigationTitle("Cloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }
}
