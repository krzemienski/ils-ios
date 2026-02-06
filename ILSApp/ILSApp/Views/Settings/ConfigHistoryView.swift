import SwiftUI

struct ConfigHistoryView: View {
    @State private var changes: [ConfigChange] = ConfigChange.sampleHistory
    @State private var selectedChange: ConfigChange?

    var body: some View {
        List {
            ForEach(changes) { change in
                ConfigChangeRow(change: change)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedChange = change }
                    .contextMenu {
                        Button {
                            // Restore action
                        } label: {
                            Label("Restore This Version", systemImage: "arrow.uturn.backward")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Config History")
        .sheet(item: $selectedChange) { change in
            NavigationStack {
                ConfigDiffView(change: change)
            }
        }
    }
}

struct ConfigChangeRow: View {
    let change: ConfigChange

    var sourceColor: Color {
        switch change.source {
        case .global: return .blue
        case .user: return .orange
        case .project: return .green
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(sourceColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(change.key)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.white)

                Text(change.description.isEmpty ? "\(change.oldValue ?? "nil") → \(change.newValue)" : change.description)
                    .font(.caption)
                    .foregroundColor(.gray)

                Text(change.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.7))
            }

            Spacer()

            Text(change.source.rawValue)
                .font(.caption2)
                .foregroundColor(sourceColor)
        }
        .padding(.vertical, 2)
    }
}

struct ConfigDiffView: View {
    let change: ConfigChange
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Change Details") {
                LabeledContent("Key", value: change.key)
                LabeledContent("Source", value: change.source.rawValue)
                LabeledContent("Time") {
                    Text(change.timestamp, style: .date)
                }
            }

            Section("Diff") {
                if let old = change.oldValue {
                    HStack {
                        Text("−")
                            .foregroundColor(.red)
                            .font(.system(.body, design: .monospaced))
                        Text(old)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                    }
                }
                HStack {
                    Text("+")
                        .foregroundColor(.green)
                        .font(.system(.body, design: .monospaced))
                    Text(change.newValue)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    Label("Restore This Version", systemImage: "arrow.uturn.backward")
                        .foregroundColor(.orange)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Change Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundColor(.orange)
            }
        }
    }
}

extension ConfigChange {
    static let sampleHistory: [ConfigChange] = [
        ConfigChange(timestamp: Date().addingTimeInterval(-3600), source: .project, key: "model", oldValue: "claude-sonnet-4-5-20250929", newValue: "claude-opus-4-5-20250929", description: "Switched to Opus for complex project"),
        ConfigChange(timestamp: Date().addingTimeInterval(-7200), source: .user, key: "permissions.mode", oldValue: "default", newValue: "plan", description: "Enabled plan mode"),
        ConfigChange(timestamp: Date().addingTimeInterval(-86400), source: .global, key: "mcpServers.memory", oldValue: nil, newValue: "enabled", description: "Added memory MCP server"),
        ConfigChange(timestamp: Date().addingTimeInterval(-172800), source: .user, key: "maxTokens", oldValue: "8192", newValue: "16384", description: "Increased token limit"),
        ConfigChange(timestamp: Date().addingTimeInterval(-259200), source: .project, key: "temperature", oldValue: "1.0", newValue: "0.7", description: "Lowered temperature for deterministic output"),
    ]
}
