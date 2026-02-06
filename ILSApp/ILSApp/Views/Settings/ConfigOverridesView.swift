import SwiftUI

struct ConfigOverridesView: View {
    let overrides: [ConfigOverrideItem] = ConfigOverrideItem.sampleData

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Circle().fill(Color.blue).frame(width: 10, height: 10)
                    Text("Global").font(.caption)
                    Circle().fill(Color.orange).frame(width: 10, height: 10)
                    Text("User").font(.caption)
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                    Text("Project").font(.caption)
                }
                .foregroundColor(.gray)
                .padding(.vertical, 4)
            } header: {
                Text("Override Precedence: Project > User > Global")
            }

            Section("Model Settings") {
                ForEach(overrides.filter { $0.category == "model" }) { item in
                    ConfigOverrideRow(item: item)
                }
            }

            Section("Permission Settings") {
                ForEach(overrides.filter { $0.category == "permissions" }) { item in
                    ConfigOverrideRow(item: item)
                }
            }

            Section("MCP Settings") {
                ForEach(overrides.filter { $0.category == "mcp" }) { item in
                    ConfigOverrideRow(item: item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Config Overrides")
    }
}

struct ConfigOverrideItem: Identifiable {
    let id = UUID()
    let key: String
    let globalValue: String?
    let userValue: String?
    let projectValue: String?
    let effectiveValue: String
    let source: ConfigChange.ConfigSource
    let category: String

    static let sampleData: [ConfigOverrideItem] = [
        ConfigOverrideItem(key: "model", globalValue: "claude-sonnet-4-5-20250929", userValue: "claude-sonnet-4-5-20250929", projectValue: nil, effectiveValue: "claude-sonnet-4-5-20250929", source: .user, category: "model"),
        ConfigOverrideItem(key: "temperature", globalValue: "1.0", userValue: nil, projectValue: "0.7", effectiveValue: "0.7", source: .project, category: "model"),
        ConfigOverrideItem(key: "maxTokens", globalValue: "8192", userValue: "16384", projectValue: nil, effectiveValue: "16384", source: .user, category: "model"),
        ConfigOverrideItem(key: "permissions.mode", globalValue: "default", userValue: nil, projectValue: "plan", effectiveValue: "plan", source: .project, category: "permissions"),
        ConfigOverrideItem(key: "permissions.allowedTools", globalValue: "[]", userValue: nil, projectValue: "[\"Bash\", \"Read\"]", effectiveValue: "[\"Bash\", \"Read\"]", source: .project, category: "permissions"),
        ConfigOverrideItem(key: "mcpServers.filesystem", globalValue: "enabled", userValue: nil, projectValue: nil, effectiveValue: "enabled", source: .global, category: "mcp"),
        ConfigOverrideItem(key: "mcpServers.memory", globalValue: nil, userValue: "enabled", projectValue: "disabled", effectiveValue: "disabled", source: .project, category: "mcp"),
    ]
}

struct ConfigOverrideRow: View {
    let item: ConfigOverrideItem

    var sourceColor: Color {
        switch item.source {
        case .global: return .blue
        case .user: return .orange
        case .project: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.key)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text(item.source.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(sourceColor.opacity(0.2))
                    .foregroundColor(sourceColor)
                    .clipShape(Capsule())
            }

            Text(item.effectiveValue)
                .font(.caption)
                .foregroundColor(.gray)

            if let projectVal = item.projectValue, item.source == .project {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                    Text("Overrides: \(item.userValue ?? item.globalValue ?? "default")")
                        .font(.caption2)
                }
                .foregroundColor(.orange.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }
}
