import Fluent
import Vapor
import Foundation
import ILSShared

/// Fluent model for Configuration Profile
final class ConfigProfileModel: Model, Content, @unchecked Sendable {
    static let schema = "config_profiles"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "is_default")
    var isDefault: Bool

    @Field(key: "is_active")
    var isActive: Bool

    @OptionalField(key: "model")
    var model: String?

    /// JSON-encoded ProfilePermissions
    @OptionalField(key: "permissions")
    var permissions: String?

    @OptionalField(key: "custom_instructions")
    var customInstructions: String?

    /// JSON-encoded [String] array of MCP server names
    @OptionalField(key: "mcp_server_names")
    var mcpServerNames: String?

    /// JSON-encoded [String] array of linked project paths
    @OptionalField(key: "linked_project_paths")
    var linkedProjectPaths: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        isDefault: Bool = false,
        isActive: Bool = false,
        model: String? = nil,
        permissions: ProfilePermissions? = nil,
        customInstructions: String? = nil,
        mcpServerNames: [String]? = nil,
        linkedProjectPaths: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isActive = isActive
        self.model = model
        self.permissions = permissions.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.customInstructions = customInstructions
        self.mcpServerNames = mcpServerNames.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
        self.linkedProjectPaths = linkedProjectPaths.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) }
    }

    /// Convert to shared ConfigProfile type
    func toShared() -> ConfigProfile {
        let decoder = JSONDecoder()

        let decodedPermissions: ProfilePermissions? = permissions
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? decoder.decode(ProfilePermissions.self, from: $0) }

        let decodedMcpServerNames: [String]? = mcpServerNames
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? decoder.decode([String].self, from: $0) }

        let decodedLinkedProjectPaths: [String]? = linkedProjectPaths
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? decoder.decode([String].self, from: $0) }

        return ConfigProfile(
            id: id ?? UUID(),
            name: name,
            isDefault: isDefault,
            isActive: isActive,
            model: model,
            permissions: decodedPermissions,
            customInstructions: customInstructions,
            mcpServerNames: decodedMcpServerNames,
            linkedProjectPaths: decodedLinkedProjectPaths,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}
