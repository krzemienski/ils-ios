import SwiftUI

struct FleetManagementView: View {
    @State private var servers: [RemoteServer] = RemoteServer.sampleFleet
    @State private var selectedGroup: String? = nil

    var groups: [String] {
        Array(Set(servers.compactMap { $0.group })).sorted()
    }

    var filteredServers: [RemoteServer] {
        guard let group = selectedGroup else { return servers }
        return servers.filter { $0.group == group }
    }

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FleetStatCard(title: "Total", value: "\(servers.count)", icon: "server.rack")
                        FleetStatCard(title: "Online", value: "\(servers.filter { $0.status == .online }.count)", icon: "checkmark.circle", color: .green)
                        FleetStatCard(title: "Degraded", value: "\(servers.filter { $0.status == .degraded }.count)", icon: "exclamationmark.triangle", color: .orange)
                        FleetStatCard(title: "Offline", value: "\(servers.filter { $0.status == .offline }.count)", icon: "xmark.circle", color: .red)
                    }
                    .padding(.horizontal, 4)
                }
            } header: {
                Text("Fleet Overview")
            }
            .listRowBackground(Color.clear)

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: selectedGroup == nil) { selectedGroup = nil }
                        ForEach(groups, id: \.self) { group in
                            FilterChip(label: group, isSelected: selectedGroup == group) { selectedGroup = group }
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)

            Section("Servers") {
                ForEach(filteredServers) { server in
                    RemoteServerRow(server: server)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Fleet Management")
    }
}

struct FleetStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .orange

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 80, height: 80)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.orange : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .black : .white)
                .cornerRadius(16)
        }
    }
}

struct RemoteServerRow: View {
    let server: RemoteServer

    var statusColor: Color {
        switch server.status {
        case .online: return .green
        case .offline: return .red
        case .degraded: return .orange
        case .unknown: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(server.username)@\(server.host)")
                    .font(.caption)
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    if let version = server.claudeVersion {
                        Text("v\(version)")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                    Text("\(server.skillCount) skills")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(server.mcpServerCount) MCP")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Text(server.status.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
