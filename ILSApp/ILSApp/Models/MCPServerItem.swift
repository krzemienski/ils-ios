import Foundation

// MARK: - MCP Server Model (extracted from MCPServerListView.swift)

struct MCPServerItem: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    let scope: String
    let status: String
    let configPath: String?

    // Hashable conformance for NavigationLink
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MCPServerItem, rhs: MCPServerItem) -> Bool {
        lhs.id == rhs.id
    }
}
