import SwiftUI
import ILSShared

struct SessionInfoView: View {
    let session: ChatSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Session Details") {
                    LabeledContent("Name", value: session.name ?? "Unnamed")
                    LabeledContent("Model", value: session.model.capitalized)
                    LabeledContent("Status", value: session.status.rawValue.capitalized)
                    LabeledContent("Messages", value: "\(session.messageCount)")
                }

                Section("Cost & Usage") {
                    if let cost = session.totalCostUSD {
                        LabeledContent("Total Cost", value: String(format: "$%.4f", cost))
                    } else {
                        LabeledContent("Total Cost", value: "N/A")
                    }
                }

                Section("Timestamps") {
                    LabeledContent("Created", value: session.createdAt.formatted())
                    LabeledContent("Last Active", value: session.lastActiveAt.formatted())
                }

                Section("Configuration") {
                    LabeledContent("Permission Mode", value: session.permissionMode.rawValue)
                    LabeledContent("Source", value: session.source.rawValue)
                    if let projectName = session.projectName {
                        LabeledContent("Project", value: projectName)
                    }
                }

                if let claudeId = session.claudeSessionId {
                    Section("Internal") {
                        LabeledContent("Claude Session ID", value: claudeId)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Session Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
