import Foundation

/// Represents an MCP tool provided by a server
public struct MCPTool: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var description: String
    public var inputSchema: String?

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        inputSchema: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}
